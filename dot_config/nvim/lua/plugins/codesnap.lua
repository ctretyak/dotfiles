local prefix = "<Leader>c"

return {
  "mistricky/codesnap.nvim",
  build = "make",
  keys = {
    { prefix .. "s", "<esc><cmd>CodeSnap<cr>", mode = "x", desc = "Save selected code snapshot" },
    {
      prefix .. "h",
      "<esc><cmd>CodeSnapHighlight<cr>",
      mode = "x",
      desc = "Save selected code snapshot with highlight",
    },
  },
  opts = {
    has_breadcrumbs = true,
    has_line_number = true,
    mac_window_bar = false,
    watermark = "",
  },
}
