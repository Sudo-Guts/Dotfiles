return {
  cmd = { "vhdl_ls" },
  filetypes = {
    "vhdl",
  },

  root_dir = function(bufnr, on_dir)
    local hdl = require("config.hdl.vhdl")
    local root = hdl.root(bufnr) or vim.fs.root(bufnr, { "vhdl_ls.toml", ".git" })
    if root then
      if hdl.root(bufnr) then
        local ok, err = pcall(hdl.ensure_index, root)
        if not ok then
          vim.notify(tostring(err), vim.log.levels.ERROR)
          return
        end
      end
      on_dir(root)
    end
  end,
}
