#!/usr/bin/env bash

# ============================================================
# Nerd Font Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala:
#
#   Iosevka Nerd Font
#
# en:
#
#   ${XDG_DATA_HOME:-~/.local/share}/fonts/IosevkaNerdFont
#
# La versión se define en:
#
#   setup/versions.sh
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Dependencies
# ============================================================

require_command unzip
require_command fc-cache


# ============================================================
# Paths
# ============================================================

font_root="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
font_dir="$font_root/IosevkaNerdFont"

version_file="$font_dir/.version"


# ============================================================
# Already Installed
# ============================================================

if [[ -f "$version_file" ]] &&
   version_ge "$(cat "$version_file")" "$NERD_FONT_VERSION" &&
   [[ -n "$(find "$font_dir" -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit)" ]]; then

    log "Iosevka Nerd Font $(cat "$version_file") ya está instalada."
    exit 0

fi


# ============================================================
# Temporary Directory
# ============================================================

work="$(mktemp -d)"

trap 'rm -rf -- "$work"' EXIT

archive="$work/Iosevka.zip"
extract_dir="$work/IosevkaNerdFont"

mkdir -p "$extract_dir"


# ============================================================
# Download
# ============================================================

log "Descargando Iosevka Nerd Font $NERD_FONT_VERSION..."

download \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/Iosevka.zip" \
    "$archive"


# ============================================================
# Extract
# ============================================================

log "Extrayendo fuente..."

unzip -q \
    "$archive" \
    -d "$extract_dir"

[[ -n "$(find "$extract_dir" -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit)" ]] ||
    die "El paquete descargado no contiene fuentes; se conserva la instalación anterior."


# ============================================================
# Install
# ============================================================

mkdir -p "$font_root"

# El directorio está completamente gestionado por estos
# dotfiles, por lo que una actualización reemplaza la versión
# anterior en lugar de mezclar archivos de ambas versiones.

rm -rf -- "$font_dir"

mv \
    "$extract_dir" \
    "$font_dir"


# ============================================================
# Version Marker
# ============================================================

printf '%s\n' \
    "$NERD_FONT_VERSION" \
    > "$version_file"


# ============================================================
# Font Cache
# ============================================================

log "Actualizando caché de fuentes..."

fc-cache -f "$font_dir"


# ============================================================
# Done
# ============================================================

log "Iosevka Nerd Font $NERD_FONT_VERSION instalada."
