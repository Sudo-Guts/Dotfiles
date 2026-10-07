local icons = require("config.nvim.icons")

local M = {}
local tasks = require("config.nvim.tasks")
local cpp = require("config.nvim.cpp")

local cpp_filetypes = { "c", "cpp", "objc", "objcpp" }
local hdl_filetypes = { "verilog", "systemverilog", "vhdl" }

function M.language(bufnr)
  local tag = vim.b[bufnr or 0].dotfiles_language
  if tag then
    return tag
  end
  local ft = vim.bo[bufnr or 0].filetype
  if vim.tbl_contains(cpp_filetypes, ft) then
    return "cpp"
  end
  if vim.tbl_contains(hdl_filetypes, ft) then
    return ft == "vhdl" and "vhdl" or "verilog"
  end
end

function M.context(bufnr)
  local root, language = vim.b[bufnr or 0].dotfiles_project, vim.b[bufnr or 0].dotfiles_language
  if root and language then
    return root, language, language ~= "cpp" and require("config.hdl." .. language) or nil
  end
  local ft = vim.bo[bufnr or 0].filetype
  if ft == "verilog" or ft == "systemverilog" or ft == "vhdl" then
    local language = ft == "vhdl" and "vhdl" or "verilog"
    local module = require("config.hdl." .. language)
    local root = assert(module.root(bufnr), "No se encontró la raíz con RTL/ y SIM/")
    return root, language, module
  end
  assert(
    ft == "c" or ft == "cpp" or ft == "objc" or ft == "objcpp",
    "Abre un archivo C/C++, Verilog/SV o VHDL para elegir el proyecto"
  )
  return tasks.cpp_root(bufnr) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr or 0)), "cpp"
end

local function has(root, file)
  return vim.fn.filereadable(root .. "/" .. file) == 1
end

function M.cpp_compile(root)
  return cpp.compile(root)
end

