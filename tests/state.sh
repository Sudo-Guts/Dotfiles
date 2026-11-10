#!/usr/bin/env bash
set -Eeuo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

# Las pruebas solo escriben en su directorio temporal.
export XDG_STATE_HOME="$work/state"
source "$repo/lib/common.sh"
source "$repo/lib/state.sh"
dotfiles_state_load
[[ "$DOTFILES_WITH_STM32" == 0 && "$DOTFILES_WITH_RISCV" == 0 ]]
mkdir -p "$DOTFILES_STATE_DIR"
state="$DOTFILES_STATE_FILE"

fixture() {
    local schema="$1"
    printf 'schema=%s\napplied_commit=\npending_commit=\nriscv=1\ndocker=0\ngnome=1\n' "$schema" > "$state"
    if (( schema >= 2 )); then printf 'apache=1\nssh=0\n' >> "$state"; fi
    if (( schema >= 3 )); then printf 'avr=1\n' >> "$state"; fi
    if (( schema >= 4 )); then printf 'stm32=1\n' >> "$state"; fi
}

for schema in 1 2 3 4; do
    fixture "$schema"
    dotfiles_state_load
    [[ "$DOTFILES_WITH_RISCV" == 1 && "$DOTFILES_WITH_DOCKER" == 0 && "$DOTFILES_WITH_GNOME" == 1 ]]
    [[ "$DOTFILES_WITH_STM32" == "$((schema == 4))" ]]
    dotfiles_state_write
    [[ "$(head -n1 "$state")" == schema=4 ]]
    dotfiles_state_load
    [[ "$DOTFILES_WITH_RISCV" == 1 && "$DOTFILES_WITH_STM32" == "$((schema == 4))" ]]
    [[ "$DOTFILES_WITH_DOCKER" == 0 && "$DOTFILES_WITH_GNOME" == 1 && "$DOTFILES_WITH_SSH" == 0 ]]
    [[ "$DOTFILES_WITH_APACHE" == "$((schema >= 2))" && "$DOTFILES_WITH_AVR" == "$((schema >= 3))" ]]
    [[ "$(stat -c %a "$state")" == 600 ]]
done

fixture 4
sed -i 's/stm32=1/stm32=0/' "$state"
dotfiles_state_load
dotfiles_state_write
dotfiles_state_load
[[ "$DOTFILES_WITH_STM32" == 0 ]]

# Rechazar estados dañados sin reemplazarlos ni interpretar sus valores.
reject_fixture() {
    cp -- "$state" "$work/rejected.state"
    if (dotfiles_state_load) > "$work/rejected.log" 2>&1; then
        die "La prueba aceptó un estado inválido."
    fi
    cmp -- "$state" "$work/rejected.state"
}
fixture 4
sed -i 's/schema=4/schema=5/' "$state"
reject_fixture
fixture 4
sed -i '/^stm32=/d' "$state"
reject_fixture
fixture 4
sed -i 's/stm32=1/stm32=2/' "$state"
reject_fixture
fixture 3
printf 'stm32=1\n' >> "$state"
reject_fixture
fixture 4
printf 'stm32=0\n' >> "$state"
reject_fixture
fixture 4
printf 'unknown=1\n' >> "$state"
reject_fixture
fixture 4
printf '$(touch "%s")\n' "$work/executed" >> "$state"
reject_fixture
[[ ! -e "$work/executed" ]]

# Dos ramas divergentes: mantener la protección y migrar con respaldo explícito.
fixture_git() {
    command git -c core.hooksPath=/dev/null -c commit.gpgSign=false \
        -c user.name=Test -c user.email=test@example.invalid "$@"
}
fixture_git -c init.defaultBranch=main init --quiet --template= "$work/repository"
fixture_git -C "$work/repository" commit --quiet --allow-empty -m base
fixture_git -C "$work/repository" switch --quiet -c stm32
fixture_git -C "$work/repository" commit --quiet --allow-empty -m stm32
previous="$(fixture_git -C "$work/repository" rev-parse HEAD)"
fixture_git -C "$work/repository" switch --quiet main
fixture_git -C "$work/repository" commit --quiet --allow-empty -m main
target="$(fixture_git -C "$work/repository" rev-parse HEAD)"
# shellcheck disable=SC2034 # Las funciones cargadas de lib/state.sh usan esta raíz.
DOTFILES_ROOT="$work/repository"
fixture 4
sed -i "s/^applied_commit=$/applied_commit=$previous/" "$state"
cp -- "$state" "$work/original.state"
dotfiles_state_load
if (dotfiles_state_guard "$target") > "$work/guard.log" 2>&1; then
    die "La protección aceptó una rama divergente sin migración."
fi
dotfiles_state_migrate "$target" > "$work/migration.log"
[[ -z "$DOTFILES_APPLIED_COMMIT" && -z "$DOTFILES_PENDING_COMMIT" && "$DOTFILES_WITH_STM32" == 1 ]]
backups=("$DOTFILES_STATE_DIR"/install.state.backup.*)
[[ ${#backups[@]} == 1 ]]
cmp -- "${backups[0]}" "$work/original.state"
cmp -- "$state" "$work/original.state"
dotfiles_state_guard "$target"
DOTFILES_PENDING_COMMIT="$target"
dotfiles_state_write
dotfiles_state_load
[[ "$DOTFILES_PENDING_COMMIT" == "$target" && "$DOTFILES_WITH_STM32" == 1 && "$DOTFILES_WITH_AVR" == 1 ]]
printf 'Estado: formatos 1–4, validación y migración con respaldo verificados.\n'
