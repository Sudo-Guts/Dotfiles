-- Comprobaciones locales compartidas por la instalación y doctor.
local M = {}
function M.plugins()
  assert(package.loaded.lazy, "No se cargó la configuración GUTS")
  local lock =
    vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    local expected = assert(lock[name], "Plugin sin versión fijada: " .. name)
    local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
    assert(
      result.code == 0 and vim.trim(result.stdout or "") == expected.commit,
      "Restauración incompleta de " .. name .. "; ejecuta dotfiles install"
    )
  end
end

function M.check()
  M.plugins()
  require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
  local failed = {}
  for _, item in ipairs(require("config.nvim.tools").status()) do
    if not item.available then
      failed[#failed + 1] = item.name .. " ausente"
    elseif item.external then
      print(item.name .. ": externo en " .. item.path .. " (versión sin verificar)")
    elseif item.drift then
      local message = item.name .. ": " .. (item.version or "sin recibo") .. "; fijado " .. item.target
      if vim.env.DOTFILES_UPDATE == "1" then
        failed[#failed + 1] = message
      else
        print(message .. "; dotfiles update reconciliará la versión")
      end
    else
      print(item.name .. ": " .. item.version)
    end
  end
  if vim.fn.executable("verible-verilog-format") == 0 then
    failed[#failed + 1] = "verible-verilog-format ausente"
  end
  for _, lang in ipairs(require("config.nvim.parsers")) do
    local ok, loaded = pcall(vim.treesitter.language.add, lang)
    if not ok or not loaded then
      failed[#failed + 1] = "parser " .. lang
    end
  end
  assert(#failed == 0, table.concat(failed, ", "))
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print("Plugins y parsers verificados.")
end
return M
