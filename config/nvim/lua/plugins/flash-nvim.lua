local icons = require("config.nvim.icons")

return {
  "folke/flash.nvim",
  opts = {},
  keys = {
    {
      "<leader>j",
      function()
        require("flash").jump()
      end,
      mode = { "n", "x", "o" },
      desc = icons.label("jump", "Saltar con Flash"),
    },
    {
      "<leader>J",
      function()
        require("flash").treesitter()
      end,
      mode = { "n", "x", "o" },
      desc = icons.label("tree", "Selección Treesitter"),
    },
  },
}
