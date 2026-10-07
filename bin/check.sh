#!/usr/bin/env bash
set -Eeuo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

[[ $# == 0 || ( $# == 1 && $1 == --nvim ) ]] || {
    printf 'Uso: dotfiles check [--nvim]\n' >&2
    exit 1
}

mapfile -d '' bash_files < <(find "$repo/bin" "$repo/lib" "$repo/setup" \
    -type f \( -name '*.sh' -o -name dotfiles \) -print0)
for file in "${bash_files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null; then
    shellcheck -S warning -e SC1091 "${bash_files[@]}"
else
    printf 'ShellCheck no está instalado; se omite ese análisis.\n'
fi

if command -v zsh >/dev/null; then
    while IFS= read -r -d '' file; do zsh -n "$file"; done \
        < <(find "$repo/config/zsh" -type f \( -name '*.zsh' -o -name .zshrc \) -print0)
else
    printf 'Zsh no está instalado; se omite su comprobación de sintaxis.\n'
fi

if command -v nvim >/dev/null; then
    DOTFILES_CHECK_ROOT="$repo" nvim --clean --headless -c 'lua
        local ok, err = pcall(function()
            local root = vim.env.DOTFILES_CHECK_ROOT
            for _, file in ipairs(vim.fn.glob(root .. "/config/nvim/**/*.lua", false, true)) do
                assert(loadfile(file))
            end
            for _, file in ipairs(vim.fn.glob(root .. "/setup/*.lua", false, true)) do
                assert(loadfile(file))
            end
        end)
        if not ok then print(err); vim.cmd("cquit 1") end
    ' +qa
else
    printf 'Neovim no está instalado; se omite la comprobación de sintaxis Lua.\n'
fi

if [[ "${1:-}" == --nvim ]]; then
    command -v nvim >/dev/null || { printf 'Falta Neovim.\n' >&2; exit 1; }
    config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    [[ "$(realpath -e -- "$config")" == "$repo/config/nvim" ]] || {
        printf 'Ejecuta dotfiles link antes de comprobar la carga de Neovim.\n' >&2
        exit 1
    }
    DOTFILES_NVIM_READONLY=1 nvim --headless -c 'lua
        local ok, err = pcall(function()
            assert(package.loaded.lazy, "No se cargó la configuración GUTS")
            local plugins = {}
            for name in pairs(require("lazy.core.config").plugins) do
                plugins[#plugins + 1] = name
            end
            require("lazy").load({ plugins = plugins })
            vim.wait(200)
            assert(vim.g.mapleader == " ")
            assert(vim.fn.maparg("<C-v>", "n") == "")
            assert(vim.fn.maparg("<leader>ff", "n") ~= "")
            assert(vim.fn.maparg("gd", "n") ~= "")
            assert(#require("dap").configurations.c == 3)
            assert(require("dap").configurations.python[1].type == "python")
            assert(vim.lsp.config.pyright.settings.python.analysis.typeCheckingMode == "basic")
            assert(vim.lsp.config.ruff.cmd[1] == "ruff")
            assert(require("cmp").get_config().sources[1].name == "nvim_lsp")
            for _, ft in ipairs({ "c", "cpp", "verilog", "systemverilog", "vhdl", "lua", "markdown", "python" }) do
                vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
                vim.bo.filetype = ft
                local cpp = ft == "c" or ft == "cpp"
                local hdl = ft == "verilog" or ft == "systemverilog" or ft == "vhdl"
                for _, key in ipairs({ "rp", "rg", "rc", "rt", "rl", "rx", "rm" }) do
                    assert((vim.fn.maparg("<leader>" .. key, "n") ~= "") == (cpp or hdl), "Atajo incorrecto: " .. ft .. " " .. key)
                end
                for _, key in ipairs({ "rn", "rs", "rw" }) do
                    assert((vim.fn.maparg("<leader>" .. key, "n") ~= "") == hdl, "Atajo HDL en " .. ft .. ": " .. key)
                end
                assert((vim.fn.maparg("<leader>re", "n") ~= "") == cpp, "Atajo de ejecución incorrecto: " .. ft)
                assert((vim.fn.maparg("<leader>db", "n") ~= "") == (cpp or ft == "python"), "Atajo de depuración incorrecto: " .. ft)
                local parser = vim.treesitter.get_parser(0)
                assert(parser and parser:parse()[1], "Parser faltante: " .. ft)
            end
            assert(vim.v.errmsg == "", vim.v.errmsg)
        end)
        if not ok then print(err); vim.cmd("cquit 1") end
    ' +qa
fi
printf 'Comprobaciones terminadas.\n'
