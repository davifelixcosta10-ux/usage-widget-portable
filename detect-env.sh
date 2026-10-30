#!/usr/bin/env bash
# Detecta ambiente gráfico, distro e dependências para o usage-widget
# Uso: source detect-env.sh && check_compatibility

set -euo pipefail

# ---------- Variáveis globais ----------
COMPOSITOR=""
DISTRO=""
DISTRO_FAMILY=""
WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}"
HAS_LAYER_SHELL=0
HAS_QUICKSHELL=0
MISSING_DEPS=()
RECOMMENDATIONS=()

# ---------- Utilitários ----------
log_info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
log_ok()   { echo -e "\033[1;32m[OK]\033[0m   $*"; }
log_warn() { echo -e "\033[1;33m[AVISO]\033[0m $*"; }
log_err()  { echo -e "\033[1;31m[ERRO]\033[0m  $*"; }

# ---------- Detectar Wayland / Compositor ----------
detect_compositor() {
    if [[ -n "$WAYLAND_DISPLAY" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        # Tentar identificar pelo PID do compositor ou variáveis conhecidas
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            COMPOSITOR="Hyprland"
        elif [[ -n "${SWAYSOCK:-}" ]]; then
            COMPOSITOR="Sway"
        elif [[ -n "${WAYFIRE_SOCKET:-}" ]]; then
            COMPOSITOR="Wayfire"
        elif [[ -n "${RIVER_SOCKET:-}" ]]; then
            COMPOSITOR="River"
        elif [[ -n "${NIRI_SOCKET:-}" ]]; then
            COMPOSITOR="Niri"
        elif [[ -n "${LABWC_SOCKET:-}" ]]; then
            COMPOSITOR="labwc"
        elif pgrep -x "kwin_wayland" >/dev/null 2>&1; then
            COMPOSITOR="KWin (KDE Plasma)"
        elif pgrep -x "mutter" >/dev/null 2>&1; then
            COMPOSITOR="Mutter (GNOME)"
        elif pgrep -x "weston" >/dev/null 2>&1; then
            COMPOSITOR="Weston"
        else
            COMPOSITOR="Wayland (desconhecido)"
        fi
        
        # Verificar suporte a layer-shell (wlr-layer-shell-unstable-v1)
        # A maioria dos compositores wlroots + KWin suportam; Mutter/GNOME NÃO
        case "$COMPOSITOR" in
            Hyprland|Sway|Wayfire|River|Niri|labwc|"KWin (KDE Plasma)"|Weston)
                HAS_LAYER_SHELL=1
                log_ok "Compositor: $COMPOSITOR — suporta layer-shell"
                ;;
            "Mutter (GNOME)")
                HAS_LAYER_SHELL=0
                log_warn "Compositor: GNOME (Mutter) — NÃO suporta layer-shell"
                RECOMMENDATIONS+=("GNOME não suporta layer-shell. Use uma extensão como 'Panel' ou considere Hyprland/Sway/KDE.")
                ;;
            *)
                log_warn "Compositor: $COMPOSITOR — suporte a layer-shell desconhecido"
                ;;
        esac
    else
        log_err "Não está rodando em Wayland (XDG_SESSION_TYPE=$XDG_SESSION_TYPE, WAYLAND_DISPLAY=$WAYLAND_DISPLAY)"
        log_err "O usage-widget requer Wayland + layer-shell (Hyprland, Sway, KDE, Wayfire, River, Niri, labwc, Weston)"
        return 1
    fi
}

# ---------- Detectar Distro ----------
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_FAMILY="${ID_LIKE:-$ID}"
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/fedora-release ]]; then
        DISTRO="fedora"
    elif [[ -f /etc/nixos/configuration.nix ]]; then
        DISTRO="nixos"
    else
        DISTRO="unknown"
    fi
    log_info "Distro detectada: $DISTRO (família: $DISTRO_FAMILY)"
}

