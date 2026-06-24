# Statusline EMA Usage Forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an EMA-based (recency-weighted) end-of-period usage forecast next to the existing linear forecast in the Claude Code status line, with a trend glyph showing whether recent pace runs hotter or cooler than the window average.

**Architecture:** All EMA decision logic (reset detection, sampling guard, time-based EMA update, projection, display gating, trend-glyph selection) lives in one pure, clock-free, I/O-free Bash function `ema_project()` in a new file `private_dot_claude/statusline-ema.sh`. The existing `statusline-command.sh` sources it and supplies the impure parts (the clock, reading/writing per-window state files, ANSI coloring). The pure function is unit-tested with a dependency-free Bash test harness; the integration is tested by piping a crafted JSON through the script with an injected clock.

**Tech Stack:** Bash, `awk` (float math; `exp`/`log` are POSIX awk), `jq` (already used by the script), chezmoi (dotfile management).

## Global Constraints

These are copied verbatim from the design spec and apply to every task.

- **EMA model:** `rate = (used_now − used_prev) / Δt`; `α = 1 − exp(−Δt / tau)`; `ema_rate = α·rate + (1−α)·ema_rate_prev`; `tau = half_life / ln(2)`. First rate after reset/cold-start seeds `ema_rate = rate`.
- **Projection:** `projected_ema = used_now + ema_rate · remaining_sec`, clamped at ≥ 0. `ema_rate` is a slope (%/sec) only; the level always comes from the fresh `used_now`.
- **Parameters (env-overridable), defaults:** 5h half-life `3600`, 7d half-life `86400`, 5h min-elapsed gate `1800`, 7d min-elapsed gate `14400`, min Δt `20`, flat-glyph threshold `2` pp. Env vars: `STATUSLINE_EMA_HALFLIFE_5H_SEC`, `STATUSLINE_EMA_HALFLIFE_7D_SEC`, `STATUSLINE_EMA_MINELAPSED_5H_SEC`, `STATUSLINE_EMA_MINELAPSED_7D_SEC`, `STATUSLINE_EMA_MIN_DT_SEC`, `STATUSLINE_EMA_FLAT_THRESHOLD_PP`.
- **Reset detection (planned + sudden, uniform):** reset if `used_now < last_used` OR `resets_at` jumped forward by more than `window_sec / 2`. On reset: skip the boundary rate sample, re-anchor (`last_ts=now`, `last_used=used_now`, `resets_at=new`), and **clear** `ema_rate`.
- **Display gates:** linear shown when `elapsed ≥ 10% of window` (existing guard, numeric necessity). EMA shown when `ema_rate` exists (≥2 samples since reset) AND `elapsed-since-reset ≥ min-elapsed gate`. Real-time gate, not sample count. EMA may appear before linear for the 7d window.
- **Δt < 20s:** skip the EMA update (keep anchor + slope), still display the held value.
- **Display format (compact, no spaces):** `used%` neutral, `→linear` colored by its own threshold, trend glyph (`↗` hotter / `↘` cooler / `~` flat) neutral, `ema` colored by its own threshold. Color ladder: ≤80 blue, ≤100 green, ≤130 yellow, >130 red. No textual `5h`/`7d` label. Layouts: both → `34%→68↘61`; linear only → `34%→68`; EMA only → `34%~61`; neither → `34%`.
- **State files (runtime, not chezmoi-managed):** `~/.claude/.statusline-ema-5h`, `~/.claude/.statusline-ema-7d`, line `last_ts last_used ema_rate resets_at`, atomic write (temp + `mv`). `ema_rate` empty/`NA` until the 2nd sample.
- **Temporary validation log:** per-window `~/.claude/.statusline-ema-{5h,7d}.samples.tsv`, append one row per render. Marked temporary — removed once the formula is trusted.
- **Git:** work on branch `feat/statusline-ema-forecast` (already checked out). Never commit to `main`. No Claude attribution in commit messages.

---

### Task 1: Stop chezmoi from deploying repo docs and tests

The `docs/` tree (specs + this plan) and the `tests/` tree we add next are
repo-internal — they must not be laid down into `$HOME`. `chezmoi managed`
currently lists `docs/...`, confirming it would deploy. Add ignore rules.

