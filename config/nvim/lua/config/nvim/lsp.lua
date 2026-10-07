local icons = require("config.nvim.icons")

local M = {}

M.servers = {
  clangd = "clangd",
  lua_ls = "lua-language-server",
  verible = "verible-verilog-ls",
  vhdl_ls = "vhdl_ls",
  pyright = "pyright-langserver",
  ruff = "ruff",
}

function M.definition()
  local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/definition" })
  if #clients == 0 then
    vim.notify(
      "No hay un servidor listo para gd. Espacio rg prepara el proyecto; Espacio ci muestra el estado LSP",
      vim.log.levels.WARN
    )
    return
  end
  vim.lsp.buf.definition()
end

function M.setup_capabilities()
  vim.lsp.config("*", {
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  })
end

function M.setup_diagnostics()
  vim.diagnostic.config({
    severity_sort = true,

    virtual_text = {
      spacing = 2,
      prefix = "●",
    },

    float = {
      border = "rounded",
      source = true,
    },

    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "",
        [vim.diagnostic.severity.WARN] = "",
        [vim.diagnostic.severity.INFO] = "",
        [vim.diagnostic.severity.HINT] = "󰌵",
      },
    },
  })
end

function M.setup_keymaps()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("GutsLsp", { clear = true }),

    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      local function map(key, action, desc)
        vim.keymap.set("n", key, action, {
          buffer = args.buf,
          desc = desc,
        })
      end

      map("gd", M.definition, icons.label("definition", "Ir a definición (LSP)"))
      for _, entry in ipairs({
        { "gr", "references", icons.label("references", "Referencias") },
        { "gI", "implementation", icons.label("implementation", "Implementación") },
        { "gy", "type_definition", icons.label("definition", "Definición del tipo"), "typeDefinition" },
        { "K", "hover", icons.label("documentation", "Documentación") },
        { "<leader>cr", "rename", icons.label("edit", "Renombrar símbolo") },
        { "<leader>ca", "code_action", icons.label("action", "Acciones de código"), "codeAction" },
        { "<leader>ck", "signature_help", icons.label("signature", "Firma de función"), "signatureHelp" },
      }) do
        if client and client:supports_method("textDocument/" .. (entry[4] or entry[2])) then
          map(entry[1], vim.lsp.buf[entry[2]], entry[3])
        end
      end
      map("<leader>ci", "<Cmd>checkhealth vim.lsp<CR>", icons.label("diagnostics", "Estado LSP"))
    end,
  })
end

function M.enable_servers()
  for server, executable in pairs(M.servers) do
    if vim.fn.executable(executable) == 1 then
      vim.lsp.enable(server)
    end
  end
end

function M.setup()
  M.setup_capabilities()
  M.setup_diagnostics()
  M.setup_keymaps()
  -- El registro explícito conserva nuestras opciones frente a nvim-lspconfig.
  for server in pairs(M.servers) do
    vim.lsp.config(server, dofile(vim.fn.stdpath("config") .. "/lsp/" .. server .. ".lua"))
  end
end

return M
