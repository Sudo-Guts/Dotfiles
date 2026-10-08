#!/usr/bin/env bash

# ============================================================
# Neovim Development Tools
# ============================================================
#
# GUTS Dotfiles
#
# Este script:
#
#   - Restaura los plugins fijados en lazy-lock.json
#   - Instala herramientas administradas por Mason
#   - Instala parsers de Treesitter
#
# No actualiza deliberadamente los plugins.
#
# Para actualizar plugins utiliza:
#
#   :Lazy update
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Dependencies
# ============================================================

require_command nvim
require_command tree-sitter

# Tree-sitter 0.27 deja un bloqueo vacío si su proceso se interrumpe. Cada
# Neovim de preparación usa su propia caché para evitar bloqueos y descargas
# compartidas con otros editores. XDG_DATA_HOME conserva plugins y parsers.
cache_home="$(mktemp -d -- "${TMPDIR:-/tmp}/dotfiles-nvim-cache.XXXXXX")"
trap 'rm -rf -- "$cache_home"' EXIT
cache_home="$(realpath -e -- "$cache_home")"


# ============================================================
# Restore Neovim Plugins
# ============================================================

# Lazy restore respeta exactamente los commits registrados
# en lazy-lock.json.
#
# Restaurar y actualizar son operaciones distintas:
#
#   restore → reproduce el entorno conocido
#   update  → busca versiones nuevas

log "Restaurando plugins de Neovim..."

XDG_CACHE_HOME="$cache_home/restore" nvim \
    --headless \
    "+Lazy! restore" \
    "+qa"


# ============================================================
# Install Development Tools
# ============================================================

# setup/nvim-tools.lua se encarga de:
#
#   - Verificar el estado de Lazy
#   - Instalar herramientas Mason faltantes y reconciliar versiones en update
#   - Instalar parsers de Treesitter
#   - Verificar que las herramientas esperadas estén disponibles

log "Instalando herramientas de desarrollo de Neovim..."

XDG_CACHE_HOME="$cache_home/tools" \
    DOTFILES_TOOLS_SCRIPT="$DOTFILES_ROOT/setup/nvim-tools.lua" \
    DOTFILES_NVIM_CHECK_SCRIPT="$DOTFILES_ROOT/setup/nvim-doctor.lua" \
    nvim \
        --headless \
        -c '
            lua local ok, err = pcall(
                dofile,
                vim.env.DOTFILES_TOOLS_SCRIPT
            )

            if not ok then
                print(err)
                vim.cmd("cquit 1")
            end
        ' \
        "+qa"


# ============================================================
# Done
# ============================================================

log "Herramientas de Neovim listas."
