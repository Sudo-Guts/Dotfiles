return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = { sh = { "shellcheck" }, bash = { "shellcheck" } }
    -- ShellCheck no soporta Zsh; Verible y clangd ya generan sus diagnósticos.
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("GutsLint", { clear = true }),
      callback = function()
        if vim.bo.buftype == "" and vim.fn.executable("shellcheck") == 1 then
          lint.try_lint()
        end
      end,
    })
  end,
}
