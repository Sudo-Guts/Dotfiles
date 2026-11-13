#!/usr/bin/env bash
# GUTS Dotfiles: fachada de paquetes; requiere lib/common.sh.
# Cargarla solo define funciones, sin detectar el sistema ni instalar paquetes.

source "$DOTFILES_ROOT/lib/platform.sh"
source "$DOTFILES_ROOT/lib/packages/apt.sh"

# Valida el backend con la deteccion central, sin confiar en datos del entorno.
# Solo APT esta implementado; no modifica archivos ante un rechazo.
dotfiles_packages_require_backend() {
    dotfiles_platform_detect || die "$DOTFILES_PLATFORM_ERROR"
    case "$DOTFILES_PLATFORM_PACKAGE_FAMILY" in
        apt) ;;
        pacman) die "Arch Linux reconocido: backend Pacman no implementado; no se pueden instalar paquetes." ;;
        *) die "Sin backend de paquetes para ID=$DOTFILES_PLATFORM_ID; distribucion no soportada." ;;
    esac
}

# Recibe nombres nativos del backend, sin traducir paquetes ni elegir modulos.
# Propaga errores del gestor; una solicitud vacia no refresca ni instala.
dotfiles_packages_install() {
    dotfiles_packages_require_backend
    dotfiles_packages_apt_install "$@"
}

# Resuelve solo los paquetes del modulo; la seleccion y dependencias siguen
# perteneciendo a lib/modules.sh. No cambia el catalogo ni activa opcionales.
dotfiles_packages_install_module() {
    local name="${1:-}"
    local -a packages=()
    if ! declare -p DOTFILES_MODULE_PACKAGES >/dev/null 2>&1; then
        source "$DOTFILES_ROOT/lib/modules.sh"
    fi
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ && ${DOTFILES_MODULE_PACKAGES[$name]+yes} ]] || die "Modulo de paquetes desconocido: $name"
    read -r -a packages <<< "${DOTFILES_MODULE_PACKAGES[$name]}"
    if (( ${#packages[@]} == 0 )); then
        dotfiles_packages_require_backend
        return 0
    fi
    dotfiles_packages_install "${packages[@]}"
}
