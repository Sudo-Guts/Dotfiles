local icons = require("config.nvim.icons")

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
  keys = {
    { "<leader>e", "<Cmd>Neotree toggle<CR>", desc = icons.label("folder", "Explorador") },
    { "<leader>E", "<Cmd>Neotree reveal<CR>", desc = icons.label("position", "Mostrar archivo en árbol") },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = "rounded",
    filesystem = {
      follow_current_file = { enabled = true },
      filtered_items = { hide_dotfiles = false, hide_gitignored = true },
      use_libuv_file_watcher = true,
    },
    default_component_configs = {
      icon = { folder_closed = "", folder_open = "", folder_empty = "󰜌" },
      modified = { symbol = "󱨍" },
      git_status = {
        symbols = {
          added = "✚",
          modified = "󱨍",
          deleted = "✖",
          renamed = "󰁕",
          untracked = "",
          ignored = "",
          unstaged = "󰄱",
          staged = "",
          conflict = "",
        },
      },
    },
    window = { width = 32, mappings = { ["H"] = "toggle_hidden" } },
  },
}
