#!/usr/bin/env bash
# Opens the latest GitLab MR of the active worktree workspace's branch in the browser.
set -u
herdr=${HERDR_BIN_PATH:-herdr}

path=$("$herdr" workspace list | jq -r --arg ws "${HERDR_WORKSPACE_ID:-}" '.result.workspaces[]
  | select(.workspace_id == $ws and .worktree.is_linked_worktree) | .worktree.checkout_path')
[ -n "$path" ] || exit 0
branch=$(git -C "$path" branch --show-current)
url=$(cd "$path" && glab mr list --all --source-branch "$branch" -F json 2>/dev/null |
  jq -r 'max_by(.iid).web_url // empty')
[ -n "$url" ] && open "$url"
