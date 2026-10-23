#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Comprobando dependencias de integración STM32..."
apt_install make bear libusb-1.0-0

# clangd necesita sus encabezados básicos también al analizar firmware ARM.
require_command clangd
clangd_dir="$(dirname -- "$(realpath -e -- "$(command -v clangd)")")"
headers=("$clangd_dir"/../lib/clang/*/include/stddef.h)
if [[ ! -f "${headers[0]}" ]]; then
    major="$(clangd --version | sed -n 's/.*clangd version \([0-9][0-9]*\)\..*/\1/p' | head -n1)"
    [[ -n "$major" ]] || die "No se pudo identificar la versión de clangd para preparar sus encabezados."
    apt_install "libclang-common-$major-dev"
fi

log "Se reutilizan STM32CubeIDE (GNU Arm) y STM32CubeProgrammer instalados."
log "Si no se encuentran, configura STM32_CUBEIDE y STM32_PROGRAMMER_CLI; consulta README."
