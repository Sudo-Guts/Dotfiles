local keymap = vim.keymap
local opts = { noremap = true, silent = true }
local builtin = require('telescope.builtin')

-- Select all
    keymap.set( 'n', '<C-a>', 'gg<S-v>G')
    
-- Save and exit
    keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
    keymap.set( 'n' , '<space>s' , ':x!<CR>' , opts )
    
-- Scroll
    keymap.set( 'n' , '<space>,' , '<C-w>h' , {} )
    keymap.set( 'n' , '<space>.' , '<C-w>l' , {} )
    
-- Deshacer (Ctrl + Z)
    keymap.set('n', "<C-z>", "u", { desc = "Deshacer" })
    keymap.set('i', "<C-z>", "<Cmd>undo<CR>", { desc = "Deshacer" })
    
-- Rehacer (Ctrl + Y)
    keymap.set('n', "<C-y>", "<C-r>", { desc = "Rehacer" })
    keymap.set('i', "<C-y>", "<Cmd>redo<CR>", { desc = "Rehacer" })
    
-- Copiar (Ctrl + C) en modo Visual
    keymap.set('v', "<C-c>", '"+y', { desc = "Copiar al portapapeles" })
    
-- Cortar (Ctrl + X) en modo Visual
    keymap.set('v', "<C-x>", '"+d', { desc = "Cortar al portapapeles" })
    
-- Pegar (Ctrl + V)
    keymap.set('n', "<C-v>", '"+p', { desc = "Pegar desde portapapeles" })
    keymap.set('v', "<C-v>", '"+p', { desc = "Pegar desde portapapeles" })
    keymap.set('i', "<C-v>", "<C-r>+", { desc = "Pegar desde portapapeles" })
    
-- /~~~>[ Neo-Tree ]<----------------------------\

    keymap.set( 'n' , '<space>t' , ':Neotree<CR>' , opts )
    
-- /~~~>[ Telescope ]<---------------------------\ 

    keymap.set( 'n', '<space>f' , builtin.find_files , {} )
    keymap.set( 'n', '<space>g' , builtin.live_grep , {} )
    keymap.set( 'n', '<space>b' , builtin.buffers , {} )
    keymap.set( 'n', '<space>h' , builtin.help_tags , {} )
    
-- /~~~>[ Bufferline ]<--------------------------\

    keymap.set( 'n' , '<tab>,' , ':tabprev<Return>' , opts )
    keymap.set( 'n' , '<tab>.' , ':tabnext<Return>' , opts )