**Files:**
- Modify: `.chezmoiignore` (top section, OS-independent rules near `CLAUDE.md`/`README.md`)

- [ ] **Step 1: Verify the problem exists**

Run: `chezmoi managed | grep -E '^docs(/|$)' || echo CLEAN`
Expected: prints `docs`, `docs/superpowers`, … (NOT `CLEAN`) — confirms docs would deploy.

- [ ] **Step 2: Add ignore rules**

In `.chezmoiignore`, find the existing OS-independent block:

```
.archive/

CLAUDE.md
README.md

old_*/**
```

Change it to:

```
.archive/

CLAUDE.md
README.md
docs/**
tests/**

old_*/**
```

- [ ] **Step 3: Verify docs and tests are now ignored**

Run: `chezmoi managed | grep -E '^(docs|tests)(/|$)' && echo STILL_MANAGED || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 4: Commit**

```bash
git add .chezmoiignore
git commit -m "chore: ignore repo docs/ and tests/ in chezmoi"
```

---

### Task 2: Pure EMA projection function + unit tests

Build the clock-free, I/O-free `ema_project()` and its test harness together —
the test file is the executable specification for the function.

**Files:**
- Create: `private_dot_claude/statusline-ema.sh`
- Create: `tests/statusline-ema.test.sh`

**Interfaces:**
- Produces: `ema_project()` — a Bash function. Positional args:
  `now used_now resets_at_now window_sec halflife_sec min_dt_sec min_elapsed_sec flat_pp lin_proj lin_shown prev_last_ts prev_last_used prev_ema_rate prev_resets_at`
  (cold start passes `NA` for the four `prev_*`; `lin_proj` is an integer or `NA`; `lin_shown` is `1`/`0`).
  Prints one space-separated line:
  `new_last_ts new_last_used new_ema_rate new_resets_at ema_ready ema_proj glyph reset_flag`
  where `new_ema_rate` is a float or `NA`, `ema_ready` is `1`/`0`, `ema_proj` is an integer or `NA`, `glyph` is `UP`/`DOWN`/`FLAT`/`NA` (semantic tokens — the presentation layer maps them to `↗`/`↘`/`~`), `reset_flag` is `1`/`0`.

- [ ] **Step 1: Write the failing test harness**

Create `tests/statusline-ema.test.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for ema_project() in private_dot_claude/statusline-ema.sh
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DIR}/private_dot_claude/statusline-ema.sh"

pass=0 fail=0
T=1000000000

# Exact-match the display-relevant fields (ready, proj, glyph, reset).
# usage: check <label> <line> <ready> <proj> <glyph> <reset>
check() {
  local label="$1" line="$2" e_ready="$3" e_proj="$4" e_glyph="$5" e_reset="$6"
  local ts used rate rst ready proj glyph reset
  read -r ts used rate rst ready proj glyph reset <<<"$line"
  if [ "$ready" = "$e_ready" ] && [ "$proj" = "$e_proj" ] \
     && [ "$glyph" = "$e_glyph" ] && [ "$reset" = "$e_reset" ]; then
    pass=$((pass+1)); printf 'PASS %s\n' "$label"
  else
    fail=$((fail+1))
    printf 'FAIL %s\n  got:    ready=%s proj=%s glyph=%s reset=%s\n  expect: ready=%s proj=%s glyph=%s reset=%s\n' \
      "$label" "$ready" "$proj" "$glyph" "$reset" "$e_ready" "$e_proj" "$e_glyph" "$e_reset"
  fi
}

# Numeric-tolerant match for the stored rate (field 3).
# usage: check_rate <label> <line> <expect> <tol>
check_rate() {
  local label="$1" line="$2" expect="$3" tol="$4" rate
  rate=$(awk '{print $3}' <<<"$line")
  if awk -v r="$rate" -v e="$expect" -v t="$tol" 'BEGIN{d=r-e; if(d<0)d=-d; exit !(d<=t)}'; then
    pass=$((pass+1)); printf 'PASS %s (rate=%s)\n' "$label" "$rate"
  else
    fail=$((fail+1)); printf 'FAIL %s rate got=%s expect~%s\n' "$label" "$rate" "$expect"
  fi
}

# 5h constants: window=18000 halflife=3600 mindt=20 minel=1800 flat=2

