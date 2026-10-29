local M = {}
-- clangd, clang-format, shellcheck: sistema. Estos paquetes: Mason.
M.packages = {
    { "lua-language-server", "lua-language-server", "3.19.1", "nvim" },
    { "stylua", "stylua", "v2.5.2", "nvim" },
    { "shfmt", "shfmt", "v3.14.1", "nvim" },
    { "verible", "verible-verilog-ls", "v0.0-4296-g0f262651", "hdl" },
    { "rust_hdl", "vhdl_ls", "v0.88.0", "hdl" },
    { "codelldb", "codelldb", "v1.12.3", "cpp" },
    { "pyright", "pyright-langserver", "1.1.414", "python" },
    { "ruff", "ruff", "0.16.10", "python" },
    { "debugpy", "debugpy-adapter", "1.8.22", "python" },
}

local function selected_modules()
    local root = vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(vim.fn.stdpath("config")))))
    local requested = vim.env.DOTFILES_NVIM_MODULES
    local known, selected = {}, {}
    for _, line in ipairs(vim.fn.readfile(root .. "/setup/modules.conf")) do
        local name, kind = line:match("^([a-z][a-z0-9-]*)|([^|]+)|")
        if name then
            known[name] = true
            if not requested and kind == "core" then
                selected[name] = true
            end
        end
    end
    for name in (requested or ""):gmatch("%S+") do
        assert(known[name], "Módulo de herramientas desconocido: " .. name)
        selected[name] = true
    end
    return selected
end

function M.enabled(module)
    return selected_modules()[module] == true
end

local function same_version(a, b)
  return a and b and a:gsub("^v", "") == b:gsub("^v", "")
end

-- Consulta local: no refresca el registro ni descarga paquetes.
function M.status()
    local registry = require("mason-registry")
    local root = vim.fs.normalize(require("mason.settings").current.install_root_dir) .. "/"
    local result, selected = {}, selected_modules()
    for _, entry in ipairs(M.packages) do
        if selected[entry[4]] then
            local name, executable, target, module = unpack(entry)
            local path = vim.fn.exepath(executable)
            local available = vim.fn.executable(executable) == 1
            local external = available and vim.fs.normalize(path):sub(1, #root) ~= root
            local ok, pkg = pcall(registry.get_package, name)
            local version = ok and pkg:is_installed() and pkg:get_installed_version() or nil
            result[#result + 1] = {
                name = name,
                executable = executable,
                target = target,
                version = version,
                path = path,
                available = available,
                external = external,
                drift = not external and not same_version(version, target),
                module = module,
            }
        end
    end
    return result
end

function M.install(wait)
  local registry = require("mason-registry")
  local update = vim.env.DOTFILES_UPDATE == "1"
  local needed = {}
  for _, item in ipairs(M.status()) do
    if not item.available or (update and item.drift) then
      needed[#needed + 1] = item
    end
  end
  if #needed == 0 then
    return
  end

  local finished, failed = false, {}
  local function finish()
    finished = true
    if not wait then
      local message = #failed == 0 and "Herramientas listas; reinicia Neovim."
        or ("No se instalaron: " .. table.concat(failed, ", "))
      vim.notify(message, #failed == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
    end
  end
  registry.refresh(function(ok)
    if not ok then
      failed[#failed + 1] = "registro Mason"
      finish()
      return
    end
    local remaining = #needed
    local function done(name, success)
      if not success then
        failed[#failed + 1] = name
      end
      remaining = remaining - 1
      if remaining == 0 then
        finish()
      end
    end
    for _, item in ipairs(needed) do
      local exists, pkg = pcall(registry.get_package, item.name)
      if not exists or pkg:is_installing() then
        done(item.name, false)
      else
        local started = pcall(function()
          pkg:install(
            { version = item.target },
            vim.schedule_wrap(function(success)
              local valid = success
                and vim.fn.executable(item.executable) == 1
                and same_version(pkg:get_installed_version(), item.target)
              done(item.name, valid)
            end)
          )
        end)
        if not started then
          done(item.name, false)
        end
      end
    end
  end)
  if wait then
    if not vim.wait(600000, function()
      return finished
    end, 100) then
      error("Tiempo agotado instalando herramientas Mason")
    end
    if #failed > 0 then
      error("No se instalaron: " .. table.concat(failed, ", "))
    end
  end
end
return M
