#!/bin/bash
# Links the local herdr glab-mr plugin (prefix+m opens the worktree's MR).
set -e
/opt/homebrew/bin/herdr plugin link "$HOME/.config/herdr/local-plugins/glab-mr" >/dev/null
