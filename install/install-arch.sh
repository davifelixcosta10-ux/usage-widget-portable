#!/usr/bin/env bash
# Instalação para Arch Linux / Manjaro / EndeavourOS / Garuda / Artix
set -euo pipefail

echo "=== usage-widget — Instalação Arch-based ==="

# 1. Quickshell (AUR)
if ! command -v quickshell >/dev/null 2>&1; then
    echo "[1/6] Instalando quickshell (AUR)..."
    if command -v yay >/dev/null; then
        yay -S --needed --noconfirm quickshell-git
    elif command -v paru >/dev/null; then
        paru -S --needed --noconfirm quickshell-git
    else
        echo "   Instale yay ou paru primeiro, ou compile quickshell manualmente"
        exit 1
    fi
else
    echo "[1/6] quickshell já instalado"
fi

# 2. Python deps
echo "[2/6] python-psutil..."
sudo pacman -S --needed --noconfirm python-psutil

# 3. Ferramentas de sistema
echo "[3/6] Ferramentas base (iproute2, iputils, iw, lm_sensors, pacman-contrib)..."
sudo pacman -S --needed --noconfirm iproute2 iputils iw lm_sensors pacman-contrib

# 4. ccusage (opcional, para tokens de Claude/Codex)
if ! command -v ccusage >/dev/null 2>&1; then
    echo "[4/6] ccusage (opcional)..."
    if command -v npm >/dev/null; then
        npm install -g ccusage 2>/dev/null || echo "   Falhou (npm não configurado?). Instale manual: npm i -g ccusage"
    else
        echo "   npm não encontrado. Pulando ccusage."
    fi
else
    echo "[4/6] ccusage já instalado"
fi

# 5. zen-usage (nosso contador)
echo "[5/6] zen-usage..."
mkdir -p "$HOME/.local/bin"
cp "$HOME/.local/share/usage-widget/portable/zen-usage-portable" "$HOME/.local/bin/zen-usage"
chmod +x "$HOME/.local/bin/zen-usage"

# 6. Coletores portáveis
echo "[6/6] Coletores portáveis..."
cp "$HOME/.local/share/usage-widget/portable/sys-state-portable" "$HOME/.local/bin/sys-state"
cp "$HOME/.local/share/usage-widget/portable/usage-state-portable" "$HOME/.local/bin/usage-state"
cp "$HOME/.local/share/usage-widget/portable/usage-widget-portable" "$HOME/.local/bin/usage-widget"
chmod +x "$HOME/.local/bin/sys-state" "$HOME/.local/bin/usage-state" "$HOME/.local/bin/usage-widget"

# Config
mkdir -p "$HOME/.config/usage-widget"
if [[ ! -f "$HOME/.config/usage-widget/config.json" ]]; then
    cp "$HOME/.config/usage-widget/config.json" "$HOME/.config/usage-widget/config.json.bak" 2>/dev/null || true
    cat > "$HOME/.config/usage-widget/config.json" <<'CFGEOF'
{
  "widget": {
    "warn_at": 0.6,
    "critical_at": 0.85,
    "size": 44,
    "tab_width": 64,
    "panel_width": 420,
    "opacity": 1.0,
    "edge": "right",
    "edge_margin": 10,
    "auto_collapse_seconds": 20,
    "screen": "",
    "system": {
      "enabled": true,
      "refresh_seconds": 3,
      "mount": "/",
      "show": ["cpu", "mem", "disk", "net", "battery", "temp", "procs", "updates", "screentime", "weather"],
      "temp_warn": 70,
      "temp_crit": 85,
      "cpu_crit": 90,
      "battery_low": 20,
      "procs_top": 5
    },
    "weather": { "city": "auto", "refresh_minutes": 30 }
  },
  "future": [
    { "name": "Claude Code", "source": "ccusage", "agent": "claude" },
    { "name": "Codex", "source": "ccusage", "agent": "codex" },
    { "name": "OpenCode Go", "source": "budget", "monthly_usd": null }
  ]
}
CFGEOF
    echo "   config.json criado em ~/.config/usage-widget/config.json"
fi

echo
echo "✅ Instalação concluída!"
echo "   Execute: usage-widget"
echo "   Atalho: SUPER+SHIFT+U (configure no Hyprland/Wayland)"
