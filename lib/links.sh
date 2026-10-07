#!/usr/bin/env bash

# Requiere DOTFILES_ROOT y las funciones log/die de lib/common.sh.
# Los únicos destinos permitidos son los declarados en el manifiesto.
source "${DOTFILES_ROOT:?}/setup/manifest.sh"

dotfiles_links_preflight() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    local home_real config_real repo_real
    local src dst dst_parent src_real dst_real other
    local i j count="${#DOTFILES_LINK_SOURCES[@]}"
    local -a real_sources=() real_destinations=()

    [[ "$HOME" == /* && "$config_dir" == /* ]] ||
        die "HOME y XDG_CONFIG_HOME deben ser rutas absolutas."

    home_real="$(realpath -m -- "$HOME")" || die "HOME inválido."
    config_real="$(realpath -m -- "$config_dir")" || die "XDG_CONFIG_HOME inválido."
    repo_real="$(realpath -e -- "$DOTFILES_ROOT")" || die "Repositorio inexistente."

    [[ "$home_real" != / && "$config_real" != / ]] || die "Rutas de usuario inválidas."
    (( count > 0 && count == ${#DOTFILES_LINK_DESTINATIONS[@]} &&
        count == ${#DOTFILES_LINK_NAMES[@]} )) || die "Manifiesto de enlaces incompleto."

    # Validar TODOS los enlaces antes de modificar cualquiera.
    for i in "${!DOTFILES_LINK_SOURCES[@]}"; do
        src="${DOTFILES_LINK_SOURCES[i]}"
        dst="${DOTFILES_LINK_DESTINATIONS[i]}"

        [[ "$src" == /* && "$dst" == /* ]] || die "Enlace con ruta relativa: $dst"
        src_real="$(realpath -e -- "$src")" || die "Origen inexistente: $src"

        # Resolver los padres, pero no seguir el enlace que vamos a sustituir.
        dst_parent="$(realpath -m -- "$(dirname -- "$dst")")" || die "Destino inválido: $dst"
        dst_real="$dst_parent/$(basename -- "$dst")"
        [[ "$dst_parent" != / ]] || dst_real="/$(basename -- "$dst")"

        if [[ "$dst_real" == / || "$dst_real" == "$home_real" ||
              "$dst_real" == "$repo_real" || "$repo_real" == "$dst_real/"* ||
              "$dst_real" == "$repo_real/"* ]]; then
            die "Destino protegido: $dst"
        fi

        real_sources+=("$src_real")
        real_destinations+=("$dst_real")
    done

    for i in "${!real_destinations[@]}"; do
        dst_real="${real_destinations[i]}"
        for src_real in "${real_sources[@]}"; do
            [[ "$src_real" != "$dst_real" && "$src_real" != "$dst_real/"* ]] ||
                die "El destino contiene un origen gestionado: ${DOTFILES_LINK_DESTINATIONS[i]}"
        done
        for j in "${!real_destinations[@]}"; do
            [[ "$i" != "$j" ]] || continue
            other="${real_destinations[j]}"
            [[ "$dst_real" != "$other" && "$dst_real" != "$other/"* ]] ||
                die "Destinos de enlaces superpuestos: ${DOTFILES_LINK_DESTINATIONS[i]}"
        done
    done
}

dotfiles_link_matches() {
    local src="$1" dst="$2" source_real target_real

    [[ -L "$dst" ]] || return 1
    source_real="$(realpath -e -- "$src" 2>/dev/null)" || return 1
    target_real="$(readlink -f -- "$dst" 2>/dev/null)" || return 1
    [[ "$target_real" == "$source_real" ]]
}

dotfiles_links_apply() {
    local i src dst backup

    dotfiles_links_preflight

    for i in "${!DOTFILES_LINK_SOURCES[@]}"; do
        src="${DOTFILES_LINK_SOURCES[i]}"
        dst="${DOTFILES_LINK_DESTINATIONS[i]}"
        backup=""

        if dotfiles_link_matches "$src" "$dst"; then
            log "Enlace correcto: $dst"
            continue
        fi

        mkdir -p -- "$(dirname -- "$dst")" || die "No se puede crear el padre de $dst"

        if [[ -e "$dst" || -L "$dst" ]]; then
            # El respaldo queda junto al destino, en el mismo sistema de archivos.
            # mv conserva también enlaces rotos sin seguir sus destinos.
            backup="$(mktemp -d -- "$dst.backup.XXXXXX")" || die "No se puede respaldar $dst"
            if ! mv -T -- "$dst" "$backup/original"; then
                rmdir -- "$backup" || true
                die "No se pudo respaldar $dst; se conserva el destino anterior."
            fi
            log "Respaldo: $dst → $backup/original"
        fi

        # ln no reemplaza un destino que aparezca mientras hacemos el cambio.
        if ! ln -sT -- "$src" "$dst"; then
            if [[ -n "$backup" ]]; then
                if mv -nT -- "$backup/original" "$dst" &&
                   [[ ! -e "$backup/original" && ! -L "$backup/original" ]]; then
                    rmdir -- "$backup" || true
                    log "Destino anterior restaurado: $dst"
                else
                    log "El contenido anterior sigue en: $backup/original"
                fi
            fi
            die "No se pudo crear el enlace: $dst"
        fi

        log "Enlace creado: $dst → $src"
    done
}

dotfiles_links_check() {
    local i src dst
    DOTFILES_LINK_FAILURES=0

    for i in "${!DOTFILES_LINK_SOURCES[@]}"; do
        src="${DOTFILES_LINK_SOURCES[i]}"
        dst="${DOTFILES_LINK_DESTINATIONS[i]}"
        if dotfiles_link_matches "$src" "$dst"; then
            log "OK enlace $dst"
        else
            log "FALTA enlace $dst → $src"
            DOTFILES_LINK_FAILURES=$((DOTFILES_LINK_FAILURES + 1))
        fi
    done

    (( DOTFILES_LINK_FAILURES == 0 ))
}
