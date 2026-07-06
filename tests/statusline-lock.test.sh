#!/usr/bin/env bash
# Unit tests for the portable advisory lock that serializes the shared EMA
# state file across concurrent Claude sessions.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DIR}/private_dot_claude/statusline-ema.sh"

fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- T1: mutual exclusion — two holders never overlap the critical section ---
# Each worker writes start<id>/end<id> around a held critical section. With a
# real lock the markers pair up (start,end,start,end); without one they
# interleave (start,start,end,end), which the odd/even check below detects.
lock="${tmp}/t1.lock"
markers="${tmp}/markers"; : > "$markers"
worker() {
  acquire_lock "$lock" "$(date +%s)" || return
  echo "start$1" >> "$markers"; sleep 0.2; echo "end$1" >> "$markers"
  release_lock "$lock"
}
worker A & worker B & wait
if awk 'NR%2==1 && $0!~/^start/{bad=1} NR%2==0 && $0!~/^end/{bad=1} END{exit bad?1:0}' "$markers" \
   && [ "$(grep -c start "$markers")" = 2 ] && [ "$(grep -c end "$markers")" = 2 ]; then
  echo "PASS lock-mutual-exclusion"
else
  echo "FAIL lock-mutual-exclusion (seq: $(tr '\n' ' ' < "$markers"))"; fail=1
fi

# --- T2: a lock abandoned by a crashed session is reclaimed ---
lock2="${tmp}/t2.lock"; mkdir "$lock2"
echo "$(( $(date +%s) - 999 ))" > "$lock2/ts"   # far older than STALE_SEC
if acquire_lock "$lock2" "$(date +%s)"; then
  echo "PASS lock-stale-reclaim"; release_lock "$lock2"
else
  echo "FAIL lock-stale-reclaim"; fail=1
fi

# --- T3: a fresh lock held by someone else -> give up (caller runs lockless) ---
lock3="${tmp}/t3.lock"; mkdir "$lock3"; echo "$(date +%s)" > "$lock3/ts"
STATUSLINE_LOCK_TRIES=3 acquire_lock "$lock3" "$(date +%s)"
if [ "$?" = 1 ]; then echo "PASS lock-timeout-degrades"; else echo "FAIL lock-timeout-degrades"; fail=1; fi
release_lock "$lock3"

exit "$fail"
