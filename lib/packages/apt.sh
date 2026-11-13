#!/usr/bin/env bash
# GUTS Dotfiles: backend APT interno, llamado por lib/packages.sh.
# Requiere log, require_command y as_root de lib/common.sh.

# Conserva los marcadores compartidos por los procesos de una ejecucion.
# Solo registra paquetes y refrescos terminados; devuelve el error original
# tambien si el llamador usa if y Bash deja de aplicar errexit.
dotfiles_packages_apt_install() {
    require_command apt-get
    local package package_status status_code
    local -a missing=()
    local -A seen=()
    for package in "$@"; do
        if [[ -z "$package" ]]; then
            printf '[error] El nombre del paquete no puede estar vacio.\n' >&2
            return 1
        fi
        [[ ! ${seen[$package]+yes} ]] || continue
        seen[$package]=1
        if [[ -n "${DOTFILES_APT_PACKAGES:-}" && -f "$DOTFILES_APT_PACKAGES" ]]; then
            if grep -Fxq -- "$package" "$DOTFILES_APT_PACKAGES"; then
                continue
            else
                status_code=$?
                (( status_code == 1 )) || return "$status_code"
            fi
        fi
        if [[ "$DOTFILES_UPDATE" != 1 ]]; then
            if package_status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)"; then
                [[ "$package_status" != 'install ok installed' ]] || continue
            else
                status_code=$?
                if (( status_code != 1 )); then
                    printf '[error] dpkg-query fallo para %s (codigo %s).\n' "$package" "$status_code" >&2
                    return "$status_code"
                fi
            fi
        fi
        missing+=("$package")
    done
    (( ${#missing[@]} > 0 )) || return 0
    log "Comprobando paquetes APT: ${missing[*]}"
    if [[ -z "${DOTFILES_APT_STAMP:-}" || ! -f "$DOTFILES_APT_STAMP" ]]; then
        as_root apt-get update || return "$?"
        if [[ -n "${DOTFILES_APT_STAMP:-}" ]]; then
            : > "$DOTFILES_APT_STAMP" || return "$?"
        fi
    fi
    as_root apt-get install -y --no-install-recommends "${missing[@]}" || return "$?"
    if [[ -n "${DOTFILES_APT_PACKAGES:-}" ]]; then
        printf '%s\n' "${missing[@]}" >> "$DOTFILES_APT_PACKAGES" || return "$?"
    fi
}
