return {
    "neovim/nvim-lspconfig",

    ft = { "c", "cpp", "objc", "objcpp", "cuda", "lua", "python", "verilog", "systemverilog", "vhdl" },

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
