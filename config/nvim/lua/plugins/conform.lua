local icons = require("config.nvim.icons")
local manual_hdl = { verilog = true, systemverilog = true }

local function project_config(ctx, names)
  return vim.fs.find(names, { path = vim.fs.dirname(ctx.filename), upward = true })[1]
end

return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = { "ConformInfo", "FormatToggle" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "x" },
      desc = icons.label("format", "Formatear"),
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      c = { "clang-format" },
      cpp = { "clang-format" },
      python = { "ruff_format" },
      verilog = { "verible" },
      systemverilog = { "verible" },
      sh = { "shfmt" },
      bash = { "shfmt" },
    },
    formatters = {
      ["clang-format"] = {
        prepend_args = function(_, ctx)
          -- Clang busca la configuración más cercana; el estilo GUTS es el respaldo.
          if project_config(ctx, { ".clang-format", "_clang-format" }) then
            return { "--style=file" }
          end
          return { "--style=file:" .. vim.fn.stdpath("config") .. "/.clang-format" }
        end,
      },
      verible = {
        prepend_args = function(_, ctx)
          local args = { "--indentation_spaces=4", "--column_limit=111" }
          local config = project_config(ctx, ".rules.verible_format")
          if config then
            -- El archivo del proyecto puede sustituir los valores predeterminados.
            args[#args + 1] = "--flagfile=" .. config
          end
          return args
        end,
      },
    },
    default_format_opts = { lsp_format = "fallback" },
    format_on_save = function(buf)
      -- Conservar la disposición escrita a mano; Espacio cf sigue siendo explícito.
      if manual_hdl[vim.bo[buf].filetype] then
        return
      end
      if not vim.g.dotfiles_format_on_save or vim.b[buf].disable_autoformat then
        return
      end
      local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
      if stat and stat.size > 1024 * 1024 then
        return
      end
      return { timeout_ms = 2000, lsp_format = "fallback" }
    end,
  },
  config = function(_, opts)
    require("conform").setup(opts)
    vim.api.nvim_create_user_command("FormatToggle", function()
      vim.g.dotfiles_format_on_save = not vim.g.dotfiles_format_on_save
      local message = "Formato al guardar: " .. tostring(vim.g.dotfiles_format_on_save)
      if manual_hdl[vim.bo.filetype] then
        message = message .. "; Verilog/SV se formatea manualmente con Espacio cf"
      end
      vim.notify(message)
    end, {})
  end,
}
