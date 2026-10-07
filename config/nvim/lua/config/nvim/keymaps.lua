local icons = require("config.nvim.icons")

local map = vim.keymap.set

map({ "n", "i", "v" }, "<C-s>", "<Cmd>write<CR><Esc>", { desc = icons.label("save", "Guardar archivo") })

map("n", "<leader>w", "<Cmd>write<CR>", { desc = icons.label("save", "Guardar") })

map("n", "<leader>q", "<Cmd>confirm quit<CR>", { desc = icons.label("close", "Cerrar ventana") })
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = icons.label("format", "Limpiar búsqueda") })
map("n", "<C-a>", "ggVG", { desc = icons.label("select_all", "Seleccionar todo") })
map("n", "<C-z>", "u", { desc = icons.label("undo", "Deshacer") })
map("i", "<C-z>", "<C-o>u", { desc = icons.label("undo", "Deshacer") })
map("n", "<C-y>", "<C-r>", { desc = icons.label("redo", "Rehacer") })
map("x", "<leader>y", '"+y', { desc = icons.label("copy", "Copiar al portapapeles") })
map("x", "<leader>X", '"+d', { desc = icons.label("cut", "Cortar al portapapeles") })
map({ "n", "x" }, "<leader>p", '"+p', { desc = icons.label("copy", "Pegar del portapapeles") })
map("x", "<C-c>", '"+y', { desc = icons.label("copy", "Copiar al portapapeles") })
map("x", "<C-x>", '"+d', { desc = icons.label("cut", "Cortar al portapapeles") })
for key, direction in pairs({ h = "h", j = "j", k = "k", l = "l" }) do
  map("n", "<C-" .. key .. ">", "<C-w>" .. direction, { desc = "Mover a ventana " .. direction })
end
map("n", "<leader>,", "<C-w>h", { desc = icons.label("left", "Ventana izquierda") })
map("n", "<leader>.", "<C-w>l", { desc = icons.label("right", "Ventana derecha") })
map("n", "<leader>bd", "<Cmd>bdelete<CR>", { desc = icons.label("close", "Cerrar buffer") })
map("n", "<leader>bn", "<Cmd>enew<CR>", { desc = icons.label("file", "Nuevo buffer") })

map("n", "<leader>tt", function()
  require("config.nvim.tasks").terminal()
end, { desc = icons.label("terminal", "Terminal") })

map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Modo normal en terminal" })

map("n", "gd", function()
  require("config.nvim.lsp").definition()
end, { desc = icons.label("definition", "Ir a definición (LSP)") })
map("n", "<leader>ci", "<Cmd>checkhealth vim.lsp<CR>", { desc = icons.label("diagnostics", "Estado LSP") })
require("config.nvim.project").setup_keymaps()
