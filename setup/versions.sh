#!/usr/bin/env bash

# ============================================================
# Managed Versions
# ============================================================
#
# GUTS Dotfiles
#
# Versiones utilizadas por los instaladores de setup/modules/.
#
# Los plugins de Neovim se fijan por separado mediante:
#
#   config/nvim/lazy-lock.json
#
# Las herramientas administradas por Mason se definen en:
#
#   config/nvim/lua/config/nvim/tools.lua
#
# ============================================================

# shellcheck disable=SC2034


# ============================================================
# Neovim
# ============================================================

NVIM_VERSION="${NVIM_VERSION:-v0.12.5}"
NVIM_MIN_VERSION="0.12.0"


# ============================================================
# Kitty
# ============================================================

KITTY_VERSION="${KITTY_VERSION:-0.49.1}"
KITTY_MIN_VERSION="0.49.1"


# ============================================================
# Tree-sitter CLI
# ============================================================

TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-v0.27.0}"
TREE_SITTER_MIN_VERSION="0.26.1"


# ============================================================
# Nerd Fonts
# ============================================================

NERD_FONT_VERSION="${NERD_FONT_VERSION:-v3.4.0}"
