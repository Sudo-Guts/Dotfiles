return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = "markdown",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  opts = { file_types = { "markdown" }, max_file_size = 1.0 },
  keys = { { "<leader>tm", "<Cmd>RenderMarkdown toggle<CR>", desc = "Vista Markdown" } },
}
