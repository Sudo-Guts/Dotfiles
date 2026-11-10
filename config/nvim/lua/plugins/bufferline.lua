return {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<S-l>", "<Cmd>BufferLineCycleNext<CR>", desc = "Buffer siguiente" },
    { "<S-h>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Buffer anterior" },
    { "<Tab>.", "<Cmd>BufferLineCycleNext<CR>", desc = "Buffer siguiente" },
    { "<Tab>,", "<Cmd>BufferLineCyclePrev<CR>", desc = "Buffer anterior" },
    { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Fijar buffer" },
  },
  opts = {
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      separator_style = "thin",
      modified_icon = "",
      buffer_close_icon = "󰛉",
      indicator = { style = "icon", icon = "▎" },
      offsets = { { filetype = "neo-tree", text = "GUTS", text_align = "center", separator = true } },
      diagnostics_indicator = function(count)
        return "  " .. count
      end,
    },
  },
}
