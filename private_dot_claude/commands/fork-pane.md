---
description: Fork this conversation into a new tmux pane
disable-model-invocation: true
---

!`tmux split-window -h -c "#{pane_current_path}" "claude --resume $CLAUDE_CODE_SESSION_ID --fork-session"`
