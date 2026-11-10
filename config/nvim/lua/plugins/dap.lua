local icons = require("config.nvim.icons")

return {
  "mfussenegger/nvim-dap",
  cmd = { "DapContinue", "DapToggleBreakpoint" },
  dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio", "mason-org/mason.nvim" },
  keys = (function()
    local keys = {
      {
        "<F5>",
        function()
          require("dap").continue()
        end,
        desc = icons.label("debug", "Iniciar / continuar depuración"),
      },
      {
        "<F9>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = icons.label("breakpoint", "Punto de interrupción"),
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = icons.label("step_over", "Siguiente línea"),
      },
      {
        "<F11>",
        function()
          require("dap").step_into()
        end,
        desc = icons.label("step_into", "Entrar a función"),
      },
      {
        "<F12>",
        function()
          require("dap").step_out()
        end,
        desc = icons.label("step_out", "Salir de función"),
      },
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = icons.label("breakpoint", "Punto de interrupción"),
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Condición: "))
        end,
        desc = icons.label("breakpoint", "Punto de interrupción condicional"),
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = icons.label("run", "Iniciar / continuar"),
      },
      {
        "<leader>dq",
        function()
          require("dap").terminate()
        end,
        desc = icons.label("stop", "Terminar depuración"),
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = icons.label("terminal", "Consola del depurador"),
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = icons.label("window", "Paneles del depurador"),
      },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "x" },
        desc = icons.label("definition", "Evaluar expresión"),
      },
    }
    for _, key in ipairs(keys) do
      key.ft = { "c", "cpp", "objc", "objcpp", "asm", "python" }
    end
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("GutsDebugKeys", { clear = true }),
      callback = function(event)
        if not vim.tbl_contains(keys[1].ft, vim.bo[event.buf].filetype) then
          for _, key in ipairs(keys) do
            pcall(vim.keymap.del, key.mode or "n", key[1], { buffer = event.buf })
          end
        end
      end,
    })
    return keys
  end)(),
  config = function()
    local dap, ui = require("dap"), require("dapui")
    ui.setup({ floating = { border = "rounded" } })
    dap.listeners.after.event_initialized.guts = function()
      ui.open()
    end
    dap.listeners.before.event_terminated.guts = function()
      ui.close()
    end
    dap.listeners.before.event_exited.guts = function()
      ui.close()
    end
    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
    dap.adapters.codelldb = function(callback)
      local executable = vim.fn.exepath("codelldb")
      if executable == "" then
        error("Falta codelldb: ejecuta :DotfilesToolsInstall")
      end
      callback({
        type = "server",
        port = "${port}",
        executable = { command = executable, args = { "--port", "${port}" } },
      })
    end
    dap.adapters.gdb = { type = "executable", command = "gdb", args = { "--interpreter=dap", "--quiet" } }
    dap.adapters.riscv_gdb = function(callback)
      local exe = vim.g.dotfiles_riscv_gdb or "gdb-multiarch"
      if vim.fn.executable(exe) == 0 then
        error("No existe " .. exe .. ". Instala GDB >= 14 con DAP y soporte RISC-V.")
      end
      callback({ type = "executable", command = exe, args = { "--interpreter=dap", "--quiet" } })
    end
    local function program()
      local name = vim.fn.input("Ejecutable / ELF: ", vim.fn.getcwd() .. "/", "file")
      if name == "" then
        return dap.ABORT
      end
      return vim.fn.fnamemodify(name, ":p")
    end
    local function local_profile()
      local root = require("config.nvim.tasks").cpp_root() or vim.fn.getcwd()
      local cpp = require("config.nvim.cpp")
      local profile = cpp.profile(root)
      assert(
        profile.target == "host",
        "Este proyecto es firmware; elige conectar a un GDB server con soporte para tu hardware"
      )
      return root, profile, cpp
    end
    local function local_program()
      local root, profile, cpp = local_profile()
      local selected = profile.program and cpp.path(root, profile.program) or program()
      if selected == dap.ABORT then
        return selected
      end
      return cpp.validate_program(selected)
    end
    local function local_args()
      local _, profile = local_profile()
      return profile.args
    end
    local function local_cwd()
      local root, profile, cpp = local_profile()
      return cpp.path(root, profile.cwd)
    end
    dap.configurations.c = {
      {
        name = "C/C++ local (CodeLLDB)",
        type = "codelldb",
        request = "launch",
        program = local_program,
        args = local_args,
        cwd = local_cwd,
        stopOnEntry = true,
      },
      {
        name = "C/C++ local (GDB >= 14)",
        type = "gdb",
        request = "launch",
        program = local_program,
        args = local_args,
        cwd = local_cwd,
        stopAtBeginningOfMainSubprogram = true,
      },
      {
        name = "RISC-V: conectar a GDB server",
        type = "riscv_gdb",
        request = "attach",
        program = program,
        target = function()
          return vim.fn.input("GDB server host:puerto: ", "localhost:3333")
        end,
      },
    }
    dap.configurations.cpp = dap.configurations.c
    dap.configurations.objc = dap.configurations.c
    dap.configurations.objcpp = dap.configurations.c
    dap.configurations.asm = dap.configurations.c
    dap.adapters.python = function(callback)
      local executable = vim.fn.exepath("debugpy-adapter")
      if executable == "" then
        error("Falta debugpy-adapter: ejecuta :DotfilesToolsInstall")
      end
      callback({ type = "executable", command = executable })
    end
    dap.configurations.python = {
      {
        name = "Python: archivo actual",
        type = "python",
        request = "launch",
        program = "${file}",
        cwd = function()
          return require("config.nvim.python").root()
        end,
        pythonPath = function()
          return require("config.nvim.python").interpreter()
        end,
        console = "integratedTerminal",
        justMyCode = true,
      },
    }
    -- No inicia OpenOCD/QEMU ni programa la FPGA automáticamente.
  end,
}
