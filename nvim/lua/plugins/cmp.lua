-- cmp.lua - Configuración de autocompletado
return {
  -- Plugin principal de autocompletado
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",   -- Fuente LSP
      "hrsh7th/cmp-buffer",      -- Fuente del buffer actual
      "hrsh7th/cmp-path",        -- Fuente de rutas de archivos
      "hrsh7th/cmp-cmdline",     -- Fuente para línea de comandos
      "L3MON4D3/LuaSnip",        -- Snippets (necesario para autocompletar)
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Configuración principal de cmp
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          -- Seleccionar siguiente/anterior
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          -- Confirmar selección
          ['<C-y>'] = cmp.mapping.confirm({ select = true }),
          -- Cerrar menú
          ['<C-e>'] = cmp.mapping.abort(),
          -- Forzar autocompletado manual
          ['<C-space>'] = cmp.mapping.complete(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },   -- Sugerencias del LSP
          { name = "buffer" },      -- Palabras del buffer actual
          { name = "path" },        -- Rutas de archivos
        }),
        -- Configuración para la línea de comandos
        experimental = {
          ghost_text = true,
        },
      })

      -- Configurar autocompletado para la línea de comandos
      cmp.setup.cmdline('/', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' },
        },
      })

      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'cmdline' },
        },
      })
    end,
  },
}
