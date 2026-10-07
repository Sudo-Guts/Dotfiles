vim.g.mapleader = " "
vim.g.maplocalleader = ","
if vim.fn.has("nvim-0.12") == 0 then
  vim.api.nvim_echo(
    { { "GUTS requiere Neovim >= 0.12. Ejecuta dotfiles install", "ErrorMsg" } },
    true,
    {}
  )
  return
end
require("config.nvim.options")
require("config.nvim.autocmds")
require("config.nvim.keymaps")
require("config.nvim.lazy")
require("config.hdl.verilog").setup()
require("config.hdl.vhdl").setup()
