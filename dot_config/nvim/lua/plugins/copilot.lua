return {
  "zbirenbaum/copilot.lua",
  opts = {
    suggestion = {
      keymap = {
        accept = "<M-l>",
        accept_word = "<M-w>",
        accept_line = "<M-W>",
      },
    },
    filetypes = {
      yaml = true,
      gitcommit = true,
      gitrebase = true,
      hgcommit = true,
    },
  },
}
