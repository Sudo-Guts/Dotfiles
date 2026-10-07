return {
  "neovim/nvim-lspconfig",

  event = {
    "BufReadPre",
    "BufNewFile",
  },

  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "mason-org/mason.nvim",
  },

  config = function()
    local lsp = require("config.nvim.lsp")

    -- Configuración común para todos los servidores.
    lsp.setup()

    -- Activar después de configurar.
    lsp.enable_servers()
  end,
}
