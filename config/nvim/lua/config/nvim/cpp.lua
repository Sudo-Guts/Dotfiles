local M = {}
local tasks = require("config.nvim.tasks")

M.targets = { host = "PC Linux", tiva = "Tiva / ARM bare-metal", riscv = "RISC-V bare-metal" }

local function arguments(value)
  assert(type(value) == "table" and vim.islist(value), "args debe ser una lista JSON")
  for _, arg in ipairs(value) do
    assert(type(arg) == "string" and not arg:find("[%z\r\n]"), "Argumento inválido")
  end
end

local function has(root, file)
  return vim.fn.filereadable(root .. "/" .. file) == 1
end

function M.path(root, path)
  return vim.fs.normalize(path:sub(1, 1) == "/" and path or root .. "/" .. path)
end

local function inferred_target(root)
  for _, name in ipairs({
    "compile_commands.json",
    "build/compile_commands.json",
    "Makefile",
    "makefile",
    "build/CMakeCache.txt",
  }) do
    if has(root, name) then
      local text = table.concat(vim.fn.readfile(root .. "/" .. name), "\n"):lower()
      if text:find("riscv[%w%-]*unknown%-elf") or text:find("riscv[%w%-]*none%-elf") then
        return "riscv"
      end
      if text:find("arm%-none%-eabi") then
        return "tiva"
      end
    end
  end
  return "host"
end

function M.profile(root)
  local data = {}
  if has(root, ".nvim/cpp.json") then
    data = vim.json.decode(table.concat(vim.fn.readfile(root .. "/.nvim/cpp.json"), "\n"))
    assert(type(data) == "table" and data.version == 1, ".nvim/cpp.json requiere version = 1")
  end
  local profile = vim.tbl_deep_extend("force", {
    version = 1,
    target = inferred_target(root),
    args = {},
    cwd = ".",
    build_dir = "build",
    build_target = "",
  }, data)
  assert(M.targets[profile.target], "target debe ser host, tiva o riscv")
  for _, key in ipairs({ "cwd", "build_dir", "build_target" }) do
    assert(type(profile[key]) == "string" and not profile[key]:find("[%z\r\n]"), key .. " inválido")
  end
  assert(profile.cwd ~= "" and profile.build_dir ~= "", "cwd y build_dir necesitan una ruta")
  assert(
    profile.program == nil
      or (
        type(profile.program) == "string"
        and profile.program ~= ""
        and not profile.program:find("[%z\r\n]")
      ),
    "program inválido"
  )
  arguments(profile.args)
  return profile
end

function M.store(root, profile)
  local result = vim
    .system({ "python3", "-m", "json.tool", "--indent", "2" }, { stdin = vim.json.encode(profile), text = true })
    :wait()
  assert(result.code == 0, result.stderr)
  tasks.write(root .. "/.nvim/cpp.json", vim.split(vim.trim(result.stdout), "\n"))
end

