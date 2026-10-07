return {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_dir = function(bufnr, on_dir)
    on_dir(require("config.nvim.python").root(bufnr))
  end,
  before_init = function(_, config)
    config.settings.python.pythonPath = require("config.nvim.python").interpreter(config.root_dir)
  end,
  settings = {
    pyright = { disableOrganizeImports = true },
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "basic",
      },
    },
  },
}
