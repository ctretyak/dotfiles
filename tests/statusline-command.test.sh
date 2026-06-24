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
fail=0
if printf '%s' "$plain" | grep -q '12%→24↗192'; then
  echo "PASS render-5h-token"
else
  echo "FAIL render-5h-token"; echo "  plain output: $plain"; fail=1
fi

# 7d window: elapsed < 10% of 604800 -> cold-start fallback -> must render single %, never %%
if printf '%s' "$plain" | grep -q '5%' && ! printf '%s' "$plain" | grep -q '5%%'; then
  echo "PASS no-double-percent-fallback"
else
  echo "FAIL no-double-percent-fallback"; echo "  plain output: $plain"; fail=1
fi

rm -rf "$tmp"

# --- Reset truncates the samples log so the new period starts fresh ---
tmp2=$(mktemp -d); mkdir -p "${tmp2}/.claude"
NOW2=1000000000; RST2=$((NOW2+9000))
# Prior state at 90% usage; the new render drops to 2% -> window reset detected.
printf '%s %s %s %s\n' "$((NOW2-100))" 90 0.01 "$RST2" > "${tmp2}/.claude/.statusline-ema-5h"
# Stale log rows from the previous period that must be wiped on reset.
printf 'old1\nold2\nold3\n' > "${tmp2}/.claude/.statusline-ema-5h.samples.tsv"

JSON2='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp2}"'"},"rate_limits":{"five_hour":{"used_percentage":2,"resets_at":'"$RST2"'}}}'
STATUSLINE_NOW=$NOW2 HOME="$tmp2" bash "$SCRIPT" <<<"$JSON2" >/dev/null

log2="${tmp2}/.claude/.statusline-ema-5h.samples.tsv"
lines=$(wc -l < "$log2" | tr -d ' ')
reset_col=$(tail -n 1 "$log2" | awk '{print $8}')
if [ "$lines" = "1" ] && [ "$reset_col" = "1" ]; then
  echo "PASS reset-truncates-samples"
else
  echo "FAIL reset-truncates-samples (lines=$lines reset_flag=$reset_col)"
  echo "  log contents: $(cat "$log2")"; fail=1
fi
rm -rf "$tmp2"

exit "$fail"
