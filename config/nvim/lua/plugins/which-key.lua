local icons = require("config.nvim.icons")

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    win = { border = "rounded" },
    icons = {
      mappings = false,
      breadcrumb = "»",
      separator = "",
      group = "+",
      keys = { Space = "󱁐", Tab = "󰌒", Esc = "󱊷" },
    },
    spec = {
      { "<leader>f", group = icons.label("search", "Buscar") },
      { "<leader>g", group = icons.label("git", "Git") },
      { "<leader>c", group = icons.label("code", "Código") },
      {
        "<leader>r",
        group = function()
          local language = require("config.nvim.project").language()
          return language == "cpp" and icons.label("project", "Proyecto C/C++")
            or language and icons.label("project", "Proyecto HDL")
            or icons.label("project", "Proceso")
        end,
      },
      { "<leader>x", group = icons.label("diagnostics", "Diagnósticos") },
      { "<leader>b", group = icons.label("buffers", "Buffers") },
      { "<leader>d", group = icons.label("debug", "Depurar") },
      { "<leader>h", group = icons.label("edit", "Cambios") },
      { "<leader>s", group = icons.label("save", "Sesiones") },
      { "<leader>t", group = icons.label("terminal", "Terminal / vista") },
    },
  },
}
