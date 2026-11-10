local M = {
    required = { "c", "cpp", "lua", "bash", "systemverilog", "vhdl", "python" },
    optional = { "luadoc", "markdown", "markdown_inline", "json", "yaml", "git_config", "git_rebase", "gitcommit", "gitignore", "diff", "make", "cmake", "vim", "vimdoc", "query" },
}

local function directory(name)
    return vim.fn.stdpath("data") .. "/site/" .. name
end

function M.status()
    local registry = require("nvim-treesitter.parsers")
    local result = {}
    for _, group in ipairs({ M.required, M.optional }) do
        for _, lang in ipairs(group) do
            local parser = directory("parser/" .. lang .. ".so")
            local managed = vim.uv.fs_stat(parser) ~= nil
            local ok, loaded = pcall(vim.treesitter.language.add, lang, managed and { path = parser } or nil)
            local file = directory("parser-info/" .. lang .. ".revision")
            local revision = vim.fn.filereadable(file) == 1 and vim.trim(table.concat(vim.fn.readfile(file), "")) or nil
            local target = registry[lang] and registry[lang].install_info.revision
            result[#result + 1] = {
                name = lang,
                required = group == M.required,
                installed = managed,
                ok = ok and loaded == true and managed and revision == target and target ~= nil,
                revision = revision,
                target = target,
            }
        end
    end
    return result
end

-- Los auxiliares existentes se conservan; una instalación nueva prepara el núcleo.
-- :TSInstall permite añadir un auxiliar usando el registro del plugin fijado.
function M.install()
    local failed = {}
    for _, item in ipairs(M.status()) do
        if not item.ok and (item.required or item.installed) then
            local ok, installed = pcall(function()
                return require("nvim-treesitter").install({ item.name }, { force = true, max_jobs = 1 }):wait(180000)
            end)
            local valid = false
            for _, status in ipairs(M.status()) do
                if status.name == item.name then
                    valid = status.ok
                end
            end
            if not ok or not installed or not valid then
                if item.required then
                    failed[#failed + 1] = item.name
                else
                    require("config.nvim.health").report("parser:" .. item.name, "No se pudo preparar el parser opcional " .. item.name .. "; la edición básica sigue disponible.")
                end
            end
        end
    end
    assert(#failed == 0, "Parsers esenciales incompletos: " .. table.concat(failed, ", "))
end

return M
