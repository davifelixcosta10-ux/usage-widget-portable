# usage-widget — Portable Version

Versão portável do widget de uso (Quickshell/QML) que funciona em **qualquer compositor Wayland com layer-shell** e **principais distros Linux**.

## ✅ Compatibilidade

| Compositor | Layer-Shell | Status |
|------------|-------------|--------|
| Hyprland | ✅ wlroots | **Suportado** |
| Sway | ✅ wlroots | **Suportado** |
| KDE Plasma (KWin) | ✅ | **Suportado** |
| Wayfire | ✅ wlroots | **Suportado** |
| River | ✅ wlroots | **Suportado** |
| Niri | ✅ wlroots | **Suportado** |
| labwc | ✅ wlroots | **Suportado** |
| Weston | ✅ wlroots | **Suportado** |
| GNOME (Mutter) | ❌ | **Não suportado** |
| X11 / i3 / bspwm | ❌ | **Não suportado** |

| Distro | Instalação |
|--------|------------|
| Arch / Manjaro / EndeavourOS / Garuda | `install-arch.sh` (pacman + AUR) |
| Fedora / RHEL / CentOS / Rocky / AlmaLinux | `install-fedora.sh` (dnf + COPR) |
| Ubuntu / Debian / Mint / Pop / Zorin | `install-ubuntu.sh` (apt + Nix/binário) |
| NixOS | `install-nixos.sh` (configuration.nix) |
| openSUSE Tumbleweed / Leap | `install-opensuse.sh` (zypper) |

## 🚀 Instalação Rápida

```bash
# 1. Clonar/baixar os arquivos portáveis para ~/.local/share/usage-widget/portable/
# 2. Rodar o instalador mestre (detecta distro automaticamente)
bash ~/.local/share/usage-widget/portable/install.sh

# 3. Executar
usage-widget
```

## 📦 O que é instalado

```
~/.local/bin/
├── usage-widget          # Launcher principal (detecta ambiente, sobe coletores, inicia Quickshell)
├── sys-state             # Coletor de métricas do sistema (loop 3s, sub-cadências)
├── usage-state           # Coletor de cotas de agentes (cache inteligente, 60s)
└── zen-usage             # Contador de requisições OpenCode Zen (stdlib only)

~/.config/systemd/user/
└── usage-widget.service  # Systemd user service para auto-start no login

~/.config/usage-widget/
└── config.json           # Configuração (criada se não existir)
```

## ⚙️ Configuração (`~/.config/usage-widget/config.json`)

```json
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
```

### Auto-detecção (rodar `detect-env.sh`)

O script `detect-env.sh` detecta automaticamente:
- Interface de rede ativa (com rota default)
- Bateria (BAT* / battery)
- Adaptador AC (ADP* / AC*)
- Sensores térmicos (coretemp, k10temp, amdgpu, nvidia, acpitz, dell_smm, thinkpad)
- Gerenciador de pacotes por distro (checkupdates, dnf, apt, nix, zypper)

## 🔧 Uso Manual

```bash
# Coletor de sistema (uma vez)
sys-state --once

# Coletor de cotas (uma vez)
usage-state --once

# Contador Zen (uma vez)
zen-usage --json

# Verificar compatibilidade
bash ~/.local/share/usage-widget/portable/detect-env.sh
```

## 📊 Métricas Coletadas

### Sistema (`sys-state` - loop 3s)
- **CPU**: total, por core, load average (1/5/15min), uptime, frequência atual
- **RAM**: total, usado, livre, %, swap
- **Disco**: uso do mount point, I/O bytes
- **Rede**: download/upload total, **interface ativa**, **SSID**, **dBm**, **taxa TX**, **IP local**, **gateway**, **ping do gateway (1 pacote, 60s)**
- **Bateria**: %, plugged, tempo restante (se descarregando)
- **Temperaturas**: CPU, GPU, AMB (deduplicado, labels normalizados)
- **Top processos**: via `/proc/<pid>/stat` (3-4x mais rápido que psutil)
- **Atualizações**: checkupdates/dnf/apt/nix/zypper (3h)
- **Clima**: Open-Meteo com geocoding automático (30min)
- **Screen time**: Omarchy history.json (30s)

### Cotas (`usage-state` - loop 60s com cache)
- **Zen**: requisições 5h/24h, modelos 5h, **primeira vaga 5h**, **detecção 429** (banner + anel vermelho pulsando)
- **ccusage**: tokens por agente (Claude, Codex, etc.) - cache 5min
- **Futuros**: budget, outros provedores configuráveis

## 🎯 Atalho de Teclado

Configure no seu compositor (ex: Hyprland):

```ini
# ~/.config/hypr/hyprland.conf
bind = SUPER SHIFT, U, exec, usage-widget
```

## 🛠️ Desenvolvimento

```bash
# Testar coletores isoladamente
sys-state --once | jq .
usage-state --once | jq .
zen-usage --json | jq .

# Ver logs do Quickshell
tail -f /run/user/1000/quickshell/by-id/*/log.log | grep -v $'\0'

# Ver state files
cat /run/user/1000/usage-widget/system.json | jq .
cat ~/.cache/usage-widget/state.json | jq .
```

## ⚡ Otimizações de Performance

| Componente | Antes | Depois |
|------------|-------|--------|
| quickshell | ~1.0% CPU | **0.57%** (1.16% com anel 429 pulsando) |
| sys-state | ~1.0% CPU | **0.43%** |
| usage-state | ~1.4% CPU | **0.03%** |
| RSS (quickshell) | 209 MB | **142 MB** |
| PSS (quickshell) | 142 MB | **70 MB** |

Técnicas:
- Sub-cadências (3s/5s/10s/30s/60s/30min/3h)
- Cache Zen por mtime/tamanho do DB + expiração de janela
- `top_procs` via `/proc` direto (não psutil)
- `MALLOC_CONF` para jemalloc (devolve memória ao SO)
- Timers discretos para anéis pulsantes (evita 10-13% CPU do driver)

## 🐛 Troubleshooting

```bash
# Widget não abre
usage-widget  # ver saída do detect-env.sh

# Coletores não sobem
pgrep -af "sys-state|usage-state"
sys-state --once  # testar manual

# Zen não conta
zen-usage --json
ls -la ~/.local/share/opencode/opencode.db

# Temperaturas não aparecem
sensors
ls /sys/class/hwmon/hwmon*/name

# WiFi não detecta
iw dev
ip -4 route show default

# systemd service
systemctl --user status usage-widget
journalctl --user -u usage-widget -f
```

## 📄 Licença

MIT — Use, modifique, distribua livremente.