# A: cold start -> not ready, no rate, not a reset
check "A cold-start" \
  "$(ema_project $T 10 $((T+9000)) 18000 3600 20 1800 2 NA 0 NA NA NA NA)" \
  0 NA NA 0

# B: 2nd sample seeds rate; ready; EMA proj far above linear -> UP
B=$(ema_project $T 10.5 $((T+9000)) 18000 3600 20 1800 2 21 1 $((T-100)) 10 NA $((T+9000)))
check      "B seed-up"   "$B" 1 56 UP 0
check_rate "B seed-rate" "$B" 0.005 0.0001

# C: recent pace below window average -> DOWN
C=$(ema_project $T 10.52 $((T+9000)) 18000 3600 20 1800 2 21 1 $((T-100)) 10.5 0.0008 $((T+9000)))
check      "C cooling-down" "$C" 1 18 DOWN 0
check_rate "C cooling-rate" "$C" 0.000789 0.00005

# D: usage dropped -> reset; re-anchored; cleared; not ready
check "D reset-drop" \
  "$(ema_project $T 2 $((T+18000)) 18000 3600 20 1800 2 NA 0 $((T-100)) 90 0.005 $((T-50)))" \
  0 NA NA 1

# E: Δt below min -> skip update, keep anchor, still display held rate
E=$(ema_project $T 10.3 $((T+9000)) 18000 3600 20 1800 2 21 1 $((T-5)) 10 0.004 $((T+9000)))
check "E mindt-display" "$E" 1 46 UP 0
read -r e_ts e_used e_rate _ <<<"$E"
if [ "$e_ts" = "$((T-5))" ] && [ "$e_used" = "10" ] && [ "$e_rate" = "0.004" ]; then
  pass=$((pass+1)); echo "PASS E anchor-held"
else
  fail=$((fail+1)); echo "FAIL E anchor-held got ts=$e_ts used=$e_used rate=$e_rate"
fi

# F: 7d early window (elapsed 4800 < gate 14400) -> suppressed but rate accumulates
F=$(ema_project $T 0.12 $((T+600000)) 604800 86400 20 14400 2 NA 0 $((T-100)) 0.1 0.0001 $((T+600000)))
check      "F gate-suppressed" "$F" 0 NA NA 0
check_rate "F gate-rate"       "$F" 0.0001 0.00002

# G: linear not shown (lin_shown=0) -> glyph FLAT even though EMA is ready
G=$(ema_project $T 10.5 $((T+9000)) 18000 3600 20 1800 2 NA 0 $((T-100)) 10 0.005 $((T+9000)))
check "G flat-no-linear" "$G" 1 56 FLAT 0

# H: constant rate fed through 30 steps -> EMA converges to that rate
pts=$((T-3000)); pu=0; pr=NA; rst=$((T+9000)); now=$((T-3000)); cur=0
for i in $(seq 1 30); do
  now=$((now+100))
  cur=$(awk -v u="$cur" 'BEGIN{printf "%.4f", u+0.01}')   # +0.01% each 100s -> 0.0001 %/s
  H=$(ema_project $now $cur $rst 18000 3600 20 1800 2 999 1 $pts $pu $pr $rst)
  read -r pts pu pr _ <<<"$H"
