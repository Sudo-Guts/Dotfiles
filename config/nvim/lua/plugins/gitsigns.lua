return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    current_line_blame = false,
    on_attach = function(buf)
      local gs = require("gitsigns")
      local function map(key, action, desc, mode)
        vim.keymap.set(mode or "n", key, action, { buffer = buf, desc = desc })
      end
      map("]c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next")
        end
      end, "Cambio siguiente")
      map("[c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev")
        end
      end, "Cambio anterior")
      map("<leader>hs", gs.stage_hunk, "Stage hunk")
      map("<leader>hr", gs.reset_hunk, "Restaurar hunk")
      map("<leader>hp", gs.preview_hunk, "Ver hunk")
      map("<leader>hb", gs.blame_line, "Autor de línea")
      map("<leader>hB", gs.toggle_current_line_blame, "Alternar blame")
      map("<leader>hd", gs.diffthis, "Diff del archivo")
      map("<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage selección", "x")
      map("<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Restaurar selección", "x")
    end,
  },
}
