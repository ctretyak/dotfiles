# Your custom zshrc content here

#export NODE_EXTRA_CA_CERTS=~/.rca-ca.crt

# Claude Code: trigger auto-compact earlier for better reasoning quality
# With 1M context (Opus 4.6), context rot starts ~500K tokens (~50%)
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50