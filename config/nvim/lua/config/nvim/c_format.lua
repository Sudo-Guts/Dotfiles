local M = {}

-- Clang alinea break con las instrucciones; el estilo GUTS lo alinea con case.
-- Usar el árbol de sintaxis evita modificar cadenas, comentarios o bucles.
local function case_breaks(lines, language)
    local source = table.concat(lines, "\n")
    local parser = vim.treesitter.get_string_parser(source, language)
    local tree = assert(parser:parse()[1], "No se obtuvo un árbol de sintaxis para " .. language)
    local query = vim.treesitter.query.parse(
        language,
        [[
    (comment) @comment
    (break_statement) @break
  ]]
    )
    local result, disabled = vim.list_extend({}, lines), false
    for id, node in query:iter_captures(tree:root(), source) do
        if query.captures[id] == "comment" then
            local text = vim.treesitter.get_node_text(node, source)
            local directive = text:match("^//%s*clang%-format%s+(%a+)") or text:match("^/%*%s*clang%-format%s+(%a+)")
            if directive == "off" then
                disabled = true
            elseif directive == "on" then
                disabled = false
            end
        elseif not disabled then
            local statement, parent = node, node:parent()
            -- Un #if puede envolver el break sin introducir un ámbito de C/C++.
            while parent and parent:type():match("^preproc_") do
                statement, parent = parent, parent:parent()
            end
            -- Algunos parsers sitúan el #if como hermano del case anterior.
            if parent and parent:type() == "compound_statement" and parent:parent() and parent:parent():type() == "switch_statement" then
                local previous = statement:prev_named_sibling()
                while previous and previous:type() ~= "case_statement" do
                    previous = previous:prev_named_sibling()
                end
                parent = previous
            end
            if parent and parent:type() == "case_statement" then
                local row, column = node:start()
                local case_row = parent:start()
                local line = lines[row + 1]
                if line:sub(1, column):match("^%s*$") then
                    local indent = lines[case_row + 1]:match("^%s*")
                    result[row + 1] = indent .. line:sub(column + 1)
                end
            end
        end
    end
    return result
end

function M.case_breaks(lines, language)
    local ok, result = pcall(case_breaks, lines, language)
    if not ok then
        require("config.nvim.health").report("c-format", "No se pudo alinear break con case; se conserva el resultado de clang-format: " .. tostring(result))
        return lines
    end
    require("config.nvim.health").issues["c-format"] = nil
    return result
end

return M
