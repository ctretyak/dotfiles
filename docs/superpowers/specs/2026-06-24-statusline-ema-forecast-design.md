# Statusline EMA usage forecast — design

**Date:** 2026-06-24
**Scope:** `private_dot_claude/statusline-command.sh`
**Status:** approved design, pending implementation

## Goal

The status line already shows, per rate-limit window, the current usage and a
**linear** end-of-period projection (`used%→projected%`). Add a second,
**EMA-based** projection next to it that reflects the *recent* burn rate rather
than the whole-window average. Show both numbers so the user keeps the
full-window view (linear) and gains a recency-weighted view (EMA).

## Background: why the current projection is "linear"

Today's projection (in `fmt_rate_limit`, line 85) is:

```
projected = used_pct * window_sec / elapsed_sec   # = used_now / fraction_of_window_elapsed
```

This is the cumulative average rate over the **entire elapsed window**, weighting
a burst at minute 5 exactly as much as activity right now. It over-projects after
an early spike and under-projects after a slow start, and never "forgets". The
linear number therefore already encodes "all history of the window, equal
weight" — it stays unchanged.

## What EMA adds

The EMA projection weights **recent** burn rate more heavily, so it diverges from
linear precisely when the pace changes (you sped up, or you went idle). That
divergence is the entire value of the second number. An EMA that remembered all
history equally would be a duplicate of the linear projection.

## Model

Per window, on each status-line render that passes the min-Δt guard:

1. **Instantaneous burn rate** since the previous sampled render:
   `rate = (used_now − used_prev) / Δt`   (units: percent per second)
2. **Time-based EMA of the rate** (correct under irregular render intervals):
   `α = 1 − exp(−Δt / tau)`
   `ema_rate = α · rate + (1 − α) · ema_rate_prev`
   On the **first** rate computation after a reset/cold start, `ema_rate` is
   seeded directly with `rate` (no prior value to blend).
3. **Projection** to end of window:
   `projected_ema = used_now + ema_rate · remaining_sec`, clamped at ≥ 0.

Note `ema_rate` is a **slope** (%/sec) only; the level always comes from the
fresh `used_now`. The previous window's usage level never leaks into the
projection.

`tau` is the e-folding constant. We parametrize by the more intuitive
**half-life** and convert internally: `tau = half_life / ln(2)`.

### Parameters (all env-overridable)

| Setting | Default | Env var |
|---------|---------|---------|
| 5h half-life | 1 h (3600 s) | `STATUSLINE_EMA_HALFLIFE_5H_SEC` |
| 7d half-life | 24 h (86400 s) | `STATUSLINE_EMA_HALFLIFE_7D_SEC` |
| 5h min-elapsed gate | 30 min (1800 s) | `STATUSLINE_EMA_MINELAPSED_5H_SEC` |
| 7d min-elapsed gate | 4 h (14400 s) | `STATUSLINE_EMA_MINELAPSED_7D_SEC` |
| min Δt between samples | 20 s | `STATUSLINE_EMA_MIN_DT_SEC` |
| flat-glyph threshold | 2 pp | `STATUSLINE_EMA_FLAT_THRESHOLD_PP` |

Half-life rationale: 5h window → reactive (catch a burst/idle within ~1h, still
sees most of the window); 7d window → on a Wednesday the prior days still count
(Tue 50%, Mon 25%, Sun 12%) with recent pace leading.

## State (new)

EMA is recursive, so per window we persist only one line:

```
last_ts last_used ema_rate resets_at
```

- `last_ts` — epoch of the last sampled render
- `last_used` — `used_pct` at that render
- `ema_rate` — last smoothed slope; **empty until the 2nd sample**. Its presence
  is therefore the "≥2 samples" signal — no explicit sample counter is stored.
- `resets_at` — the window's reset epoch, to detect a new window

Files:
- `~/.claude/.statusline-ema-5h`
- `~/.claude/.statusline-ema-7d`

Writes are **atomic** (write a temp file in the same dir, then `mv`) so
overlapping renders cannot corrupt the file. These are runtime state, not
dotfiles — they are **not** added to chezmoi source and need no `.chezmoiignore`
rule. The `~/.claude/` target dir already exists.

### Temporary validation log

While validating the formula, also append one row per sampled render to a
per-window TSV log:

- `~/.claude/.statusline-ema-5h.samples.tsv`
- `~/.claude/.statusline-ema-7d.samples.tsv`

Columns: `ts used resets_at dt rate alpha ema_rate proj_linear proj_ema reset_flag`.
This both validates the math and lets us observe real reset behavior (see
fixed-vs-rolling note). **Temporary — to be removed once the formula is trusted.**

## Reset handling

A window reset (planned end-of-period **or** an unexpected mid-period reset) is
detected uniformly — we do not distinguish the two. On a render, treat it as a
reset if **either**:

1. `used_now < last_used` — usage dropped (it is monotonic within a window, so a
   drop means the window rolled over), **or**
2. `resets_at` jumped forward by more than `window_sec / 2` — covers the case
   where a long gap (display asleep) hid the usage drop and new usage already
   exceeds the old value.

