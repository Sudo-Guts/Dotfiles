return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    { "<leader>gd", "<Cmd>DiffviewOpen<CR>", desc = "Revisar cambios" },
    { "<leader>gH", "<Cmd>DiffviewFileHistory %<CR>", desc = "Historial del archivo" },
    { "<leader>gq", "<Cmd>DiffviewClose<CR>", desc = "Cerrar Diffview" },
  },
}
