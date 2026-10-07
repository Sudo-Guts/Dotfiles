#!/usr/bin/env bash
# Sincronizar antes de ejecutar los instaladores; reiniciar con el código nuevo.
dotfiles_update_sync() {
    local head branch upstream remote candidate
    head="$(dotfiles_git_head)"
    dotfiles_git_clean
    branch="$(git -C "$DOTFILES_ROOT" symbolic-ref --quiet --short HEAD)" || die "Update requiere una rama, no un HEAD separado."
    upstream="$(git -C "$DOTFILES_ROOT" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null)" || die "La rama $branch no tiene upstream configurado."
    remote="$(git -C "$DOTFILES_ROOT" config --get "branch.$branch.remote")"
    if [[ "$remote" != . ]]; then
        log "Buscando cambios de $upstream..."
        git -C "$DOTFILES_ROOT" fetch -- "$remote"
    fi
    dotfiles_git_clean
    [[ "$(dotfiles_git_head)" == "$head" && "$(git -C "$DOTFILES_ROOT" symbolic-ref --short HEAD)" == "$branch" ]] || die "La rama cambió durante la actualización; vuelve a intentarlo."
    candidate="$(git -C "$DOTFILES_ROOT" rev-parse --verify "$upstream")"
    if git -C "$DOTFILES_ROOT" merge-base --is-ancestor "$head" "$candidate"; then
        dotfiles_state_guard "$candidate"
    elif git -C "$DOTFILES_ROOT" merge-base --is-ancestor "$candidate" "$head"; then
        dotfiles_state_guard "$head"
        log "La rama ya contiene el upstream; se conservan los commits locales."
    else
        die "La rama y su upstream divergieron; update no los fusionará."
    fi
    git -C "$DOTFILES_ROOT" merge --ff-only "$upstream"
    dotfiles_git_clean
    DOTFILES_UPDATE_APPLY_COMMIT="$(dotfiles_git_head)"
    export DOTFILES_UPDATE_APPLY_COMMIT
    export DOTFILES_UPDATE_REPO="$DOTFILES_ROOT"
    log "Aplicando la revisión $DOTFILES_UPDATE_APPLY_COMMIT con su código actualizado..."
    exec bash "$DOTFILES_ROOT/bin/dotfiles" update "$@"
}