-- Inspeccionar la cabecera sin ejecutar el archivo ni depender de su extensión.
function M.elf(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return
  end
  local fd = vim.uv.fs_open(path, "r", 0)
  if not fd then
    return
  end
  local header = vim.uv.fs_read(fd, 64, 0)
  vim.uv.fs_close(fd)
  if not header or #header < 52 or header:sub(1, 4) ~= "\127ELF" then
    return
  end
  local class, endian = header:byte(5, 6)
  if (class ~= 1 and class ~= 2) or (endian ~= 1 and endian ~= 2) or (class == 2 and #header < 64) then
    return
  end
  local function half(offset)
    local first, second = header:byte(offset, offset + 1)
    return endian == 1 and first + second * 256 or first * 256 + second
  end
  local kind, machine = half(17), half(19)
  local entry = header:sub(25, class == 1 and 28 or 32)
  if (kind ~= 2 and kind ~= 3) or entry == string.rep("\0", #entry) then
    return
  end
  return { machine = machine, class = class }
end

function M.validate_program(path)
  local info = assert(M.elf(path), "Elige un ejecutable ELF; no un .o, biblioteca, script, .hex o .bin")
  local architecture = vim.uv.os_uname().machine
  local native = ({ x86_64 = 62, aarch64 = 183, riscv64 = 243, i386 = 3, i686 = 3 })[architecture]
    or (architecture:match("^arm") and 40)
  assert(
    native and info.machine == native,
    "Este ELF usa otra arquitectura; el firmware Tiva/RISC-V se ejecuta en su hardware o emulador"
  )
  assert(vim.fn.executable(path) == 1, "El archivo no tiene permiso de ejecución: " .. path)
  return path
end

function M.executables(root)
  local result, seen = {}, {}
  local ignored = {
    [".git"] = true,
    [".venv"] = true,
    venv = true,
    node_modules = true,
    ISE = true,
    CMakeFiles = true,
    _deps = true,
  }
  local function scan(directory, depth)
    if depth > 12 then
      return
    end
    local entries = vim.uv.fs_scandir(directory)
    if not entries then
      return
    end
    while true do
      local name, kind = vim.uv.fs_scandir_next(entries)
      if not name then
        break
      end
      local path = directory .. "/" .. name
      if kind == "directory" and not ignored[name] then
        scan(path, depth + 1)
      elseif kind == "file" or kind == "link" then
        local identity = vim.uv.fs_realpath(path) or path
        if not seen[identity] and M.elf(path) and pcall(M.validate_program, path) then
          seen[identity] = true
          result[#result + 1] = path
        end
      end
    end
  end
  scan(root, 0)
  table.sort(result)
  return result
end

function M.compile(root, done)
  tasks.save(root)
  local profile = M.profile(root)
  local command
  if has(root, "Makefile") or has(root, "makefile") then
    command = { "make" }
    if profile.build_target ~= "" then
      vim.list_extend(command, { "--", profile.build_target })
    end
  else
    assert(has(root, "CMakeLists.txt"), "No hay Makefile ni CMakeLists.txt en " .. root)
    command = { "cmake", "--build", M.path(root, profile.build_dir) }
    if profile.build_target ~= "" then
      vim.list_extend(command, { "--target", profile.build_target })
    end
  end
  return tasks.run(command, root, done, { stage = "Compilar C/C++ (" .. command[1] .. ")" })
end

function M.choose(root, done)
  assert(not tasks.is_running(root), "Detén el proceso con Espacio rx antes de cambiar el programa")
  local profile = M.profile(root)
  local kinds = { profile.target }
  for _, kind in ipairs({ "host", "tiva", "riscv" }) do
    if kind ~= profile.target then
      kinds[#kinds + 1] = kind
    end
  end
  tasks.select(kinds, {
    prompt = "Destino del programa",
    format_item = function(kind)
      return M.targets[kind]
    end,
  }, function(kind)
    if not kind then
      return
    end
    tasks.safe(function()
      profile.target = kind
      if kind ~= "host" then
        M.store(root, profile)
        vim.notify(
          M.targets[kind]
            .. ": rc compila; rm usa los objetivos de tu Makefile. La ejecución local queda deshabilitada."
        )
        return
      end
      local files = M.executables(root)
      files[#files + 1] = false
      tasks.select(files, {
        prompt = "Ejecutable de PC (o escribe una ruta después de compilar)",
        format_item = function(file)
          return file and file:sub(#root + 2) or "Escribir ruta del ejecutable…"
        end,
      }, function(file)
        if file == nil then
          return
        end
        local function configure(program)
          if not program or program == "" then
            return
          end
          tasks.safe(function()
            program = M.path(root, program)
            if vim.uv.fs_stat(program) then
              M.validate_program(program)
            end
            profile.program = program:sub(1, #root + 1) == root .. "/" and program:sub(#root + 2) or program
            vim.ui.input(
              { prompt = "Argumentos como lista JSON: ", default = vim.json.encode(profile.args) },
              function(args)
                if args == nil then
                  return
                end
                tasks.safe(function()
                  profile.args = vim.json.decode(args)
                  arguments(profile.args)
                  vim.ui.input(
                    { prompt = "Directorio de ejecución: ", default = profile.cwd, completion = "dir" },
                    function(cwd)
                      if not cwd or cwd == "" then
                        return
                      end
                      tasks.safe(function()
                        assert(
                          vim.fn.isdirectory(M.path(root, cwd)) == 1,
                          "No existe el directorio de ejecución"
                        )
                        profile.cwd = cwd
                        vim.ui.input({
                          prompt = "Objetivo de compilación (vacío = predeterminado): ",
                          default = profile.build_target,
                        }, function(target)
                          if target == nil then
                            return
                          end
                          tasks.safe(function()
                            assert(not target:find("[%z\r\n]"), "Objetivo inválido")
                            profile.build_target = target
                            M.store(root, profile)
                            vim.notify(
                              "Programa seleccionado: " .. profile.program .. "; Espacio re compila y ejecuta"
                            )
                            if done then
                              done(profile)
                            end
                          end)
                        end)
                      end)
                    end
                  )
                end)
              end
            )
          end)
        end
        if file then
          configure(file)
        else
          vim.ui.input({
            prompt = "Ruta del ejecutable: ",
            default = profile.program or root .. "/",
            completion = "file",
          }, configure)
        end
      end)
    end)
  end)
end

function M.launch(root, profile)
  profile = profile or M.profile(root)
  assert(
    profile.target == "host",
    "Este proyecto es firmware; usa su hardware o emulador y los objetivos de Make"
  )
  local program =
    M.validate_program(M.path(root, assert(profile.program, "Selecciona el programa con Espacio rt")))
  local cwd = M.path(root, profile.cwd)
  assert(vim.fn.isdirectory(cwd) == 1, "No existe cwd: " .. cwd)
  local command = { program }
  vim.list_extend(command, profile.args)
  return tasks.run_terminal(command, cwd, { project = root, append = true, stage = "Ejecutar C/C++" })
end

function M.execute(root)
  tasks.save(root)
  local profile = M.profile(root)
  assert(
    profile.target == "host",
    "Este proyecto es "
      .. M.targets[profile.target]
      .. "; rc compila y rm usa sus objetivos de hardware/emulación"
  )
  M.compile(root, function()
    if profile.program then
      M.launch(root)
    else
      M.choose(root, function(selected)
        if selected.build_target ~= profile.build_target then
          M.compile(root, function()
            M.launch(root)
          end)
        else
          M.launch(root, selected)
        end
      end)
    end
  end)
end

return M
