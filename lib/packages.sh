#!/usr/bin/env bash
# GUTS Dotfiles: fachada de paquetes; requiere lib/common.sh.
# Cargarla solo define funciones, sin detectar el sistema ni instalar paquetes.

source "$DOTFILES_ROOT/lib/platform.sh"
source "$DOTFILES_ROOT/lib/packages/apt.sh"
source "$DOTFILES_ROOT/lib/packages/pacman.sh"

# Valida el backend con la deteccion central, sin confiar en datos del entorno.
# Un backend esperado protege las llamadas historicas con nombres APT.
# common.sh pasa apt; los clientes genericos no necesitan argumento.
# shellcheck disable=SC2120
dotfiles_packages_require_backend() {
    dotfiles_platform_detect || die "$DOTFILES_PLATFORM_ERROR"
    case "$DOTFILES_PLATFORM_PACKAGE_FAMILY" in
        apt|pacman) ;;
        *) die "Sin backend de paquetes para ID=$DOTFILES_PLATFORM_ID; distribucion no soportada." ;;
    esac
    if [[ -n "${1:-}" && "$1" != "$DOTFILES_PLATFORM_PACKAGE_FAMILY" ]]; then
        die "apt_install requiere APT; no se envian nombres APT a Pacman. Usa dotfiles_packages_install_module para resolver un modulo."
    fi
}

# Recibe nombres nativos del backend, sin traducir paquetes ni elegir modulos.
# Propaga errores del gestor; una solicitud vacia no refresca ni instala.
dotfiles_packages_install() {
    dotfiles_packages_require_backend
    case "$DOTFILES_PLATFORM_PACKAGE_FAMILY" in
        apt) dotfiles_packages_apt_install "$@" ;;
        pacman) dotfiles_packages_pacman_install "$@" ;;
    esac
}

# Datos de Arch, sin ejecutar el archivo ni duplicar seleccion o dependencias.
dotfiles_packages_arch_load() {
    local line separators name state packages commands reason package command
    local -a package_list=() command_list=()
    local file="$DOTFILES_ROOT/setup/packages/arch.conf"
    [[ -f "$file" && -r "$file" ]] || die "Falta el catalogo de paquetes Arch: $file"
    declare -gA DOTFILES_ARCH_PACKAGE_STATE=() DOTFILES_ARCH_PACKAGES=() DOTFILES_ARCH_COMMANDS=() DOTFILES_ARCH_REASON=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" && "$line" != \#* ]] || continue
        separators="${line//[^|]/}"
        [[ ${#separators} == 4 && ! "$line" =~ [[:cntrl:]] ]] || die "Fila Arch mal formada: $line"
        IFS='|' read -r name state packages commands reason <<< "$line"
        [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] && [[ ${DOTFILES_MODULE_KIND[$name]+yes} ]] || die "Modulo Arch desconocido: $name"
        [[ ! ${DOTFILES_ARCH_PACKAGE_STATE[$name]+yes} ]] || die "Modulo Arch duplicado: $name"
        case "$state" in
            native) [[ -n "${packages// /}" ]] || die "Paquetes Arch obligatorios no definidos: $name" ;;
            none) [[ -z "$packages" && -n "${reason// /}" ]] || die "Modulo Arch sin paquetes requiere mecanismo explicito: $name" ;;
            pending) [[ -n "${reason// /}" ]] || die "Modulo Arch pendiente sin motivo: $name" ;;
            *) die "Estado de paquetes Arch invalido: $name ($state)" ;;
        esac
        read -r -a package_list <<< "$packages"
        read -r -a command_list <<< "$commands"
        for package in "${package_list[@]}"; do
            [[ "$package" =~ ^[a-zA-Z0-9@_+][a-zA-Z0-9@._+-]*$ ]] || die "Paquete Arch invalido: $name ($package)"
        done
        for command in "${command_list[@]}"; do
            [[ "$command" =~ ^[a-zA-Z0-9_+.-]+(:/[a-zA-Z0-9_+./-]+)?$ ]] || die "Comando Arch invalido: $name ($command)"
        done
        DOTFILES_ARCH_PACKAGE_STATE[$name]="$state"
        DOTFILES_ARCH_PACKAGES[$name]="$packages"
        DOTFILES_ARCH_COMMANDS[$name]="$commands"
        DOTFILES_ARCH_REASON[$name]="$reason"
    done < "$file"
}

# Resultados de resolucion para instaladores y doctor; nunca instala ni activa
# opcionales. El grafo y la seleccion siguen perteneciendo a lib/modules.sh.
# shellcheck disable=SC2034
dotfiles_packages_resolve_module() {
    local name="${1:-}"
    DOTFILES_RESOLVED_PACKAGES=()
    DOTFILES_RESOLVED_COMMANDS=""
    DOTFILES_RESOLVED_STATE=""
    DOTFILES_RESOLVED_REASON=""
    if ! declare -p DOTFILES_MODULE_PACKAGES >/dev/null 2>&1; then
        source "$DOTFILES_ROOT/lib/modules.sh"
    fi
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ && ${DOTFILES_MODULE_PACKAGES[$name]+yes} ]] || die "Modulo de paquetes desconocido: $name"
    dotfiles_packages_require_backend
    DOTFILES_RESOLVED_COMMANDS="${DOTFILES_MODULE_COMMANDS[$name]}"
    if [[ "$DOTFILES_PLATFORM_PACKAGE_FAMILY" == apt ]]; then
        read -r -a DOTFILES_RESOLVED_PACKAGES <<< "${DOTFILES_MODULE_PACKAGES[$name]}"
        DOTFILES_RESOLVED_STATE=none
        if (( ${#DOTFILES_RESOLVED_PACKAGES[@]} > 0 )); then DOTFILES_RESOLVED_STATE=native; fi
    else
        if ! declare -p DOTFILES_ARCH_PACKAGE_STATE >/dev/null 2>&1; then
            dotfiles_packages_arch_load
        fi
        [[ ${DOTFILES_ARCH_PACKAGE_STATE[$name]+yes} ]] || die "Modulo sin entrada Arch: $name"
        read -r -a DOTFILES_RESOLVED_PACKAGES <<< "${DOTFILES_ARCH_PACKAGES[$name]}"
        DOTFILES_RESOLVED_STATE="${DOTFILES_ARCH_PACKAGE_STATE[$name]}"
        DOTFILES_RESOLVED_COMMANDS="${DOTFILES_ARCH_COMMANDS[$name]:-$DOTFILES_RESOLVED_COMMANDS}"
        DOTFILES_RESOLVED_REASON="${DOTFILES_ARCH_REASON[$name]}"
    fi
}

dotfiles_packages_install_module() {
    local name="${1:-}"
    dotfiles_packages_resolve_module "$name"
    case "$DOTFILES_RESOLVED_STATE" in
        pending) die "Modulo Arch pendiente: $name. $DOTFILES_RESOLVED_REASON" ;;
        none) return 0 ;;
        native) dotfiles_packages_install "${DOTFILES_RESOLVED_PACKAGES[@]}" ;;
    esac
}
