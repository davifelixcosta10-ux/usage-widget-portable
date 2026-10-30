#!/usr/bin/env bash
# Instalação para openSUSE Tumbleweed / Leap
set -euo pipefail

echo "=== usage-widget — Instalação openSUSE ==="

if ! command -v quickshell >/dev/null 2>&1; then
    echo "[1/6] quickshell — verifique se há pacote no OBS ou compile"
    echo "   zypper search quickshell"
else
    echo "[1/6] quickshell OK"
fi

echo "[2/6] python3-psutil..."
sudo zypper install -y python3-psutil

echo "[3/6] Ferramentas base..."
sudo zypper install -y iproute2 iputils iw lm_sensors

echo "[4/6] ccusage (opcional)..."
if command -v npm >/dev/null; then
    npm install -g ccusage 2>/dev/null || echo "   Instale manual: npm i -g ccusage"
fi

echo "[5/6] zen-usage + coletores..."
mkdir -p "$HOME/.local/bin"
cp "$HOME/.local/share/usage-widget/portable/zen-usage-portable" "$HOME/.local/bin/zen-usage"
cp "$HOME/.local/share/usage-widget/portable/sys-state-portable" "$HOME/.local/bin/sys-state"
cp "$HOME/.local/share/usage-widget/portable/usage-state-portable" "$HOME/.local/bin/usage-state"
cp "$HOME/.local/share/usage-widget/portable/usage-widget-portable" "$HOME/.local/bin/usage-widget"
chmod +x "$HOME/.local/bin"/{zen-usage,sys-state,usage-state,usage-widget}

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

echo "✅ Pronto! Execute: usage-widget"
