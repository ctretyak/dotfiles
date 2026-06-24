return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        files = {
          hidden = true,
          exclude = { "**/docs/superpowers/**" },
        },
        grep = {
          hidden = true,
          exclude = { "**/docs/superpowers/**" },
        },
      },
    },
  },
}
