#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cli="$repo/bin/dotfiles"

# =============================================================================
#  Contrato público de la interfaz de comandos
# =============================================================================

fail() {
    printf '[error] Prueba de CLI: %s\n' "$1" >&2
    exit 1
}

expect_rejection() {
    local description="$1"
    local output
    shift

    if output="$(bash "$cli" "$@" 2>&1)"; then
        fail "$description: se aceptó una combinación inválida"
    fi
    [[ "$output" == *'[error]'* ]] || fail "$description: falta un mensaje de error"
}

help_text="$(bash "$cli" help)"
[[ -n "$help_text" ]] || fail 'La ayuda está vacía'
[[ "$(bash "$cli")" == "$help_text" ]] || fail 'La ayuda predeterminada es diferente'
[[ "$(bash "$cli" --help)" == "$help_text" ]] || fail '--help es diferente'
[[ "$(bash "$cli" -h)" == "$help_text" ]] || fail '-h es diferente'
[[ "$(bash "$cli" install --help)" == "$help_text" ]] || fail 'install --help es diferente'
[[ "$help_text" == *"En sesiones GNOME configura Ctrl+T para Kitty de forma automática."* ]] || fail "Falta documentar la integración GNOME predeterminada"

for option in --with-avr --with-riscv --with-docker --with-gnome --with-apache --with-ssh --change-shell --migrate-state; do
    [[ "$help_text" == *"$option"* ]] || fail "La ayuda no documenta $option"
done

# El parser debe rechazar entradas inválidas sin iniciar instalaciones.
expect_rejection 'Opción desconocida' install --with-unknown
expect_rejection 'Opción desconocida en update' update --with-unknown
expect_rejection 'Flag opcional vacío' install --with-
expect_rejection 'HDL pertenece al núcleo' install --with-hdl
expect_rejection 'Python pertenece al núcleo' install --with-python
expect_rejection 'Cambio de shell en update' update --change-shell
expect_rejection 'Migración en update' update --migrate-state
expect_rejection 'Argumentos de doctor' doctor --with-avr
expect_rejection 'Argumentos de link' link --with-avr
expect_rejection 'Comando desconocido' comando-desconocido

printf 'CLI: ayuda, opciones existentes y rechazo de argumentos inválidos verificados.\n'
