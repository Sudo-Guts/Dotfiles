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
# Serie
# ============================================================

SERIE_VERSION="${SERIE_VERSION:-v0.10.1}"
SERIE_MIN_VERSION="0.10.1"

# Binarios Linux musl de la release oficial. Si cambia la versión,
# actualizar también la suma SHA-256 de cada arquitectura.
SERIE_SHA256_X86_64="${SERIE_SHA256_X86_64:-8016af97a51cee5e17942b91eb05b92378ba39af1b7ae9902767fdb6938d017f}"
SERIE_SHA256_AARCH64="${SERIE_SHA256_AARCH64:-e2e47038e176ddb3d5b0f353d0c7febc4c6fc761d387d39af04d84da623577cc}"


# ============================================================
# Tree-sitter CLI
# ============================================================

TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-v0.27.0}"
TREE_SITTER_MIN_VERSION="0.26.1"


# ============================================================
# Nerd Fonts
# ============================================================

NERD_FONT_VERSION="${NERD_FONT_VERSION:-v3.4.0}"
