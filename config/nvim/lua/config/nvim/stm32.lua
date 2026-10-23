local M = {}
local source = debug.getinfo(1, "S").source:sub(2)
source = vim.uv.fs_realpath(source) or source
local helper = vim.fs.normalize(vim.fs.dirname(source) .. "/../../../../../bin/stm32.py")

local function command(action, root, configuration)
  local args = { "python3", helper, action }
  if root then
    vim.list_extend(args, { "--root", root })
  end
  if configuration then
    vim.list_extend(args, { "--configuration", configuration })
  end
  return args
end

local function read(action, root)
  local result = vim.system(command(action, root), { text = true, timeout = 3000 }):wait()
  assert(result.code == 0, result.stderr or "No se pudo leer la configuración STM32")
  return vim.json.decode(result.stdout)
end

function M.tools()
  local ok, data = pcall(read, "tools")
  return ok and data or {}
end

function M.configure(root)
  local tasks, cpp = require("config.nvim.tasks"), require("config.nvim.cpp")
  assert(
    not tasks.is_running(root),
    "Detén el proceso con Espacio rx antes de cambiar la configuración"
  )
  tasks.select(read("metadata", root).configurations, {
    prompt = "Configuración STM32CubeIDE",
    format_item = function(item)
      return item.name .. " · " .. item.mcu
    end,
  }, function(item)
    if not item then
      return
    end
    tasks.safe(function()
      cpp.store(root, { version = 1, target = "stm32", configuration = item.name })
      vim.notify("STM32 " .. item.name .. ": rc compila; rg prepara gd; rf graba por USB DFU")
    end)
  end)
end

function M.build(root, index, done)
  local tasks = require("config.nvim.tasks")
  tasks.save(root)
  local profile = require("config.nvim.cpp").profile(root)
  return tasks.run(
    command(index and "index" or "build", root, profile.configuration),
    root,
    function()
      if index then
        tasks.restart("clangd", root)
      end
      if done then
        done()
      end
    end,
    {
      language = "cpp",
      stage = index and "STM32: compilar e indexar" or "STM32: compilar y generar HEX",
    }
  )
end

function M.flash(root)
  local tasks = require("config.nvim.tasks")
  local configuration = require("config.nvim.cpp").profile(root).configuration
  local firmware
  for _, item in ipairs(read("metadata", root).configurations) do
    if item.name == configuration then
      firmware = item.hex:sub(#root + 2)
    end
  end
  assert(firmware, "Elige una configuración existente con Espacio rt")
  M.build(root, false, function()
    tasks.run(command("devices"), root, function(result)
      local devices = vim.json.decode(result.stdout)
      assert(
        #devices > 0,
        "No hay placas DFU; entra en modo DFU y revisa los permisos USB de CubeProgrammer"
      )
      tasks.select(devices, {
        prompt = "Grabar " .. firmware .. " · elige la placa en modo DFU",
        format_item = function(device)
          return device.port .. " · serie " .. device.serial
        end,
      }, function(device)
        if not device then
          return
        end
        tasks.safe(function()
          local args = command("flash", root, configuration)
          vim.list_extend(args, { "--serial", device.serial })
          tasks.run(
            args,
            root,
            nil,
            { language = "cpp", append = true, stage = "STM32: grabar y verificar USB DFU" }
          )
        end)
      end)
    end, { language = "cpp", append = true, stage = "STM32: buscar placas USB DFU" })
  end)
end

return M
