return {
  "mason-org/mason.nvim",
  cmd = { "Mason", "DotfilesToolsInstall" },
  opts = { PATH = "append", ui = { border = "rounded" } },
  config = function(_, opts)
    require("mason").setup(opts)
    vim.api.nvim_create_user_command("DotfilesToolsInstall", function()
      require("config.nvim.tools").install(false)
    end, { desc = "Instalar herramientas de desarrollo faltantes" })
  end,
}