done
check_rate "H steady-converge" "$H" 0.0001 0.00003

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/statusline-ema.test.sh`
Expected: FAIL — `ema_project: command not found` (or all cases fail), exit non-zero.

- [ ] **Step 3: Implement the pure function**

Create `private_dot_claude/statusline-ema.sh`:

```bash
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

    reset = 0
    if (!cold) {
      if (used + 0 < pu + 0) reset = 1
      if ((rst + 0) - (prst + 0) > win / 2) reset = 1
    }

    remaining = rst - now
    if (remaining < 0) remaining = 0
    elapsed = win - remaining

    if (cold || reset) {
      print now, used, "NA", rst, 0, "NA", "NA", reset
      exit
    }

    dt = now - pts
    if (dt < mindt) {
      out_ts = pts; out_used = pu; out_rate = pr; out_rst = prst
    } else {
      rate = (used - pu) / dt
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/statusline-ema.test.sh`
Expected: every case prints `PASS …`, final line `8 passed, 0 failed` (the PASS count is higher — multiple asserts per case), exit 0.

- [ ] **Step 5: Commit**

```bash
git add private_dot_claude/statusline-ema.sh tests/statusline-ema.test.sh
git commit -m "feat: pure EMA projection function with unit tests"
```

---

### Task 3: Wire EMA into the status line script

Source the pure function, compute the linear projection + guard, read/write
per-window state atomically, render the new compact format, and append the
temporary validation log. Add a clock seam (`STATUSLINE_NOW`) so the integration
test is deterministic.

**Files:**
- Modify: `private_dot_claude/statusline-command.sh` (source line near top; new env reads + `color_for` helper; rewritten `fmt_rate_limit`; updated call sites at lines 107–108)
- Create: `tests/statusline-command.test.sh`

**Interfaces:**
- Consumes: `ema_project()` from Task 2.
- Consumes (env, with defaults): all six `STATUSLINE_EMA_*` vars from Global Constraints, plus `STATUSLINE_NOW` (clock override; defaults to `date +%s`).

- [ ] **Step 1: Write the failing integration test**

Create `tests/statusline-command.test.sh`:

```bash
#!/usr/bin/env bash
# Integration test: pipe a crafted JSON through the status line, assert the
# rendered (ANSI-stripped) 5h token. Clock and HOME are injected for determinism.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${DIR}/private_dot_claude/statusline-command.sh"

tmp=$(mktemp -d)
mkdir -p "${tmp}/.claude"
# Pre-seed 5h state: prior sample 100s ago at 10%, rate 0.02 %/s, same reset epoch.
NOW=1000000000
RST5=$((NOW+9000))            # elapsed 9000 of 18000 -> half window
printf '%s %s %s %s\n' "$((NOW-100))" 10 0.02 "$RST5" > "${tmp}/.claude/.statusline-ema-5h"

read -r -d '' JSON <<JSON
{
  "model": {"display_name": "Test"},
  "context_window": {"used_percentage": 40},
  "workspace": {"current_dir": "${tmp}"},
  "rate_limits": {
    "five_hour": {"used_percentage": 12, "resets_at": ${RST5}},
    "seven_day": {"used_percentage": 5,  "resets_at": $((NOW+600000))}
  }
}
JSON

out=$(STATUSLINE_NOW=$NOW HOME="$tmp" bash "$SCRIPT" <<<"$JSON")
plain=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')

# EMA: dt=100, rate=(12-10)/100=0.02 -> proj=12+0.02*9000=192; linear=12*18000/9000=24; 192>24 -> UP (↗)
if printf '%s' "$plain" | grep -q '12%→24↗192'; then
  echo "PASS render-5h-token"; rm -rf "$tmp"; exit 0
else
  echo "FAIL render-5h-token"; echo "  plain output: $plain"; rm -rf "$tmp"; exit 1
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/statusline-command.test.sh`
Expected: FAIL — current script renders the old `12%→24%` format (no `↗192`), so the grep misses.

- [ ] **Step 3: Add the source line and env reads**

In `private_dot_claude/statusline-command.sh`, immediately after `input=$(cat)` (line 3), add:

```bash
source "$(dirname "$0")/statusline-ema.sh"

# EMA tuning (env-overridable) + injectable clock for tests
EMA_HL_5H=${STATUSLINE_EMA_HALFLIFE_5H_SEC:-3600}
EMA_HL_7D=${STATUSLINE_EMA_HALFLIFE_7D_SEC:-86400}
EMA_MINEL_5H=${STATUSLINE_EMA_MINELAPSED_5H_SEC:-1800}
EMA_MINEL_7D=${STATUSLINE_EMA_MINELAPSED_7D_SEC:-14400}
EMA_MIN_DT=${STATUSLINE_EMA_MIN_DT_SEC:-20}
EMA_FLAT_PP=${STATUSLINE_EMA_FLAT_THRESHOLD_PP:-2}
EMA_NOW=${STATUSLINE_NOW:-$(date +%s)}
```

- [ ] **Step 4: Add the `color_for` helper**

After the color definitions block (after line 40, where `MAGENTA` is defined), add:

```bash
# Pick a color for a projection value by the existing threshold ladder.
# Emits the raw escape sequence (literal \033...), interpreted by the final printf "%b".
color_for() {
  local v="$1"
  if   [ "$v" -le 80 ];  then printf '%s' "$BLUE"
  elif [ "$v" -le 100 ]; then printf '%s' "$GREEN"
  elif [ "$v" -le 130 ]; then printf '%s' "$YELLOW"
  else                        printf '%s' "$RED"
  fi
}
```

- [ ] **Step 5: Replace `fmt_rate_limit`**

Replace the entire existing `fmt_rate_limit` function (lines 69–99) with:

```bash
# Format one rate-limit window: used% + linear projection + EMA projection.
# Args: used_pct resets_at window_sec label state_file halflife min_elapsed
fmt_rate_limit() {
  local used_pct="$1" resets_at="$2" window_sec="$3" label="$4"
  local state_file="$5" halflife="$6" min_elapsed="$7"
  [ -z "$used_pct" ] && return
  [ -z "$resets_at" ] && return
  local used_int; used_int=$(printf "%.0f" "$used_pct")

  local now="$EMA_NOW" remaining_sec elapsed_sec
  remaining_sec=$(( resets_at - now )); [ "$remaining_sec" -lt 0 ] && remaining_sec=0
  elapsed_sec=$(( window_sec - remaining_sec ))

  # Linear projection + existing 10% guard
  local min_lin=$(( window_sec / 10 )) lin_proj="NA" lin_shown=0
  if [ "$elapsed_sec" -gt "$min_lin" ] && [ "$used_int" -gt 0 ]; then
    lin_proj=$(( used_int * window_sec / elapsed_sec )); lin_shown=1
  fi

  # Prior EMA state
  local p_ts="NA" p_used="NA" p_rate="NA" p_rst="NA"
  if [ -f "$state_file" ]; then
    read -r p_ts p_used p_rate p_rst < "$state_file"
    [ -z "$p_ts" ] && p_ts="NA"
  fi

  # Pure projection
  local result
  result=$(ema_project "$now" "$used_pct" "$resets_at" "$window_sec" \
    "$halflife" "$EMA_MIN_DT" "$min_elapsed" "$EMA_FLAT_PP" \
    "$lin_proj" "$lin_shown" "$p_ts" "$p_used" "$p_rate" "$p_rst")
  local n_ts n_used n_rate n_rst ema_ready ema_proj ema_glyph reset_flag
  read -r n_ts n_used n_rate n_rst ema_ready ema_proj ema_glyph reset_flag <<<"$result"

  # Persist state atomically
  local tmp="${state_file}.tmp.$$"
  printf '%s %s %s %s\n' "$n_ts" "$n_used" "$n_rate" "$n_rst" > "$tmp" \
    && mv -f "$tmp" "$state_file"

  # Temporary validation sample log (remove once the formula is trusted)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$now" "$used_pct" "$resets_at" "$n_rate" "$lin_proj" "$ema_proj" "$ema_glyph" "$reset_flag" \
    >> "${state_file}.samples.tsv"

  # Assemble: used% (neutral) + →linear (colored) + glyph (neutral) + ema (colored)
  if [ "$lin_shown" = "0" ] && [ "$ema_ready" = "0" ]; then
    printf "%b" "${DIM}${used_int}%%${RESET}"
    return
  fi
  local s="${used_int}%"
  if [ "$lin_shown" = "1" ]; then
    s="${s}$(color_for "$lin_proj")→${lin_proj}${RESET}"
  fi
  if [ "$ema_ready" = "1" ]; then
    local g="~"
    case "$ema_glyph" in UP) g="↗" ;; DOWN) g="↘" ;; FLAT) g="~" ;; esac
    s="${s}${g}$(color_for "$ema_proj")${ema_proj}${RESET}"
  fi
  printf "%b" "$s"
}
```

- [ ] **Step 6: Update the call sites**

Replace the two `fmt_rate_limit` calls (lines 107–108) with:

```bash
rl_5h_fmt=$(fmt_rate_limit "$rl_5h" "$rl_5h_reset" 18000 "5h" \
  "${HOME}/.claude/.statusline-ema-5h" "$EMA_HL_5H" "$EMA_MINEL_5H")
