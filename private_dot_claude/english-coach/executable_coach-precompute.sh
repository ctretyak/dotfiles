#!/usr/bin/env bash
# UserPromptSubmit hook (configured async): precompute English coaching for the just-submitted
# prompt, in parallel with the turn. Writes a JSON array of corrections to /tmp/coach_<session_id>.json.
# The Stop hook (coach-hook.sh) reads + displays it. Writes NO stdout (avoid context injection).
# Plan: ~/.claude/plans/recursive-jumping-cake.md

if [ -n "${COACH_HOOK_RUNNING:-}" ]; then exit 0; fi
command -v jq >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
if [ -z "$PROMPT" ] || [ -z "$SID" ]; then exit 0; fi
OUT="/tmp/coach_${SID}.json"

RUBRIC='You are an English-writing coach for a Russian native speaker writing casual messages to colleagues in chat. Analyze the message between the --- markers.
Rules:
- Register = informal colleague chat. Flag ONLY what would out a non-native even in casual chat: word order, articles, prepositions, verb forms/tense, subject-verb agreement, unnatural collocations/phrasing, missing words.
- Do NOT flag: capitalization, terminal punctuation, plain typos.
- At most 3 items, the strongest non-native tells first.
- For each item: the original snippet (verbatim), a natural native rewrite, and a one-line reason written IN RUSSIAN.
- Tag each "error" (ungrammatical) or "upgrade" (grammatical but non-native).
Do NOT use any tools. Respond with ONLY a JSON array, no prose and no markdown fences. Each element:
{"you_wrote":"...","natural":"...","why_ru":"...","tag":"error","category":"short-english-label"}
If nothing is worth flagging, respond with exactly: []'

FULL="$RUBRIC
---
$PROMPT
---"

RAW="$(COACH_HOOK_RUNNING=1 claude -p "$FULL" --model haiku --output-format json --no-session-persistence --strict-mcp-config --disable-slash-commands 2>/dev/null)"
ITEMS="$(printf '%s' "$RAW" | jq -r '.result // empty' 2>/dev/null | sed '/^```/d')"

# Must be a JSON array; otherwise store an empty array so Stop knows the run finished with nothing.
if ! printf '%s' "$ITEMS" | jq -e 'type=="array"' >/dev/null 2>&1; then
  ITEMS='[]'
fi

printf '%s' "$ITEMS" > "${OUT}.tmp" 2>/dev/null && mv -f "${OUT}.tmp" "$OUT" 2>/dev/null
exit 0
