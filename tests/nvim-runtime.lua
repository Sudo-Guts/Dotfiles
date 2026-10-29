-- Integración sobre la instalación enlazada. Los proyectos y binarios son temporales.
local root = assert(vim.env.DOTFILES_TEST_ROOT)
local temporary = vim.fn.tempname()
local failures = {}
local checks = dofile(root .. "/setup/nvim-doctor.lua")
vim.fn.mkdir(temporary .. "/.git", "p")
vim.fn.mkdir(temporary .. "/RTL", "p")
vim.fn.mkdir(temporary .. "/SIM", "p")

local function test(name, action)
    local ok, err = xpcall(action, debug.traceback)
    if ok then
        print("OK " .. name)
    else
        failures[#failures + 1] = name .. ": " .. tostring(err)
    end
end

local function fixture(name, lines)
    local path = temporary .. "/" .. name
    vim.fn.writefile(lines, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), path
end

local function attached(buf, name)
    local client
    assert(
        vim.wait(20000, function()
            client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
            return client and client.initialized
        end, 50),
        "No se conectó " .. name .. "; revisa :LspLog"
    )
    return client
end

local function format(buf)
    local done, failure = false, nil
    require("conform").format({ bufnr = buf, async = true, lsp_format = "never", timeout_ms = 5000 }, function(err)
        failure, done = err, true
    end)
    assert(
        vim.wait(10000, function()
            return done
        end),
        "El formato no terminó"
    )
    assert(not failure, tostring(failure))
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function request(client, method, params, buf)
    local result = assert(client:request_sync(method, params, 10000, buf), "LSP sin respuesta: " .. method)
    assert(not result.err, vim.inspect(result.err))
    return result.result
end

test("Versiones fijadas y carga por lenguaje", function()
    checks.check()
    assert(package.loaded["config.hdl.verilog"] == nil, "HDL se cargó antes de abrir su lenguaje")
    assert(package.loaded["config.hdl.vhdl"] == nil, "VHDL se cargó antes de abrir su lenguaje")
    local plugins = vim.tbl_keys(require("lazy.core.config").plugins)
    require("lazy").load({ plugins = plugins })
    vim.wait(200)
    assert(vim.v.errmsg == "", vim.v.errmsg)
    assert(vim.g.mapleader == " ")
    assert(vim.fn.maparg("<C-v>", "n") == "")
    assert(vim.fn.maparg("<leader>ff", "n") ~= "")
    assert(require("cmp").get_config().sources[1].name == "nvim_lsp")
    assert(#require("dap").configurations.c == 3)
    assert(require("dap").configurations.python[1].type == "python")
end)

local examples = {
    { "main.c", "c", { "int twice(int value) { return value * 2; }", "int main(void) { return twice(3); }" }, { "clangd" } },
    { "main.cpp", "cpp", { "int main() { return 0; }" }, { "clangd" } },
    { "main.py", "python", { "def twice(value: int) -> int:", "    return value * 2", "result=twice(3)" }, { "pyright", "ruff" } },
    { "RTL/top.v", "verilog", { "module top(input wire a, output wire b);", "assign b=a;", "endmodule" }, { "verible" } },
    { "RTL/top.sv", "systemverilog", { "module top_sv(input logic a,output logic b);", "assign b=a;", "endmodule" }, { "verible" } },
    { "RTL/top.vhd", "vhdl", { "entity top_vhdl is end entity;", "architecture rtl of top_vhdl is begin end architecture;" }, { "vhdl_ls" } },
    { "sample.lua", "lua", { "local function value()", "return 1", "end", "return value()" }, { "lua_ls" } },
    { "sample.sh", "sh", { "#!/bin/sh", "printf '%s\\n' ready" }, {} },
}

local buffers = {}
for _, item in ipairs(examples) do
    test("Parser, LSP y atajos de " .. item[2], function()
        local buf = fixture(item[1], item[3])
        buffers[item[2]] = buf
        assert(vim.bo[buf].filetype == item[2], vim.bo[buf].filetype)
        local parser = vim.treesitter.get_parser(buf)
        assert(parser and parser:parse()[1], "Parser sin árbol: " .. item[2])
        for _, name in ipairs(item[4]) do
            attached(buf, name)
        end
        local cpp = item[2] == "c" or item[2] == "cpp"
        local hdl = vim.tbl_contains({ "verilog", "systemverilog", "vhdl" }, item[2])
        for _, key in ipairs({ "rp", "rg", "rc", "rt", "rl", "rx", "rm" }) do
            assert((vim.fn.maparg("<leader>" .. key, "n") ~= "") == (cpp or hdl), "Atajo " .. key)
        end
        for _, key in ipairs({ "rn", "rs", "rw" }) do
            assert((vim.fn.maparg("<leader>" .. key, "n") ~= "") == hdl, "Atajo " .. key)
        end
        assert((vim.fn.maparg("<leader>re", "n") ~= "") == cpp)
        assert((vim.fn.maparg("<leader>db", "n") ~= "") == (cpp or item[2] == "python"))
        if #item[4] > 0 then
            assert(vim.fn.maparg("gd", "n") ~= "")
        end
    end)
end

test("Navegación y capacidades de autocompletado C", function()
    local buf = assert(buffers.c)
    local client = attached(buf, "clangd")
    assert(client.config.capabilities.textDocument.completion.completionItem.snippetSupport)
    local result = request(client, "textDocument/definition", {
        textDocument = { uri = vim.uri_from_bufnr(buf) },
        position = { line = 1, character = 25 },
    }, buf)
    assert(type(result) == "table" and next(result), "clangd no devolvió la definición de twice")
    local completion_buf = fixture("completion.c", { "int twice(int value) { return value * 2; }", "int main(void) {", "    tw", "}" })
    local completion_client = attached(completion_buf, "clangd")
    local params = { textDocument = { uri = vim.uri_from_bufnr(completion_buf) }, position = { line = 2, character = 6 } }
    local completion = request(completion_client, "textDocument/completion", params, completion_buf)
    local found = false
    for _, item in ipairs(completion.items or completion) do
        if item.label:find("twice", 1, true) then
            found = true
        end
    end
    assert(found, "clangd no completó twice")
end)

test("Formato C/C++ y configuración del proyecto", function()
    for _, ft in ipairs({ "c", "cpp" }) do
        local buf = assert(buffers[ft])
        local text = format(buf)
        assert(text:find("int main%([^\n]*%) {"), "Llave fuera de línea: " .. text)
        vim.api.nvim_buf_call(buf, function()
            vim.cmd.write()
        end)
    end
    vim.fn.writefile({ "BasedOnStyle: LLVM", "IndentWidth: 2", "BreakBeforeBraces: Allman", "AllowShortFunctionsOnASingleLine: None" }, temporary .. "/.clang-format")
    local custom = format(buffers.c)
    assert(custom:find("int main%(void%)\n{"), "No se respetó .clang-format del proyecto: " .. custom)
    vim.fn.delete(temporary .. "/.clang-format")
end)

test("Formato Python, Lua y HDL explícito", function()
    assert(format(buffers.python):find("result = twice%(3%)"))
    assert(format(buffers.systemverilog):find("assign b = a;"))
    assert(format(buffers.lua):find("\n    return 1\n", 1, true))
    assert(not require("conform").formatters_by_ft.vhdl, "Documentar el formateador VHDL si se añade")
end)

test("Commit sin parser opcional y sin atajos de proyectos", function()
    fixture("COMMIT_EDITMSG", { "Prueba de edición básica" })
    vim.bo.filetype = "gitcommit"
    assert(vim.api.nvim_get_current_line() == "Prueba de edición básica")
    assert(vim.fn.maparg("<leader>db", "n") == "")
    assert(vim.fn.maparg("<leader>rc", "n") == "")
    vim.cmd.write()
    assert(not require("config.nvim.health").issues["format:gitcommit"])
end)

test("Terminal interactiva y registro", function()
    local tasks = require("config.nvim.tasks")
    local id = tasks.run_terminal({ "sh", "-c", 'read value; printf "RECIBIDO:%s\\n" "$value"' }, temporary)
    vim.fn.chansend(id, "dotfiles\n")
    assert(vim.wait(10000, function()
        return not tasks.is_running(temporary)
    end))
    local log = table.concat(vim.fn.readfile(tasks.log_path(temporary)), "\n")
    assert(log:find("RECIBIDO:dotfiles", 1, true), log)
end)

-- DAP necesita permiso del sistema para lanzar procesos bajo un depurador.
-- Se puede comprobar un adaptador con DOTFILES_TEST_DAP=c o python.
local debug_mode = vim.env.DOTFILES_TEST_DAP
if debug_mode == "1" or debug_mode == "c" or debug_mode == "python" then
    local function debug_program(config)
        local dap = require("dap")
        local stopped, terminated = false, false
        dap.listeners.after.event_stopped.dotfiles_test = function()
            stopped = true
        end
        dap.listeners.after.event_terminated.dotfiles_test = function()
            terminated = true
        end
        local ok, err = pcall(function()
            dap.run(config)
            local ready = vim.wait(15000, function()
                local session = dap.session()
                return terminated or (stopped and session and session.stopped_thread_id and session.current_frame)
            end)
            assert(ready, "DAP no llegó al programa; revisa :DapShowLog y los permisos del sistema")
            assert(stopped and not terminated, "DAP terminó sin detenerse")
            dap.continue()
            local finished = vim.wait(10000, function()
                return terminated
            end)
            assert(finished, "DAP no terminó")
        end)
        dap.terminate()
        vim.wait(500)
        dap.listeners.after.event_stopped.dotfiles_test = nil
        dap.listeners.after.event_terminated.dotfiles_test = nil
        assert(ok, err)
    end
    if debug_mode ~= "python" then
        test("DAP C con CodeLLDB", function()
            local binary = temporary .. "/main"
            local result = vim.system({ "gcc", "-g", "-O0", temporary .. "/main.c", "-o", binary }):wait()
            assert(result.code == 0, result.stderr)
            local config = vim.deepcopy(require("dap").configurations.c[1])
            config.program, config.cwd, config.args = binary, temporary, {}
            debug_program(config)
        end)
    end
    if debug_mode ~= "c" then
        test("DAP Python con debugpy", function()
            vim.api.nvim_set_current_buf(assert(buffers.python))
            local config = vim.deepcopy(require("dap").configurations.python[1])
            config.program, config.cwd, config.stopOnEntry = temporary .. "/main.py", temporary, true
            debug_program(config)
        end)
    end
end

pcall(function()
    require("dap").terminate()
end)
for _, client in ipairs(vim.lsp.get_clients()) do
    client:stop(true)
end
vim.wait(200)
vim.cmd("silent! %bwipeout!")
vim.fn.delete(temporary, "rf")
if #failures > 0 then
    print(table.concat(failures, "\n"))
    vim.cmd("cquit 1")
end
print("Integración de Neovim terminada.")
