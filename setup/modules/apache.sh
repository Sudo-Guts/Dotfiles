#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Instalando/comprobando Apache..."
apt_install_module apache
if [[ "$DOTFILES_PLATFORM_PACKAGE_FAMILY" == apt ]]; then
    log "Apache listo. APT administra el servicio y puede iniciarlo al instalarlo."
else
    log "Apache instalado. Administra el servicio httpd explicitamente."
fi
# Los sitios, permisos de /var/www y reglas del firewall se administran aparte.
