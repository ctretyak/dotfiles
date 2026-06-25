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

# D: genuine reset via resets_at jump (used need not drop) -> re-anchored, cleared, not ready
check "D reset-via-resets_at" \
  "$(ema_project $T 2 $((T+18000)) 18000 3600 20 1800 2 NA 0 $((T-100)) 1 0.005 $((T-50)))" \
  0 NA NA 1

# I: used dips (66->47) with resets_at UNCHANGED -> NOT a reset (non-monotonic noise);
#    the dip HOLDS the anchor (rate untouched), so a later recovery can't whiplash it.
Idip=$(ema_project $T 47 $((T+9000)) 18000 3600 20 1800 2 94 1 $((T-100)) 66 0.001 $((T+9000)))
check      "I dip-no-reset"  "$Idip" 1 56 DOWN 0
check_rate "I dip-rate-held" "$Idip" 0.001 0.00001

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

# J: stale resets_at (rst <= now) is input noise -> ignore the sample entirely.
#    Prior state is held and (critically) the good FUTURE resets_at is preserved, so
#    the next real sample is NOT seen as a forward jump / phantom window reset.
J=$(ema_project $T 18 $((T-50000)) 18000 3600 20 1800 2 NA 0 $((T-100)) 10 0.0003 $((T+9000)))
check "J stale-ignored" "$J" 0 NA NA 0
read -r j_ts j_used j_rate j_rst _ <<<"$J"
if [ "$j_rst" = "$((T+9000))" ] && [ "$j_rate" = "0.0003" ] && [ "$j_used" = "10" ]; then
  pass=$((pass+1)); echo "PASS J state-held (good resets_at preserved)"
else
  fail=$((fail+1)); echo "FAIL J state-held got ts=$j_ts used=$j_used rate=$j_rate rst=$j_rst"
fi

# K: a single-sample dip then recovery (78->67->78) must NOT whiplash the rate.
#    Real 7d bug: the dip moved the anchor to 67, then the 67->78 recovery seeded a
#    huge burst. With the dip-hold guard the anchor stays at 78 across both steps.
K1=$(ema_project $T 67 $((T+255000)) 604800 86400 20 14400 2 135 1 $((T-100)) 78 0.0000822 $((T+255000)))
read -r k_ts k_used k_rate _ <<<"$K1"
K2=$(ema_project $((T+21)) 78 $((T+255000)) 604800 86400 20 14400 2 135 1 "$k_ts" "$k_used" "$k_rate" $((T+255000)))
check_rate "K recovery-no-whiplash" "$K2" 0.0000822 0.00001

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
