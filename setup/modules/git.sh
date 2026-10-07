#!/usr/bin/env bash

# ============================================================
# Git Configuration
# ============================================================
#
# GUTS Dotfiles
#
# Instala y configura:
#
#   - Git
#   - GitHub CLI
#
# La configuración aplicada afecta únicamente al comportamiento
# general de Git.
#
# No modifica:
#
#   - user.name
#   - user.email
#   - credenciales
#   - autenticación de GitHub CLI
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Installation
# ============================================================

apt_install \
    git \
    gh


# ============================================================
# Git Configuration
# ============================================================

log "Configurando Git..."


# ------------------------------------------------------------
# Push
# ------------------------------------------------------------

# Al hacer push por primera vez en una rama nueva:
#
#   git push
#
# configura automáticamente su upstream.

command git config --global \
    push.autoSetupRemote true


# ------------------------------------------------------------
# Fetch
# ------------------------------------------------------------

# Elimina referencias locales a ramas remotas que ya no existen.

command git config --global \
    fetch.prune true


# ------------------------------------------------------------
# Pull
# ------------------------------------------------------------

# Mantiene un historial lineal al actualizar una rama.

command git config --global \
    pull.rebase true


# ------------------------------------------------------------
# Conflict Resolution
# ------------------------------------------------------------

# Recuerda resoluciones de conflictos anteriores y puede
# reutilizarlas cuando aparece el mismo conflicto.

command git config --global \
    rerere.enabled true


# ------------------------------------------------------------
# Interface
# ------------------------------------------------------------

command git config --global \
    color.ui auto

command git config --global \
    column.ui auto


# ------------------------------------------------------------
# Sorting
# ------------------------------------------------------------

# Ramas ordenadas por último commit, más recientes primero.

command git config --global \
    branch.sort -committerdate


# Tags ordenados como versiones.

command git config --global \
    tag.sort version:refname


# ============================================================
# Done
# ============================================================

log "Git configurado."
log "Identidad, credenciales y autenticación permanecen sin cambios."
