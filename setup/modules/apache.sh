#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Instalando/comprobando Apache..."
apt_install apache2
log "Apache listo. APT administra el servicio y puede iniciarlo al instalarlo."
# Los sitios, permisos de /var/www y reglas del firewall se administran aparte.
