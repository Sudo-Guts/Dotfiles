local M = { issues = {} }

function M.report(key, message, required)
    if M.issues[key] and M.issues[key].message == message then
        return
    end
    M.issues[key] = { message = message, required = required == true }
    vim.schedule(function()
        vim.notify(message .. "\n:DotfilesHealth muestra el diagnóstico.", required and vim.log.levels.ERROR or vim.log.levels.WARN, { title = "Dotfiles" })
    end)
end

function M.guard(name, action)
    local ok, result = xpcall(action, debug.traceback)
    if ok then
        M.issues[name] = nil
    else
        M.report(name, tostring(result), true)
    end
    return ok, result
end

function M.setup()
    vim.api.nvim_create_user_command("DotfilesHealth", function()
        vim.cmd("checkhealth config.nvim")
    end, { desc = "Revisar el entorno de Neovim sin descargar componentes" })
end

function M.check()
    vim.health.start("Dotfiles: versiones, herramientas y parsers")
    local root = vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(vim.fn.stdpath("config")))))
    local ok, entries = pcall(function()
        return dofile(root .. "/setup/nvim-doctor.lua").status()
    end)
    if not ok then
        vim.health.error(tostring(entries))
        return
    end
    for _, entry in ipairs(entries) do
        local message = entry.name .. ": " .. entry.message
        if entry.ok then
            vim.health.ok(message)
        elseif entry.required then
            vim.health.error(message)
        else
            vim.health.warn(message)
        end
    end
end

return M
