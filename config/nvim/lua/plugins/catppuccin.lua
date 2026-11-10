return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "mocha",
    transparent_background = true,
    integrations = {
      cmp = true,
      gitsigns = true,
      treesitter = true,
      notify = true,
      neotree = true,
      mason = true,
      which_key = true,
      dap = true,
      dap_ui = true,
      render_markdown = true,
      telescope = { enabled = true },
      native_lsp = { enabled = true },
      mini = { enabled = true },
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin-mocha")
    vim.api.nvim_set_hl(0, "AlphaHeaderLabel", { fg = "#cba6f7", bold = true })
  end,
}
