local toolchains = require("config.nvim.toolchains")

local cmd = {
  "clangd",
  "--background-index",
  "--clang-tidy",
  "--header-insertion=never",
}

local drivers = {}

for _, driver in ipairs(toolchains.clangd_query_drivers) do
  if vim.fn.executable(driver) == 1 then
    drivers[#drivers + 1] = driver
  end
end

if #drivers > 0 then
  cmd[#cmd + 1] = "--query-driver=" .. table.concat(drivers, ",")
end

return {
  cmd = cmd,
  root_dir = function(bufnr, on_dir)
    local root = require("config.nvim.tasks").cpp_root(bufnr)
    if root then
      on_dir(root)
    end
  end,
}
