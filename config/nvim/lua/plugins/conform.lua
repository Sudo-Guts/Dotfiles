local icons = require("config.nvim.icons")
local manual_hdl = { verilog = true, systemverilog = true }

local function available(buf)
    for _, formatter in ipairs(require("conform").list_formatters(buf)) do
        if formatter.available and formatter.name ~= "guts_case_breaks" then
            require("config.nvim.health").issues["format:" .. vim.bo[buf].filetype] = nil
            return true
        end
    end
    require("config.nvim.health").report("format:" .. vim.bo[buf].filetype, "No hay un formateador disponible para " .. vim.bo[buf].filetype .. "; se conserva el texto. :ConformInfo muestra el estado.")
    return false
end

local function project_config(ctx, names)
    return vim.fs.find(names, { path = vim.fs.dirname(ctx.filename), upward = true })[1]
end

local function c_formatters(bufnr)
    local ctx = { filename = vim.api.nvim_buf_get_name(bufnr) }
    if vim.fn.executable("clang-format") == 1 and not project_config(ctx, { ".clang-format", "_clang-format" }) then
        return { "clang-format", "guts_case_breaks" }
    end
    return { "clang-format" }
end

return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo", "FormatToggle" },
    keys = {
        {
            "<leader>cf",
            function()
                if available(0) then
                    require("conform").format({ async = true, lsp_format = "never" })
                end
            end,
            mode = { "n", "x" },
            desc = icons.label("format", "Formatear"),
        },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            c = c_formatters,
            cpp = c_formatters,
            python = { "ruff_format" },
            verilog = { "verible" },
            systemverilog = { "verible" },
            sh = { "shfmt" },
            bash = { "shfmt" },
        },
        formatters = {
            stylua = {
                prepend_args = function(_, ctx)
                    if project_config(ctx, { ".stylua.toml", "stylua.toml" }) then
                        return {}
                    end
                    return { "--config-path", vim.fn.stdpath("config") .. "/.stylua.toml" }
                end,
            },
            guts_case_breaks = {
                format = function(_, ctx, lines, callback)
                    local language = vim.bo[ctx.buf].filetype == "cpp" and "cpp" or "c"
                    callback(nil, require("config.nvim.c_format").case_breaks(lines, language))
                end,
            },
            ["clang-format"] = {
                prepend_args = function(_, ctx)
                    -- Clang busca la configuración más cercana; el estilo GUTS es el respaldo.
                    if project_config(ctx, { ".clang-format", "_clang-format" }) then
                        return { "--style=file" }
                    end
                    return { "--style=file:" .. vim.fn.stdpath("config") .. "/.clang-format" }
                end,
            },
            verible = {
                prepend_args = function(_, ctx)
                    local args = { "--indentation_spaces=4", "--column_limit=111" }
                    local config = project_config(ctx, ".rules.verible_format")
                    if config then
                        -- El archivo del proyecto puede sustituir los valores predeterminados.
                        args[#args + 1] = "--flagfile=" .. config
                    end
                    return args
                end,
            },
        },
        default_format_opts = { lsp_format = "never" },
        format_on_save = function(buf)
            -- Conservar la disposición escrita a mano; Espacio cf sigue siendo explícito.
            if manual_hdl[vim.bo[buf].filetype] then
                return
            end
            if not vim.g.dotfiles_format_on_save or vim.b[buf].disable_autoformat then
                return
            end
            if not require("conform").formatters_by_ft[vim.bo[buf].filetype] then
                return
            end
            local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
            if stat and stat.size > 1024 * 1024 then
                return
            end
            if not available(buf) then
                return
            end
            return { timeout_ms = 2000, lsp_format = "never" }
        end,
    },
    config = function(_, opts)
        require("conform").setup(opts)
        vim.api.nvim_create_user_command("FormatToggle", function()
            vim.g.dotfiles_format_on_save = not vim.g.dotfiles_format_on_save
            local message = "Formato al guardar: " .. tostring(vim.g.dotfiles_format_on_save)
            if manual_hdl[vim.bo.filetype] then
                message = message .. "; Verilog/SV se formatea manualmente con Espacio cf"
            end
            vim.notify(message)
        end, {})
    end,
}
