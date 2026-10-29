local health = require("config.nvim.health")
local lock_path = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))
local expected = assert(lock["lazy.nvim"], "Falta la versión fijada de Lazy")
local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local install = vim.env.DOTFILES_NVIM_INSTALL == "1" and vim.env.DOTFILES_NVIM_READONLY ~= "1"

local function git(arguments)
    local result = vim.system(arguments, { text = true }):wait(120000)
    assert(result.code == 0, "Git/Lazy: " .. (result.stderr or result.stdout or "operación fallida"))
    return vim.trim(result.stdout or "")
end

if vim.fn.filereadable(path .. "/lua/lazy/init.lua") == 0 then
    if not install then
        health.report("lazy", "Falta Lazy o su instalación está incompleta; ejecuta dotfiles install. Se conserva la edición básica.", true)
        return
    end
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    if not vim.uv.fs_stat(path) then
        local staged = path .. ".tmp." .. tostring(vim.uv.hrtime())
        local ok, err = pcall(function()
            git({ "git", "clone", "--filter=blob:none", "--no-checkout", "https://github.com/folke/lazy.nvim.git", staged })
            git({ "git", "-C", staged, "fetch", "--depth=1", "origin", expected.commit })
            git({ "git", "-C", staged, "checkout", "--detach", expected.commit })
            assert(vim.uv.fs_rename(staged, path))
        end)
        if not ok then
            vim.fn.delete(staged, "rf")
            error(err)
        end
    end
end

if install and git({ "git", "-C", path, "rev-parse", "HEAD" }) ~= expected.commit then
    git({ "git", "-C", path, "fetch", "--depth=1", "origin", expected.commit })
    git({ "git", "-C", path, "checkout", "--detach", expected.commit })
end

local spec = { { import = "plugins" } }
for name, version in pairs(lock) do
    assert(type(version.commit) == "string" and version.commit:match("^%x+$") and #version.commit == 40, "Commit de plugin inválido: " .. name)
    spec[#spec + 1] = { name, name = name, optional = true, commit = version.commit, branch = version.branch, pin = true }
end
vim.opt.rtp:prepend(path)
require("lazy").setup({
    spec = spec,
    defaults = { lazy = true },
    concurrency = 2,
    lockfile = vim.env.DOTFILES_NVIM_LOCKFILE or lock_path,
    checker = { enabled = false },
    install = { missing = false },
    rocks = { enabled = false },
    change_detection = { notify = false },
    ui = { border = "rounded" },
    performance = { rtp = { disabled_plugins = { "netrwPlugin", "tutor" } } },
})
