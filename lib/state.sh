#!/usr/bin/env bash
# Estado de instalación: datos validados, nunca código ejecutado con source.

dotfiles_state_load() {
    local state_root="${XDG_STATE_HOME:-$HOME/.local/state}" key value schema=""
    local -A seen=()
    [[ "$state_root" == /* ]] || die "XDG_STATE_HOME debe ser una ruta absoluta."
    DOTFILES_STATE_DIR="$(realpath -m -- "$state_root/dotfiles")"
    [[ "$DOTFILES_STATE_DIR" != "$DOTFILES_ROOT" && "$DOTFILES_STATE_DIR" != "$DOTFILES_ROOT/"* &&
       "$DOTFILES_ROOT" != "$DOTFILES_STATE_DIR/"* ]] || die "El estado debe quedar fuera del repositorio."
    DOTFILES_STATE_FILE="$DOTFILES_STATE_DIR/install.state"
    [[ ! -L "$DOTFILES_STATE_FILE" && ( ! -e "$DOTFILES_STATE_FILE" || -f "$DOTFILES_STATE_FILE" ) ]] || die "Archivo de estado inválido."
    DOTFILES_APPLIED_COMMIT=""
    DOTFILES_PENDING_COMMIT=""
    DOTFILES_WITH_RISCV=0
    DOTFILES_WITH_DOCKER=0
    DOTFILES_WITH_GNOME=0
    DOTFILES_WITH_APACHE=0
    DOTFILES_WITH_SSH=0
    DOTFILES_WITH_AVR=0
    [[ -f "$DOTFILES_STATE_FILE" ]] || return 0
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -n "$key" && ! ${seen[$key]+yes} ]] || die "Estado incompleto o duplicado: $key"
        seen[$key]=1
        case "$key" in
            schema)
                [[ "$value" == 1 || "$value" == 2 || "$value" == 3 ]] || die "Versión de estado no soportada."
                schema="$value" ;;
            applied_commit|pending_commit)
                [[ -z "$value" || "$value" =~ ^[[:xdigit:]]{40}$ || "$value" =~ ^[[:xdigit:]]{64}$ ]] || die "Commit inválido en el estado."
                if [[ "$key" == applied_commit ]]; then DOTFILES_APPLIED_COMMIT="$value"; else DOTFILES_PENDING_COMMIT="$value"; fi ;;
            riscv|docker|gnome|apache|ssh|avr)
                [[ "$value" == 0 || "$value" == 1 ]] || die "Componente inválido en el estado: $key"
                case "$key" in
                    riscv) DOTFILES_WITH_RISCV="$value" ;;
                    docker) DOTFILES_WITH_DOCKER="$value" ;;
                    gnome) DOTFILES_WITH_GNOME="$value" ;;
                    apache) DOTFILES_WITH_APACHE="$value" ;;
                    ssh) DOTFILES_WITH_SSH="$value" ;;
                    avr) DOTFILES_WITH_AVR="$value" ;;
                esac ;;
            *) die "Campo de estado desconocido: $key" ;;
        esac
    done < "$DOTFILES_STATE_FILE"
    for key in schema applied_commit pending_commit riscv docker gnome; do
        [[ ${seen[$key]+yes} ]] || die "El estado está incompleto; no se modificó."
    done
    if [[ "$schema" == 1 ]]; then
        (( ${#seen[@]} == 6 )) || die "Campos incompatibles con la versión de estado."
    elif [[ "$schema" == 2 ]]; then
        [[ ${seen[apache]+yes} && ${seen[ssh]+yes} ]] || die "El estado está incompleto; no se modificó."
        (( ${#seen[@]} == 8 )) || die "Campos incompatibles con la versión de estado."
    else
        [[ ${seen[apache]+yes} && ${seen[ssh]+yes} && ${seen[avr]+yes} ]] || die "El estado está incompleto; no se modificó."
    fi
}

dotfiles_state_lock() {
    require_command flock
    mkdir -p -- "$DOTFILES_STATE_DIR"
    [[ ! -L "$DOTFILES_STATE_DIR/install.lock" &&
       ( ! -e "$DOTFILES_STATE_DIR/install.lock" || -f "$DOTFILES_STATE_DIR/install.lock" ) ]] || die "Archivo de bloqueo inválido."
    # El descriptor se conserva cuando update reinicia el comando actualizado.
    if [[ "${DOTFILES_UPDATE_REPO:-}" == "$DOTFILES_ROOT" &&
          "$(readlink -- "/proc/$$/fd/9" 2>/dev/null || true)" == "$DOTFILES_STATE_DIR/install.lock" ]]; then
        flock -n 9 || die "Otra instalación está en curso."
    else
        exec 9>>"$DOTFILES_STATE_DIR/install.lock"
        flock -n 9 || die "Otra instalación o actualización está en curso."
    fi
    dotfiles_state_load
}

dotfiles_state_write() {
    local temporary
    temporary="$(umask 077; mktemp -- "$DOTFILES_STATE_DIR/.install.state.XXXXXX")"
    if ! printf 'schema=3\napplied_commit=%s\npending_commit=%s\nriscv=%s\ndocker=%s\ngnome=%s\napache=%s\nssh=%s\navr=%s\n' \
        "$DOTFILES_APPLIED_COMMIT" "$DOTFILES_PENDING_COMMIT" "$DOTFILES_WITH_RISCV" \
        "$DOTFILES_WITH_DOCKER" "$DOTFILES_WITH_GNOME" "$DOTFILES_WITH_APACHE" "$DOTFILES_WITH_SSH" "$DOTFILES_WITH_AVR" > "$temporary"; then
        rm -f -- "$temporary"
        die "No se pudo guardar el estado."
    fi
    mv -fT -- "$temporary" "$DOTFILES_STATE_FILE" || { rm -f -- "$temporary"; die "No se pudo guardar el estado."; }
}

dotfiles_git_head() {
    local root
    root="$(git -C "$DOTFILES_ROOT" rev-parse --show-toplevel 2>/dev/null)" || die "Este comando requiere un clon Git."
    [[ "$(realpath -e -- "$root")" == "$DOTFILES_ROOT" ]] || die "La raíz no corresponde al repositorio Git."
    git -C "$DOTFILES_ROOT" rev-parse --verify HEAD
}

dotfiles_git_clean() {
    local status
    status="$(git -C "$DOTFILES_ROOT" status --porcelain)" || die "No se pudo comprobar el estado Git."
    [[ -z "$status" ]] || die "Hay cambios locales en los dotfiles; guárdalos antes de instalar o actualizar."
}

dotfiles_state_guard() {
    local target="$1" previous
    for previous in "$DOTFILES_APPLIED_COMMIT" "$DOTFILES_PENDING_COMMIT"; do
        [[ -n "$previous" ]] || continue
        git -C "$DOTFILES_ROOT" cat-file -e "$previous^{commit}" 2>/dev/null ||
            die "No se puede verificar el commit aplicado o pendiente $previous; falta historial Git. Si es un clon superficial, recupera su historial. Si cambiaste a un repositorio con otro historial, usa: bash bin/dotfiles install --migrate-state."
        git -C "$DOTFILES_ROOT" merge-base --is-ancestor "$previous" "$target" ||
            die "Esta revisión no contiene el último commit aplicado o pendiente. Usa una rama que lo incluya."
    done
}

# La migración se solicita únicamente con install --migrate-state. El estado
# anterior se respalda antes de comenzar; install registrará el nuevo intento
# pendiente y solo lo marcará como aplicado cuando termine correctamente.
dotfiles_state_migrate() {
    local target="$1" previous backup needs_migration=0
    for previous in "$DOTFILES_APPLIED_COMMIT" "$DOTFILES_PENDING_COMMIT"; do
        [[ -n "$previous" ]] || continue
        if ! git -C "$DOTFILES_ROOT" cat-file -e "$previous^{commit}" 2>/dev/null ||
           ! git -C "$DOTFILES_ROOT" merge-base --is-ancestor "$previous" "$target"; then
            needs_migration=1
        fi
    done
    if (( needs_migration == 0 )); then
        log "El estado ya es compatible con esta revisión; no necesita migración."
        return 0
    fi

    backup="$(umask 077; mktemp -- "$DOTFILES_STATE_DIR/install.state.backup.XXXXXX")" ||
        die "No se pudo crear el respaldo del estado; no se migró."
    if ! cp -- "$DOTFILES_STATE_FILE" "$backup"; then
        rm -f -- "$backup"
        die "No se pudo respaldar el estado; no se migró."
    fi
    log "Estado anterior respaldado en $backup"
    DOTFILES_APPLIED_COMMIT=""
    DOTFILES_PENDING_COMMIT=""
    log "Migrando al nuevo historial; se conservan los componentes opcionales elegidos."
}
