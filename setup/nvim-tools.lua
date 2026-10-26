-- Lazy puede notificar un fallo sin cambiar el código de salida del editor.
local checks = dofile(assert(vim.env.DOTFILES_NVIM_CHECK_SCRIPT))
checks.plugins()
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
require("config.nvim.tools").install(true)
-- Compila un parser a la vez, también durante la primera instalación.
local installed =
  require("nvim-treesitter").install(require("config.nvim.parsers"), { max_jobs = 1 }):wait(600000)
assert(installed, "No se pudieron instalar todos los parsers de Treesitter")
checks.check()
