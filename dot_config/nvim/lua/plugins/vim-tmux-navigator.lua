-- Seamless <C-h/j/k/l> across editor splits and multiplexer panes.
-- Inside herdr, vim-herdr-navigation's editor shim takes over (it falls back to
-- tmux/wincmd on its own); on machines without herdr, vim-tmux-navigator's
-- lazy setup applies as before.
local nav = vim.fn.glob("~/.config/herdr/plugins/github/vim-herdr-navigation-*/editor/nvim.lua", true, true)[1]

if not nav then
  return {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>" },
    },
  }
end

return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  config = function()
    -- LazyVim's default <C-hjkl> window keymaps load on VeryLazy and would
    -- override the shim's, so apply the shim after them.
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        vim.schedule(function()
          dofile(nav)
        end)
      end,
    })
  end,
}
