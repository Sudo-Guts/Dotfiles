return {
  "rcarriga/nvim-notify",
  lazy = true,
  opts = { background_colour = "#1e1e2e", timeout = 2500, stages = "static" },
  config = function(_, opts)
    local notify = require("notify")
    notify.setup(opts)
    vim.notify = notify
  end,
}
