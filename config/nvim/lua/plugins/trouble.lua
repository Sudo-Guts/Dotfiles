local icons = require("config.nvim.icons")

return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {},
  keys = {
    {
      "<leader>xx",
      "<Cmd>Trouble diagnostics toggle<CR>",
      desc = icons.label("diagnostics", "Diagnósticos del proyecto"),
    },
    {
      "<leader>xb",
      "<Cmd>Trouble diagnostics toggle filter.buf=0<CR>",
      desc = icons.label("diagnostics", "Diagnósticos del buffer"),
    },
    { "<leader>xq", "<Cmd>Trouble qflist toggle<CR>", desc = icons.label("log", "Quickfix") },
    { "<leader>xl", "<Cmd>Trouble loclist toggle<CR>", desc = icons.label("log", "Lista local") },
    {
      "<leader>cs",
      "<Cmd>Trouble symbols toggle focus=false<CR>",
      desc = icons.label("symbols", "Símbolos"),
    },
    {
      "<leader>cL",
      "<Cmd>Trouble lsp toggle<CR>",
      desc = icons.label("references", "Referencias y definiciones"),
    },
  },
}
