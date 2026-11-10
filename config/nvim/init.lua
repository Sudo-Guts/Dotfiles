vim.g.mapleader = " "
vim.g.maplocalleader = ","
if vim.fn.has("nvim-0.12") == 0 then
    vim.api.nvim_echo({ { "GUTS requiere Neovim >= 0.12. Ejecuta dotfiles install", "ErrorMsg" } }, true, {})
    return
end
local health = require("config.nvim.health")
health.setup()
for _, name in ipairs({ "options", "autocmds", "keymaps", "lazy" }) do
    health.guard("config:" .. name, function()
        require("config.nvim." .. name)
    end)
end
local configured = {}
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("GutsHdlSetup", { clear = true }),
    pattern = { "verilog", "systemverilog", "vhdl" },
    callback = function(args)
        local name = vim.bo[args.buf].filetype == "vhdl" and "vhdl" or "verilog"
        if not configured[name] then
            configured[name] = health.guard("hdl:" .. name, function()
                require("config.hdl." .. name).setup()
            end)
        end
    end,
})
