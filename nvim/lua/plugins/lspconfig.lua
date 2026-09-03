-- lspconfig.lua - Configuración LSP para Verilog (nuevo estilo)
return {
  -- Cargamos nvim-lspconfig para tener utilidades, pero usamos la API nueva
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Registrar el servidor Verible
      vim.lsp.config("verible", {
        cmd = { "verible-verilog-ls" },
        filetypes = { "verilog", "systemverilog" },
        -- Buscar raíz del proyecto (intenta encontrar .git o cualquier archivo .prj)
        root_dir = function()
          return vim.fs.root(0, { ".git", "*.prj" }) or vim.fn.getcwd()
        end,
        -- Opciones adicionales (si necesitas incluir rutas, añádelas aquí)
        -- init_options = {
        --   include_paths = { "/path/to/includes" },
        -- },
      })

      -- Activar el servidor para los filetypes definidos
      vim.lsp.enable("verible")
    end,
  },
}
