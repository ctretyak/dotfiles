#!/usr/bin/env bash
# English-coaching Stop hook (display only). Fires after every assistant turn.
# The corrections are precomputed in parallel by ~/.claude/english-coach/coach-precompute.sh
# (UserPromptSubmit, async) into /tmp/coach_<session_id>.json. This hook reads that file,
# surfaces a Phrasing block, appends the log, and deletes the file. No model call here.
# Design: ~/.claude/plans/recursive-jumping-cake.md
#
# Never hard-fails: any problem -> exit 0 with no output, so it can't disrupt the user.
#
# NOTE FOR CLAUDE: English coaching lives entirely here, out of process. The model does
# nothing per turn -- do NOT add a per-turn coaching rule to CLAUDE.md. The rubric
# (informal-chat register, <=3 items, examples in English / *why* in Russian, log schema)
# lives in coach-precompute.sh; this script only renders and logs the result.

if [ -n "${COACH_HOOK_RUNNING:-}" ]; then exit 0; fi
command -v jq >/dev/null 2>&1 || exit 0

LOG="${COACH_LOG:-$HOME/.claude/english-coach/log.md}"
TODAY="$(date +%F)"
NEXT="$(date -v+1d +%F 2>/dev/null || date -d '+1 day' +%F 2>/dev/null)"

INPUT="$(cat)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
if [ -z "$SID" ]; then exit 0; fi
FILE="/tmp/coach_${SID}.json"

# The precompute runs in parallel with the turn; on a very short turn it may not be done yet.
# Wait briefly (up to ~8s) for the result, then give up.
i=0
while [ ! -f "$FILE" ] && [ "$i" -lt 40 ]; do sleep 0.2; i=$((i+1)); done
[ -f "$FILE" ] || exit 0

ITEMS="$(cat "$FILE" 2>/dev/null)"
rm -f "$FILE" 2>/dev/null

COUNT="$(printf '%s' "$ITEMS" | jq 'if type=="array" then length else 0 end' 2>/dev/null)"
if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ]; then exit 0; fi

# Append one log row per item (pipes/newlines neutralized so the table stays valid).
printf '%s' "$ITEMS" | jq -r --arg d "$TODAY" --arg n "$NEXT" '
  def cell: gsub("\n";" ") | gsub("\\|";"/");
  .[] | "| \($d) | \(.you_wrote|cell) | \(.natural|cell) | \(.category|cell) | \(.why_ru|cell) | \($n) |"
' >> "$LOG" 2>/dev/null

# Build the Phrasing block and surface it via systemMessage.
BLOCK="$(printf '%s' "$ITEMS" | jq -r '
  def oneline: gsub("\n";" ");
  ["> 📝 **Phrasing**"]
  + (map("> **You wrote:** \(.you_wrote|oneline) → **Natural:** \(.natural|oneline) — *\(.why_ru|oneline)* `[\(.tag)]`"))
  | join("\n")
' 2>/dev/null)"
if [ -z "$BLOCK" ]; then exit 0; fi

jq -nc --arg m "$BLOCK" '{systemMessage: $m}'
