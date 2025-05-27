return {
  "folke/snacks.nvim",
  keys = {
    { "<leader>/", LazyVim.pick("grep", { hidden = true }), desc = "Grep (Root Dir)" },
    { "<leader><space>", LazyVim.pick("files", { hidden = true }), desc = "Find Files (Root Dir)" },
    { "<leader>ff", LazyVim.pick("files", { hidden = true }), desc = "Find Files (Root Dir)" },
    { "<leader>fF", LazyVim.pick("files", { root = false, hidden = true }), desc = "Find Files (cwd)" },
    { "<leader>sg", LazyVim.pick("live_grep", { hidden = true }), desc = "Grep (Root Dir)" },
    { "<leader>sG", LazyVim.pick("live_grep", { root = false, hidden = true }), desc = "Grep (cwd)" },
    {
      "<leader>sw",
      LazyVim.pick("grep_word", { hidden = true }),
      desc = "Visual selection or word (Root Dir)",
      mode = { "n", "x" },
    },
    {
      "<leader>sW",
      LazyVim.pick("grep_word", { root = false, { hidden = true } }),
      desc = "Visual selection or word (cwd)",
      mode = { "n", "x" },
    },
  },
}
