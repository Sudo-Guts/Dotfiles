-- Las descargas solo se solicitan desde el instalador o comandos explícitos.
local checks = dofile(assert(vim.env.DOTFILES_NVIM_CHECK_SCRIPT))
checks.plugins()
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
require("config.nvim.tools").install(true)
require("config.nvim.parsers").install()
checks.check()
