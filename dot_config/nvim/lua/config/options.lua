-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.ai_cmp = false

-- LazyVim root dir detection
-- Each entry can be:
-- * the name of a detector function like `lsp` or `cwd`
-- * a pattern or array of patterns like `.git` or `lua`.
-- * a function with signature `function(buf) -> string|string[]`
vim.g.root_spec = {}

vim.opt.foldenable = false

vim.opt.clipboard = "unnamedplus"

-- tmux 3.7 added synchronized-output support (DECSET 2026, issues 4744/4887): it
-- defers nvim's frame flushes and occasionally drops one, leaving a blank/stale
-- buffer until a forced redraw (<C-l>/resize). Stop nvim requesting the buffering
-- while inside tmux so there's nothing to defer. Kept on outside tmux (no bug there).
if vim.env.TMUX then
  vim.opt.termsync = false
end
