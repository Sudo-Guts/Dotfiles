#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

# La copia evita escribir en el repositorio incluso al probar destinos inválidos.
fixture_repo="$work/repository"
test_home="$work/home with spaces"
test_config="$work/config with spaces"
mkdir -p "$fixture_repo" "$test_config/nvim" "$test_config/ruff" "$test_config/unmanaged" "$test_home/.local/bin"
cp -R -- "$repo/bin" "$repo/lib" "$repo/setup" "$repo/config" "$fixture_repo/"

fail() {
    printf '[error] Prueba de enlaces: %s\n' "$1" >&2
    exit 1
}

run_link() {
    env HOME="$1" XDG_CONFIG_HOME="$2" DOTFILES_ALLOW_ROOT=1 bash "$fixture_repo/bin/dotfiles" link
}

backup_for() {
    local -a backups=("$1".backup.*/original)
    [[ ${#backups[@]} == 1 ]] || fail "Se esperaba un respaldo único de $1"
    printf '%s\n' "${backups[0]}"
}

assert_link() {
    [[ -L "$2" && "$(realpath -e -- "$2")" == "$1" ]] || fail "Enlace incorrecto: $2"
}

# Respaldos y repetición sobre configuraciones existentes.
printf 'zsh anterior\n' > "$test_home/.zshrc"
printf 'nvim anterior\n' > "$test_config/nvim/init.lua"
printf 'ruff anterior\n' > "$test_config/ruff/ruff.toml"
printf 'comando anterior\n' > "$test_home/.local/bin/dotfiles"
printf 'archivo ajeno\n' > "$test_config/unmanaged/keep.txt"
ln -s -- "$work/missing-kitty" "$test_config/kitty"

run_link "$test_home" "$test_config" > "$work/first.log"
assert_link "$fixture_repo/config/zsh/.zshrc" "$test_home/.zshrc"
assert_link "$fixture_repo/config/nvim" "$test_config/nvim"
assert_link "$fixture_repo/config/kitty" "$test_config/kitty"
assert_link "$fixture_repo/bin/dotfiles" "$test_home/.local/bin/dotfiles"
assert_link "$fixture_repo/config/ruff/ruff.toml" "$test_config/ruff/ruff.toml"

[[ "$(cat -- "$(backup_for "$test_home/.zshrc")")" == 'zsh anterior' ]] || fail 'Se perdió la configuración Zsh'
[[ "$(cat -- "$(backup_for "$test_config/nvim")/init.lua")" == 'nvim anterior' ]] || fail 'Se perdió el directorio Neovim'
[[ "$(cat -- "$(backup_for "$test_config/ruff/ruff.toml")")" == 'ruff anterior' ]] || fail 'Se perdió la configuración Ruff'
[[ "$(cat -- "$(backup_for "$test_home/.local/bin/dotfiles")")" == 'comando anterior' ]] || fail 'Se perdió el comando anterior'
[[ "$(readlink -- "$(backup_for "$test_config/kitty")")" == "$work/missing-kitty" ]] || fail 'Se perdió el enlace roto anterior'

find "$test_home" "$test_config" -type d -name '*.backup.*' -print | LC_ALL=C sort > "$work/backups-before.txt"
find "$test_home" "$test_config" -type l -printf '%p %i %l\n' | LC_ALL=C sort > "$work/links-before.txt"
run_link "$test_home" "$test_config" > "$work/second.log"
find "$test_home" "$test_config" -type d -name '*.backup.*' -print | LC_ALL=C sort > "$work/backups-after.txt"
find "$test_home" "$test_config" -type l -printf '%p %i %l\n' | LC_ALL=C sort > "$work/links-after.txt"
cmp -- "$work/backups-before.txt" "$work/backups-after.txt"
cmp -- "$work/links-before.txt" "$work/links-after.txt"
[[ "$(cat -- "$test_config/unmanaged/keep.txt")" == 'archivo ajeno' ]] || fail 'Se modificó un archivo ajeno'

# La validación completa debe rechazar el cambio antes de sustituir ~/.zshrc.
protected_home="$work/protected-home"
mkdir -p "$protected_home"
printf 'conservar antes de validar\n' > "$protected_home/.zshrc"
cp -- "$protected_home/.zshrc" "$work/protected-original"
if run_link "$protected_home" "$fixture_repo/config" > "$work/protected.log" 2>&1; then
    fail 'Se aceptó un destino dentro del repositorio'
fi
[[ ! -L "$protected_home/.zshrc" ]] || fail 'La validación modificó el primer destino'
cmp -- "$protected_home/.zshrc" "$work/protected-original"

mv -- "$fixture_repo/config/ruff/ruff.toml" "$work/ruff-saved.toml"
if run_link "$protected_home" "$protected_home/.config" > "$work/missing-source.log" 2>&1; then
    fail 'Se aceptó un origen inexistente'
fi
[[ ! -L "$protected_home/.zshrc" ]] || fail 'El origen ausente dejó una instalación parcial'
cmp -- "$protected_home/.zshrc" "$work/protected-original"
mv -- "$work/ruff-saved.toml" "$fixture_repo/config/ruff/ruff.toml"

# Un fallo al crear el enlace debe restaurar el archivo que se había respaldado.
rollback_home="$work/rollback-home"
mkdir -p "$rollback_home" "$work/fail-bin"
printf 'restaurar si falla ln\n' > "$rollback_home/.zshrc"
cp -- "$rollback_home/.zshrc" "$work/rollback-original"
cat > "$work/fail-bin/ln" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$work/fail-bin/ln"
if env HOME="$rollback_home" XDG_CONFIG_HOME="$rollback_home/.config" DOTFILES_ALLOW_ROOT=1 PATH="$work/fail-bin:$PATH" bash "$fixture_repo/bin/dotfiles" link > "$work/rollback.log" 2>&1; then
    fail 'Se ignoró el fallo de ln'
fi
[[ ! -L "$rollback_home/.zshrc" ]] || fail 'No se restauró el archivo anterior'
cmp -- "$rollback_home/.zshrc" "$work/rollback-original"
rollback_backups=("$rollback_home"/.zshrc.backup.*)
[[ ${#rollback_backups[@]} == 0 ]] || fail 'Quedó un respaldo vacío tras restaurar'

printf 'Enlaces: respaldos, rutas con espacios, idempotencia, validación previa y recuperación verificados.\n'
