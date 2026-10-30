#!/usr/bin/env bash
# Instalação para Ubuntu / Debian / Linux Mint / Pop!_OS / Zorin / elementary
set -euo pipefail

echo "=== usage-widget — Instalação Ubuntu/Debian ==="

# 1. Quickshell (sem pacote oficial — compilar ou usar binário)
if ! command -v quickshell >/dev/null 2>&1; then
    echo "[1/6] Quickshell não tem pacote .deb oficial."
    echo "   Opções:"
    echo "   a) Compilar: https://github.com/quickshell/quickshell#building"
    echo "   b) Baixar AppImage/build do GitHub Releases"
    echo "   c) Usar Nix: nix profile install nixpkgs#quickshell"
    read -rp "   Tentar instalar via Nix? (s/N) " yn
    if [[ "$yn" =~ ^[Ss]$ ]] && command -v nix >/dev/null; then
        nix profile install nixpkgs#quickshell
    else
        echo "   ⚠  Instale quickshell manualmente antes de continuar."
        exit 1
    fi
else
    echo "[1/6] quickshell já instalado"
fi

# 2. Python deps
echo "[2/6] python3-psutil..."
sudo apt update && sudo apt install -y python3-psutil

# 3. Ferramentas
echo "[3/6] Ferramentas base..."
sudo apt install -y iproute2 iputils-ping iw lm-sensors

# 4. ccusage
if ! command -v ccusage >/dev/null 2>&1; then
    echo "[4/6] ccusage (opcional)..."
    if command -v npm >/dev/null; then
        npm install -g ccusage 2>/dev/null || echo "   Falhou. Instale manual: npm i -g ccusage"
    else
        echo "   npm não encontrado. sudo apt install nodejs npm"
    fi
fi

# 5. zen-usage
echo "[5/6] zen-usage..."
mkdir -p "$HOME/.local/bin"
cp "$HOME/.local/share/usage-widget/portable/zen-usage-portable" "$HOME/.local/bin/zen-usage"
chmod +x "$HOME/.local/bin/zen-usage"

# 6. Coletores
echo "[6/6] Coletores portáveis..."
cp "$HOME/.local/share/usage-widget/portable/sys-state-portable" "$HOME/.local/bin/sys-state"
cp "$HOME/.local/share/usage-widget/portable/usage-state-portable" "$HOME/.local/bin/usage-state"
cp "$HOME/.local/share/usage-widget/portable/usage-widget-portable" "$HOME/.local/bin/usage-widget"
chmod +x "$HOME/.local/bin/sys-state" "$HOME/.local/bin/usage-state" "$HOME/.local/bin/usage-widget"

# Config
mkdir -p "$HOME/.config/usage-widget"
if [[ ! -f "$HOME/.config/usage-widget/config.json" ]]; then
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
fi

echo
echo "✅ Instalação base concluída!"
echo "   ⚠  Lembre-se: quickshell precisa ser instalado separadamente no Ubuntu/Debian"
echo "   Execute: usage-widget"
