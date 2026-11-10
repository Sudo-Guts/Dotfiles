local M = {}
local tasks = require("config.nvim.tasks")
local tb = require("config.nvim.testbench")
local header = "# Generado por GUTS; Espacio rg actualiza esta lista."
local extensions = { vhd = true, vhdl = true }
local defaults = {
  standard = "08",
  library = "defaultlib",
  stop_time = "1ms",
  sources = {},
  extra_sources = {},
  compile_args = {},
  run_args = {},
  run_dir = ".",
  timeout_ms = 30000,
}

function M.root(bufnr)
  return tasks.project_root({ "RTL", "SIM" }, bufnr)
end

function M.profile(root)
  local profile = tasks.profile(root, "vhdl", defaults)
  for _, field in ipairs({ "sources", "extra_sources", "compile_args", "run_args" }) do
    tasks.strings(profile[field], field)
  end
  assert(
    vim.tbl_contains({ "87", "93", "93c", "00", "02", "08", "19" }, profile.standard),
    "Estándar VHDL inválido"
  )
  assert(
    type(profile.library) == "string" and profile.library:match("^[%a][%w_]*$"),
    "Biblioteca VHDL inválida"
  )
  assert(
    type(profile.stop_time) == "string" and profile.stop_time:match("^%d+[munpf]?s$"),
    "stop_time inválido (ejemplo: 1ms)"
  )
  assert(type(profile.run_dir) == "string" and profile.run_dir ~= "", "run_dir debe ser un directorio")
  assert(type(profile.timeout_ms) == "number" and profile.timeout_ms > 0, "timeout_ms debe ser positivo")
  return profile
end

function M.ensure_index(root)
  local ok, profile = pcall(M.profile, root)
  if not ok then
    profile = defaults
  end
  return tasks.write(root .. "/vhdl_ls.toml", {
    "# GUTS: configuración inicial; tus bibliotecas personalizadas se conservan.",
    "[libraries." .. profile.library .. "]",
    'files = ["RTL/**/*.vhd", "RTL/**/*.vhdl", "SIM/tb/**/*.vhd", "SIM/tb/**/*.vhdl", "SIM/models/**/*.vhd", "SIM/models/**/*.vhdl"]',
  }, true)
end

