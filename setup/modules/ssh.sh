#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Instalando/comprobando el servidor OpenSSH..."
apt_install_module ssh
if [[ "$DOTFILES_PLATFORM_PACKAGE_FAMILY" == apt ]]; then
    log "OpenSSH listo. APT administra el servicio y puede iniciarlo al instalarlo."
else
    log "OpenSSH instalado. Administra el servicio sshd explicitamente."
fi
# El modulo no modifica la autenticacion, las claves existentes ni el firewall.
