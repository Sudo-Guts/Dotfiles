#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

# Node/npm ejecutan e instalan Pyright; las herramientas Python viven en Mason.
apt_install python3 python3-venv nodejs npm
require_command python3
require_command node
require_command npm
node_version="$(node -p 'process.versions.node')"
version_ge "$node_version" 14.0.0 || die "Pyright requiere Node >= 14; tienes $node_version. Actualiza Node y repite la instalación."
log "Python listo; Pyright, Ruff y debugpy se preparan con nvim-tools."
