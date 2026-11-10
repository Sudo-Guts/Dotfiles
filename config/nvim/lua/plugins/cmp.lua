return {
  "hrsh7th/nvim-cmp",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "saadparwaiz1/cmp_luasnip",
    "L3MON4D3/LuaSnip",
    "rafamadriz/friendly-snippets",
    "nvim-mini/mini.icons",
  },
  config = function()
    local cmp, snippets = require("cmp"), require("luasnip")
    require("luasnip.loaders.from_vscode").lazy_load()
    require("config.nvim.snippets").setup()
    cmp.setup({
      snippet = {
        expand = function(args)
          snippets.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif snippets.expand_or_locally_jumpable() then
            snippets.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif snippets.locally_jumpable(-1) then
            snippets.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      sources = cmp.config.sources(
        { { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } },
        { { name = "buffer" } }
      ),
      formatting = {
        format = function(entry, item)
          local icon = require("mini.icons").get("lsp", item.kind)
          item.kind = icon .. " " .. item.kind
          item.menu = ({ nvim_lsp = "LSP", luasnip = "Snip", path = "Ruta", buffer = "Texto" })[entry.source.name]
          return item
        end,
      },
      window = { completion = cmp.config.window.bordered(), documentation = cmp.config.window.bordered() },
      experimental = { ghost_text = false },
    })
    cmp.setup.cmdline(
      { "/", "?" },
      { mapping = cmp.mapping.preset.cmdline(), sources = { { name = "buffer" } } }
    )
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
    })
  end,
}
