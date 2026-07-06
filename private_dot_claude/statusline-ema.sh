#!/usr/bin/env bash
# Pure EMA projection for the status line. No clock, no file I/O — `now` is an
# argument so the function is fully deterministic and unit-testable.
#
# Args (positional):
#   1  now              epoch seconds (caller passes the clock)
#   2  used_now         current used percentage (float ok)
#   3  resets_at_now    window reset epoch (from the JSON)
#   4  window_sec       window length in seconds
#   5  halflife_sec     EMA half-life
#   6  min_dt_sec       minimum Δt to accept a sample
#   7  min_elapsed_sec  EMA display gate (elapsed since window start)
#   8  flat_pp          flat-glyph threshold, percentage points
#   9  lin_proj         linear projection (int) or NA
#   10 lin_shown        1 if linear is trustworthy (elapsed >= 10%), else 0
#   11 prev_last_ts     prior state, or NA (cold start)
#   12 prev_last_used   prior state, or NA
#   13 prev_ema_rate    prior state, or NA
#   14 prev_resets_at   prior state, or NA
#
# Prints: new_last_ts new_last_used new_ema_rate new_resets_at ema_ready ema_proj glyph reset_flag
ema_project() {
  awk -v now="$1" -v used="$2" -v rst="$3" -v win="$4" -v hl="$5" \
      -v mindt="$6" -v minel="$7" -v flat="$8" -v linp="$9" -v lins="${10}" \
      -v pts="${11}" -v pu="${12}" -v pr="${13}" -v prst="${14}" '
  BEGIN {
    OFMT = "%.9g"
    cold = (pts == "NA")

    # Stale-sample guard: a window whose resets_at is already at/in the past cannot
    # be the current window — it is noise in the input JSON. Ignore the sample
    # entirely: hold prior state and, crucially, do NOT persist the stale resets_at
    # (which would later look like a forward jump and trigger a phantom reset).
    if ((rst + 0) <= (now + 0)) {
      if (cold) print "NA", "NA", "NA", "NA", 0, "NA", "NA", 0
      else      print pts, pu, pr, prst, 0, "NA", "NA", 0
      exit
    }

    # A reset is a genuine window rollover, signalled by resets_at jumping
    # forward. used_percentage is NOT monotonic (it can dip and recover), so a
    # mere decrease is treated as noise, never a reset.
    reset = 0
    if (!cold && (rst + 0) - (prst + 0) > win / 2) reset = 1

    remaining = rst - now
    if (remaining < 0) remaining = 0
    elapsed = win - remaining

    if (cold || reset) {
      print now, used, "NA", rst, 0, "NA", "NA", reset
      exit
    }

    dt = now - pts
    # Hold the anchor when the sample is too close in time (dt < mindt) OR when used
    # dipped below the anchor. used is non-monotonic; moving the anchor down to a
    # transient dip makes the subsequent recovery read as a huge burst (whiplash).
    # Holding keeps the dip-then-recover net rate near zero.
    if (dt < mindt || (used + 0) < (pu + 0)) {
      out_ts = pts; out_used = pu; out_rate = pr; out_rst = prst
    } else {
      rate = (used - pu) / dt
      if (rate < 0) rate = 0   # defensive: float noise only; real dips are held above
      if (pr == "NA") {
        out_rate = rate
      } else {
        tau = hl / log(2)
        alpha = 1 - exp(-dt / tau)
        out_rate = alpha * rate + (1 - alpha) * (pr + 0)
      }
      out_ts = now; out_used = used; out_rst = rst
    }

    if (out_rate == "NA") {
      print out_ts, out_used, out_rate, out_rst, 0, "NA", "NA", 0
      exit
    }

    pe = used + out_rate * remaining
    if (pe < 0) pe = 0
    proj = int(pe + 0.5)

    if (elapsed < minel) {
      print out_ts, out_used, out_rate, out_rst, 0, "NA", "NA", 0
      exit
    }

    glyph = "FLAT"
    if (lins + 0 == 1 && linp != "NA") {
      if (proj > linp + flat)      glyph = "UP"
      else if (proj < linp - flat) glyph = "DOWN"
    }
    print out_ts, out_used, out_rate, out_rst, 1, proj, glyph, 0
  }'
}

# --- Portable advisory lock (macOS ships no flock) --------------------------
# Serializes the shared-state read-modify-write so concurrent Claude sessions
# can't feed one EMA file interleaved, differently-timed samples. mkdir is
# atomic across processes. Best-effort: bounded wait, reclaim a lock abandoned
# by a crashed session, and fall back to lockless rather than hang the prompt.
STATUSLINE_LOCK_STALE_SEC=${STATUSLINE_LOCK_STALE_SEC:-10}
STATUSLINE_LOCK_TRIES=${STATUSLINE_LOCK_TRIES:-15}

# acquire_lock <lockdir> <now_epoch> -> 0 held, 1 gave up (caller runs lockless)
acquire_lock() {
  local lock="$1" now="$2" i=0 ts
  while ! mkdir "$lock" 2>/dev/null; do
    # Reclaim a lock whose holder crashed without releasing it. The counter
    # below always advances, so a reclaim that can't remove the dir still
    # degrades to lockless instead of spinning forever.
    ts=$(cat "$lock/ts" 2>/dev/null)
    case "$ts" in
      ''|*[!0-9]*) : ;;
      *) [ $(( now - ts )) -ge "$STATUSLINE_LOCK_STALE_SEC" ] && rm -rf "$lock" 2>/dev/null ;;
    esac
    i=$(( i + 1 ))
    [ "$i" -ge "$STATUSLINE_LOCK_TRIES" ] && return 1
    sleep 0.02
  done
  printf '%s' "$now" > "$lock/ts" 2>/dev/null
  return 0
}

# release_lock <lockdir>
release_lock() {
  rm -rf "$1" 2>/dev/null
}
