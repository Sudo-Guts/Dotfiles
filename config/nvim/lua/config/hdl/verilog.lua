local M = {}
local tasks = require("config.nvim.tasks")
local tb = require("config.nvim.testbench")
local header = "# Generado por GUTS; Espacio rg actualiza esta lista."
local extensions = { v = true, sv = true }
local defaults = {
  standard = "2012",
  include_dirs = { "RTL", "SIM/models", "SIM/tb" },
  defines = {},
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
function M.verible_filelist(root)
  return root .. "/SIM/verible.filelist"
end

function M.profile(root)
  local profile = tasks.profile(root, "verilog", defaults)
  for _, field in ipairs({ "include_dirs", "defines", "sources", "extra_sources", "compile_args", "run_args" }) do
    tasks.strings(profile[field], field)
  end
  assert(
    vim.tbl_contains({ "1995", "2001", "2005", "2009", "2012" }, profile.standard),
    "Estándar Verilog inválido"
  )
  assert(type(profile.run_dir) == "string" and profile.run_dir ~= "", "run_dir debe ser un directorio")
  assert(type(profile.timeout_ms) == "number" and profile.timeout_ms > 0, "timeout_ms debe ser positivo")
  if profile.filelist then
    assert(type(profile.filelist) == "string" and profile.filelist ~= "", "filelist inválido")
  end
  if profile.filelist_cwd then
    assert(type(profile.filelist_cwd) == "string", "filelist_cwd inválido")
  end
  return profile
end

function M.ensure_index(root, force)
  local path = M.verible_filelist(root)
  if not force and vim.fn.filereadable(path) == 1 and vim.fn.readfile(path, "", 1)[1] ~= header then
    return false -- Una lista anterior/personalizada se conserva hasta la preparación explícita.
  end
  local files = tasks.files(
    root,
    { "RTL", "SIM/models", "SIM/tb" },
    { v = true, sv = true, vh = true, svh = true }
  )
  local ok, profile = pcall(M.profile, root)
  if ok then
    files = tasks.sources(root, files, vim.list_extend(vim.deepcopy(profile.sources), profile.extra_sources))
  end
  return tasks.write(path, vim.list_extend({ header }, files))
end

function M.prepare(root, internal)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  local profile = M.profile(root)
  local changed = M.ensure_index(root, true)
  local files = #profile.sources > 0 and {} or tasks.files(root, { "RTL", "SIM/models" }, extensions)
  files = tasks.sources(root, vim.list_extend(vim.deepcopy(profile.sources), files), profile.extra_sources)
  if profile.testbench then
    files = tasks.sources(root, files, { profile.testbench })
  end
  local lines = { header, "# Rutas relativas a la raíz del proyecto; un archivo por línea." }
  for _, path in ipairs(files) do
    assert(not path:find("[\r\n]"), "Una ruta contiene un salto de línea")
    lines[#lines + 1] = path:sub(1, #root + 1) == root .. "/" and path:sub(#root + 2) or path
  end
  tasks.write(root .. "/SIM/iverilog.f", lines)
  tasks.store_profile(root, "verilog", profile)
  if changed or not internal then
    tasks.restart("verible", root)
  end
  if not internal then
    vim.notify("Verilog: índice preparado; " .. #files .. " fuentes de simulación")
  end
  return profile
end

function M.choose_testbench(root, done)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.choose_testbench(root, "verilog", extensions, defaults, "module%s+([%a_][%w_]*)", function(profile)
    M.prepare(root, true)
    if done then
      done(profile)
    end
  end)
end

local function build(root, profile, done)
  profile = M.profile(root)
  assert(
    type(profile.top) == "string" and type(profile.testbench) == "string",
    "Selecciona el testbench con Espacio rt"
  )
  assert(profile.top:match("^[%a_][%w_]*$"), "Top Verilog inválido")
  assert(
    vim.fn.filereadable(root .. "/" .. profile.testbench) == 1,
    "No existe el testbench seleccionado; usa Espacio rt"
  )
  tasks.save(root)
  M.prepare(root, true)
  local output = root .. "/SIM/out/" .. profile.top .. ".vvp"
  vim.fn.mkdir(root .. "/SIM/out", "p")
  local command =
    { "iverilog", "-g" .. profile.standard, "-grelative-include", "-s", profile.top, "-o", output }
  for _, dir in ipairs(profile.include_dirs) do
    vim.list_extend(command, { "-I", root .. "/" .. dir })
  end
  for _, define in ipairs(profile.defines) do
    vim.list_extend(command, { "-D", define })
  end
  vim.list_extend(command, profile.compile_args)
  local cwd = root
  if profile.filelist then
    assert(vim.fn.filereadable(root .. "/" .. profile.filelist) == 1, "No existe " .. profile.filelist)
    cwd = root .. "/" .. (profile.filelist_cwd or ".")
    vim.list_extend(command, { "-f", root .. "/" .. profile.filelist })
  else
    vim.list_extend(command, { "-f", root .. "/SIM/iverilog.f" })
  end
  tasks.run(command, cwd, function()
    if done then
      done(output)
    end
  end, { project = root, stage = "Compilar Verilog/SV (Icarus)" })
end

function M.compile(root)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.with_testbench(root, "verilog", defaults, M.choose_testbench, function(profile)
    tasks.safe(function()
      build(root, profile)
    end)
  end)
end

function M.simulate(root)
  root = root or assert(M.root(), "No se encontró RTL/ y SIM/")
  tasks.with_testbench(root, "verilog", defaults, M.choose_testbench, function(profile)
    tasks.safe(function()
      build(root, profile, function(output)
        local command = vim.list_extend({ "vvp", output }, profile.run_args)
        local cwd = root .. "/" .. profile.run_dir
        assert(vim.fn.isdirectory(cwd) == 1, "No existe run_dir: " .. cwd)
        tasks.run(command, cwd, nil, {
          append = true,
          timeout_ms = profile.timeout_ms,
          project = root,
          stage = "Simular Verilog/SV (vvp)",
        })
      end)
    end)
  end)
end

function M.waves(root)
  tasks.waves(root or assert(M.root(), "No se encontró RTL/ y SIM/"))
end

function M.create_testbench(root)
  tb.create(root or assert(M.root(), "No se encontró RTL/ y SIM/"), "verilog", M)
end

function M.testbench_identifier(name)
  return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

local function identifier(node, source)
  local name = tb.text(tb.first(node, { "simple_identifier", "escaped_identifier" }), source)
  assert(name:match("^[%a_][%w_$]*$"), "Identificador HDL no compatible: " .. name)
  return name
end

function M.testbench_units(source)
  local nodes, tree = tb.syntax(source, "systemverilog", "module_declaration")
  local result = {}
  for _, node in ipairs(nodes) do
    local head = tb.first(node, { "module_ansi_header", "module_nonansi_header" })
    assert(head, "No se pudo leer la cabecera del módulo")
    result[#result + 1] = { name = identifier(head, source), node = node, head = head, tree = tree }
  end
  return result
end

local function port_type(node, source)
  local text = tb.text(node, source):gsub("^var%s+", "")
  text = text:gsub("^(wire)%f[%W]%s*", ""):gsub("^(reg)%f[%W]%s*", "")
  local dimensions = {}
  for dimension in text:gmatch("%b[]") do
    assert(dimension:find(":", 1, true), "Dimensión de puerto no compatible: " .. dimension)
    assert(not dimension:find("`", 1, true), "Resuelve las macros del ancho antes de crear el testbench")
    dimensions[#dimensions + 1] = dimension
  end
  local base = vim.trim(text:gsub("%b[]", ""):gsub("%s+", " "))
  local signed = base:find("signed", 1, true) and not base:find("unsigned", 1, true)
  base = vim.trim(base:gsub("unsigned", ""):gsub("signed", ""))
  local integer_widths = { byte = 8, shortint = 16, int = 32, integer = 32, longint = 64, time = 64 }
  if integer_widths[base] then
    assert(#dimensions == 0, "Arreglos de enteros requieren un testbench manual")
    dimensions = { "[" .. integer_widths[base] - 1 .. ":0]" }
    signed = not text:find("unsigned", 1, true) and base ~= "time"
  else
    assert(base == "" or base == "logic" or base == "bit", "Tipo de puerto no compatible: " .. text)
  end
  local suffix = (signed and "signed " or "") .. table.concat(dimensions, " ")
  return vim.trim(suffix), #dimensions == 0
end

local function parameters(design, node, source)
  assert(
    not tb.first(node, { "type_assignment", "list_of_type_assignments" }, true),
    "Los parámetros de tipo requieren un testbench manual"
  )
  for _, assignment in ipairs(tb.nodes(node, { "param_assignment" }, true)) do
    local decl = assignment:parent()
    while
      decl
      and decl:id() ~= node:id()
      and decl:type() ~= "parameter_declaration"
      and decl:type() ~= "local_parameter_declaration"
    do
      decl = decl:parent()
    end
    local dtype = decl and tb.text(tb.first(decl, { "data_type_or_implicit", "data_type" }), source) or ""
    local name = identifier(assignment, source)
    local value = tb.text(tb.first(assignment, { "constant_param_expression" }), source)
    assert(
      value ~= "" and not value:find("`", 1, true),
      "El parámetro " .. name .. " necesita un valor concreto"
    )
    assert(not design.used[name:lower()], "Parámetro duplicado: " .. name)
    design.used[name:lower()] = true
    design.parameters[#design.parameters + 1] = {
      name = name,
      dtype = dtype,
      value = value,
      pass = not tb.text(decl, source):match("^localparam"),
    }
  end
end

function M.testbench_design(unit, source)
  assert(not unit.head:has_error(), "Corrige la cabecera del módulo antes de crear el testbench")
  local design = { name = unit.name, ports = {}, parameters = {}, used = {}, imports = {} }
  local parameter_list = tb.first(unit.head, { "parameter_port_list" })
  if parameter_list then
    parameters(design, parameter_list, source)
    assert(#design.parameters > 0, "Esta lista de parámetros requiere un testbench manual")
  end
  for _, item in ipairs(tb.nodes(unit.node, { "module_item" })) do
    if tb.first(item, { "parameter_declaration", "local_parameter_declaration" }) then
      parameters(design, item, source)
    end
    for _, import in ipairs(tb.nodes(item, { "package_import_declaration" })) do
      design.imports[#design.imports + 1] = tb.text(import, source)
    end
  end
  local function add(name, direction, dtype, scalar, declaration)
    assert(not design.used[name:lower()], "Puerto duplicado: " .. name)
    assert(
      not tb.first(declaration, { "unpacked_dimension", "variable_dimension" }),
      "El puerto " .. name .. " usa un arreglo no compatible"
    )
    design.used[name:lower()] = true
    design.ports[#design.ports + 1] = {
      name = name,
      direction = direction,
      dtype = dtype,
      clockable = direction == "input" and scalar,
      initial = tb.text(tb.first(declaration, { "constant_expression" }), source),
    }
  end
  local ansi = tb.first(unit.head, { "list_of_port_declarations" })
  if ansi then
    local direction, dtype, scalar
    for _, declaration in ipairs(tb.nodes(ansi, { "ansi_port_declaration" })) do
      assert(not declaration:has_error(), "Puerto no compatible con el asistente")
      local head =
        tb.first(declaration, { "net_port_header", "variable_port_header", "interface_port_header" })
      if head then
        direction = tb.text(tb.first(head, { "port_direction" }), source)
        assert(direction ~= "", "Las interfaces requieren un testbench manual")
        dtype, scalar = port_type(tb.first(head, { "net_port_type", "variable_port_type" }), source)
      end
      assert(direction, "No se pudo determinar la dirección del puerto")
      add(identifier(declaration, source), direction, dtype, scalar, declaration)
    end
  else
    local declared = {}
    for _, item in ipairs(tb.nodes(unit.node, { "module_item" })) do
      for _, decl in
        ipairs(tb.nodes(item, { "input_declaration", "output_declaration", "inout_declaration" }, true))
      do
        local direction = decl:type():gsub("_declaration$", "")
        local dtype, scalar = port_type(tb.first(decl, { "net_port_type", "variable_port_type" }), source)
        local list = tb.first(decl, { "list_of_port_identifiers", "list_of_variable_port_identifiers" })
        assert(list, "Declaración de puertos no compatible")
        for child in list:iter_children() do
          if child:named() and child:type() ~= "comment" then
            local name = child:type() == "simple_identifier" and tb.text(child, source)
              or identifier(child, source)
            assert(not declared[name], "Puerto duplicado: " .. name)
            declared[name] = { direction, dtype, scalar, child }
          end
        end
      end
    end
    -- Conservar el tipo de las declaraciones reg asociadas a puertos clásicos.
    for _, item in ipairs(tb.nodes(unit.node, { "module_item" })) do
      local declaration = tb.first(item, { "data_declaration", "net_declaration" })
      if declaration then
        local dtype_node = tb.first(declaration, { "data_type_or_implicit", "data_type" })
        for _, assignment in
          ipairs(tb.nodes(declaration, { "variable_decl_assignment", "net_decl_assignment" }, true))
        do
          local name = identifier(assignment, source)
          if declared[name] then
            assert(
              not tb.first(assignment, { "unpacked_dimension", "variable_dimension" }),
              "El puerto " .. name .. " usa un arreglo no compatible"
            )
            local dtype, scalar = port_type(dtype_node, source)
            if dtype ~= "" or declared[name][2] == "" then
              declared[name][2], declared[name][3] = dtype, scalar
            end
          end
        end
      end
    end
    local list = tb.first(unit.head, { "list_of_ports" })
    for _, port in ipairs(list and tb.nodes(list, { "port" }) or {}) do
      local name = identifier(port, source)
      local declaration = assert(declared[name], "No se encontró la declaración de " .. name)
      add(name, unpack(declaration))
      declared[name] = nil
    end
    assert(next(declared) == nil, "Hay declaraciones que no coinciden con la cabecera")
  end
  return design
end

function M.testbench_render(design, options)
  local used = vim.deepcopy(design.used)
  local period = tb.unique("TB_CLOCK_PERIOD_NS", used)
  local hold = tb.unique("TB_RESET_HOLD_NS", used)
  local duration = tb.unique("TB_DURATION_NS", used)
  local dut = tb.unique("dut", used)
  local lines = {
    "`timescale 1ns/1ps",
    "",
    "// Base generada para " .. design.name .. "; añade estímulos y comprobaciones.",
    "module " .. options.top .. ";",
  }
  for _, import in ipairs(design.imports) do
    lines[#lines + 1] = "    " .. import
  end
  for _, parameter in ipairs(design.parameters) do
    lines[#lines + 1] = "    localparam "
      .. (parameter.dtype ~= "" and parameter.dtype .. " " or "")
      .. parameter.name
      .. " = "
      .. parameter.value
      .. ";"
  end
  if options.clock then
    lines[#lines + 1] = "    localparam real " .. period .. " = " .. options.period .. ";"
  end
  if options.reset then
    lines[#lines + 1] = "    localparam real " .. hold .. " = " .. options.hold .. ";"
  end
  lines[#lines + 1] = "    localparam real " .. duration .. " = " .. options.duration .. ";"
  lines[#lines + 1] = ""
  for _, port in ipairs(design.ports) do
    local declaration = port.direction == "input" and "reg" or "wire"
    lines[#lines + 1] = "    "
      .. declaration
      .. " "
      .. (port.dtype ~= "" and port.dtype .. " " or "")
      .. port.name
      .. ";"
    if port.direction == "inout" then
      lines[#lines + 1] = "    // TODO: añade un driver para "
        .. port.name
        .. " si lo requiere tu prueba; queda en alta impedancia."
    end
  end
  lines[#lines + 1] = ""
  local overrides = {}
  for _, parameter in ipairs(design.parameters) do
    if parameter.pass then
      overrides[#overrides + 1] = "        ." .. parameter.name .. "(" .. parameter.name .. ")"
    end
  end
  if #overrides > 0 then
    lines[#lines + 1] = "    " .. design.name .. " #("
    for index, line in ipairs(overrides) do
      lines[#lines + 1] = line .. (index < #overrides and "," or "")
    end
    lines[#lines + 1] = "    ) " .. dut .. " ("
  else
    lines[#lines + 1] = "    " .. design.name .. " " .. dut .. " ("
  end
  for index, port in ipairs(design.ports) do
    lines[#lines + 1] = "        ."
      .. port.name
      .. "("
      .. port.name
      .. ")"
      .. (index < #design.ports and "," or "")
  end
  vim.list_extend(lines, { "    );", "" })
  if options.clock then
    lines[#lines + 1] = "    always #("
      .. period
      .. " / 2.0) "
      .. options.clock
      .. " = ~"
      .. options.clock
      .. ";"
    lines[#lines + 1] = ""
  end
  vim.list_extend(lines, { "    initial begin" })
  for _, port in ipairs(design.ports) do
    if port.direction == "input" then
      local value = port.name == options.reset and "1'b" .. options.active
        or (port.initial ~= "" and port.initial or "0")
      if port.name == options.clock then
        value = "0"
      end
      lines[#lines + 1] = "        " .. port.name .. " = " .. value .. ";"
    end
  end
  if options.reset then
    lines[#lines + 1] = "        #(" .. hold .. ");"
    lines[#lines + 1] = "        " .. options.reset .. " = 1'b" .. (1 - options.active) .. ";"
  end
  vim.list_extend(lines, {
    "        // TODO: aplica entradas y comprueba las salidas de tu diseño.",
    "    end",
    "",
    "    initial begin",
  })
  local wave = "SIM/out/" .. options.top .. ".vcd"
  if options.run_dir ~= "." then
    wave = tb.relative(
      options.root .. "/" .. options.run_dir,
      options.root .. "/SIM/out/" .. options.top .. ".vcd"
    )
  end
  lines[#lines + 1] = "        $dumpfile(" .. vim.json.encode(wave) .. ");"
  lines[#lines + 1] = "        $dumpvars(0, " .. options.top .. ");"
  lines[#lines + 1] = "        #(" .. duration .. ");"
  vim.list_extend(lines, {
    '        $display("Testbench base finalizado; añade comprobaciones funcionales.");',
    "        $finish;",
    "    end",
    "",
    "endmodule",
  })
  return lines
end

function M.setup()
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("GutsVerilog", { clear = true }),
    pattern = { "*.v", "*.sv", "*.vh", "*.svh" },
    callback = function(args)
      local root = M.root(args.buf)
      if root then
        tasks.safe(function()
          if M.ensure_index(root) then
            tasks.restart("verible", root)
          end
        end)
      end
    end,
  })
end

function M.setup_snippets()
  local ls = require("luasnip")
  local s, t, i = ls.snippet, ls.text_node, ls.insert_node
  ls.add_snippets("verilog", {
    s("modg", {
      t("module "),
      i(1, "module_name"),
      t({ " (", "    input wire clk,", "    input wire n_rst", ");", "    " }),
      i(0),
      t({ "", "endmodule" }),
    }),
    s("seqg", {
      t({ "always @(posedge clk or negedge n_rst) begin", "    if (!n_rst) begin", "        " }),
      i(1, "q <= 0;"),
      t({ "", "    end else begin", "        " }),
      i(2, "q <= d;"),
      t({ "", "    end", "end" }),
    }),
  })
  ls.filetype_extend("systemverilog", { "verilog" })
end

return M
