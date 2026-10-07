local M = {}
local process_log = require("config.nvim.process")
local icons = require("config.nvim.icons")
local terminal_buf
local jobs = {}
local stopping, restarts = {}, {}

-- Busca una raíz por directorios requeridos; los lenguajes deciden su estructura.
function M.project_root(directories, bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  while dir and dir ~= "" do
    local found = true
    for _, directory in ipairs(directories) do
      if vim.fn.isdirectory(dir .. "/" .. directory) == 0 then
        found = false
        break
      end
    end
    if found then
      return dir
    end
    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
end

function M.open_viewer(executable, default)
  vim.ui.input({ prompt = "Archivo: ", default = default, completion = "file" }, function(file)
    if not file or file == "" then
      return
    end
    if vim.fn.executable(executable) == 0 then
      vim.notify("Falta " .. executable, vim.log.levels.ERROR)
      return
    end
    if vim.fn.filereadable(file) == 0 then
      vim.notify("No existe el archivo", vim.log.levels.ERROR)
      return
    end
    vim.fn.jobstart({ executable, file }, { detach = true })
  end)
end

function M.root()
  if vim.b.dotfiles_project then
    return vim.b.dotfiles_project
  end
  local hdl = M.project_root({ "RTL", "SIM" })
  local ft = vim.bo.filetype
  if hdl and (ft == "verilog" or ft == "systemverilog" or ft == "vhdl") then
    return hdl
  end
  return M.cpp_root() or vim.fn.getcwd()
end

function M.cpp_root(bufnr)
  return vim.fs.root(
    bufnr or 0,
    { ".nvim", "compile_commands.json", ".clangd", "Makefile", "makefile", "CMakeLists.txt", ".git" }
  )
end

function M.files(root, directories, extensions)
  local files, seen = {}, {}
  for _, directory in ipairs(directories) do
    for _, path in ipairs(vim.fn.globpath(root .. "/" .. directory, "**/*", false, true)) do
      local extension = path:match("%.([^./]+)$")
      if extensions[extension] and vim.fn.filereadable(path) == 1 then
        path = vim.fs.normalize(path)
        local identity = vim.uv.fs_realpath(path) or path
        if not seen[identity] then
          seen[identity] = true
          files[#files + 1] = path
        end
      end
    end
  end
  table.sort(files)
  return files
end

function M.write(path, lines, only_missing)
  if only_missing and vim.uv.fs_stat(path) then
    return false
  end
  if vim.fn.filereadable(path) == 1 and vim.deep_equal(vim.fn.readfile(path), lines) then
    return false
  end
  local buf = vim.fn.bufnr(path)
  assert(buf == -1 or not vim.bo[buf].modified, "Guarda primero los cambios en " .. path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temp = path .. ".tmp." .. tostring(vim.uv.hrtime())
  assert(vim.fn.writefile(lines, temp) == 0, "No se pudo escribir " .. temp)
  local ok, err = vim.uv.fs_rename(temp, path)
  if not ok then
    vim.fn.delete(temp)
    error(err)
  end
  return true
end

function M.profile(root, language, defaults)
  local path = root .. "/SIM/project.json"
  local data = { version = 1 }
  if vim.fn.filereadable(path) == 1 then
    data = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    assert(type(data) == "table" and data.version == 1, "SIM/project.json requiere version = 1")
  end
  assert(data[language] == nil or type(data[language]) == "table", "Perfil inválido: " .. language)
  return vim.tbl_deep_extend("force", defaults, data[language] or {}), data
end

function M.store_profile(root, language, profile)
  local _, data = M.profile(root, language, {})
  data[language] = profile
  local result = vim
    .system({ "python3", "-m", "json.tool", "--indent", "2" }, { stdin = vim.json.encode(data), text = true })
    :wait()
  assert(result.code == 0, result.stderr)
  M.write(root .. "/SIM/project.json", vim.split(vim.trim(result.stdout), "\n"))
end

function M.strings(value, field)
  assert(type(value) == "table" and vim.islist(value), field .. " debe ser una lista")
  for _, item in ipairs(value) do
    assert(type(item) == "string" and item ~= "" and not item:find("[\r\n]"), field .. ": valor inválido")
  end
end

function M.sources(root, files, extras)
  local result, seen = {}, {}
  for _, file in ipairs(vim.list_extend(vim.deepcopy(files), extras or {})) do
    local path = file:sub(1, 1) == "/" and file or root .. "/" .. file
    assert(vim.fn.filereadable(path) == 1, "No existe la fuente: " .. path)
    local identity = vim.uv.fs_realpath(path) or path
    if not seen[identity] then
      seen[identity] = true
      result[#result + 1] = path
    end
  end
  return result
end

function M.choose_testbench(root, language, extensions, defaults, name_pattern, done)
  local benches = M.files(root, { "SIM/tb" }, extensions)
  assert(#benches > 0, "No hay testbenches " .. language .. " en SIM/tb/; Espacio rn crea uno")
  M.select(benches, {
    prompt = "Testbench " .. language,
    format_item = function(path)
      return path:sub(#root + 2)
    end,
  }, function(path)
    if not path then
      return
    end
    M.safe(function()
      local profile = M.profile(root, language, defaults)
      local text = table.concat(vim.fn.readfile(path), "\n")
      if language == "verilog" then
        text = text:gsub("/%*.-%*/", ""):gsub("//[^\n]*", "")
        text = text:gsub("module%s+automatic%s+", "module "):gsub("module%s+static%s+", "module ")
      else
        text = text:gsub("%-%-[^\n]*", "")
      end
      local guess = text:match(name_pattern) or vim.fn.fnamemodify(path, ":t:r")
      vim.ui.input(
        { prompt = "Top (nombre declarado, no nombre del archivo): ", default = guess },
        function(top)
          if not top or top == "" then
            return
          end
          M.safe(function()
            assert(top:match("^[%a_][%w_]*$"), "Nombre de top inválido")
            profile.testbench, profile.top = path:sub(#root + 2), top
            M.store_profile(root, language, profile)
            if done then
              done(profile)
            end
            vim.notify("Testbench: " .. profile.testbench .. "; top: " .. top)
          end)
        end
      )
    end)
  end)
end

function M.with_testbench(root, language, defaults, choose, done)
  local profile = M.profile(root, language, defaults)
  if not profile.testbench or not profile.top then
    choose(root, done)
  else
    done(profile)
  end
end

function M.waves(root)
  local waves = M.files(root, { "SIM/out", "SIM" }, { vcd = true, fst = true, ghw = true })
  -- glob SIM/ también encuentra artefactos de versiones anteriores.
  assert(#waves > 0, "No hay ondas .vcd, .fst o .ghw; ejecuta primero la simulación")
  M.select(waves, {
    prompt = "Ondas",
    format_item = function(path)
      return path:sub(#root + 2)
    end,
  }, function(path)
    if path then
      M.safe(function()
        assert(vim.fn.executable("gtkwave") == 1, "Falta gtkwave")
        assert(vim.fn.jobstart({ "gtkwave", path }, { detach = true }) > 0, "No se pudo abrir GTKWave")
      end)
    end
  end)
end

function M.save(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local path = vim.api.nvim_buf_get_name(buf)
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and vim.bo[buf].modified
      and path:sub(1, #root + 1) == root .. "/"
    then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd.update()
      end)
    end
  end
end

function M.select(items, opts, callback)
  require("telescope") -- Carga también ui-select antes de mostrar el selector.
  vim.ui.select(items, opts, callback)
end

function M.menu(title, items, status, opts)
  opts = opts or {}
  local preview_buf, unsubscribe
  local function refresh()
    if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
      local lines = type(status) == "function" and status() or status
      vim.bo[preview_buf].modifiable = true
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
      vim.bo[preview_buf].modifiable = false
    end
  end
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  require("telescope.pickers")
    .new({}, {
      prompt_title = title,
      results_title = "Acciones",
      layout_strategy = "flex",
      layout_config = {
        width = 0.9,
        height = 0.9,
        flip_columns = 120,
        flip_lines = 10,
        horizontal = { preview_cutoff = 0 },
        vertical = { preview_cutoff = 0, preview_height = 0.5 },
      },
      finder = require("telescope.finders").new_table({
        results = items,
        entry_maker = function(item)
          return { value = item, display = item.text, ordinal = item.text }
        end,
      }),
      sorter = require("telescope.config").values.generic_sorter({}),
      previewer = require("telescope.previewers").new_buffer_previewer({
        title = "Estado del proyecto",
        define_preview = function(self)
          preview_buf = self.state.bufnr
          refresh()
        end,
      }),
      attach_mappings = function(buf)
        if opts.project then
          unsubscribe = process_log.subscribe(opts.project, refresh)
          vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = buf,
            once = true,
            callback = function()
              unsubscribe()
            end,
          })
        end
        actions.select_default:replace(function()
          local selected = state.get_selected_entry()
          actions.close(buf)
          if selected then
            M.safe(selected.value.action)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.safe(action)
  local ok, err = pcall(action)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end

function M.restart(server, root)
  local executable = require("config.nvim.lsp").servers[server]
  if not executable or vim.fn.executable(executable) == 0 then
    return
  end
  local key = server .. "\n" .. root
  local pending = restarts[key] or { previous = {}, generation = 0 }
  restarts[key] = pending
  pending.generation = pending.generation + 1
  local generation, previous = pending.generation, pending.previous
  for _, client in ipairs(vim.lsp.get_clients({ name = server })) do
    if client.config.root_dir == root then
      previous[client.id] = true
      for buf in pairs(client.attached_buffers) do
        vim.lsp.buf_detach_client(buf, client.id)
      end
      if not stopping[client.id] then
        stopping[client.id] = true
        client:stop()
      end
    end
  end
  vim.defer_fn(function()
    if pending.generation ~= generation then
      return
    end
    restarts[key] = nil
    for id in pairs(stopping) do
      if not vim.lsp.get_client_by_id(id) then
        stopping[id] = nil
      end
    end
    local config = vim.deepcopy(vim.lsp.config[server])
    config.name, config.root_dir = server, root
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local path = vim.api.nvim_buf_get_name(buf)
      if
        vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ""
        and path:sub(1, #root + 1) == root .. "/"
        and vim.tbl_contains(config.filetypes or {}, vim.bo[buf].filetype)
      then
        vim.lsp.start(config, {
          bufnr = buf,
          reuse_client = function(client)
            return not previous[client.id] and client.name == server and client.config.root_dir == root
          end,
        })
      end
    end
  end, 150)
end

function M.log_path(root)
  return process_log.log_path(root)
end

function M.process_status(root)
  return process_log.status(root)
end

function M.log(root, opts)
  opts = opts or {}
  root = root or M.root()
  local path = M.log_path(root)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("Todavía no hay un registro de compilación o simulación")
    return
  end
  local buf = vim.fn.bufnr(path)
  local win = buf ~= -1 and vim.fn.bufwinid(buf) or -1
  local opened = win == -1
  if buf == -1 then
    buf = vim.fn.bufadd(path)
  end
  vim.fn.bufload(buf)
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = "nofile", "hide", false
  local lines = vim.fn.readfile(path)
  if not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines) then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  vim.bo[buf].modified, vim.bo[buf].modifiable = false, false
  vim.b[buf].dotfiles_project = root
  vim.b[buf].dotfiles_language = process_log.language(root)
  if opened then
    win = vim.api.nvim_open_win(buf, false, { split = "below", win = -1, height = 14 })
  end
  vim.keymap.set("n", "<leader>rx", function()
    M.cancel(root)
  end, { buffer = buf, desc = icons.label("stop", "Detener proceso") })
  vim.keymap.set("n", "<leader>rl", function()
    M.log(root)
  end, { buffer = buf, desc = icons.label("log", "Registro en vivo") })
  vim.keymap.set("n", "<leader>rp", function()
    require("config.nvim.project").panel()
  end, { buffer = buf, desc = icons.label("project", "Estado del proceso") })
  if opened or opts.focus ~= false then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
  if opts.focus ~= false then
    vim.api.nvim_set_current_win(win)
  end
end

function M.cancel(root)
  root = vim.fs.normalize(root or M.root())
  if jobs[root] then
    jobs[root]:kill(15)
  else
    vim.notify("No hay un proceso activo en este proyecto")
  end
end

function M.is_running(root)
  return jobs[vim.fs.normalize(root or M.root())] ~= nil
end

function M.terminal()
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    local win = vim.fn.bufwinid(terminal_buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, false)
      return
    end
    vim.cmd("botright 14split")
    vim.api.nvim_win_set_buf(0, terminal_buf)
  else
    local cwd = M.root()
    vim.cmd("botright 14new")
    terminal_buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart(vim.o.shell, { term = true, cwd = cwd })
  end
  vim.cmd.startinsert()
end

function M.run(command, cwd, done, opts)
  opts = opts or {}
  local project = vim.fs.normalize(opts.project or cwd)
  if jobs[project] then
    vim.notify("El proyecto tiene un proceso activo; Espacio rx lo detiene", vim.log.levels.WARN)
    return false
  end
  if vim.fn.executable(command[1]) == 0 then
    vim.notify("Falta " .. command[1], vim.log.levels.ERROR)
    return false
  end
  local title = table.concat(vim.tbl_map(vim.fn.shellescape, command), " ")
  opts.language = opts.language or require("config.nvim.project").language()
  local record = process_log.start(project, command, cwd, opts)
  M.log(project, { focus = false })
  vim.notify("Ejecutando: " .. title)
  local ok, process = pcall(
    vim.system,
    command,
    {
      cwd = cwd,
      text = true,
      timeout = opts.timeout_ms,
      stdout = function(err, data)
        process_log.feed(record, "stdout", err and tostring(err) or data)
      end,
      stderr = function(err, data)
        process_log.feed(record, "stderr", err and tostring(err) or data)
      end,
    },
    vim.schedule_wrap(function(result)
      jobs[project] = nil
      if result.signal ~= 0 and result.code == 0 then
        result.code = 128 + result.signal
      end
      process_log.finish(record, result)
      local output = process_log.clean((result.stdout or "") .. (result.stderr or ""))
      local output_lines = vim.split(output, "\n", { trimempty = true })
      -- Resolver rutas del compilador desde cwd sin cambiar el directorio del usuario.
      local lines = { "make: Entering directory '" .. cwd .. "'" }
      vim.list_extend(lines, output_lines)
      lines[#lines + 1] = "make: Leaving directory '" .. cwd .. "'"
      vim.fn.setqflist(
        {},
        "r",
        { title = title, lines = lines, efm = "%E%f:%l:%c: %m,%E%f:%l: %m," .. vim.o.errorformat }
      )
      if opts.on_exit then
        M.safe(function()
          opts.on_exit(result)
        end)
      end
      if record.cancelled then
        vim.notify("Proceso detenido; Espacio rl muestra el registro")
      elseif result.code ~= 0 then
        vim.cmd.copen()
        vim.notify(
          "Proceso falló: " .. result.code .. ". Espacio rl muestra el registro",
          vim.log.levels.ERROR
        )
      else
        vim.notify("Proceso terminado")
        if done then
          M.safe(function()
            done(result)
          end)
        end
      end
    end)
  )
  if not ok then
    process_log.feed(record, "stderr", tostring(process))
    process_log.finish(record, { code = -1, signal = 0 })
    vim.notify(tostring(process), vim.log.levels.ERROR)
    return false
  end
  jobs[project] = {
    kill = function()
      process_log.stopping(record)
      process:kill(15)
    end,
  }
  return true
end

-- Una terminal real permite scanf/cin y comparte el registro en vivo.
function M.run_terminal(command, cwd, opts)
  opts = opts or {}
  local project = vim.fs.normalize(opts.project or cwd)
  assert(not jobs[project], "El proyecto tiene un proceso activo; Espacio rx lo detiene")
  assert(vim.fn.executable(command[1]) == 1, "No existe el ejecutable: " .. command[1])
  opts.language = opts.language or "cpp"
  local record = process_log.start(project, command, cwd, opts)
  local log_buf = vim.fn.bufnr(record.path)
  local log_win = log_buf ~= -1 and vim.fn.bufwinid(log_buf) or -1
  if log_win ~= -1 then
    vim.api.nvim_set_current_win(log_win)
    vim.cmd.enew()
  else
    vim.cmd("botright 14new")
  end
  local buf = vim.api.nvim_get_current_buf()
  vim.bo.bufhidden, vim.bo.swapfile = "hide", false
  vim.b.dotfiles_project, vim.b.dotfiles_language = project, opts.language
  local id = vim.fn.jobstart(command, {
    term = true,
    cwd = cwd,
    on_stdout = function(_, data)
      process_log.feed(record, "stdout", table.concat(data, "\n"))
    end,
    on_exit = vim.schedule_wrap(function(_, code)
      jobs[project] = nil
      process_log.finish(record, { code = code, signal = 0 })
      vim.notify(
        record.cancelled and "Programa detenido" or "Programa terminó con código " .. code,
        code ~= 0 and not record.cancelled and vim.log.levels.ERROR or vim.log.levels.INFO
      )
    end),
  })
  if id <= 0 then
    process_log.finish(record, { code = id, signal = 0 })
    vim.api.nvim_buf_delete(buf, { force = true })
    error("No se pudo iniciar el programa: " .. id)
  end
  jobs[project] = {
    kill = function()
      process_log.stopping(record)
      vim.fn.jobstop(id)
    end,
  }
  vim.keymap.set("n", "<leader>rx", function()
    M.cancel(project)
  end, { buffer = buf, desc = icons.label("stop", "Detener programa") })
  vim.keymap.set("n", "<leader>rl", function()
    M.log(project)
  end, { buffer = buf, desc = icons.label("log", "Registro de ejecución") })
  vim.keymap.set("n", "<leader>rp", function()
    require("config.nvim.project").panel()
  end, { buffer = buf, desc = icons.label("project", "Estado del proceso") })
  vim.notify("Programa en terminal; Esc Esc vuelve al modo normal y Espacio rx lo detiene")
  vim.cmd.startinsert()
  return id
end

function M.make()
  local root = M.root()
  M.save(root)
  vim.ui.input({ prompt = "Objetivo make (vacío = predeterminado): " }, function(target)
    if target == nil then
      return
    end
    local cmd = { "make" }
    if target ~= "" then
      cmd[#cmd + 1] = target
    end
    M.run(cmd, root, nil, { stage = "Make: " .. (target ~= "" and target or "objetivo predeterminado") })
  end)
end

return M
