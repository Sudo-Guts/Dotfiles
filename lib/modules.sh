#!/usr/bin/env bash

# Tablas compartidas con la CLI, los instaladores APT y doctor.
# shellcheck disable=SC2034

# El orden del manifiesto resuelve las dependencias sin un planificador adicional.
dotfiles_modules_load() {
    local name kind dependencies commands packages extra dependency
    DOTFILES_MODULES=()
    declare -gA DOTFILES_MODULE_KIND=() DOTFILES_MODULE_DEPENDENCIES=() DOTFILES_MODULE_COMMANDS=() DOTFILES_MODULE_PACKAGES=()
    while IFS='|' read -r name kind dependencies commands packages extra || [[ -n "$name" ]]; do
        [[ -n "$name" && "$name" != \#* ]] || continue
        [[ "$name" =~ ^[a-z][a-z0-9-]*$ && -z "$extra" && ! ${DOTFILES_MODULE_KIND[$name]+yes} ]] || die "Módulo inválido o duplicado: $name"
        [[ "$kind" == core || "$kind" == optional || "$kind" == gnome ]] || die "Selección de módulo inválida: $name"
        [[ "$kind" != optional || "$name" =~ ^[a-z]+$ ]] || die "Nombre opcional inválido: $name"
        [[ -f "$DOTFILES_ROOT/setup/modules/$name.sh" ]] || die "Falta el instalador del módulo: $name"
        for dependency in $dependencies; do
            [[ ${DOTFILES_MODULE_KIND[$dependency]+yes} ]] || die "Dependencia desconocida o fuera de orden: $name necesita $dependency"
        done
        DOTFILES_MODULES+=("$name")
        DOTFILES_MODULE_KIND[$name]="$kind"
        DOTFILES_MODULE_DEPENDENCIES[$name]="$dependencies"
        DOTFILES_MODULE_COMMANDS[$name]="$commands"
        DOTFILES_MODULE_PACKAGES[$name]="$packages"
    done < "$DOTFILES_ROOT/setup/modules.conf"
    (( ${#DOTFILES_MODULES[@]} > 0 )) || die "El manifiesto de módulos está vacío."
}

dotfiles_module_enabled() {
    local name="$1" variable
    case "${DOTFILES_MODULE_KIND[$name]:-}" in
        core) return 0 ;;
        gnome) [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] ;;
        optional)
            variable="DOTFILES_WITH_${name^^}"
            [[ "${!variable:-0}" == 1 ]] ;;
        *) return 1 ;;
    esac
}

dotfiles_modules_select() {
    local name dependency
    DOTFILES_SELECTED_MODULES=()
    for name in "${DOTFILES_MODULES[@]}"; do
        dotfiles_module_enabled "$name" || continue
        for dependency in ${DOTFILES_MODULE_DEPENDENCIES[$name]}; do
            dotfiles_module_enabled "$dependency" || die "El módulo $name requiere $dependency."
        done
        DOTFILES_SELECTED_MODULES+=("$name")
    done
    export DOTFILES_NVIM_MODULES="${DOTFILES_SELECTED_MODULES[*]}"
}

dotfiles_modules_load
