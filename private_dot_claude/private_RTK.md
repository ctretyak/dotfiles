# RTK - Rust Token Killer

Token-optimized CLI proxy (60-90% savings on dev operations). Bash commands are rewritten to `rtk <cmd>` automatically by a `PreToolUse` hook — transparent, 0 tokens overhead, nothing to do.

Meta commands, always run `rtk` directly:

```bash
rtk gain              # Token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Run a raw command without filtering (debugging)
```

If `rtk gain` errors out, the wrong `rtk` is on PATH — likely reachingforthejack/rtk ("Rust Type Kit").
