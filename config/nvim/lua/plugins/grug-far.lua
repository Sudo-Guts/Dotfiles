local icons = require("config.nvim.icons")

return {
  "MagicDuck/grug-far.nvim",
  cmd = "GrugFar",
  opts = {},
  keys = { { "<leader>cR", "<Cmd>GrugFar<CR>", desc = icons.label("replace", "Reemplazar en proyecto") } },
}
