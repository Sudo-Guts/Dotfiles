#!/usr/bin/env bash

# ============================================================
# Neovim Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala y prepara el entorno principal de Neovim:
#
#   - Neovim
#
# C/C++ y Tree-sitter CLI tienen sus propios módulos.
#
# Neovim se instala localmente en:
#
#   ~/.local/opt/nvim-<version>
#
# y se expone mediante:
#
#   ~/.local/bin/nvim
#
# Las versiones se administran desde:
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

require_command tar


# ============================================================
# Current Neovim
# ============================================================

current="$(
    nvim --version 2>/dev/null |
        sed -n '1s/^NVIM v//p' ||
        true
)"


# ============================================================
# Existing Installation
# ============================================================

if [[ -n "$current" ]] &&
   binary_satisfies "$current" "$NVIM_MIN_VERSION" "$NVIM_VERSION"; then

    log "Neovim $current satisface el mínimo requerido."

else

    # ========================================================
    # Architecture
    # ========================================================

    case "$(uname -m)" in

        x86_64)
            arch="x86_64"
            ;;

        aarch64|arm64)
            arch="arm64"
            ;;

        *)
            die "Arquitectura Neovim no soportada: $(uname -m)"
            ;;

    esac


    # ========================================================
    # Paths
    # ========================================================

    target="$HOME/.local/opt/nvim-$NVIM_VERSION"

    mkdir -p \
        "$HOME/.local/opt" \
        "$HOME/.local/bin"


    # ========================================================
    # Temporary Workspace
    # ========================================================

    work="$(mktemp -d)"

    trap 'rm -rf -- "$work"' EXIT

    archive="$work/nvim.tar.gz"
    extracted="$work/nvim-linux-$arch"


    # ========================================================
    # Download
    # ========================================================

    log "Descargando Neovim $NVIM_VERSION..."

    download \
        "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$arch.tar.gz" \
        "$archive"


    # ========================================================
    # Extract
    # ========================================================

    log "Extrayendo Neovim..."

    tar \
        --no-same-owner \
        -xzf "$archive" \
        -C "$work"


    [[ -x "$extracted/bin/nvim" ]] ||
        die "El paquete descargado no contiene un ejecutable Neovim válido."


    # ========================================================
    # Verify Downloaded Version
    # ========================================================

    downloaded_version="$(
        "$extracted/bin/nvim" --version |
            sed -n '1s/^NVIM v//p'
    )"

    expected_version="${NVIM_VERSION#v}"

    [[ "$downloaded_version" == "$expected_version" ]] ||
        die "Versión inesperada de Neovim: $downloaded_version; se esperaba $expected_version."
    version_ge "$downloaded_version" "$NVIM_MIN_VERSION" || die "La versión solicitada de Neovim no cumple el mínimo."


    # ========================================================
    # Install
    # ========================================================

    # El directorio target pertenece completamente a los
    # dotfiles. Si entramos en el flujo de instalación,
    # reemplazamos la copia administrada anterior.

    if [[ -e "$target" ]]; then
        log "Reemplazando instalación administrada: $target"
        rm -rf -- "$target"
    fi

    mv \
        "$extracted" \
        "$target"


    # ========================================================
    # Local Binary
    # ========================================================

    ln -sfnT \
        "$target/bin/nvim" \
        "$HOME/.local/bin/nvim"


    # ========================================================
    # Verification
    # ========================================================

    installed_version="$(
        "$HOME/.local/bin/nvim" --version |
            sed -n '1s/^NVIM v//p'
    )"

    [[ "$installed_version" == "$expected_version" ]] ||
        die "La instalación de Neovim no pudo verificarse."

    log "Neovim $installed_version instalado."

fi


# ============================================================
# Done
# ============================================================

log "Entorno base de Neovim listo."
