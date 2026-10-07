#!/usr/bin/env bash

# ============================================================
# Shared Installation Library
# ============================================================
#
# GUTS Dotfiles
#
# Funciones y variables compartidas por los scripts de:
#
#   setup/modules/
#
# Este archivo proporciona:
#
#   - Detección de la raíz del repositorio
#   - PATH del entorno de instalación
#   - Manejo de errores
#   - Ejecución privilegiada mediante sudo
#   - Instalación idempotente de paquetes APT
#   - Descargas HTTP
#   - Comparación de versiones
#   - Sincronización de repositorios Git
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# Dotfiles Root
# ============================================================

DOTFILES_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd -P
)"


# ============================================================
# Environment
# ============================================================

# Herramientas instaladas localmente tienen prioridad sobre
# versiones antiguas disponibles en el sistema.

export PATH="$HOME/.local/bin:$HOME/.local/kitty.app/bin:$PATH"

# Modo interno de mantenimiento; install no lo activa.
DOTFILES_UPDATE="${DOTFILES_UPDATE:-0}"


# ============================================================
# Versions
# ============================================================

source "$DOTFILES_ROOT/setup/versions.sh"


# ============================================================
# Logging
# ============================================================

log() {
    printf '[dotfiles] %s\n' "$*"
}


die() {
    printf '[error] %s\n' "$*" >&2
    exit 1
}


# ============================================================
# Error Reporting
# ============================================================

# Muestra archivo, línea y comando cuando un script gestionado
# por esta librería termina debido a set -e.

trap '
    printf "[error] %s:%s: %s\n" \
        "${BASH_SOURCE[0]}" \
        "$LINENO" \
        "$BASH_COMMAND" >&2
' ERR


# ============================================================
# Privileged Commands
# ============================================================

as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo -- "$@"
    fi
}


# ============================================================
# Command Validation
# ============================================================

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 ||
        die "Falta $command_name; ejecuta setup/modules/base.sh."
}


# ============================================================
# APT Packages
# ============================================================

apt_install() {
    require_command apt-get

    local missing=()
    local package


    # --------------------------------------------------------
    # Find Missing Packages
    # --------------------------------------------------------

    for package in "$@"; do

        if ! dpkg-query \
            -W \
            -f='${Status}' \
            "$package" \
            2>/dev/null |
            grep -qx 'install ok installed'; then

            missing+=("$package")

        fi

    done


    # --------------------------------------------------------
    # Nothing to Install
    # --------------------------------------------------------

    if (( ${#missing[@]} == 0 )) && [[ "$DOTFILES_UPDATE" != 1 ]]; then
        return 0
    fi


    # --------------------------------------------------------
    # Install Missing Packages
    # --------------------------------------------------------

    if [[ "$DOTFILES_UPDATE" == 1 ]]; then
        missing=("$@")
    fi
    log "Comprobando paquetes APT: ${missing[*]}"
    if [[ -z "${DOTFILES_APT_STAMP:-}" || ! -f "$DOTFILES_APT_STAMP" ]]; then
        as_root apt-get update
        if [[ -n "${DOTFILES_APT_STAMP:-}" ]]; then : > "$DOTFILES_APT_STAMP"; fi
    fi

    as_root apt-get install \
        -y \
        --no-install-recommends \
        "${missing[@]}"
}


# ============================================================
# Downloads
# ============================================================

download() {
    local url="$1"
    local destination="$2"

    require_command curl

    curl \
        --fail \
        --location \
        --show-error \
        --silent \
        --retry 3 \
        --connect-timeout 20 \
        "$url" \
        -o "$destination"
}


# ============================================================
# Version Comparison
# ============================================================

version_ge() {
    local current="${1#v}" required="${2#v}" current_base required_base
    current="${current%%+*}"
    required="${required%%+*}"
    [[ "$current" =~ ^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.-]+)?$ &&
       "$required" =~ ^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.-]+)?$ ]] || return 1
    current_base="${current%%-*}"
    required_base="${required%%-*}"
    if [[ "$current_base" == "$required_base" ]]; then
        [[ "$current" != *-* || "$required" == *-* ]] || return 1
        [[ "$required" != *-* || "$current" == *-* ]] || return 0
    fi

    [[ "$(
        printf '%s\n%s\n' "$current" "$required" |
            sort -V |
            head -n1
    )" == "$required" ]]
}

binary_satisfies() {
    local current="$1" minimum="$2" target="${3#v}"
    version_ge "$current" "$minimum" || return 1
    [[ "$DOTFILES_UPDATE" != 1 ]] || version_ge "$current" "$target"
}

# ============================================================
# Git Repository Synchronization
# ============================================================

sync_repo() {
    local url="$1"
    local destination="$2"

    require_command git


    # --------------------------------------------------------
    # First Installation
    # --------------------------------------------------------

    if [[ ! -e "$destination" ]]; then

        log "Clonando: $url"

        command git clone \
            --depth 1 \
            "$url" \
            "$destination"

        return 0

    fi


    # --------------------------------------------------------
    # Validate Existing Destination
    # --------------------------------------------------------

    if [[ ! -d "$destination/.git" ]]; then
        die "$destination existe y no es un repositorio Git."
    fi


    # --------------------------------------------------------
    # Normal Installation
    # --------------------------------------------------------

    # En instalación normal se conserva exactamente el checkout actual.

    if [[ "$DOTFILES_UPDATE" != "1" ]]; then
        return 0
    fi


    # --------------------------------------------------------
    # Protect Local Changes
    # --------------------------------------------------------

    if [[ -n "$(command git -C "$destination" status --porcelain)" ]]; then
        die "Hay cambios locales en $destination."
    fi


    # --------------------------------------------------------
    # Update Repository
    # --------------------------------------------------------

    log "Actualizando: $destination"

    command git -C "$destination" pull --ff-only
}
