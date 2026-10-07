local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
  assert(vim.env.DOTFILES_NVIM_READONLY ~= "1", "Falta Lazy; ejecuta dotfiles install")
  local result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    path,
  })
  if vim.v.shell_error ~= 0 then
    error("No se pudo instalar Lazy: " .. result)
  end
  -- Restaurar también la versión de Lazy fijada en el lockfile.
  local lock = vim.fn.stdpath("config") .. "/lazy-lock.json"
  if vim.fn.filereadable(lock) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(lock), "\n"))
    if ok and data["lazy.nvim"] then
      vim.fn.system({ "git", "-C", path, "fetch", "--depth=1", "origin", data["lazy.nvim"].commit })
      if vim.v.shell_error == 0 then
        vim.fn.system({ "git", "-C", path, "checkout", data["lazy.nvim"].commit })
      end
    end
  end
end
vim.opt.rtp:prepend(path)
require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = true },
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
  checker = { enabled = false },
  install = { missing = vim.env.DOTFILES_NVIM_READONLY ~= "1" },
  rocks = { enabled = false }, -- Ningún plugin de este conjunto requiere LuaRocks.
  change_detection = { notify = false },
  ui = { border = "rounded" },
  performance = { rtp = { disabled_plugins = { "netrwPlugin", "tutor" } } },
})
