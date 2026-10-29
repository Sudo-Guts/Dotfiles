-- Probar selección y reconciliación de Mason sin descargar herramientas.
local original_vim = vim
local ok, err = pcall(function()
    local root = assert(os.getenv("DOTFILES_TEST_ROOT"))
    local installed, versions, calls, refreshes = {}, {}, {}, 0
    local executables = {}
    package.loaded["mason.settings"] = { current = { install_root_dir = "/mason" } }
    package.loaded["mason-registry"] = {
        refresh = function(callback)
            refreshes = refreshes + 1
            callback(true)
        end,
        get_package = function(name)
            return {
                is_installed = function() return installed[name] == true end,
                is_installing = function() return false end,
                get_installed_version = function() return versions[name] end,
                install = function(_, opts, callback)
                    calls[#calls + 1] = name
                    installed[name], versions[name] = true, opts.version
                    callback(true)
                end,
            }
        end,
    }
    _G.vim = {
        env = { DOTFILES_UPDATE = "0" },
        uv = { fs_realpath = function(path) return path end },
        fs = {
            normalize = function(path) return path end,
            dirname = function(path) return path:match("^(.*)/[^/]+$") end,
        },
        fn = {
            stdpath = function() return root .. "/config/nvim" end,
            readfile = function(path)
                local lines = {}
                for line in io.lines(path) do lines[#lines + 1] = line end
                return lines
            end,
            executable = function(exe) return installed[executables[exe]] and 1 or 0 end,
            exepath = function(exe) return installed[executables[exe]] and "/mason/bin/" .. exe or "" end,
        },
        schedule_wrap = function(callback) return callback end,
        wait = function(_, condition) return condition() end,
    }
    -- Neovim utiliza LuaJIT; también permite ejecutar esta prueba con Lua 5.4.
    _G.unpack = _G.unpack or table.unpack
    local tools = dofile(root .. "/config/nvim/lua/config/nvim/tools.lua")
    for _, entry in ipairs(tools.packages) do executables[entry[2]] = entry[1] end
    assert(#tools.status() == 9, "El núcleo debe incluir los nueve paquetes Mason")
    assert(tools.enabled("hdl") and tools.enabled("python"))
    vim.env.DOTFILES_NVIM_MODULES = "nvim cpp"
    assert(#tools.status() == 4 and not tools.enabled("hdl"))
    tools.install(true)
    assert(#calls == 4 and refreshes == 1)
    tools.install(true)
    assert(#calls == 4 and refreshes == 1, "Se reinstalaron herramientas completas")
    versions.codelldb = "v0.0.0"
    tools.install(true)
    assert(#calls == 4, "install sustituyó una herramienta disponible")
    vim.env.DOTFILES_UPDATE = "1"
    tools.install(true)
    assert(#calls == 5 and calls[5] == "codelldb", "update no reconcilió únicamente la versión distinta")
    vim.env.DOTFILES_NVIM_MODULES = "hdl python"
    assert(#tools.status() == 5 and tools.enabled("python"))
    tools.install(true)
    assert(installed.verible and installed.rust_hdl and installed.pyright and installed.ruff and installed.debugpy)
    vim.env.DOTFILES_NVIM_MODULES = "unknown"
    assert(not pcall(tools.status), "Se aceptó un módulo inexistente")
end)
_G.vim = original_vim
assert(ok, err)
print("Mason: selección por módulo, idempotencia y reconciliación verificadas sin descargas.")