# ---------- Verificar Quickshell ----------
check_quickshell() {
    if command -v quickshell >/dev/null 2>&1; then
        local ver=$(quickshell --version 2>&1 | head -1)
        HAS_QUICKSHELL=1
        log_ok "Quickshell encontrado: $ver"
    else
        log_err "Quickshell NÃO encontrado no PATH"
        MISSING_DEPS+=("quickshell")
        case "$DISTRO" in
            arch|manjaro|endeavouros|garuda)
                RECOMMENDATIONS+=("Instale: sudo pacman -S quickshell (ou quickshell-git do AUR)")
                ;;
            fedora)
                RECOMMENDATIONS+=("Instale: sudo dnf copr enable erikreider/quickshell && sudo dnf install quickshell")
                ;;
            nixos)
                RECOMMENDATIONS+=("Adicione ao configuration.nix: programs.quickshell.enable = true;")
                ;;
            ubuntu|debian|linuxmint|pop|zorin)
                RECOMMENDATIONS+=("Sem pacote oficial. Compile do fonte ou use: pipx install quickshell (se disponível)")
                ;;
            opensuse*)
                RECOMMENDATIONS+=("Instale: sudo zypper install quickshell (verifique repos)")
                ;;
            *)
                RECOMMENDATIONS+=("Compile do fonte: https://github.com/quickshell/quickshell")
                ;;
        esac
    fi
}

# ---------- Verificar dependências Python ----------
check_python_deps() {
    local missing=()
    python3 -c "import psutil" 2>/dev/null || missing+=("python3-psutil")
    python3 -c "import sqlite3" 2>/dev/null || missing+=("python3-sqlite3")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Dependências Python faltando: ${missing[*]}"
        MISSING_DEPS+=("${missing[@]}")
        case "$DISTRO" in
            arch|manjaro*) RECOMMENDATIONS+=("sudo pacman -S python-psutil") ;;
            fedora) RECOMMENDATIONS+=("sudo dnf install python3-psutil") ;;
            ubuntu|debian*) RECOMMENDATIONS+=("sudo apt install python3-psutil") ;;
            nixos) RECOMMENDATIONS+=("Adicione python3Packages.psult ao environment.systemPackages") ;;
            opensuse*) RECOMMENDATIONS+=("sudo zypper install python3-psutil") ;;
        esac
    else
        log_ok "Python deps: psutil, sqlite3 OK"
    fi
}

# ---------- Verificar ferramentas de sistema ----------
check_system_tools() {
    local tools=("ip" "ping" "iw" "lsblk" "df" "free" "uptime" "cat" "grep" "awk" "sed" "date")
    local missing=()
    for t in "${tools[@]}"; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    
    # Sensores (opcional)
    if ! command -v sensors >/dev/null 2>&1; then
        log_warn "lm-sensors não encontrado — temperaturas não funcionarão"
        RECOMMENDATIONS+=("Instale lm-sensors: pacman -S lm_sensors / apt install lm-sensors / dnf install lm_sensors")
    else
        log_ok "sensors (lm-sensors) OK"
    fi
    
    # Verificador de updates por distro
    case "$DISTRO" in
        arch|manjaro|endeavouros|garuda|artix)
            command -v checkupdates >/dev/null 2>&1 || { log_warn "checkupdates não encontrado"; RECOMMENDATIONS+=("sudo pacman -S pacman-contrib"); }
            ;;
        fedora|rhel|centos|rocky|almalinux)
            command -v dnf >/dev/null 2>&1 && log_ok "dnf para updates OK" || RECOMMENDATIONS+=("dnf não encontrado")
            ;;
        ubuntu|debian|linuxmint|pop|zorin|elementary)
            command -v apt >/dev/null 2>&1 && log_ok "apt para updates OK" || RECOMMENDATIONS+=("apt não encontrado")
            ;;
        nixos)
            command -v nix >/dev/null 2>&1 && log_ok "nix para updates OK" || RECOMMENDATIONS+=("nix não encontrado")
            ;;
        opensuse*|suse)
            command -v zypper >/dev/null 2>&1 && log_ok "zypper para updates OK" || RECOMMENDATIONS+=("zypper não encontrado")
            ;;
    esac
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "Ferramentas base faltando: ${missing[*]}"
        MISSING_DEPS+=("${missing[@]}")
    else
        log_ok "Ferramentas base OK"
    fi
}

