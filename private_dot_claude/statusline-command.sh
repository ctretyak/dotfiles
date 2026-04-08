#!/usr/bin/env bash

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# effortLevel is a setting in settings.json, not part of the statusline stdin JSON
effort=$(jq -r '.effortLevel // empty' "${HOME}/.claude/settings.json" 2>/dev/null)

# Format effort level as orange bars: low=|   medium=||  high=|||
ORANGE='\033[38;5;208m'
DIM='\033[2m'
RESET='\033[0m'
case "$effort" in
  high)   effort_dots="${ORANGE}|||${RESET}" ;;
  medium) effort_dots="${ORANGE}||${RESET}${DIM}|${RESET}" ;;
  low)    effort_dots="${ORANGE}|${RESET}${DIM}||${RESET}" ;;
  *)      effort_dots="" ;;
esac

# Build progress bar
bar_width=10
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  ctx_part="[${bar}] ${used_int}%"
else
  ctx_part="[░░░░░░░░░░] -"
fi

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# Format rate limit with projected end-of-period usage
# Args: used_pct, resets_at (epoch), window_seconds, label
fmt_rate_limit() {
  local used_pct="$1" resets_at="$2" window_sec="$3" label="$4"
  [ -z "$used_pct" ] && return
  used_pct=$(printf "%.0f" "$used_pct")

  local now remaining_sec elapsed_sec projected color
  now=$(date +%s)
  remaining_sec=$(( resets_at - now ))
  [ "$remaining_sec" -lt 0 ] && remaining_sec=0
  elapsed_sec=$(( window_sec - remaining_sec ))

  # Project usage at end of period; require >=10% of window elapsed
  local min_elapsed=$(( window_sec / 10 ))
  if [ "$elapsed_sec" -gt "$min_elapsed" ] && [ "$used_pct" -gt 0 ]; then
    projected=$(( used_pct * window_sec / elapsed_sec ))
    if [ "$projected" -le 80 ]; then
      color="$BLUE"
    elif [ "$projected" -le 100 ]; then
      color="$GREEN"
    elif [ "$projected" -le 130 ]; then
      color="$YELLOW"
    else
      color="$RED"
    fi
    printf "${color}${used_pct}%%→${projected}%%${RESET}"
  else
    printf "${DIM}${used_pct}%%${RESET}"
  fi
}

# Rate limits
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

rl_5h_fmt=$(fmt_rate_limit "$rl_5h" "$rl_5h_reset" 18000 "5h")
rl_7d_fmt=$(fmt_rate_limit "$rl_7d" "$rl_7d_reset" 604800 "7d")

# Assemble output
parts="\033[0;36m${model}\033[0m"
[ -n "$effort_dots" ] && parts="${parts} · ${effort_dots}"
parts="${parts} · ${ctx_part}"
[ -n "$rl_5h_fmt" ] && parts="${parts} · ${rl_5h_fmt}"
[ -n "$rl_7d_fmt" ] && parts="${parts} · ${rl_7d_fmt}"
printf "%b" "$parts"
