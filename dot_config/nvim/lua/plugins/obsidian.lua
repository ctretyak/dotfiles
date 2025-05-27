return {
  {
    "epwalsh/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    lazy = true,
    -- ft = "markdown",
    event = {
      "BufReadPre " .. vim.fn.expand("~") .. "/Documents/Core/*.md",
      "BufNewFile " .. vim.fn.expand("~") .. "/Documents/Core/*.md",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
    },
    opts = {
      completion = {
        nvim_cmp = false, -- disable!
      },
      workspaces = {
        {
          name = "Core",
          path = "~/Documents/Core",
        },
      },
      picker = {
        name = "fzf-lua",
      },
      templates = {
        folder = "system/templates",
      },
      daily_notes = {
        folder = "periodic",
        template = "system/templates/Daily Note.md",
      },
      notes_subdir = "index",
      ui = {
        enbaled = false,
      },
    },
    keys = {
      { "<leader>on", "<cmd>ObsidianNew<CR>", desc = "New Obsidian note" },
      { "<leader>ot", "<cmd>ObsidianToday<CR>", desc = "Daily note" },
      { "<leader>of", "<cmd>ObsidianQuickSwitch<CR>", desc = "Find note" },
      { "<leader>ol", "<cmd>ObsidianLink<CR>", desc = "Link note" },
      { "<leader>ob", "<cmd>ObsidianBacklinks<CR>", desc = "Show backlinks" },
      { "<leader>os", "<cmd>ObsidianSearch<CR>", desc = "Search" },
    },
    config = function(_, opts)
      require("obsidian").setup(opts)

      -- HACK: fix error, disable completion.nvim_cmp option, manually register sources
      local cmp = require("cmp")
      cmp.register_source("obsidian", require("cmp_obsidian").new())
      cmp.register_source("obsidian_new", require("cmp_obsidian_new").new())
      cmp.register_source("obsidian_tags", require("cmp_obsidian_tags").new())
    end,
  },
  -- https://github.com/epwalsh/obsidian.nvim/issues/770#issuecomment-2557300925
  {
    "saghen/blink.cmp",
    dependencies = { "saghen/blink.compat" },
    opts = {
      sources = {
        default = { "obsidian", "obsidian_new", "obsidian_tags" },
        providers = {
          obsidian = {
            name = "obsidian",
            module = "blink.compat.source",
          },
          obsidian_new = {
            name = "obsidian_new",
            module = "blink.compat.source",
          },
          obsidian_tags = {
            name = "obsidian_tags",
            module = "blink.compat.source",
          },
        },
      },
    },
  },
}