function M.cpp_prepare(root)
  tasks.save(root)
  local profile = cpp.profile(root)
  if has(root, "Makefile") or has(root, "makefile") then
    assert(vim.fn.executable("bear") == 1, "Falta bear; ejecuta dotfiles install")
    vim.ui.input(
      { prompt = "Objetivo Make para indexar (vacío = predeterminado): ", default = profile.build_target },
      function(target)
        if target == nil then
          return
        end
        tasks.safe(function()
          local temp = root .. "/.compile_commands.nvim." .. tostring(vim.uv.hrtime()) .. ".json"
          local command = { "bear", "--output", temp, "--", "make", "-B" }
          if target ~= "" then
            vim.list_extend(command, { "--", target })
          end
          local started = tasks.run(command, root, function()
            local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(temp), "\n"))
            if not ok or type(entries) ~= "table" or not vim.islist(entries) or #entries == 0 then
              vim.fn.delete(temp)
              error("Bear no registró compilaciones; se conservó el compile_commands.json anterior")
            end
            local lines = vim.fn.readfile(temp)
            vim.fn.delete(temp)
            tasks.write(root .. "/compile_commands.json", lines)
            tasks.restart("clangd", root)
            vim.notify("clangd: " .. #entries .. " comandos reales del Makefile")
          end, {
            stage = "Preparar C/C++ (Bear)",
            on_exit = function(result)
              if result.code ~= 0 then
                vim.fn.delete(temp)
              end
            end,
          })
          if not started then
            vim.fn.delete(temp)
          end
        end)
      end
    )
    return
  end
  assert(has(root, "CMakeLists.txt"), "No hay Makefile ni CMakeLists.txt en " .. root)
  tasks.run(
    { "cmake", "-S", root, "-B", cpp.path(root, profile.build_dir), "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
    root,
    function()
      local database = cpp.path(root, profile.build_dir) .. "/compile_commands.json"
      assert(vim.fn.filereadable(database) == 1, "CMake no generó la base de compilación")
      tasks.write(root .. "/compile_commands.json", vim.fn.readfile(database))
      tasks.restart("clangd", root)
    end,
    { stage = "Configurar CMake" }
  )
end

function M.action(name)
  tasks.safe(function()
    local root, language, module = M.context()
    if name == "log" then
      tasks.log(root)
      return
    end
    if name == "cancel" then
      tasks.cancel(root)
      return
    end
    if language == "cpp" then
      assert(
        name == "prepare" or name == "compile" or name == "execute" or name == "choose_program",
        "Esta acción requiere un archivo HDL"
      )
      if name == "prepare" then
        M.cpp_prepare(root)
      elseif name == "compile" then
        M.cpp_compile(root)
      elseif name == "choose_program" then
        cpp.choose(root)
      else
        cpp.execute(root)
      end
    else
      assert(name ~= "execute" and name ~= "choose_program", "Espacio re ejecuta programas C/C++ de PC")
      module[name](root)
    end
  end)
end

function M.setup_keymaps()
  local keys = { "rp", "rg", "rc", "rt", "rn", "re", "rs", "rw", "rl", "rx", "rm" }
  local function attach(buf)
    for _, key in ipairs(keys) do
      pcall(vim.keymap.del, "n", "<leader>" .. key, { buffer = buf })
    end
    local language = M.language(buf)
    if not language then
      return
    end
    local actions = {
      rp = { "panel", icons.label("project", "Panel del proyecto") },
      rg = { "prepare", icons.label("index", "Preparar índice para gd") },
      rc = { "compile", icons.label("compile", "Compilar proyecto") },
      rl = { "log", icons.label("log", "Registro de ejecución") },
      rx = { "cancel", icons.label("stop", "Detener proceso") },
      rm = { "make", icons.label("make", "Objetivo de Make") },
    }
    if language == "cpp" then
      actions.rt = { "choose_program", icons.label("target", "Elegir programa y destino") }
      actions.re = { "execute", icons.label("run", "Compilar y ejecutar en PC") }
    else
      actions.rt = { "choose_testbench", icons.label("target", "Elegir testbench y top") }
      actions.rn = { "create_testbench", icons.label("file", "Nuevo testbench desde puertos") }
      actions.rs = { "simulate", icons.label("simulate", "Compilar y simular") }
      actions.rw = { "waves", icons.label("waves", "Abrir ondas") }
    end
    for key, action in pairs(actions) do
      vim.keymap.set("n", "<leader>" .. key, function()
        if action[1] == "panel" then
          M.panel()
        elseif action[1] == "make" then
          tasks.make()
        else
          M.action(action[1])
        end
      end, { buffer = buf, desc = action[2] })
    end
  end
  for _, key in ipairs(keys) do
    pcall(vim.keymap.del, "n", "<leader>" .. key)
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("GutsProjectKeys", { clear = true }),
    callback = function(event)
      attach(event.buf)
    end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    attach(buf)
  end
end

function M.panel()
  tasks.safe(function()
    local root, language, module = M.context()
    local server = ({ cpp = "clangd", verilog = "verible", vhdl = "vhdl_ls" })[language]
    local clients = vim.lsp.get_clients({ name = server, bufnr = 0 })
    local status = {
      "Proyecto: " .. root,
      "Lenguaje: " .. language,
      "Servidor: " .. server .. (#clients > 0 and " (conectado)" or " (sin conectar)"),
      "",
      "gd: ir a definición; Ctrl+O: regresar",
      "Preparar: genera el índice para navegar entre archivos.",
      "Compilar: usa el Makefile o el simulador del proyecto.",
      "Registro: conserva stdout, stderr y el comando ejecutado.",
    }
    if module then
      local ok, profile = pcall(module.profile, root)
      if not ok then
        status[#status + 1] = "Perfil inválido: " .. tostring(profile)
        profile = {}
      end
      vim.list_extend(status, {
        "",
        "Testbench: " .. (profile.testbench or "sin seleccionar"),
        "Top: " .. (profile.top or "sin seleccionar"),
        "Salida: " .. root .. "/SIM/out/",
        "Perfil: SIM/project.json",
        "Directorio de ejecución: " .. (profile.run_dir or "."),
        "",
      })
      if language == "verilog" then
        vim.list_extend(status, {
          "SIM/iverilog.f: fuentes para Icarus.",
          "SIM/verible.filelist: índice de RTL, modelos y testbenches.",
        })
      else
        vim.list_extend(
          status,
          { "SIM/vhdl.f: fuentes para GHDL.", "vhdl_ls.toml: bibliotecas de navegación VHDL." }
        )
      end
    else
      local profile = cpp.profile(root)
      status[#status + 1] = ""
      status[#status + 1] = "Destino: " .. cpp.targets[profile.target]
      status[#status + 1] = "Programa: " .. (profile.program or "sin seleccionar; usa rt")
      status[#status + 1] = "Argumentos: " .. vim.json.encode(profile.args)
      status[#status + 1] = "Directorio de ejecución: " .. profile.cwd
      status[#status + 1] = "Objetivo de compilación: "
        .. (profile.build_target ~= "" and profile.build_target or "predeterminado")
      status[#status + 1] = "Perfil: .nvim/cpp.json"
      status[#status + 1] = profile.target == "host" and "re: compila y ejecuta en una terminal con teclado."
        or "Firmware: usa los objetivos de Make para hardware/emulación."
      status[#status + 1] = "Índice: compile_commands.json (o build/compile_commands.json)"
      status[#status + 1] = "Base de compilación: "
        .. (
          (has(root, "compile_commands.json") or has(root, "build/compile_commands.json")) and "disponible"
          or "pendiente; usa rg"
        )
      status[#status + 1] = "Preparar con Bear recompila usando make -B; no ejecuta make clean."
    end
    status[#status + 1] = ""
    local executables = ({
      cpp = { "make", "bear", "clangd" },
      verilog = { "iverilog", "vvp", "verible-verilog-ls", "gtkwave" },
      vhdl = { "ghdl", "vhdl_ls", "gtkwave" },
    })[language]
    for _, executable in ipairs(executables) do
      status[#status + 1] = executable
        .. ": "
        .. (vim.fn.executable(executable) == 1 and "disponible" or "falta")
    end
    local items = {
      {
        text = icons.label("index", "[rg] Preparar archivos e índice para gd"),
        action = function()
          M.action("prepare")
        end,
      },
      {
        text = icons.label("compile", "[rc] Compilar proyecto"),
        action = function()
          M.action("compile")
        end,
      },
      {
        text = icons.label("log", "[rl] Ver registro de ejecución"),
        action = function()
          tasks.log(root)
        end,
      },
      { text = icons.label("make", "[rm] Ejecutar objetivo de Make"), action = tasks.make },
      {
        text = icons.label("stop", "[rx] Detener proceso activo"),
        action = function()
          tasks.cancel(root)
        end,
      },
    }
    if module then
      items[#items + 1] = {
        text = icons.label("file", "[rn] Crear testbench desde puertos"),
        action = function()
          module.create_testbench(root)
        end,
      }
      table.insert(items, 2, {
        text = icons.label("target", "[rt] Elegir testbench y top"),
        action = function()
          module.choose_testbench(root)
        end,
      })
      table.insert(items, 4, {
        text = icons.label("simulate", "[rs] Simular (compilar y ejecutar)"),
        action = function()
          module.simulate(root)
        end,
      })
      items[#items + 1] = {
        text = icons.label("waves", "[rw] Abrir ondas en GTKWave"),
        action = function()
          tasks.waves(root)
        end,
      }
      items[#items + 1] = {
        text = icons.label("settings", "Editar SIM/project.json"),
        action = function()
          local path = root .. "/SIM/project.json"
          if not has(root, "SIM/project.json") then
            tasks.store_profile(root, language, module.profile(root))
          end
          vim.cmd.edit(vim.fn.fnameescape(path))
        end,
      }
    else
      table.insert(items, 2, {
        text = icons.label("target", "[rt] Elegir programa, argumentos y destino"),
        action = function()
          cpp.choose(root)
        end,
      })
      if cpp.profile(root).target == "host" then
        table.insert(items, 4, {
          text = icons.label("run", "[re] Compilar y ejecutar en PC"),
          action = function()
            cpp.execute(root)
          end,
        })
      end
      items[#items + 1] = {
        text = icons.label("settings", "Editar .nvim/cpp.json"),
        action = function()
          if not has(root, ".nvim/cpp.json") then
            cpp.store(root, cpp.profile(root))
          end
          vim.cmd.edit(vim.fn.fnameescape(root .. "/.nvim/cpp.json"))
        end,
      }
    end
    tasks.menu("Proyecto " .. language .. " · " .. vim.fn.fnamemodify(root, ":t"), items, function()
      local current = { status[1], status[2], status[3], "" }
      vim.list_extend(current, tasks.process_status(root))
      vim.list_extend(current, { unpack(status, 4) })
      return current
    end, { project = root })
  end)
end

return M
