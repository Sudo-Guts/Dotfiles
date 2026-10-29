#!/usr/bin/env bash

# ============================================================
# Common Dependencies
# ============================================================
#
# GUTS Dotfiles
#
# Instala las dependencias base utilizadas por:
#
#   - Bootstrap
#   - Git / GitHub CLI
#   - Zsh
#   - Kitty
#   - Neovim
#   - Herramientas HDL
#   - Scripts de diagnóstico
#
# No realiza:
#
#   - apt upgrade
#   - cambios de zona horaria
#   - configuraciones de escritorio
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# Los paquetes comunes se declaran en setup/modules.conf.
log "Instalando dependencias comunes..."
apt_install_module base


# ============================================================
# Local Bin
# ============================================================

mkdir -p "$HOME/.local/bin"


# ============================================================
# fd Compatibility
# ============================================================

# Debian/Ubuntu instala fd como:
#
#   fdfind
#
# Algunos programas esperan encontrar:
#
#   fd
#
# Crear un enlace compatible únicamente cuando sea necesario.

if ! command -v fd >/dev/null 2>&1 &&
   command -v fdfind >/dev/null 2>&1; then

    ln -sfnT \
        "$(command -v fdfind)" \
        "$HOME/.local/bin/fd"

    log "Compatibilidad creada: fd → $(command -v fdfind)"

fi


# ============================================================
# Done
# ============================================================

log "Dependencias comunes listas."
