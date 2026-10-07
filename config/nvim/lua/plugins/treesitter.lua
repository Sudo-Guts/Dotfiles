return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
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
        -- El parser systemverilog actual cubre ambos filetypes.
        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang or not vim.treesitter.language.add(lang) then
          return
        end
        local ok = pcall(vim.treesitter.start, args.buf)
        if ok then
          vim.wo.foldmethod = "expr"
          vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo.foldlevel = 99
        end
      end,
    })
  end,
}
