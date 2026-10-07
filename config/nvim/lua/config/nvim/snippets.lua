local M = {}
function M.setup()
  local ls = require("luasnip")
  local s, t, i = ls.snippet, ls.text_node, ls.insert_node
  require("config.hdl.verilog").setup_snippets()
  ls.add_snippets("c", {
    s("mainbare", {
      t({ "#include <stdint.h>", "", "int main(void) {", "    " }),
      i(0),
      t({ "", "    for (;;) {}", "}" }),
    }),
  })
end
return M
