#!/usr/bin/env bash
# Instalador mestre — detecta distro e roda o script apropriado
set -euo pipefail

echo "=== usage-widget — Instalador Universal ==="
echo

# Detectar distro
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="$ID"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    echo "❌ Não foi possível detectar a distro (/etc/os-release não encontrado)"
    exit 1
fi

echo "Distro detectada: $DISTRO_ID (família: $DISTRO_LIKE)"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$DISTRO_ID" in
    arch|manjaro|endeavouros|garuda|artix|manjaro-arm)
        exec "$SCRIPT_DIR/install/install-arch.sh"
        ;;
    fedora|rhel|centos|rocky|almalinux|nobara)
        exec "$SCRIPT_DIR/install/install-fedora.sh"
        ;;
    ubuntu|debian|linuxmint|pop|zorin|elementary|kali|parrot|deepin)
        exec "$SCRIPT_DIR/install/install-ubuntu.sh"
        ;;
    nixos)
        exec "$SCRIPT_DIR/install/install-nixos.sh"
        ;;
    opensuse*|suse)
        exec "$SCRIPT_DIR/install/install-opensuse.sh"
        ;;
    *)
        # Tentar por família
        case "$DISTRO_LIKE" in
            *arch*) exec "$SCRIPT_DIR/install/install-arch.sh" ;;
            *fedora*|*rhel*) exec "$SCRIPT_DIR/install/install-fedora.sh" ;;
            *debian*|*ubuntu*) exec "$SCRIPT_DIR/install/install-ubuntu.sh" ;;
            *suse*|*opensuse*) exec "$SCRIPT_DIR/install/install-opensuse.sh" ;;
            *)
                echo "❌ Distro não suportada automaticamente: $DISTRO_ID"
                echo "   Scripts disponíveis:"
                ls "$SCRIPT_DIR/install/"install-*.sh | sed 's|.*/||'
                echo
                echo "   Rode manualmente: bash ~/.local/share/usage-widget/portable/install/install-<distro>.sh"
                exit 1
                ;;
        esac
        ;;
esac
