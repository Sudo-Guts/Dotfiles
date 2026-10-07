local function picker(name)
  return function()
    require("telescope.builtin")[name]()
  end
end
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-ui-select.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
  },
  keys = {
    { "<leader>ff", picker("find_files"), desc = "Buscar archivos" },
    { "<leader>fg", picker("live_grep"), desc = "Buscar texto" },
    { "<leader>fb", picker("buffers"), desc = "Buscar buffers" },
    { "<leader>fh", picker("help_tags"), desc = "Buscar ayuda" },
    { "<leader>fr", picker("oldfiles"), desc = "Archivos recientes" },
    { "<leader>fG", picker("git_files"), desc = "Archivos Git" },
    { "<leader>gb", picker("git_branches"), desc = "Ramas" },
    { "<leader>gc", picker("git_commits"), desc = "Commits" },
    { "<leader>fs", picker("lsp_document_symbols"), desc = "Símbolos del archivo" },
    { "<leader>fR", picker("lsp_references"), desc = "Referencias LSP" },
    { "<leader>fd", picker("diagnostics"), desc = "Buscar diagnósticos" },
  },
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      layout_config = { horizontal = { preview_width = 0.55 } },
      file_ignore_patterns = { "%.git/", "node_modules/", "build/", "%.vcd$", "%.fst$" },
      sorting_strategy = "ascending",
      border = true,
    },
    pickers = { find_files = { hidden = true } },
    extensions = { ["ui-select"] = {} },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    telescope.load_extension("ui-select")
    pcall(telescope.load_extension, "fzf")
  end,
}
