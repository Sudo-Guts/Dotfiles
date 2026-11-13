#!/usr/bin/env bash
# GUTS Dotfiles: identifica la plataforma y valida operaciones antes de escribir.
# Requiere lib/common.sh. Las variables DOTFILES_PLATFORM_* son resultados.
# shellcheck disable=SC2034

# Decodifica un valor de os-release sin source, eval ni expansion de variables.
dotfiles_platform_value() {
    local value="$1" quote="" decoded="" character next index
    local LC_ALL=C
    [[ ! "$value" =~ [[:cntrl:]] ]] || return 1
    case "$value" in
        \'*|\"*)
            quote="${value:0:1}"
            (( ${#value} >= 2 )) && [[ "${value: -1}" == "$quote" ]] || return 1
            value="${value:1:${#value}-2}"
            ;;
        *)
            [[ "$value" =~ ^[a-zA-Z0-9._~^+-]*$ ]] || return 1
            printf '%s' "$value"
            return 0
            ;;
    esac
    if [[ "$quote" == "'" ]]; then
        [[ "$value" != *"'"* ]] || return 1
        printf '%s' "$value"
        return 0
    fi
    for (( index=0; index<${#value}; index++ )); do
        character="${value:index:1}"
        case "$character" in
            '\')
                index=$((index + 1))
                (( index < ${#value} )) || return 1
                next="${value:index:1}"
                case "$next" in
                    '$'|$'\x60'|'"'|'\') decoded+="$next" ;;
                    *) decoded+="\\$next" ;;
                esac
                ;;
            '"'|'$'|$'\x60') return 1 ;;
            *) decoded+="$character" ;;
        esac
    done
    printf '%s' "$decoded"
}

# Sin argumentos usa rutas del sistema y uname. Los parametros explicitos
# permiten probar archivos aislados; la CLI nunca los toma del entorno.
# Devuelve 1 y DOTFILES_PLATFORM_ERROR ante datos ausentes o invalidos.
dotfiles_platform_detect() {
    local primary="${1:-/etc/os-release}" fallback="${2:-/usr/lib/os-release}"
    local architecture="${3:-}" file line key value line_number=0
    local -A release=()
    DOTFILES_PLATFORM_ID=""
    DOTFILES_PLATFORM_NAME=""
    DOTFILES_PLATFORM_VERSION=""
    DOTFILES_PLATFORM_ARCH=""
    DOTFILES_PLATFORM_PACKAGE_FAMILY="unknown"
    DOTFILES_PLATFORM_ID_LIKE=""
    DOTFILES_PLATFORM_VERSION_CODENAME=""
    DOTFILES_PLATFORM_UBUNTU_CODENAME=""
    DOTFILES_PLATFORM_OS_RELEASE=""
    DOTFILES_PLATFORM_ERROR=""
    file="$primary"
    if [[ ! -e "$primary" && ! -L "$primary" ]]; then file="$fallback"; fi
    DOTFILES_PLATFORM_OS_RELEASE="$file"
    if [[ ! -f "$file" || ! -r "$file" ]]; then
        DOTFILES_PLATFORM_ERROR="No se puede leer os-release: $file."
        return 1
    fi
    if IFS= read -r -d '' line < "$file"; then
        DOTFILES_PLATFORM_ERROR="os-release contiene un byte NUL: $file."
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        [[ ! "$line" =~ ^[[:space:]]*(#|$) ]] || continue
        if [[ ! "$line" =~ ^([A-Z_][A-Z_0-9]*)=(.*)$ ]]; then
            DOTFILES_PLATFORM_ERROR="os-release mal formado: $file, linea $line_number."
            return 1
        fi
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        case "$key" in
            ID|NAME|VERSION_ID|ID_LIKE|VERSION_CODENAME|UBUNTU_CODENAME)
                if ! value="$(dotfiles_platform_value "$value")"; then
                    DOTFILES_PLATFORM_ERROR="Valor invalido de $key en $file, linea $line_number."
                    return 1
                fi
                release[$key]="$value"
                ;;
        esac
    done < "$file"
    if [[ ! "${release[ID]:-}" =~ ^[a-z0-9._-]+$ ||
          ! "${release[VERSION_ID]:-}" =~ ^[a-zA-Z0-9._~^+-]*$ ||
          ! "${release[VERSION_CODENAME]:-}" =~ ^[a-zA-Z0-9._-]*$ ||
          ! "${release[UBUNTU_CODENAME]:-}" =~ ^[a-zA-Z0-9._-]*$ ]]; then
        DOTFILES_PLATFORM_ERROR="Identificacion incompleta o invalida en $file: revisa ID, VERSION_ID y codename."
        return 1
    fi
    if [[ -z "$architecture" ]]; then
        if ! architecture="$(uname -m)" || [[ -z "$architecture" ]]; then
            DOTFILES_PLATFORM_ERROR="No se pudo identificar la arquitectura mediante uname -m."
            return 1
        fi
    fi
    DOTFILES_PLATFORM_ID="${release[ID]}"
    DOTFILES_PLATFORM_NAME="${release[NAME]:-${release[ID]}}"
    DOTFILES_PLATFORM_VERSION="${release[VERSION_ID]:-}"
    DOTFILES_PLATFORM_ARCH="$architecture"
    DOTFILES_PLATFORM_ID_LIKE="${release[ID_LIKE]:-}"
    DOTFILES_PLATFORM_VERSION_CODENAME="${release[VERSION_CODENAME]:-}"
    DOTFILES_PLATFORM_UBUNTU_CODENAME="${release[UBUNTU_CODENAME]:-}"
    case "$DOTFILES_PLATFORM_ID" in
        ubuntu|debian) DOTFILES_PLATFORM_PACKAGE_FAMILY="apt" ;;
        arch) DOTFILES_PLATFORM_PACKAGE_FAMILY="pacman" ;;
    esac
}

# Informa datos detectados, sin afirmar certificacion de versiones.
dotfiles_platform_report() {
    log "Plataforma: $DOTFILES_PLATFORM_NAME (ID=$DOTFILES_PLATFORM_ID, version=${DOTFILES_PLATFORM_VERSION:-sin VERSION_ID}, arquitectura=$DOTFILES_PLATFORM_ARCH, familia=$DOTFILES_PLATFORM_PACKAGE_FAMILY)."
}

# Solo install/update necesitan backend y arquitectura de los binarios core.
# link conserva sus protecciones y no requiere gestor ni toolchain instalada.
dotfiles_platform_preflight() {
    local operation="$1" prerequisite
    local -a prerequisites=(realpath dirname basename mkdir mktemp mv ln readlink rmdir)
    case "$operation" in
        install|update|link) ;;
        *) die "Operacion de preflight desconocida: $operation." ;;
    esac
    dotfiles_platform_detect || die "$DOTFILES_PLATFORM_ERROR"
    dotfiles_platform_report
    case "$DOTFILES_PLATFORM_ID" in
        arch|ubuntu|debian) ;;
        *) die "No se permite $operation en ID=$DOTFILES_PLATFORM_ID (ID_LIKE=${DOTFILES_PLATFORM_ID_LIKE:-ninguno}): distribucion no soportada; las derivadas requieren validacion explicita. Usa help, doctor o check para obtener informacion." ;;
    esac
    if [[ "$operation" != link ]]; then
        if [[ "$DOTFILES_PLATFORM_PACKAGE_FAMILY" == pacman ]]; then
            die "Arch Linux reconocido: install y update estan detenidos porque el backend Pacman se implementara en la siguiente fase. No se aplicaron cambios."
        fi
        case "$DOTFILES_PLATFORM_ARCH" in
            x86_64|aarch64|arm64) ;;
            *) die "Arquitectura no contemplada para $operation: $DOTFILES_PLATFORM_ARCH. Los binarios core requieren x86_64 o ARM64." ;;
        esac
        # Solo herramientas del bootstrap; base instala curl, Zsh y lenguajes.
        prerequisites+=(apt-get dpkg-query git flock cp rm find grep sed sort head tar)
        if (( EUID != 0 )); then prerequisites+=(sudo); fi
    fi
    for prerequisite in "${prerequisites[@]}"; do
        command -v "$prerequisite" >/dev/null 2>&1 || die "Preflight $operation: falta el requisito minimo $prerequisite del bootstrap."
    done
}
