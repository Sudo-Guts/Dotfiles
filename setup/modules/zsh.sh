#!/usr/bin/env bash

# ============================================================
# Zsh Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala y configura las dependencias de Zsh:
#
#   - Zsh
#   - fzf
#   - Oh My Zsh
#   - zsh-autosuggestions
#   - zsh-history-substring-search
#   - zsh-syntax-highlighting
#
# El archivo ~/.zshrc NO se modifica aquí.
# dotfiles link administra el enlace simbólico correspondiente.
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Dependencies
# ============================================================

apt_install \
    zsh \
    fzf \
    git


# ============================================================
# Oh My Zsh
# ============================================================

zsh_root="${ZSH:-$HOME/.oh-my-zsh}"

log "Instalando/comprobando Oh My Zsh..."

sync_repo \
    "https://github.com/ohmyzsh/ohmyzsh.git" \
    "$zsh_root"


# ============================================================
# Plugins
# ============================================================

plugin_root="${ZSH_CUSTOM:-$zsh_root/custom}/plugins"

mkdir -p "$plugin_root"

plugins=(
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
)

for plugin in "${plugins[@]}"; do

    log "Instalando/comprobando plugin: $plugin"

    sync_repo \
        "https://github.com/zsh-users/$plugin.git" \
        "$plugin_root/$plugin"

done


# ============================================================
# Done
# ============================================================

log "Zsh listo."
log "fzf se administra mediante APT."
log "dotfiles link administra ~/.zshrc."
