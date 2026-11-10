return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local dashboard = require("alpha.themes.dashboard")
    local alpha = require("alpha")

    dashboard.section.header.val = {
      "  ▄████     █    ██    ▄▄▄█████▓     ██████ ",
      " ██▒ ▀█▒    ██  ▓██▒   ▓  ██▒ ▓▒   ▒██    ▒ ",
      "▒██░▄▄▄░   ▓██  ▒██░   ▒ ▓██░ ▒░   ░ ▓██▄   ",
      "░▓█  ██▓   ▓▓█  ░██░   ░ ▓██▓ ░      ▒   ██▒",
      "░▒▓███▀▒   ▒▒█████▓      ▒██▒ ░    ▒██████▒▒",
      " ░▒   ▒    ░▒▓▒ ▒ ▒      ▒ ░░      ▒ ▒▓▒ ▒ ░",
      "  ░   ░    ░░▒░ ░ ░        ░       ░ ░▒  ░ ░",
      "░ ░   ░     ░░░ ░ ░      ░         ░  ░  ░  ",
      "      ░       ░                          ░  ",
    }

    dashboard.section.header.opts.hl = "AlphaHeaderLabel"

    -- Menu
    dashboard.section.buttons.val = {
      dashboard.button("f", "  Buscar archivo", ":Telescope find_files<CR>"),
      dashboard.button("g", "󱎸  Buscar texto", ":Telescope live_grep<CR>"),
      dashboard.button("r", "󰋚  Recientes", ":Telescope oldfiles<CR>"),
      dashboard.button("e", "󰙅  Proyecto", ":Neotree reveal<CR>"),
      dashboard.button("s", "󰁯  Sesión", ":lua require('persistence').load()<CR>"),
      dashboard.button("l", "󰒲  Plugins", ":Lazy<CR>"),
      dashboard.button("m", "󰏖  Herramientas", ":Mason<CR>"),
      dashboard.button("q", "󰗼  Salir", ":qa<CR>"),
    }

    alpha.setup(dashboard.opts)
  end,
}
