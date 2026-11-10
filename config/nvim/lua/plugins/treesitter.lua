return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    config = function()
        require("nvim-treesitter").setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
        vim.treesitter.language.register("systemverilog", { "verilog", "systemverilog" })
        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("GutsTreesitter", { clear = true }),
            callback = function(args)
                if vim.bo[args.buf].buftype ~= "" then
                    return
                end
                local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(args.buf))
                if stat and stat.size > 1024 * 1024 then
                    return
                end
                local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
                if not lang then
                    return
                end
                local ok, loaded = pcall(vim.treesitter.language.add, lang)
                if not ok or not loaded then
                    require("config.nvim.health").report("parser:" .. lang, "Parser " .. lang .. " no disponible; se conserva el resaltado básico. :TSInstall " .. lang .. " permite prepararlo.")
                    return
                end
                local started, err = pcall(vim.treesitter.start, args.buf)
                if started then
                    require("config.nvim.health").issues["parser:" .. lang] = nil
                    vim.wo.foldmethod = "expr"
                    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
                    vim.wo.foldlevel = 99
                else
                    require("config.nvim.health").report("parser:" .. lang, "No se pudo activar " .. lang .. ": " .. tostring(err))
                end
            end,
        })
    end,
}
