local group = vim.api.nvim_create_augroup("GutsEditing", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.hl.on_yank({ timeout = 180 })
  end,
})
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "lua", "json", "yaml" },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "make",
  callback = function()
    vim.bo.expandtab = false
  end,
})
vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
  end,
})

-- ============================================================
-- Kitty keyboard protocol workaround
-- ============================================================

-- Neovim 0.12 habilita eventos press/repeat/release del protocolo
-- Kitty. En algunos entornos esto provoca que Tab, Backspace y
-- Enter se procesen dos veces.
--
-- Conservamos la desambiguación de teclas, pero desactivamos
-- los eventos de release/repeat.

if vim.env.TERM == "xterm-kitty" then
  vim.schedule(function()
    vim.api.nvim_ui_send("\27[=1u")
  end)
end
