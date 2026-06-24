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

rm -rf "$tmp"; exit "$fail"
