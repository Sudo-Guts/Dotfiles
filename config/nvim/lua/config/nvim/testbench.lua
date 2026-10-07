local M = {}
local tasks = require("config.nvim.tasks")

-- Utilidades del editor; cada módulo HDL interpreta y genera su propio lenguaje.
function M.nodes(node, kinds, recursive)
  local result = {}
  for child in node:iter_children() do
    if vim.tbl_contains(kinds, child:type()) then
      result[#result + 1] = child
    elseif recursive then
      vim.list_extend(result, M.nodes(child, kinds, true))
    end
  end
  return result
end

function M.first(node, kinds, recursive)
  return M.nodes(node, kinds, recursive)[1]
end

function M.text(node, source)
  if not node then
    return ""
  end
  local text = vim.treesitter.get_node_text(node, source)
  local _, _, base = node:start()
  local comments = M.nodes(node, { "comment", "line_comment", "block_comment" }, true)
  for index = #comments, 1, -1 do
    local _, _, first = comments[index]:start()
    local _, _, last = comments[index]:end_()
    text = text:sub(1, first - base) .. " " .. text:sub(last - base + 1)
  end
  return vim.trim(text:gsub("[\r\n]+", " "))
end

function M.syntax(source, language, kind)
  local parser = vim.treesitter.get_string_parser(source, language)
  local tree = assert(parser:parse()[1], "No se pudo analizar el archivo")
  local units = M.nodes(tree:root(), { kind }, true)
  assert(#units > 0, "No se encontró ningún módulo o entidad en este archivo")
  return units, tree
end

function M.unique(seed, used)
  local name = seed
  while used[name:lower()] do
    name = name .. "_tb"
  end
  used[name:lower()] = true
  return name
end

function M.relative(from, to)
  from = vim.split(vim.fs.normalize(vim.fn.fnamemodify(from, ":p")), "/", { trimempty = true })
  to = vim.split(vim.fs.normalize(vim.fn.fnamemodify(to, ":p")), "/", { trimempty = true })
  local common, result = 0, {}
  while from[common + 1] and from[common + 1] == to[common + 1] do
    common = common + 1
  end
  for _ = common + 1, #from do
    result[#result + 1] = ".."
  end
  for index = common + 1, #to do
    result[#result + 1] = to[index]
  end
  return table.concat(result, "/")
end

local function source_text(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  end
  return table.concat(vim.fn.readfile(path), "\n")
end

local function ask(show)
  local thread = coroutine.running()
  show(function(value)
    vim.schedule(function()
      local ok, err = coroutine.resume(thread, value)
      if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
      end
    end)
  end)
  return coroutine.yield()
end

local function input(prompt, default)
  return ask(function(done)
    vim.ui.input({ prompt = prompt, default = default }, done)
  end)
end

local function select(items, prompt, format)
  return ask(function(done)
    tasks.select(items, { prompt = prompt, format_item = format }, done)
  end)
end

local function number(prompt, default, quantum)
  local text = input(prompt .. " (ns): ", tostring(default))
  if text == nil then
    return nil
  end
  local value = tonumber(text)
  assert(text:match("^%d+%.?%d*$") and value and value > 0 and value < 1e12, "Tiempo inválido")
  local steps = value / quantum
  assert(math.abs(steps - math.floor(steps + 0.5)) < 1e-5, "Usa múltiplos de " .. quantum .. " ns")
  return value
end

local function signal(design, label, excluded, pattern)
  local choices, guessed = { { label = "Ninguno", name = false } }, false
  for _, port in ipairs(design.ports) do
    if port.clockable and port.name ~= excluded then
      local item = { label = port.name, name = port.name }
      if not guessed and port.name:lower():match(pattern) then
        table.insert(choices, 1, item)
        guessed = true
      else
        choices[#choices + 1] = item
      end
    end
  end
  return select(choices, label, function(item)
    return item.label
  end)
end

local function create_file(path, lines)
  assert(not vim.uv.fs_lstat(path), "Ya existe " .. path .. "; elige otro nombre")
  local buf = vim.fn.bufnr(path)
  assert(buf == -1 or not vim.bo[buf].modified, "Ya tienes cambios sin guardar en " .. path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd, err = vim.uv.fs_open(path, "wx", 420)
  assert(fd, err)
  local text, offset = table.concat(lines, "\n") .. "\n", 0
  while offset < #text do
    local count, write_error = vim.uv.fs_write(fd, text:sub(offset + 1), offset)
    if not count or count == 0 then
      vim.uv.fs_close(fd)
      vim.fn.delete(path)
      error(write_error or "No se pudo escribir el testbench")
    end
    offset = offset + count
  end
  assert(vim.uv.fs_close(fd))
end

local function commit(root, language, module, path, options, lines)
  assert(not tasks.is_running(root), "Detén el proceso del proyecto con Espacio rx antes de crear")
  local profile_path = root .. "/SIM/project.json"
  local profile = module.profile(root)
  local targets = language == "verilog"
      and { profile_path, root .. "/SIM/iverilog.f", root .. "/SIM/verible.filelist" }
    or { profile_path, root .. "/SIM/vhdl.f", root .. "/vhdl_ls.toml" }
  local backups = {}
  -- Detectar ediciones pendientes antes de crear el archivo o cambiar la selección.
  for _, file in ipairs(targets) do
    local buf = vim.fn.bufnr(file)
    assert(buf == -1 or not vim.bo[buf].modified, "Guarda primero " .. file)
    backups[file] = vim.fn.filereadable(file) == 1 and vim.fn.readfile(file) or false
  end
  create_file(path, lines)
  local ok, err = pcall(function()
    profile.top, profile.testbench = options.top, path:sub(#root + 2)
    if language == "vhdl" then
      profile.stop_time = string.format("%.0f", options.duration * 1000) .. "ps"
    end
    tasks.store_profile(root, language, profile)
    module.prepare(root)
  end)
  if not ok then
    vim.fn.delete(path)
    for _, file in ipairs(targets) do
      if backups[file] then
        tasks.write(file, backups[file])
      else
        vim.fn.delete(file)
      end
    end
    error(err)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  for index, line in ipairs(lines) do
    if line:find("TODO", 1, true) then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      break
    end
  end
  vim.notify("Creado y seleccionado: " .. profile.testbench .. ". Añade tus estímulos y usa Espacio rs")
end

function M.create(root, language, module)
  local current = vim.api.nvim_buf_get_name(0)
  local extension = language == "vhdl" and ".vhd" or ".sv"
  local thread = coroutine.create(function()
    assert(not tasks.is_running(root), "Detén el proceso del proyecto con Espacio rx antes de crear")
    local profile = module.profile(root)
    assert(
      language ~= "vhdl" or profile.standard == "08" or profile.standard == "19",
      "El testbench VHDL usa std.env.finish; configura standard = 08"
    )
    local path = current
    if path:sub(1, #root + 5) ~= root .. "/RTL/" then
      local extensions = language == "vhdl" and { vhd = true, vhdl = true } or { v = true, sv = true }
      local files = tasks.files(root, { "RTL" }, extensions)
      assert(#files > 0, "No hay fuentes en RTL/")
      path = select(files, "Archivo del diseño", function(file)
        return file:sub(#root + 2)
      end)
      if not path then
        return
      end
    end
    local source = source_text(path)
    local units = module.testbench_units(source)
    local unit = #units == 1 and units[1]
      or select(units, "Módulo o entidad", function(item)
        return item.name
      end)
    if not unit then
      return
    end
    local design = module.testbench_design(unit, source)
    local top = input("Nombre del testbench: ", design.name .. "_tb")
    if top == nil then
      return
    end
    assert(module.testbench_identifier(top), "Nombre de testbench inválido")
    assert(top:lower() ~= design.name:lower(), "El testbench necesita un nombre distinto al diseño")
    local output = root .. "/SIM/tb/" .. top .. extension
    assert(not vim.uv.fs_lstat(output), "Ya existe " .. output .. "; elige otro nombre")
    local clock = signal(design, "Entrada de reloj", nil, "clk")
    if not clock then
      return
    end
    local period = 10
    if clock.name then
      period = number("Periodo del reloj", 10, 0.002)
    end
    if not period then
      return
    end
    local reset = signal(design, "Entrada de reset", clock.name, "rst")
    if not reset then
      return
    end
    local active, hold = 0, 0
    if reset.name then
      local low = reset.name:lower():match("^n_") or reset.name:lower():match("_n$")
      local choices = low and { 0, 1 } or { 1, 0 }
      active = select(choices, "Polaridad del reset", function(value)
        return "Activo en " .. value
      end)
      if active == nil then
        return
      end
      hold = number("Duración del reset activo", period * 2, 0.001)
      if not hold then
        return
      end
    end
    local duration = number("Duración total de simulación", math.max(1000, period * 20, hold * 10), 0.001)
    if not duration then
      return
    end
    assert(duration > hold, "La simulación debe durar más que el reset")
    local options = {
      top = top,
      clock = clock.name,
      period = period,
      reset = reset.name,
      active = active,
      hold = hold,
      duration = duration,
      root = root,
      run_dir = profile.run_dir,
    }
    local lines = module.testbench_render(design, options)
    local parser = vim.treesitter.get_string_parser(
      table.concat(lines, "\n"),
      language == "vhdl" and "vhdl" or "systemverilog"
    )
    assert(
      not parser:parse()[1]:root():has_error(),
      "La interfaz necesita un testbench manual; no se creó ningún archivo"
    )
    local preview = vim.deepcopy(lines)
    if profile.filelist then
      table.insert(
        preview,
        1,
        "Lista manual: " .. profile.filelist .. "; añade este testbench antes de simular."
      )
    end
    tasks.menu("Vista previa: " .. top .. extension, {
      {
        text = "Crear y seleccionar " .. output:sub(#root + 2),
        action = function()
          assert(source_text(path) == source, "El diseño cambió durante el asistente; vuelve a iniciarlo")
          commit(root, language, module, output, options, lines)
        end,
      },
      { text = "Cancelar", action = function() end },
    }, preview)
  end)
  local ok, err = coroutine.resume(thread)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end

return M
