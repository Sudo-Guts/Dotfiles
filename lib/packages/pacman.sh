#!/usr/bin/env bash
# GUTS Dotfiles: backend Pacman interno; requiere lib/common.sh.
# El usuario mantiene Arch sincronizado. Ni install ni update refrescan la BD.

dotfiles_packages_pacman_install() {
    local package unmet status_code
    local -a requested=() missing=()
    local -A seen=() unsatisfied=()
    for package in "$@"; do
        [[ "$package" =~ ^[a-zA-Z0-9@_+][a-zA-Z0-9@._+-]*$ ]] || {
            printf '[error] Nombre de paquete Pacman invalido o vacio: %s\n' "$package" >&2
            return 1
        }
        [[ ! ${seen[$package]+yes} ]] || continue
        seen[$package]=1
        requested+=("$package")
    done
    (( ${#requested[@]} > 0 )) || return 0
    require_command pacman
    # -T considera paquetes instalados y proveedores. 127 significa faltantes;
    # cualquier otro error se propaga y nunca se convierte en una instalacion.
    if unmet="$(pacman -T -- "${requested[@]}")"; then
        [[ -z "$unmet" ]] || {
            printf '[error] Respuesta inesperada de pacman -T con codigo 0.\n' >&2
            return 1
        }
        return 0
    else
        status_code=$?
        if (( status_code != 127 )) || [[ -z "$unmet" ]]; then
            printf '[error] pacman -T fallo (codigo %s).\n' "$status_code" >&2
            return "$status_code"
        fi
    fi
    while IFS= read -r package; do
        [[ "$package" =~ ^[a-zA-Z0-9@_+][a-zA-Z0-9@._+-]*$ ]] && [[ ${seen[$package]+yes} ]] || {
            printf '[error] Respuesta invalida de pacman -T: %s\n' "$package" >&2
            return 1
        }
        unsatisfied[$package]=1
    done <<< "$unmet"
    for package in "${requested[@]}"; do
        [[ ${unsatisfied[$package]+yes} ]] || continue
        missing+=("$package")
    done
    log "Comprobando paquetes Pacman: ${missing[*]}"
    # --needed protege tambien frente a cambios entre consulta e instalacion.
    # Sin -y/-u ni --noconfirm; los bloqueos y errores quedan a cargo de Pacman.
    as_root pacman -S --needed -- "${missing[@]}" || return "$?"
}
