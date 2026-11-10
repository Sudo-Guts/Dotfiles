local M = {}
function M.setup()
    local ls = require("luasnip")
    local s, t, i = ls.snippet, ls.text_node, ls.insert_node
    local configured = false
    local function hdl_snippets()
        if not configured then
            configured = true
            require("config.hdl.verilog").setup_snippets()
        end
    end
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("GutsHdlSnippets", { clear = true }),
        pattern = { "verilog", "systemverilog" },
        callback = hdl_snippets,
    })
    if vim.bo.filetype == "verilog" or vim.bo.filetype == "systemverilog" then
        hdl_snippets()
    end
    ls.add_snippets("c", {
        s("mainbare", {
            t({ "#include <stdint.h>", "", "int main(void) {", "    " }),
            i(0),
            t({ "", "    for (;;) {}", "}" }),
        }),
    })
end
return M
