return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {},
  keys = {
    {
      "<leader>sr",
      function()
        require("persistence").load()
      end,
      desc = "Restaurar sesión del proyecto",
    },
    {
      "<leader>ss",
      function()
        require("persistence").select()
      end,
      desc = "Elegir sesión",
    },
    {
      "<leader>sl",
      function()
        require("persistence").load({ last = true })
      end,
      desc = "Última sesión",
    },
    {
      "<leader>sd",
      function()
        require("persistence").stop()
      end,
      desc = "No guardar esta sesión",
    },
  },
}
