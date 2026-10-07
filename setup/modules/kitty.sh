#!/usr/bin/env bash

# ============================================================
# Kitty Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala Kitty mediante el instalador oficial.
#
# Ubicación:
#
#   ~/.local/kitty.app
#
# Binarios expuestos en:
#
#   ~/.local/bin/kitty
#   ~/.local/bin/kitten
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
# Versions
# ============================================================

current="$(
    kitty --version 2>/dev/null |
        awk '{print $2}' ||
        true
)"

expected="${KITTY_VERSION#v}"

# ============================================================
# Installation Decision
# ============================================================

needs_install=0

if [[ -z "$current" ]]; then

    needs_install=1

elif ! version_ge "$current" "$KITTY_MIN_VERSION"; then

    needs_install=1

elif [[ "$DOTFILES_UPDATE" == "1" ]] &&
    ! version_ge "$current" "$expected"; then

    needs_install=1

fi

# ============================================================
# Install Kitty
# ============================================================

if ((needs_install)); then

    log "Instalando Kitty $KITTY_VERSION..."

    work="$(mktemp -d)"

    trap 'rm -rf -- "$work"' EXIT

    installer="$work/installer.sh"

    download \
        "https://sw.kovidgoyal.net/kitty/installer.sh" \
        "$installer"

    sh "$installer" \
        "installer=version-$expected" \
        "launch=n"

else

    log "Kitty $current satisface la versión requerida."

fi

# ============================================================
# Local Directories
# ============================================================

mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications"

# ============================================================
# Binary Links
# ============================================================

kitty_root="$HOME/.local/kitty.app"

if [[ -x "$kitty_root/bin/kitty" ]]; then

    for binary in kitty kitten; do

        [[ -x "$kitty_root/bin/$binary" ]] ||
            die "No se encontró el ejecutable: $kitty_root/bin/$binary"

        ln -sfnT \
            "$kitty_root/bin/$binary" \
            "$HOME/.local/bin/$binary"

    done

fi

# ============================================================
# Desktop Entry
# ============================================================

if [[ -x "$kitty_root/bin/kitty" ]]; then

    cat >"$HOME/.local/share/applications/kitty.desktop" <<EOF
[Desktop Entry]
Name=Kitty
Comment=Terminal GUTS
Exec=$kitty_root/bin/kitty
Icon=$kitty_root/share/icons/hicolor/256x256/apps/kitty.png
Type=Application
Categories=System;TerminalEmulator;
Terminal=false
EOF

fi

# ============================================================
# Verification
# ============================================================

if [[ -x "$kitty_root/bin/kitty" ]]; then

    installed="$(
        "$kitty_root/bin/kitty" --version |
            awk '{print $2}'
    )"

    version_ge "$installed" "$KITTY_MIN_VERSION" ||
        die "Kitty $installed no satisface >= $KITTY_MIN_VERSION."

    log "Kitty $installed lista."

elif [[ -n "$current" ]] &&
    version_ge "$current" "$KITTY_MIN_VERSION"; then

    log "Kitty $current disponible desde el sistema."

else

    die "No se encontró una instalación válida de Kitty."

fi
