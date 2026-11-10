#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

require_command nvim
require_command tree-sitter

# Tree-sitter puede dejar bloqueos tras una interrupción. Cada proceso usa una
# caché temporal propia; plugins, herramientas y parsers conservan sus datos.
cache_home="$(mktemp -d -- "${TMPDIR:-/tmp}/dotfiles-nvim-cache.XXXXXX")"
trap 'rm -rf -- "$cache_home"' EXIT
cache_home="$(realpath -e -- "$cache_home")"

# Una comprobación local evita restaurar o descargar componentes ya preparados.
# El marcador permite conservar los plugins si solo faltan herramientas/parsers.
if XDG_CACHE_HOME="$cache_home/check" DOTFILES_NVIM_READONLY=1 DOTFILES_NVIM_CHECK_SCRIPT="$DOTFILES_ROOT/setup/nvim-doctor.lua" DOTFILES_NVIM_PLUGINS_READY="$cache_home/plugins-ready" nvim --headless -c 'lua
    local ok, err = pcall(function()
        local checks = dofile(vim.env.DOTFILES_NVIM_CHECK_SCRIPT)
        checks.plugins()
        assert(vim.fn.writefile({ "ready" }, vim.env.DOTFILES_NVIM_PLUGINS_READY) == 0)
        checks.check()
    end)
    if not ok then print(err); vim.cmd("cquit 1") end
' +qa > "$cache_home/check.log" 2>&1; then
    log "Neovim: núcleo completo; se conserva la instalación actual."
    exit 0
fi

# restore reproduce el lockfile; no busca versiones nuevas de plugins.
if [[ ! -f "$cache_home/plugins-ready" ]]; then
    log "Restaurando plugins de Neovim..."
    cp -- "$DOTFILES_ROOT/config/nvim/lazy-lock.json" "$cache_home/lazy-lock.json"
    XDG_CACHE_HOME="$cache_home/restore" DOTFILES_NVIM_INSTALL=1 DOTFILES_NVIM_LOCKFILE="$cache_home/lazy-lock.json" DOTFILES_NVIM_CHECK_SCRIPT="$DOTFILES_ROOT/setup/nvim-doctor.lua" nvim --headless -c 'lua
        local ok, err = pcall(function()
            local checks = dofile(vim.env.DOTFILES_NVIM_CHECK_SCRIPT)
            checks.locked()
            require("lazy").install({ wait = true, lockfile = true })
            if not pcall(checks.plugins) then require("lazy").restore({ wait = true }) end
            checks.plugins()
        end)
        if not ok then print(err); vim.cmd("cquit 1") end
    ' +qa
fi

log "Preparando herramientas de Neovim para los módulos seleccionados..."
XDG_CACHE_HOME="$cache_home/tools" DOTFILES_TOOLS_SCRIPT="$DOTFILES_ROOT/setup/nvim-tools.lua" DOTFILES_NVIM_CHECK_SCRIPT="$DOTFILES_ROOT/setup/nvim-doctor.lua" nvim --headless -c 'lua
    local ok, err = pcall(dofile, vim.env.DOTFILES_TOOLS_SCRIPT)
    if not ok then print(err); vim.cmd("cquit 1") end
' +qa
log "Herramientas de Neovim listas."