On reset:
- **Skip the boundary rate sample** — do not compute `(used_now − last_used)/Δt`
  across the boundary; that drop (e.g. 90% → 2%) would inject a large negative
  spike into `ema_rate`.
- Re-anchor: `last_ts = now`, `last_used = used_now`, `resets_at = new`.
- **Clear `ema_rate`** (start fresh). Rationale: a deliberate end-of-window
  "use up the remaining budget" burst would otherwise inflate the *next* period's
  EMA for ~1 half-life. Clearing prevents that bleed; the EMA rebuilds from
  fresh in-window samples.

The `resets_at` threshold of `window_sec / 2` cleanly separates a real reset from
slow "creep" whether the window is fixed or rolling. **We have not verified which
semantics Claude's limits use** — the temporary sample log will confirm it on the
first real reset, and the threshold can be tuned then.

## Display gates

- **`used%`** — always shown.
- **Linear projection (`→N`)** — shown when `elapsed ≥ 10% of window`
  (the existing guard; numerically required since linear divides by `elapsed`).
  Unchanged.
- **EMA projection (`~N`)** — shown when **both**:
  - `ema_rate` is present (≥2 samples since the last reset), **and**
  - `elapsed-since-reset ≥ min-elapsed gate` (30 min for 5h, 4 h for 7d).

  The gate is in **real time**, not sample count, because the status line renders
  at a wildly variable, render-frequency-dependent rate (20 samples could be 7
  minutes of active typing or several hours). A short-history EMA early in a long
  window explodes (`rate · huge_remaining` → absurd numbers); a real-time gate
  ensures enough smoothed history before the number appears.

  For the 7d window the EMA gate (4 h) is **smaller** than the linear gate (~17 h),
  so EMA can appear *before* linear. That is intended: EMA does not need the 10%
  guard numerically, and it is the early-available estimator.
- **Δt < 20 s** → skip the EMA update (usage % is coarsely quantized, so a tiny Δt
  yields a noisy rate; also guards against Δt = 0). The held `ema_rate` is still
  used for display.
- Cold start / EMA not ready → omit the `~N` part entirely (show only
  `used% →N`), rather than printing a placeholder.

## Display format

Compact, no spaces. Each projection is colored by its own threshold (the existing
blue/green/yellow/red ladder); `used%` and the trend glyph are neutral:

```
34%→68↘61
│  │ │ └ EMA projection (recent-weighted)
│  │ └ trend glyph (EMA vs linear)
│  └ linear projection (whole-window)
└ current usage
```

- **Linear** keeps its `→` glyph and current color logic, untouched.
- **Trend glyph** (between linear and EMA) encodes EMA vs linear — note `ema_rate`
  is always ≥ 0 (usage is monotonic within a window), so the slope sign is never
  the signal; the signal is whether recent pace runs hotter or cooler than the
  whole-window average:
  - `↗` (U+2197) when `projected_ema > projected_linear + flat_threshold` — burning
    hotter than the window average (speeding up)
  - `↘` (U+2198) when `projected_ema < projected_linear − flat_threshold` — cooling off
  - `~` (U+007E, flat) when within ±`flat_threshold` (default 2 pp), **or** when the
    linear projection is not trustworthy yet (elapsed < 10%, no baseline to compare)
- Direction compares the two **projection** numbers the user sees, which is
  equivalent to comparing the rates (both projections share `used_now` and
  `remaining_sec`).
- No textual `5h`/`7d` label — windows are distinguished by position, as today.

Layout by readiness:
- both ready: `34%→68↘61`
- linear only (EMA not ready): `34%→68`
- EMA only (linear still gated, e.g. 7d window at 4–17 h): `34%~61` (flat glyph, no
  linear baseline)
- neither ready: `34%`

## Files touched

- `private_dot_claude/statusline-command.sh` — extend `fmt_rate_limit()` to:
  read the per-window state file, detect resets, compute the EMA projection and
  state update via a single `awk` call (bash is integer-only), write state back
  atomically, append the temporary validation row, and append the `~N` part to
  the output subject to the gates above. Call sites (lines 107–108) pass the
  per-window state-file path and the env-var keys for half-life / min-elapsed.

No other source files change. `CLAUDE.md` is not updated (the statusline is not
documented there).

## Testability

Factor the EMA/projection math (the `awk` step) so it can be driven with fixed
inputs (`used%`, `Δt`, prior state) and asserted against an expected number.
Scenarios:

1. **Steady rate** → EMA ≈ linear.
2. **Spike then idle** → EMA drops below linear (linear stays inflated).
3. **Window reset** → state clears, boundary drop ignored, no negative/garbage
   projection, EMA omitted until the gate passes again.
4. **Cold start** → EMA omitted until ≥2 samples and the min-elapsed gate.
5. **Tiny Δt** → no update, no division error.
6. **Early long window** → EMA gated until 4 h (7d), so no `rate · huge_remaining`
   explosion.
7. **Trend glyph** → `↗`/`↘`/`~` chosen correctly around the flat threshold; flat
   when elapsed < 10% (no linear baseline).
