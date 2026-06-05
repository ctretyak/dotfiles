return {
  -- treesitter highlighting for graphql (incl. embedded in tagged templates)
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "graphql" } },
  },
  -- graphql language server (mason auto-installs graphql-language-service-cli)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        graphql = {
          -- default is { "graphql", "typescriptreact", "javascriptreact" };
          -- add plain ts/js so completion fires inside graphql(`...`) in .ts files
          filetypes = { "graphql", "typescript", "typescriptreact", "javascript", "javascriptreact" },
        },
      },
    },
  },
}
