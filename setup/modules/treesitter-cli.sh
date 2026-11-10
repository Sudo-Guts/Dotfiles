#!/usr/bin/env bash

# ============================================================
# Tree-sitter CLI Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala Tree-sitter CLI desde las releases oficiales.
#
# Soporta:
#
#   - Linux x86_64
#   - Linux arm64
#
# La versión objetivo y la versión mínima se definen en:
#
#   setup/versions.sh
#
# El binario se instala en:
#
#   ~/.local/bin/tree-sitter
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Current Version
# ============================================================

current="$(
    tree-sitter --version 2>/dev/null |
        awk '{print $2}' ||
        true
)"


# ============================================================
# Already Installed
# ============================================================

if [[ -n "$current" ]] &&
   binary_satisfies "$current" "$TREE_SITTER_MIN_VERSION" "$TREE_SITTER_VERSION"; then

    log "Tree-sitter CLI $current ya satisface el mínimo requerido."
    exit 0

fi


# ============================================================
# Architecture
# ============================================================

case "$(uname -m)" in

    x86_64)
        arch="x64"
        ;;

    aarch64|arm64)
        arch="arm64"
        ;;

    *)
        die "Arquitectura Tree-sitter no soportada: $(uname -m)"
        ;;

esac


# ============================================================
# Temporary Workspace
# ============================================================

work="$(mktemp -d)"

trap 'rm -rf -- "$work"' EXIT

archive="$work/tree-sitter.zip"
extract_dir="$work/tree-sitter"

mkdir -p "$extract_dir"


# ============================================================
# Download
# ============================================================

log "Descargando Tree-sitter CLI $TREE_SITTER_VERSION..."

download \
    "https://github.com/tree-sitter/tree-sitter/releases/download/$TREE_SITTER_VERSION/tree-sitter-cli-linux-$arch.zip" \
    "$archive"


# ============================================================
# Extract
# ============================================================

unzip -q \
    "$archive" \
    -d "$extract_dir"


# ============================================================
# Locate Binary
# ============================================================

binary="$(
    find "$extract_dir" \
        -type f \
        -name tree-sitter \
        -print \
        -quit
)"

[[ -n "$binary" ]] ||
    die "El paquete descargado no contiene el binario tree-sitter."

chmod 0755 "$binary"
downloaded="$("$binary" --version | awk '{print $2}')"
[[ "$downloaded" == "${TREE_SITTER_VERSION#v}" ]] || die "Versión inesperada de Tree-sitter: $downloaded."
version_ge "$downloaded" "$TREE_SITTER_MIN_VERSION" || die "La versión solicitada de Tree-sitter no cumple el mínimo."


# ============================================================
# Install
# ============================================================

mkdir -p "$HOME/.local/bin"

install \
    -m 0755 \
    "$binary" \
    "$HOME/.local/bin/tree-sitter"


# ============================================================
# Verification
# ============================================================

installed="$(
    "$HOME/.local/bin/tree-sitter" --version |
        awk '{print $2}'
)"

version_ge "$installed" "$TREE_SITTER_MIN_VERSION" ||
    die "Tree-sitter instalado ($installed) no satisface >= $TREE_SITTER_MIN_VERSION."


# ============================================================
# Done
# ============================================================

log "Tree-sitter CLI $installed instalada."
