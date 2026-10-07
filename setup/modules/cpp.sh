#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Comprobando herramientas C/C++..."
apt_install build-essential bear cmake ninja-build pkg-config clangd clang-format gdb
