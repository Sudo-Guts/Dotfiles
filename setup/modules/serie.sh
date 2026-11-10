#!/usr/bin/env bash

# Instala Serie desde sus binarios oficiales en ~/.local/bin/serie.
# Las versiones y sumas SHA-256 se definen en setup/versions.sh.
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

current="$(serie --version 2>/dev/null | awk '$1 == "serie" { print $2; exit }' || true)"
if [[ -n "$current" ]] &&
   binary_satisfies "$current" "$SERIE_MIN_VERSION" "$SERIE_VERSION"; then
    log "Serie $current satisface la versión requerida."
    exit 0
fi

case "$(uname -m)" in
    x86_64)
        arch="x86_64"
        checksum="$SERIE_SHA256_X86_64"
        ;;
    aarch64|arm64)
        arch="aarch64"
        checksum="$SERIE_SHA256_AARCH64"
        ;;
    *) die "Arquitectura Serie no soportada: $(uname -m)" ;;
esac

require_command tar
require_command sha256sum
expected="${SERIE_VERSION#v}"
work="$(mktemp -d)"
staged=""
trap 'rm -rf -- "$work"; if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi' EXIT
archive="$work/serie.tar.gz"

log "Descargando Serie $SERIE_VERSION para Linux $arch..."
download \
    "https://github.com/lusingander/serie/releases/download/$SERIE_VERSION/serie-$expected-$arch-unknown-linux-musl.tar.gz" \
    "$archive"

printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die "El paquete de Serie no coincide con la suma SHA-256 esperada."

tar --no-same-owner -xzf "$archive" -C "$work"
binary="$(find "$work" -type f -name serie -print -quit)"
[[ -n "$binary" ]] || die "El paquete descargado no contiene el ejecutable serie."
chmod 0755 "$binary"
downloaded="$("$binary" --version | awk '$1 == "serie" { print $2; exit }')"
[[ "$downloaded" == "$expected" ]] || die "Versión inesperada de Serie: $downloaded; se esperaba $expected."
version_ge "$downloaded" "$SERIE_MIN_VERSION" || die "La versión solicitada de Serie no cumple el mínimo."

# Sustituir el destino solo después de validar la descarga y el ejecutable.
mkdir -p "$HOME/.local/bin"
staged="$(mktemp -- "$HOME/.local/bin/.serie.XXXXXX")"
install -m 0755 -- "$binary" "$staged"
mv -fT -- "$staged" "$HOME/.local/bin/serie"
staged=""
log "Serie $downloaded instalada. Usa glpick dentro de un repositorio Git en Kitty."
