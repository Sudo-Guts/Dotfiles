local M = {}

M.clangd_query_drivers = {
  "/opt/riscv/bin/riscv64-unknown-elf-gcc",
  "/opt/riscv/bin/riscv64-unknown-elf-g++",
}

-- Rutas concretas encontradas en PATH, incluidas las instalaciones APT/xPack.
for _, name in ipairs({
  "gcc",
  "g++",
  "riscv64-unknown-elf-gcc",
  "riscv64-unknown-elf-g++",
  "riscv32-unknown-elf-gcc",
  "riscv32-unknown-elf-g++",
  "arm-none-eabi-gcc",
  "arm-none-eabi-g++",
}) do
  local path = vim.fn.exepath(name)
  if path ~= "" and not vim.tbl_contains(M.clangd_query_drivers, path) then
    M.clangd_query_drivers[#M.clangd_query_drivers + 1] = path
  end
end

return M
