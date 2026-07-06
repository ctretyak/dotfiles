#!/usr/bin/env bash

input=$(cat)

source "$(dirname "$0")/statusline-ema.sh"

# EMA tuning (env-overridable) + injectable clock for tests
EMA_HL_5H=${STATUSLINE_EMA_HALFLIFE_5H_SEC:-3600}
EMA_HL_7D=${STATUSLINE_EMA_HALFLIFE_7D_SEC:-86400}
EMA_MINEL_5H=${STATUSLINE_EMA_MINELAPSED_5H_SEC:-1800}
EMA_MINEL_7D=${STATUSLINE_EMA_MINELAPSED_7D_SEC:-14400}
EMA_MIN_DT=${STATUSLINE_EMA_MIN_DT_SEC:-20}
EMA_FLAT_PP=${STATUSLINE_EMA_FLAT_THRESHOLD_PP:-2}
EMA_NOW=${STATUSLINE_NOW:-$(date +%s)}

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# effort.level is the live session value from stdin, reflecting mid-session /effort changes
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Format effort level as orange bars: low=|  medium=||  high=|||  xhigh=||||  max=|||||
ORANGE='\033[38;5;208m'
DIM='\033[2m'
RESET='\033[0m'
case "$effort" in
  max)    effort_dots="${ORANGE}|||||${RESET}" ;;
  xhigh)  effort_dots="${ORANGE}||||${RESET}" ;;
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
MAGENTA='\033[0;35m'

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

# Git status for current workspace dir
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
git_part=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if [ -n "$(git -C "$cwd" status --porcelain --untracked-files=no --ignore-submodules 2>/dev/null | head -n 1)" ]; then
    dirty=" ${YELLOW}●${RESET}"
  fi

  ab=""
  upstream=$(git -C "$cwd" rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  if [ -n "$upstream" ]; then
    counts=$(git -C "$cwd" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null)
    if [ -n "$counts" ]; then
      ahead=${counts%%	*}
      behind=${counts##*	}
      [ "$ahead" -gt 0 ] 2>/dev/null && ab="${ab}${DIM}↑${ahead}${RESET}"
      [ "$behind" -gt 0 ] 2>/dev/null && ab="${ab}${DIM}↓${behind}${RESET}"
    fi
  fi

  git_part="${MAGENTA}${branch}${RESET}${dirty}${ab}"
fi

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

  # Linear projection + existing 10% guard. Computed from the fractional used_pct
  # (round only the final number), so linear and EMA share the same input.
  local min_lin=$(( window_sec / 10 )) lin_proj="NA" lin_shown=0
  if [ "$elapsed_sec" -gt "$min_lin" ] && [ "$used_int" -gt 0 ]; then
    lin_proj=$(awk -v u="$used_pct" -v w="$window_sec" -v e="$elapsed_sec" \
      'BEGIN { printf "%.0f", u * w / e }')
    lin_shown=1
  fi

  # Serialize the read-modify-write below: concurrent Claude sessions share this
  # state file, so an unlocked reader could act on a stale snapshot and corrupt
  # the EMA. The lock makes each session read the latest committed state.
  local lock="${state_file}.lock" locked=0
  acquire_lock "$lock" "$now" && locked=1

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

  # Temporary validation sample log (remove once the formula is trusted).
  # Keep ~7 days of rows; prune older ones. The rewrite is batched (only once the
  # oldest row passes 8 days) so we don't rewrite the file on every render.
  local log_file="${state_file}.samples.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$now" "$used_pct" "$resets_at" "$n_rate" "$lin_proj" "$ema_proj" "$ema_glyph" "$reset_flag" \
    >> "$log_file"
  local oldest
  oldest=$(head -n 1 "$log_file" 2>/dev/null | cut -f1)
  if [ -n "$oldest" ] && [ "$oldest" -lt "$(( now - 691200 ))" ] 2>/dev/null; then
    awk -F'\t' -v c="$(( now - 604800 ))" '$1 >= c' "$log_file" > "${log_file}.prune.$$" \
      && mv -f "${log_file}.prune.$$" "$log_file"
  fi

  [ "$locked" = 1 ] && release_lock "$lock"

  # Assemble: used% (neutral) + →linear (colored) + glyph (neutral) + ema (colored)
  if [ "$lin_shown" = "0" ] && [ "$ema_ready" = "0" ]; then
    printf "%b" "${DIM}${used_int}%${RESET}"
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

# Rate limits
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

rl_5h_fmt=$(fmt_rate_limit "$rl_5h" "$rl_5h_reset" 18000 "5h" \
  "${HOME}/.claude/.statusline-ema-5h" "$EMA_HL_5H" "$EMA_MINEL_5H")
rl_7d_fmt=$(fmt_rate_limit "$rl_7d" "$rl_7d_reset" 604800 "7d" \
  "${HOME}/.claude/.statusline-ema-7d" "$EMA_HL_7D" "$EMA_MINEL_7D")

# Assemble output
parts="\033[0;36m${model}\033[0m"
[ -n "$effort_dots" ] && parts="${parts} · ${effort_dots}"
parts="${parts} · ${ctx_part}"
[ -n "$rl_5h_fmt" ] && parts="${parts} · ${rl_5h_fmt}"
[ -n "$rl_7d_fmt" ] && parts="${parts} · ${rl_7d_fmt}"
[ -n "$git_part" ] && parts="${parts} · ${git_part}"
printf "%b" "$parts"
