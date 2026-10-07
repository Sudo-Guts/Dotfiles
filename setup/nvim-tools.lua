-- Lazy puede notificar un fallo sin cambiar el código de salida del editor.
local checks = dofile(assert(vim.env.DOTFILES_NVIM_CHECK_SCRIPT))
checks.plugins()
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
require("config.nvim.tools").install(true)
require("nvim-treesitter").install(require("config.nvim.parsers")):wait(600000)
checks.check()
