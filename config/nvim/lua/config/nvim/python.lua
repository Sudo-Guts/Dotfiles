-- Intérprete del proyecto compartido por Pyright y DAP.
local M = {}

function M.root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local markers = {
    "pyrightconfig.json",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "ruff.toml",
    ".ruff.toml",
    ".venv",
    "venv",
    ".git",
  }
  return vim.fs.root(name ~= "" and name or vim.fn.getcwd(), markers)
    or (name ~= "" and vim.fs.dirname(name))
    or vim.fn.getcwd()
end

function M.interpreter(root)
  root = root or M.root()
  for _, directory in ipairs({ ".venv", "venv" }) do
    local executable = vim.fs.joinpath(root, directory, "bin", "python")
    if vim.fn.executable(executable) == 1 then
      return executable
    end
  end
  if vim.env.VIRTUAL_ENV then
    local executable = vim.fs.joinpath(vim.env.VIRTUAL_ENV, "bin", "python")
    if vim.fn.executable(executable) == 1 then
      return executable
    end
  end
  local executable = vim.fn.exepath("python3")
  assert(executable ~= "", "Falta python3; ejecuta dotfiles install")
  return executable
end

return M
