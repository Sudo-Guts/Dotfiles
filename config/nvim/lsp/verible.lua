local hdl = require("config.hdl.verilog")

return {
  root_dir = function(bufnr, on_dir)
    local root = hdl.root(bufnr)

    if not root then
      return
    end

    local ok, err = pcall(hdl.ensure_index, root)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end
    on_dir(root)
  end,

  cmd = function(dispatchers, config)
    local filelist = hdl.verible_filelist(config.root_dir)

    local cmd = {
      "verible-verilog-ls",
      "--rules_config_search",
      "--file_list_path",
      filelist,
    }

    return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
  end,
}
