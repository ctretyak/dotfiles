#!/usr/bin/env bash
# Reports the latest GitLab MR of each worktree workspace's branch as the
# workspace token $mr: "!123" for open MRs, "!123 merged" / "!123 closed" otherwise.
set -u
herdr=${HERDR_BIN_PATH:-herdr}

# Prints the newest MR (any state) of the branch as JSON, or nothing.
latest_mr() {
  (cd "$1" && glab mr list --all --source-branch "$2" -F json 2>/dev/null) | jq -c 'max_by(.iid) // empty'
}

update() {
  local ws=$1 path=$2 branch mr
  branch=$(git -C "$path" branch --show-current 2>/dev/null)
  [ -n "$branch" ] || return 0
  mr=$(latest_mr "$path" "$branch" |
    jq -r '"!\(.iid)" + (if .state == "opened" then "" else " \(.state)" end)')
  if [ -n "$mr" ]; then
    "$herdr" workspace report-metadata "$ws" --source glab-mr --token "mr=$mr" >/dev/null
  else
    "$herdr" workspace report-metadata "$ws" --source glab-mr --clear-token mr >/dev/null
  fi
}

workspaces() {
  "$herdr" workspace list | jq -r '.result.workspaces[] | select(.worktree.is_linked_worktree)
    | "\(.workspace_id)\t\(.worktree.checkout_path)"'
}

# "open": open the active workspace's MR in the browser.
if [ "${1:-}" = open ]; then
  path=$(workspaces | awk -F'\t' -v ws="${HERDR_WORKSPACE_ID:-}" '$1 == ws { print $2 }')
  [ -n "$path" ] || exit 0
  url=$(latest_mr "$path" "$(git -C "$path" branch --show-current)" | jq -r '.web_url // empty')
  [ -n "$url" ] && open "$url"
  exit 0
fi

# Startup and the manual action refresh everything; events refresh one workspace.
target=""
if [ "${HERDR_PLUGIN_EVENT:-startup}" != startup ] && [ "${1:-}" != all ]; then
  target=$(jq -r '[.. | .workspace_id? // empty] | first // empty' <<<"${HERDR_PLUGIN_EVENT_JSON:-null}")
fi

workspaces | awk -F'\t' -v t="$target" 't == "" || $1 == t' |
  while IFS=$'\t' read -r ws path; do update "$ws" "$path"; done
