#!/usr/bin/env bash

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# effortLevel is a setting in settings.json, not part of the statusline stdin JSON
effort=$(jq -r '.effortLevel // empty' /Users/tretyak.k/.claude/settings.json 2>/dev/null)

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

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# Format rate limit with pace indicator
# Args: used_pct, resets_at (epoch), window_seconds, label
fmt_rate_limit() {
  local used_pct="$1" resets_at="$2" window_sec="$3" label="$4"
  [ -z "$used_pct" ] && return

  local now remaining_sec
  now=$(date +%s)
  remaining_sec=$(( resets_at - now ))
  [ "$remaining_sec" -lt 0 ] && remaining_sec=0

  # Time remaining as Xh Xm
  local hours mins time_left
  hours=$(( remaining_sec / 3600 ))
  mins=$(( (remaining_sec % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    time_left="${hours}h${mins}m"
  else
    time_left="${mins}m"
  fi

  # Pace: delta from even distribution
  local elapsed_sec budget_pct delta delta_fmt color
  elapsed_sec=$(( window_sec - remaining_sec ))
  if [ "$elapsed_sec" -gt 0 ]; then
    budget_pct=$(echo "$elapsed_sec * 100 / $window_sec" | bc)
    delta=$(( used_pct - budget_pct ))
  else
    delta=0
  fi

  if [ "$delta" -le 0 ]; then
    color="$GREEN"
    delta_fmt="${delta}%"
  elif [ "$delta" -le 15 ]; then
    color="$YELLOW"
    delta_fmt="+${delta}%"
  else
    color="$RED"
    delta_fmt="+${delta}%"
  fi

  printf "${color}${used_pct}%% ${delta_fmt}${RESET} ${DIM}${time_left}${RESET}"
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
