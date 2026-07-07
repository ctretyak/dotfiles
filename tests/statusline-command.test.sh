#!/usr/bin/env bash
# Integration test: pipe a crafted JSON through the status line, assert the
# rendered (ANSI-stripped) 5h token. Clock and HOME are injected for determinism.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${DIR}/private_dot_claude/statusline-command.sh"

tmp=$(mktemp -d)
mkdir -p "${tmp}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp}/.claude.json"
# Pre-seed 5h state: prior sample 100s ago at 10%, rate 0.02 %/s, same reset epoch.
NOW=1000000000
RST5=$((NOW+9000))            # elapsed 9000 of 18000 -> half window
printf '%s %s %s %s\n' "$((NOW-100))" 10 0.02 "$RST5" > "${tmp}/.claude/.statusline-ema-5h-acctA"

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

# --- Samples log prunes rows older than ~7 days (no truncate-on-reset) ---
tmp2=$(mktemp -d); mkdir -p "${tmp2}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp2}/.claude.json"
NOW2=2000000000; RST2=$((NOW2+9000))
# Normal prior state (no reset) so a regular render appends one row.
printf '%s %s %s %s\n' "$((NOW2-100))" 10 0.001 "$RST2" > "${tmp2}/.claude/.statusline-ema-5h-acctA"
log2="${tmp2}/.claude/.statusline-ema-5h-acctA.samples.tsv"
# One stale row (~8.1d old, must be pruned) and one recent row (must stay).
printf '%s\t10\t%s\t0\t18\t18\tFLAT\t0\n' "$((NOW2-700000))" "$RST2" >  "$log2"
printf '%s\t10\t%s\t0\t18\t18\tFLAT\t0\n' "$((NOW2-100))"    "$RST2" >> "$log2"

JSON2='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp2}"'"},"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":'"$RST2"'}}}'
STATUSLINE_NOW=$NOW2 HOME="$tmp2" bash "$SCRIPT" <<<"$JSON2" >/dev/null

field1(){ awk -F'\t' -v t="$1" '$1==t{print "y"; exit}' "$log2"; }
old_present=$(field1 "$((NOW2-700000))")
recent_present=$(field1 "$((NOW2-100))")
new_present=$(field1 "$NOW2")
if [ -z "$old_present" ] && [ "$recent_present" = "y" ] && [ "$new_present" = "y" ]; then
  echo "PASS samples-prune-old"
else
  echo "FAIL samples-prune-old (old=$old_present recent=$recent_present new=$new_present)"
  echo "  log: $(cat "$log2")"; fail=1
fi
rm -rf "$tmp2"

# --- Effort level is read from stdin (.effort.level), not settings.json ---
tmp3=$(mktemp -d); mkdir -p "${tmp3}/.claude"
# Stale settings.json source must be IGNORED: it says high (3 bars)...
printf '{"effortLevel":"high"}\n' > "${tmp3}/.claude/settings.json"
# ...but stdin says xhigh, which must win and render 4 bars.
JSON3='{"model":{"display_name":"Test"},"effort":{"level":"xhigh"},"workspace":{"current_dir":"'"${tmp3}"'"}}'
out3=$(STATUSLINE_NOW=$NOW HOME="$tmp3" bash "$SCRIPT" <<<"$JSON3")
plain3=$(printf '%s' "$out3" | sed 's/\x1b\[[0-9;]*m//g')
if printf '%s' "$plain3" | grep -q '||||' && ! printf '%s' "$plain3" | grep -q '|||||'; then
  echo "PASS effort-from-stdin-xhigh"
else
  echo "FAIL effort-from-stdin-xhigh"; echo "  plain output: $plain3"; fail=1
fi
rm -rf "$tmp3"

# --- State file is keyed by accountUuid; unkeyed path is not written ---
tmp4=$(mktemp -d); mkdir -p "${tmp4}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp4}/.claude.json"
NOW4=1000000000; RST4=$((NOW4+9000))
JSON4='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp4}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST4"'}}}'
STATUSLINE_NOW=$NOW4 HOME="$tmp4" bash "$SCRIPT" <<<"$JSON4" >/dev/null
if [ -f "${tmp4}/.claude/.statusline-ema-5h-acctA" ] && [ ! -f "${tmp4}/.claude/.statusline-ema-5h" ]; then
  echo "PASS state-keyed-by-account"
else
  echo "FAIL state-keyed-by-account"; ls "${tmp4}/.claude/"; fail=1
fi
rm -rf "$tmp4"

# --- No oauthAccount -> shared 'unknown' bucket, legacy file left untouched ---
tmp5=$(mktemp -d); mkdir -p "${tmp5}/.claude"
printf '{}\n' > "${tmp5}/.claude.json"
NOW5=1000000000; RST5b=$((NOW5+9000))
printf 'legacy\n' > "${tmp5}/.claude/.statusline-ema-5h"   # sentinel legacy file
JSON5='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp5}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST5b"'}}}'
STATUSLINE_NOW=$NOW5 HOME="$tmp5" bash "$SCRIPT" <<<"$JSON5" >/dev/null
if [ -f "${tmp5}/.claude/.statusline-ema-5h-unknown" ] \
   && [ "$(cat "${tmp5}/.claude/.statusline-ema-5h")" = "legacy" ]; then
  echo "PASS fallback-unknown-bucket"
else
  echo "FAIL fallback-unknown-bucket"; ls "${tmp5}/.claude/"; fail=1
fi
rm -rf "$tmp5"

# --- Legacy unkeyed state is adopted once into the current account's keyed path ---
tmp6=$(mktemp -d); mkdir -p "${tmp6}/.claude"
printf '{"oauthAccount":{"accountUuid":"acctA"}}\n' > "${tmp6}/.claude.json"
NOW6=1000000000; RST6=$((NOW6+9000))
# Seed ONLY the legacy unkeyed files (state + samples); no keyed file yet.
printf '%s %s %s %s\n' "$((NOW6-100))" 10 0.02 "$RST6" > "${tmp6}/.claude/.statusline-ema-5h"
printf '%s\t10\t%s\t0\t18\t18\tFLAT\t0\n' "$((NOW6-100))" "$RST6" > "${tmp6}/.claude/.statusline-ema-5h.samples.tsv"
JSON6='{"model":{"display_name":"Test"},"context_window":{"used_percentage":40},"workspace":{"current_dir":"'"${tmp6}"'"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":'"$RST6"'}}}'
out6=$(STATUSLINE_NOW=$NOW6 HOME="$tmp6" bash "$SCRIPT" <<<"$JSON6")
plain6=$(printf '%s' "$out6" | sed 's/\x1b\[[0-9;]*m//g')
# Adopted warmup must yield the same EMA token as a directly-seeded keyed file.
if [ -f "${tmp6}/.claude/.statusline-ema-5h-acctA" ] \
   && [ ! -f "${tmp6}/.claude/.statusline-ema-5h" ] \
   && [ -f "${tmp6}/.claude/.statusline-ema-5h-acctA.samples.tsv" ] \
   && printf '%s' "$plain6" | grep -q '12%→24↗192'; then
  echo "PASS adopts-legacy-unkeyed"
else
  echo "FAIL adopts-legacy-unkeyed"; echo "  plain: $plain6"; ls "${tmp6}/.claude/"; fail=1
fi
rm -rf "$tmp6"

exit "$fail"
