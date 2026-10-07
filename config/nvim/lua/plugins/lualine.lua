return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = { theme = "catppuccin", globalstatus = true },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = {
        function()
          local names = {}
          for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
            names[#names + 1] = client.name
          end
          return table.concat(names, ",")
        end,
        "encoding",
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    extensions = { "neo-tree", "trouble", "nvim-dap-ui", "quickfix" },
  },
}