function M.prepare(root, internal)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  local profile = M.profile(root)
  local changed = M.ensure_index(root)
  local files = #profile.sources > 0 and {} or tasks.files(root, { "RTL", "SIM/models" }, extensions)
  files = tasks.sources(root, vim.list_extend(vim.deepcopy(profile.sources), files), profile.extra_sources)
  if profile.testbench then
    files = tasks.sources(root, files, { profile.testbench })
  end
  local lines = { header, "# Rutas relativas a SIM/. GHDL resuelve las dependencias con -i y -m." }
  for _, path in ipairs(files) do
    lines[#lines + 1] = path:sub(1, #root + 1) == root .. "/" and "../" .. path:sub(#root + 2) or path
  end
  local path = root .. "/SIM/vhdl.f"
  if vim.fn.filereadable(path) == 0 or vim.fn.readfile(path, "", 1)[1] == header then
    tasks.write(path, lines)
  end
  tasks.store_profile(root, "vhdl", profile)
  if changed or not internal then
    tasks.restart("vhdl_ls", root)
  end
  if not internal then
    vim.notify("VHDL: bibliotecas preparadas; SIM/vhdl.f disponible")
  end
  return profile
end

function M.choose_testbench(root, done)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.choose_testbench(
    root,
    "vhdl",
    extensions,
    defaults,
    "[Ee][Nn][Tt][Ii][Tt][Yy]%s+([%a][%w_]*)%s+[Ii][Ss]",
    function(profile)
      M.prepare(root, true)
      if done then
        done(profile)
      end
    end
  )
end

local function build(root, profile, done)
  profile = M.profile(root)
  assert(
    type(profile.top) == "string" and type(profile.testbench) == "string",
    "Selecciona el testbench con Espacio rt"
  )
  assert(profile.top:match("^[%a][%w_]*$"), "Top VHDL inválido")
  assert(
    vim.fn.filereadable(root .. "/" .. profile.testbench) == 1,
    "No existe el testbench seleccionado; usa Espacio rt"
  )
  tasks.save(root)
  M.prepare(root, true)
  local files = {}
  for _, line in ipairs(vim.fn.readfile(root .. "/SIM/vhdl.f")) do
    line = vim.trim(line)
    if line ~= "" and line:sub(1, 1) ~= "#" then
      files[#files + 1] = line:sub(1, 1) == "/" and line or root .. "/SIM/" .. line
    end
  end
  files = tasks.sources(root, files, { profile.testbench })
  assert(#files > 0, "SIM/vhdl.f no contiene fuentes")
  local work = root .. "/SIM/out/ghdl-" .. profile.top
  vim.fn.mkdir(work, "p")
  local flags = { "--std=" .. profile.standard, "--work=" .. profile.library, "--workdir=" .. work }
  vim.list_extend(flags, profile.compile_args)
  local import = vim.list_extend({ "ghdl", "-i" }, flags)
  vim.list_extend(import, files)
  tasks.run(import, root, function()
    local make = vim.list_extend({ "ghdl", "-m" }, flags)
    make[#make + 1] = profile.top
    tasks.run(make, root, function()
      if done then
        done(flags)
      end
    end, { append = true, stage = "Elaborar VHDL (GHDL)" })
  end, { stage = "Analizar VHDL (GHDL)" })
end

function M.compile(root)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.with_testbench(root, "vhdl", defaults, M.choose_testbench, function(profile)
    tasks.safe(function()
      build(root, profile)
    end)
  end)
end

function M.simulate(root)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.with_testbench(root, "vhdl", defaults, M.choose_testbench, function(profile)
    tasks.safe(function()
      build(root, profile, function(flags)
        local command = vim.list_extend({ "ghdl", "-r" }, flags)
        vim.list_extend(command, {
          profile.top,
          "--vcd=" .. root .. "/SIM/out/" .. profile.top .. ".vcd",
          "--stop-time=" .. profile.stop_time,
        })
        vim.list_extend(command, profile.run_args)
        local cwd = root .. "/" .. profile.run_dir
        assert(vim.fn.isdirectory(cwd) == 1, "No existe run_dir: " .. cwd)
        tasks.run(
          command,
          cwd,
          nil,
          { append = true, timeout_ms = profile.timeout_ms, project = root, stage = "Simular VHDL (GHDL)" }
        )
      end)
    end)
  end)
end

function M.waves(root)
  tasks.waves(root or assert(M.root(), "No se encontró RTL/ y SIM/"))
end

function M.create_testbench(root)
  tb.create(root or assert(M.root(), "No se encontró RTL/ y SIM/"), "vhdl", M)
end

function M.testbench_identifier(name)
  return type(name) == "string"
    and name:match("^[%a][%w_]*$") ~= nil
    and not name:match("_$")
    and not name:find("__", 1, true)
end

function M.testbench_units(source)
  local nodes, tree = tb.syntax(source, "vhdl", "entity_declaration")
  local result = {}
  for _, node in ipairs(nodes) do
    local name = tb.text(tb.first(node, { "identifier" }), source)
    assert(M.testbench_identifier(name), "Identificador VHDL no compatible: " .. name)
    result[#result + 1] = { name = name, node = node, tree = tree }
  end
  return result
end

local function interfaces(clause, source)
  local result = {}
  if not clause then
    return result
  end
  assert(not clause:has_error(), "Corrige la declaración de puertos o generics antes de crear el testbench")
  for _, declaration in ipairs(tb.nodes(clause, { "interface_declaration" }, true)) do
    local names = tb.first(declaration, { "identifier_list" })
    local indication = tb.first(declaration, { "simple_mode_indication" })
    assert(names and indication, "Esta interfaz VHDL requiere un testbench manual")
    local dtype = tb.text(tb.first(indication, { "subtype_indication" }), source)
    assert(dtype ~= "", "No se pudo determinar el tipo del puerto")
    local mode = tb.text(tb.first(indication, { "mode" }), source):lower()
    local initial = tb.text(tb.first(indication, { "initialiser" }), source):gsub("^:=%s*", "")
    for child in names:iter_children() do
      if child:named() and child:type() ~= "comment" then
        local name = tb.text(child, source)
        assert(M.testbench_identifier(name), "Identificador VHDL no compatible: " .. name)
        result[#result + 1] =
          { name = name, dtype = dtype, direction = mode ~= "" and mode or "in", initial = initial }
      end
    end
  end
  return result
end

function M.testbench_design(unit, source)
  local head = assert(tb.first(unit.node, { "entity_head" }), "No se encontró la cabecera de la entidad")
  local design = { name = unit.name, ports = {}, parameters = {}, imports = {}, used = {} }
  for _, item in ipairs(tb.nodes(unit.node:parent(), { "library_clause", "use_clause", "context_reference" })) do
    design.imports[#design.imports + 1] = tb.text(item, source)
  end
  for _, generic in ipairs(interfaces(tb.first(head, { "generic_clause" }), source)) do
    assert(generic.initial ~= "", "El generic " .. generic.name .. " necesita un valor predeterminado")
    assert(not design.used[generic.name:lower()], "Generic duplicado")
    design.used[generic.name:lower()] = true
    design.parameters[#design.parameters + 1] = generic
  end
  for _, port in ipairs(interfaces(tb.first(head, { "port_clause" }), source)) do
    assert(not design.used[port.name:lower()], "Puerto duplicado")
    design.used[port.name:lower()] = true
    local base = port.dtype:lower():match("^([%w_]+)")
    assert(
      vim.tbl_contains({ "in", "out", "inout", "buffer" }, port.direction),
      "Modo de puerto no compatible"
    )
    if
      vim.tbl_contains({ "std_logic_vector", "std_ulogic_vector", "bit_vector", "signed", "unsigned" }, base)
    then
      assert(port.dtype:find("(", 1, true), "Concreta el rango de " .. port.name .. " antes de crear")
    end
    local scalar = base == "std_logic" or base == "std_ulogic" or base == "bit"
    port.clockable = port.direction == "in" and scalar and not port.dtype:find("(", 1, true)
    if port.direction == "in" or port.direction == "inout" then
      if port.initial == "" then
        if scalar then
          port.initial = port.direction == "inout" and base ~= "bit" and "'Z'" or "'0'"
        elseif
          vim.tbl_contains(
            { "std_logic_vector", "std_ulogic_vector", "bit_vector", "signed", "unsigned" },
            base
          )
        then
          assert(port.dtype:find("(", 1, true), "Concreta el rango de " .. port.name .. " antes de crear")
          local value = port.direction == "inout" and base ~= "bit_vector" and "Z" or "0"
          port.initial = "(others => '" .. value .. "')"
        elseif base == "boolean" then
          port.initial = "false"
        elseif base == "positive" or base == "natural" or base == "integer" then
          local range = port.dtype:lower():match("range%s+(.+)")
          local bound = range and (range:match("^(.-)%s+to%s+") or range:match("^(.-)%s+downto%s+"))
          assert(not range or bound, "No se pudo determinar el rango de " .. port.name)
          port.initial = bound and "(" .. bound .. ")" or (base == "positive" and "1" or "0")
        else
          error(
            "Añade un valor predeterminado al puerto "
              .. port.name
              .. " (tipo "
              .. port.dtype
              .. ") o crea el testbench manualmente"
          )
        end
      end
    end
    design.ports[#design.ports + 1] = port
  end
  return design
end

function M.testbench_render(design, options)
  local used = vim.deepcopy(design.used)
  local period = tb.unique("TB_CLOCK_PERIOD", used)
  local hold = tb.unique("TB_RESET_HOLD", used)
  local duration = tb.unique("TB_DURATION", used)
  local dut = tb.unique("dut", used)
  local lines = {
    "-- Base generada para " .. design.name .. "; añade estímulos y comprobaciones.",
    "library ieee;",
    "use ieee.std_logic_1164.all;",
    "use ieee.numeric_std.all;",
  }
  local seen = {
    ["library ieee;"] = true,
    ["use ieee.std_logic_1164.all;"] = true,
    ["use ieee.numeric_std.all;"] = true,
  }
  for _, import in ipairs(design.imports) do
    if not seen[import:lower()] then
      lines[#lines + 1] = import
      seen[import:lower()] = true
    end
  end
  vim.list_extend(lines, {
    "",
    "entity " .. options.top .. " is",
    "end entity " .. options.top .. ";",
    "",
    "architecture simulation of " .. options.top .. " is",
  })
  for _, parameter in ipairs(design.parameters) do
    lines[#lines + 1] = "    constant "
      .. parameter.name
      .. " : "
      .. parameter.dtype
      .. " := "
      .. parameter.initial
      .. ";"
  end
  if options.clock then
    lines[#lines + 1] = "    constant " .. period .. " : time := " .. options.period .. " ns;"
  end
  if options.reset then
    lines[#lines + 1] = "    constant " .. hold .. " : time := " .. options.hold .. " ns;"
  end
  lines[#lines + 1] = "    constant " .. duration .. " : time := " .. options.duration .. " ns;"
  for _, port in ipairs(design.ports) do
    local initial = port.initial
    if port.name == options.reset then
      initial = "'" .. options.active .. "'"
    elseif port.name == options.clock then
      initial = "'0'"
    end
    local drive = port.direction == "in" or port.direction == "inout"
    lines[#lines + 1] = "    signal "
      .. port.name
      .. " : "
      .. port.dtype
      .. (drive and " := " .. initial or "")
      .. ";"
    if port.direction == "inout" then
      lines[#lines + 1] = "    -- TODO: añade un driver de " .. port.name .. " si lo requiere tu prueba."
    end
  end
  vim.list_extend(lines, { "begin", "    " .. dut .. ": entity work." .. design.name })
  if #design.parameters > 0 then
    lines[#lines + 1] = "        generic map ("
    for index, parameter in ipairs(design.parameters) do
      lines[#lines + 1] = "            "
        .. parameter.name
        .. " => "
        .. parameter.name
        .. (index < #design.parameters and "," or "")
    end
    lines[#lines + 1] = "        )"
  end
  if #design.ports > 0 then
    lines[#lines + 1] = "        port map ("
    for index, port in ipairs(design.ports) do
      lines[#lines + 1] = "            "
        .. port.name
        .. " => "
        .. port.name
        .. (index < #design.ports and "," or "")
    end
    lines[#lines + 1] = "        );"
  else
    lines[#lines] = lines[#lines] .. ";"
  end
  if options.clock then
    vim.list_extend(lines, {
      "",
      "    process",
      "    begin",
      "        wait for " .. period .. " / 2;",
      "        " .. options.clock .. " <= not " .. options.clock .. ";",
      "    end process;",
    })
  end
  vim.list_extend(lines, { "", "    process", "    begin" })
  if options.reset then
    lines[#lines + 1] = "        wait for " .. hold .. ";"
    lines[#lines + 1] = "        " .. options.reset .. " <= '" .. (1 - options.active) .. "';"
  end
  vim.list_extend(lines, {
    "        -- TODO: aplica entradas y comprueba las salidas de tu diseño.",
    "        wait;",
    "    end process;",
    "",
    "    process",
    "    begin",
    "        wait for " .. duration .. ";",
    '        report "Testbench base finalizado; añade comprobaciones funcionales." severity note;',
    "        std.env.finish;",
    "        wait;",
    "    end process;",
    "end architecture simulation;",
  })
  return lines
end
function M.setup() end

return M
