local M = {}

function M.locked()
    assert(package.loaded.lazy, "No se cargó Lazy; ejecuta dotfiles install")
    local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
    for name, plugin in pairs(require("lazy.core.config").plugins) do
        local expected = assert(lock[name], "Plugin sin versión fijada: " .. name)
        assert(plugin.commit == expected.commit and plugin.pin, "Plugin sin restricción de versión: " .. name)
    end
    return lock
end

function M.plugins()
    local lock = M.locked()
    for name, plugin in pairs(require("lazy.core.config").plugins) do
        assert(plugin._.installed and not vim.uv.fs_stat(plugin.dir .. ".cloning"), "Instalación incompleta de " .. name .. "; ejecuta dotfiles install")
        local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
        assert(result.code == 0 and vim.trim(result.stdout or "") == lock[name].commit, "Restauración incompleta de " .. name .. "; ejecuta dotfiles install")
    end
end

function M.status()
    local entries = {}
    local function add(name, ok, message, required)
        entries[#entries + 1] = { name = name, ok = ok == true, message = tostring(message), required = required ~= false }
    end
    local ok, err = pcall(M.plugins)
    add("Plugins fijados", ok, ok and "commits y restricciones correctos" or err)
    for name, issue in pairs(require("config.nvim.health").issues) do
        add(name, false, issue.message, issue.required)
    end
    local tools_ok, tools = pcall(function()
        require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
        return require("config.nvim.tools").status()
    end)
    if tools_ok then
        for _, item in ipairs(tools) do
            if not item.available then
                add(item.name, false, "herramienta ausente")
            elseif item.external then
                add(item.name, false, "externa en " .. item.path .. "; versión sin verificar", false)
            elseif item.drift then
                add(item.name, false, (item.version or "sin recibo") .. "; fijada " .. item.target, vim.env.DOTFILES_UPDATE == "1")
            else
                add(item.name, true, item.version)
            end
        end
        if require("config.nvim.tools").enabled("hdl") then
            add("verible-verilog-format", vim.fn.executable("verible-verilog-format") == 1, "formateador HDL")
        end
    else
        add("Herramientas", false, tools)
    end
    local parsers_ok, parsers = pcall(function()
        return require("config.nvim.parsers").status()
    end)
    if parsers_ok then
        for _, item in ipairs(parsers) do
            if item.required or item.installed then
                add("Parser " .. item.name, item.ok, item.ok and ("revisión " .. item.target) or "ausente, incompatible o revisión distinta; ejecuta dotfiles install", item.required)
            end
        end
    else
        add("Parsers", false, parsers)
    end
    return entries
end

function M.check()
    local failed = {}
    for _, item in ipairs(M.status()) do
        if item.ok then
            print("OK " .. item.name .. ": " .. item.message)
        elseif item.required then
            failed[#failed + 1] = item.name .. ": " .. item.message
        else
            print("REVISAR " .. item.name .. ": " .. item.message)
        end
    end
    assert(#failed == 0, table.concat(failed, "\n"))
    print("Núcleo de Neovim verificado; los parsers auxiliares son opcionales.")
end

return M
