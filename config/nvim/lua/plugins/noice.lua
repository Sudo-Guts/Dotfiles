return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
  opts = {
    lsp = { progress = { enabled = true }, hover = { enabled = false }, signature = { enabled = false } },
    notify = { enabled = true },
    presets = { bottom_search = true, command_palette = true, long_message_to_split = true },
    routes = { { filter = { event = "msg_show", kind = "search_count" }, opts = { skip = true } } },
  },
}
