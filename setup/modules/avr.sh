#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Comprobando herramientas AVR..."
apt_install gcc-avr binutils-avr avr-libc avrdude make
log "AVR listo; la compilación y grabación usan el Makefile de cada proyecto."
