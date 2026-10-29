#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
failures=0
pending() { log "$*"; failures=$((failures+1)); }
check_command() {
    local binary
    binary="$(command -v "$1" 2>/dev/null || true)"
    if [[ -z "$binary" && -n "${2:-}" && -x "$2" ]]; then binary="$2"; fi
    if [[ -n "$binary" ]]; then log "OK $1: $binary"
    else pending "FALTA $1"; fi
}
source "$DOTFILES_ROOT/lib/links.sh"
if ! dotfiles_links_check; then
    failures=$((failures + DOTFILES_LINK_FAILURES))
fi
source "$DOTFILES_ROOT/lib/state.sh"
dotfiles_state_load
source "$DOTFILES_ROOT/lib/modules.sh"
dotfiles_modules_select
for module in "${DOTFILES_SELECTED_MODULES[@]}"; do
    for cmd in ${DOTFILES_MODULE_COMMANDS[$module]}; do
        fallback=""
        if [[ "$cmd" == *:* ]]; then fallback="${cmd#*:}"; cmd="${cmd%%:*}"; fi
        check_command "$cmd" "$fallback"
    done
done
if [[ ! -f "$DOTFILES_STATE_FILE" ]]; then
    pending "Sin estado de instalación; ejecuta dotfiles install o update."
elif [[ "${DOTFILES_DOCTOR_ALLOW_PENDING:-0}" != 1 ]]; then
    if [[ -n "$DOTFILES_PENDING_COMMIT" ]]; then
        pending "Instalación pendiente: $DOTFILES_PENDING_COMMIT; repite install o update."
    fi
    head="$(dotfiles_git_head)"
    if [[ "$DOTFILES_APPLIED_COMMIT" != "$head" ]]; then
        pending "La revisión actual aún no figura como aplicada."
    fi
fi
log "Commit aplicado: ${DOTFILES_APPLIED_COMMIT:-ninguno}"
log "Módulos seleccionados: ${DOTFILES_SELECTED_MODULES[*]}"
if (( DOTFILES_WITH_STM32 )); then log "STM32: selección conservada para su rama independiente."; fi
log "GNOME: integración automática cuando hay una sesión GNOME activa"
if dotfiles_module_enabled avr; then
    if command -v avr-gcc >/dev/null &&
       ! printf '#include <avr/io.h>\n' | avr-gcc -mmcu=atmega328p -E -x c - >/dev/null 2>&1; then
        pending "AVR-LibC incompleta: avr/io.h para ATmega328P no se pudo procesar."
    fi
fi
if dotfiles_module_enabled docker; then
    if command -v docker >/dev/null; then
        docker compose version || pending "FALTA Docker Compose"
    fi
fi
if dotfiles_module_enabled gnome; then
    shortcut='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/guts-kitty/'
    schema='org.gnome.settings-daemon.plugins.media-keys'
    if ! command -v gsettings >/dev/null ||
       [[ "$(gsettings get "$schema" custom-keybindings)" != *"'$shortcut'"* ]] ||
       [[ "$(gsettings get "$schema.custom-keybinding:$shortcut" binding)" != "'<Control>t'" ]]; then
        pending "FALTA el atajo GNOME Ctrl+T para Kitty"
    fi
fi
if dotfiles_module_enabled zsh && command -v zsh >/dev/null; then
    while IFS= read -r -d '' file; do
        zsh -n "$file" || failures=$((failures+1))
    done < <(find "$DOTFILES_ROOT/config/zsh" -type f \( -name '*.zsh' -o -name .zshrc \) -print0)
fi
if dotfiles_module_enabled nvim && command -v nvim >/dev/null; then
    current="$(nvim --version | sed -n '1s/^NVIM v//p')"
    if ! binary_satisfies "$current" "$NVIM_MIN_VERSION" "$NVIM_VERSION"; then
        pending "Neovim $current no cumple la versión requerida."
    elif [[ "$(realpath -e -- "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" 2>/dev/null || true)" == "$DOTFILES_ROOT/config/nvim" &&
         -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim/lua/lazy/init.lua" ]]; then
        DOTFILES_NVIM_READONLY=1 DOTFILES_NVIM_CHECK_SCRIPT="$DOTFILES_ROOT/setup/nvim-doctor.lua" \
            nvim --headless -c 'lua
                local ok, err = pcall(function()
                    dofile(vim.env.DOTFILES_NVIM_CHECK_SCRIPT).check()
                end)
                if not ok then print(err); vim.cmd("cquit 1") end
            ' +qa || pending "Herramientas, plugins o parsers de Neovim incompletos."
    else
        pending "Enlaza Neovim e instala sus plugins antes de comprobarlos."
    fi
fi
if dotfiles_module_enabled kitty && command -v kitty >/dev/null; then
    current="$(kitty --version | awk '{print $2}')"
    binary_satisfies "$current" "$KITTY_MIN_VERSION" "$KITTY_VERSION" || pending "Kitty $current no cumple la versión requerida."
fi
if dotfiles_module_enabled serie && command -v serie >/dev/null; then
    current="$(serie --version 2>/dev/null | awk '$1 == "serie" { print $2; exit }' || true)"
    binary_satisfies "$current" "$SERIE_MIN_VERSION" "$SERIE_VERSION" || pending "Serie ${current:-desconocida} no cumple la versión requerida."
fi
if dotfiles_module_enabled treesitter-cli && command -v tree-sitter >/dev/null; then
    current="$(tree-sitter --version | awk '{print $2}')"
    binary_satisfies "$current" "$TREE_SITTER_MIN_VERSION" "$TREE_SITTER_VERSION" || pending "Tree-sitter $current no cumple la versión requerida."
fi
if dotfiles_module_enabled fonts; then
    font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/IosevkaNerdFont"
    if [[ ! -f "$font_dir/.version" ]] || ! version_ge "$(cat "$font_dir/.version")" "$NERD_FONT_VERSION" || [[ -z "$(find "$font_dir" -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit)" ]]; then
        pending "FALTA Iosevka Nerd Font $NERD_FONT_VERSION"
    fi
fi
log "Comprobación terminada: $failures pendientes. En Neovim: :checkhealth"
if (( failures > 0 )); then exit 1; fi
