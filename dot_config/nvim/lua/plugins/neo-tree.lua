return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_by_name = {
          ".git",
        },
        always_show_by_pattern = {
          ".env*",
        },
      },
      window = {
        mappings = {
          ["/"] = "live_grep_in_dir",
        },
      },
    },
    commands = {
      live_grep_in_dir = function(state)
        local node = state.tree:get_node()
        local path = node.type == "file" and node:get_parent_id() or node:get_id()
        LazyVim.pick("live_grep", {
          hidden = true,
          cwd = path,
          title = "Grep in " .. vim.fn.fnamemodify(path, ":."),
        })()
      end,
    },
  },
}