rl_7d_fmt=$(fmt_rate_limit "$rl_7d" "$rl_7d_reset" 604800 "7d" \
  "${HOME}/.claude/.statusline-ema-7d" "$EMA_HL_7D" "$EMA_MINEL_7D")
```

- [ ] **Step 7: Run the integration test to verify it passes**

Run: `bash tests/statusline-command.test.sh`
Expected: `PASS render-5h-token`, exit 0.

- [ ] **Step 8: Re-run the unit tests (no regression)**

Run: `bash tests/statusline-ema.test.sh`
Expected: `… 0 failed`, exit 0.

- [ ] **Step 9: Commit**

```bash
git add private_dot_claude/statusline-command.sh tests/statusline-command.test.sh
git commit -m "feat: render EMA forecast + trend glyph in status line"
```

---

### Task 4: Deploy-path verification

Confirm chezmoi will lay the new files down correctly and nothing unintended
changes, and eyeball the real render.

**Files:** none modified (verification only).

- [ ] **Step 1: Confirm chezmoi targets**

Run: `chezmoi managed | grep -E 'statusline'`
Expected: lists `.claude/statusline-command.sh` and `.claude/statusline-ema.sh` (both map under `~/.claude/`); no `tests/` or `docs/` entries.

- [ ] **Step 2: Preview the diff**

Run: `chezmoi diff`
Expected: changes limited to `~/.claude/statusline-command.sh` (modified) and `~/.claude/statusline-ema.sh` (new). No other targets.

- [ ] **Step 3: Eyeball a real render**

Run (uses real clock; values won't be "ready" unless a window has progressed, which is fine — verifies no errors and correct fallback):

```bash
echo '{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"/"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$(( $(date +%s) + 9000 ))"'},"seven_day":{"used_percentage":5,"resets_at":'"$(( $(date +%s) + 600000 ))"'}}}' | bash private_dot_claude/statusline-command.sh; echo
```

Expected: a status line ending with rate-limit tokens; no `awk`/`jq` errors, no stray `NA` in the visible output. (First run seeds state; a second run within the same window may show the EMA token.)

- [ ] **Step 4: Note the temporary log for later removal**

The `~/.claude/.statusline-ema-{5h,7d}.samples.tsv` files accumulate validation
rows. They are intentional and temporary — once the formula is trusted, a
follow-up change removes the logging block from `fmt_rate_limit`. No action now.

---

## Self-Review

**1. Spec coverage:**
- EMA model / projection / seeding → Task 2 `ema_project` (Steps 3), tests B/C/H.
- Parameters + env overrides → Task 3 Step 3 (env reads), passed through call sites Step 6.
- Reset detection (drop + resets_at jump), boundary skip, clear → Task 2 awk `reset` block; test D.
- Δt<20s skip → Task 2 awk `dt < mindt` branch; test E.
- Display gates (linear 10%, EMA min-elapsed + ≥2 samples, EMA-before-linear) → Task 2 awk `elapsed < minel` + `out_rate == "NA"` gates; tests A/F/G; linear guard in Task 3 Step 5.
- Compact format + glyph mapping + color ladder + layouts → Task 3 Step 4 (`color_for`) and Step 5 (assembly); integration test Task 3 Step 1.
- State file + atomic write + `NA` until 2nd sample → Task 3 Step 5; Task 2 prints `NA` rate.
- Temporary validation log → Task 3 Step 5; Task 4 Step 4.
- chezmoi non-deployment of docs/tests → Task 1.
- Testability scenarios 1–7 → Task 2 tests A–H + Task 3 integration.

**2. Placeholder scan:** No `TBD`/`TODO`/"handle edge cases"/"similar to" — all steps carry full code and exact commands. `NA` is a real sentinel value, not a placeholder.

**3. Type consistency:** `ema_project` output field order (`new_last_ts new_last_used new_ema_rate new_resets_at ema_ready ema_proj glyph reset_flag`) is identical in the function `print` (Task 2 Step 3), the unit-test `read` (Task 2 Step 1), and the script `read` (Task 3 Step 5). Glyph tokens `UP`/`DOWN`/`FLAT`/`NA` produced by awk match the `case` mapping in Task 3 Step 5. State-file field order (`last_ts last_used ema_rate resets_at`) matches between the writer (Task 3 Step 5 `printf`), the reader (Task 3 Step 5 `read`), and the test seed (Task 3 Step 1).