# ---------- Auto-detectar interface de rede ----------
detect_network_iface() {
    local iface=""
    # Preferir interface com rota default
    iface=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    if [[ -n "$iface" ]]; then
        log_ok "Interface de rede detectada: $iface"
        echo "$iface"
        return
    fi
    # Fallback: primeira interface up não-loopback
    iface=$(ip -4 -o link show up 2>/dev/null | awk -F': ' '!/lo/ {print $2; exit}')
    if [[ -n "$iface" ]]; then
        log_warn "Sem rota default; usando primeira interface up: $iface"
        echo "$iface"
        return
    fi
    log_warn "Nenhuma interface de rede detectada"
    echo ""
}

# ---------- Auto-detectar bateria ----------
detect_battery() {
    local bat_path=""
    for p in /sys/class/power_supply/BAT*/ /sys/class/power_supply/battery/; do
        if [[ -d "$p" ]]; then
            bat_path="$p"
            break
        fi
    done
    if [[ -n "$bat_path" ]]; then
        log_ok "Bateria detectada: $bat_path"
        echo "$bat_path"
    else
        log_warn "Nenhuma bateria detectada (desktop ou sysfs diferente)"
        echo ""
    fi
}

# ---------- Auto-detectar adaptador AC ----------
detect_ac_adapter() {
    for p in /sys/class/power_supply/ADP*/ /sys/class/power_supply/AC*/ /sys/class/power_supply/ac/; do
        if [[ -f "$p/online" ]]; then
            log_ok "Adaptador AC detectado: $p"
            echo "$p"
            return
        fi
    done
    log_warn "Adaptador AC não detectado via sysfs"
    echo ""
}

# ---------- Verificar sensores térmicos ----------
detect_thermal_sensors() {
    local found=0
    for d in /sys/class/hwmon/hwmon*/; do
        if [[ -f "${d}name" ]]; then
            local name=$(cat "${d}name" 2>/dev/null || echo "")
            if [[ "$name" =~ (coretemp|k10temp|amdgpu|nouveau|nvidia|acpitz|dell_smm|thinkpad) ]]; then
                log_ok "Sensor térmico: $name em $d"
                found=1
            fi
        fi
    done
    if [[ $found -eq 0 ]]; then
        log_warn "Nenhum sensor térmico conhecido encontrado (coretemp, k10temp, amdgpu, etc.)"
    fi
}

# ---------- Função principal ----------
check_compatibility() {
    echo "========================================="
    echo "  usage-widget — Verificação de Ambiente"
    echo "========================================="
    echo
    
    detect_compositor || return 1
    detect_distro
    check_quickshell
    check_python_deps
    check_system_tools
    detect_thermal_sensors
    
    echo
    echo "--- Auto-detecção para config.json ---"
    local iface=$(detect_network_iface)
    local bat=$(detect_battery)
    local ac=$(detect_ac_adapter)
    
    echo
    echo "========================================="
    if [[ $HAS_LAYER_SHELL -eq 1 && $HAS_QUICKSHELL -eq 1 && ${#MISSING_DEPS[@]} -eq 0 ]]; then
        log_ok "AMBIENTE COMPATÍVEL — o widget deve funcionar"
        return 0
    else
        log_err "AMBIENTE INCOMPATÍVEL OU FALTANDO DEPENDÊNCIAS"
        if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
            echo
            echo "Recomendações:"
            for r in "${RECOMMENDATIONS[@]}"; do
                echo "  - $r"
            done
        fi
        return 1
    fi
}

# Exportar variáveis para uso pelo instalador
export COMPOSITOR DISTRO DISTRO_FAMILY HAS_LAYER_SHELL HAS_QUICKSHELL
