return {
  "LazyVim/LazyVim",
  keys = {
    {
      "<leader>cd",
      function()
        vim.cmd("new | setlocal buftype=nowrite | put + | diffthis")
        vim.cmd("wincmd p | diffthis")
      end,
      desc = "Compare with Clipboard",
    },
  },
}
