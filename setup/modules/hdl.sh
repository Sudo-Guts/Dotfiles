#!/usr/bin/env bash

# ============================================================
# HDL Development Tools
# ============================================================
#
# GUTS Dotfiles
#
# Instala simuladores y herramientas HDL disponibles mediante APT:
#
#   - GHDL
#   - GTKWave
#   - Icarus Verilog
#
# Verible y VHDL LS se administran desde Mason en Neovim.
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Installation
# ============================================================

log "Instalando herramientas HDL..."

apt_install \
    ghdl \
    gtkwave \
    iverilog


# ============================================================
# Done
# ============================================================

log "Herramientas HDL listas."
log "Verible y VHDL LS se administran mediante Mason."
