#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
module="$repo/setup/modules/gnome.sh"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

# =============================================================================
#  Integración GNOME sin modificar la configuración del usuario
# =============================================================================

mkdir -p "$work/bin" "$work/home"

cat > "$work/bin/kitty" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK

cat > "$work/bin/gsettings" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' "$*" >> "$GNOME_TEST_LOG"

if [[ "$1" == get ]]; then
    cat "$GNOME_TEST_SHORTCUTS"
elif [[ "$1" == set && "$3" == custom-keybindings ]]; then
    printf '%s\n' "$4" > "$GNOME_TEST_SHORTCUTS"
fi
MOCK

chmod +x "$work/bin/kitty" "$work/bin/gsettings"

log="$work/gsettings.log"
shortcuts="$work/shortcuts.txt"
original="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/existing/"
shortcut="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/guts-kitty/"
printf "['%s']\n" "$original" > "$shortcuts"

run_session() {
    env HOME="$work/home" PATH="$work/bin:$PATH" XDG_CURRENT_DESKTOP="$1" GNOME_TEST_LOG="$log" GNOME_TEST_SHORTCUTS="$shortcuts" bash "$module"
}

# Un escritorio ajeno a GNOME no debe cambiar sus preferencias.
run_session XFCE
[[ ! -e "$log" ]] || { printf '[error] GNOME: se modificó un escritorio diferente.\n' >&2; exit 1; }

# En GNOME se conserva el acceso personalizado existente.
run_session 'ubuntu:GNOME'
grep -Fq "set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$shortcut binding <Control>t" "$log"
grep -Fq "set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$shortcut name Kitty" "$log"

# Al instalar de nuevo no deben duplicarse entradas.
run_session GNOME
python3 - "$shortcuts" "$original" "$shortcut" <<'PYTHON'
import ast
import pathlib
import sys

items = ast.literal_eval(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert items.count(sys.argv[2]) == 1, "Se perdió el atajo existente"
assert items.count(sys.argv[3]) == 1, "El atajo de Kitty está duplicado"
PYTHON

# La selección del manifiesto debe activar GNOME sin un flag adicional.
env XDG_CURRENT_DESKTOP=GNOME bash -c 'source "$1/lib/common.sh"; source "$1/lib/modules.sh"; dotfiles_modules_select; [[ " ${DOTFILES_SELECTED_MODULES[*]} " == *" gnome "* ]]' bash "$repo"
env XDG_CURRENT_DESKTOP=XFCE bash -c 'source "$1/lib/common.sh"; source "$1/lib/modules.sh"; dotfiles_modules_select; [[ " ${DOTFILES_SELECTED_MODULES[*]} " != *" gnome "* ]]' bash "$repo"

printf 'GNOME: detección de escritorio, atajo, conservación e idempotencia verificadas.\n'
