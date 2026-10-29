#!/usr/bin/env bash
set -Eeuo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

[[ $# == 0 || ( $# == 1 && $1 == --nvim ) ]] || {
    printf 'Uso: dotfiles check [--nvim]\n' >&2
    exit 1
}

mapfile -d '' bash_files < <(find "$repo/bin" "$repo/lib" "$repo/setup" "$repo/tests" \
    -type f \( -name '*.sh' -o -name dotfiles \) -print0)
for file in "${bash_files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null; then
    shellcheck -S warning -e SC1091 "${bash_files[@]}"
else
    printf 'ShellCheck no está instalado; se omite ese análisis.\n'
fi

bash "$repo/tests/state.sh"
bash "$repo/tests/cli.sh"
bash "$repo/tests/gnome.sh"
bash "$repo/tests/links.sh"
python3 "$repo/tests/install.py"

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
            for _, file in ipairs(vim.fn.glob(root .. "/tests/*.lua", false, true)) do
                assert(loadfile(file))
            end
        end)
        if not ok then print(err); vim.cmd("cquit 1") end
    ' +qa
    DOTFILES_TEST_ROOT="$repo" nvim --clean --headless -l "$repo/tests/tools.lua"
    python3 "$repo/tests/nvim.py"
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
    DOTFILES_NVIM_READONLY=1 DOTFILES_TEST_ROOT="$repo" nvim --headless -c 'lua
        local ok, err = pcall(dofile, vim.env.DOTFILES_TEST_ROOT .. "/tests/nvim-runtime.lua")
        if not ok then print(err); vim.cmd("cquit 1") end
    ' +qa!
fi
printf 'Comprobaciones terminadas.\n'
