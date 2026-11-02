// usage-widget — interface Quickshell (layer-shell)
// Lê os coletores portáveis:
//   /run/user/<uid>/usage-widget/system.json   (sys-state)
//   ~/.cache/usage-widget/state.json           (usage-state)
//
// Atalho: SUPER+SHIFT+U   |   Config: ~/.config/usage-widget/config.json

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  // ─── Configuração ─────────────────────────────────────────────────────────
  property var cfg: ({
    widget: {
      size: 46,
      tab_width: 50,
      panel_width: 396,
      opacity: 0.78,
      edge: "right",
      edge_margin: 12,
      auto_collapse_seconds: 20,
      warn_at: 0.6,
      critical_at: 0.85,
      system: { procs_top: 5, temp_warn: 70, temp_crit: 85, battery_low: 20 },
      weather: {}
    }
  })

  readonly property var wcfg: (cfg && cfg.widget) ? cfg.widget : ({})
  readonly property var scfg: wcfg.system ? wcfg.system : ({})
  readonly property int stripSize: wcfg.size ? wcfg.size : 44
  readonly property int tabH: wcfg.tab_width ? wcfg.tab_width : 48
  readonly property int panelW: wcfg.panel_width ? wcfg.panel_width : 380
  readonly property real glass: (wcfg.opacity !== undefined) ? wcfg.opacity : 0.82
  readonly property int edgeMargin: (wcfg.edge_margin !== undefined) ? wcfg.edge_margin : 12
  readonly property int collapseSecs: wcfg.auto_collapse_seconds ? wcfg.auto_collapse_seconds : 20
  readonly property int procsTop: scfg.procs_top ? scfg.procs_top : 5
  readonly property real warnAt: wcfg.warn_at ? wcfg.warn_at : 0.6
  readonly property real critAt: wcfg.critical_at ? wcfg.critical_at : 0.85

  // ─── Paleta gruvbox ───────────────────────────────────────────────────────
  readonly property color bg: "#1d2021"
  readonly property color bg1: "#282828"
  readonly property color bg2: "#3c3836"
  readonly property color bg3: "#504945"
  readonly property color fg: "#ebdbb2"
  readonly property color dim: "#bdae93"
  readonly property color gray: "#928374"
  readonly property color red: "#fb4934"
  readonly property color orange: "#fe8019"
  readonly property color yellow: "#fabd2f"
  readonly property color green: "#b8bb26"
  readonly property color aqua: "#8ec07c"
  readonly property color blue: "#83a598"
  readonly property color purple: "#d3869b"

  readonly property string mono: "FiraCode Nerd Font Mono"

  // ─── Estado ───────────────────────────────────────────────────────────────
  property var sys: ({})
  property var usage: ({})
  property string hostname: ""
  property string kernel: ""
  property string distro: ""

  property int activeTab: 0          // -1 = recolhido
  property bool hovered: false

  readonly property bool expanded: activeTab >= 0

  readonly property var tabs: [
    { icon: "\uf0e7", label: "Agentes", short: "IA",   accent: "#fabd2f" },
    { icon: "\uf2db", label: "Sistema", short: "Sis",  accent: "#8ec07c" },
    { icon: "\uf085", label: "Procs",   short: "Proc", accent: "#fe8019" },
    { icon: "\uf05a", label: "Info",    short: "Info", accent: "#83a598" }
  ]

  readonly property color accent: activeTab >= 0 ? tabs[activeTab].accent : yellow

  // Tela alvo
  readonly property var shownScreen: {
    var name = wcfg.screen ? String(wcfg.screen) : ""
    var list = Quickshell.screens
    if (!list || list.length === 0) return null
    if (name !== "") {
      for (var i = 0; i < list.length; i++)
        if (list[i].name === name) return list[i]
    }
    return list[0]
  }

  readonly property int screenH: shownScreen ? shownScreen.height : 800

  // ─── Helpers ──────────────────────────────────────────────────────────────
  function clamp01(v) { return Math.max(0, Math.min(1, v)) }
  function num(v, def) { return (v === undefined || v === null) ? def : v }

  function pctColor(p) {
    if (p === undefined || p === null || p < 0) return blue
    if (p >= critAt) return red
    if (p >= warnAt) return orange
    return green
  }

  function fmtBytes(b) {
    if (b === undefined || b === null || isNaN(b)) return "—"
    var g = b / 1073741824
    if (g >= 1) return g.toFixed(1) + " GB"
    return (b / 1048576).toFixed(0) + " MB"
  }

  function fmtRate(bps) {
    if (!bps || bps < 1) return "0 B/s"
    var units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var i = 0, v = bps
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
    return v.toFixed(i > 0 ? 1 : 0) + " " + units[i]
  }

  function fmtUptime(s) {
    if (!s) return "—"
    var d = Math.floor(s / 86400)
    var h = Math.floor((s % 86400) / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  function fmtTime(iso) {
    if (!iso) return ""
    var m = String(iso).match(/T(\d\d:\d\d)/)
    return m ? m[1] : ""
  }

  // Altura de cada linha (compartilhada entre cálculo e delegate)
  function rowHeight(md) {
    if (!md) return 0
    if (!md) return 0
    if (md.kind === "sep") return 8
    if (md.kind === "header") return 24
    if (md.kind === "big") return 58
    if (md.kind === "foot") return 18
    if (md.sub && md.sub !== "") return 40
    if (md.pct !== undefined && md.pct >= 0) return 34
    return 25
  }

  readonly property int rowsHeight: {
    var total = 0
    for (var i = 0; i < rows.length; i++) total += rowHeight(rows[i])
    return total
  }

  // Altura do cartão: compacta, nunca maior que 72% da tela
  readonly property int cardH: {
    if (activeTab < 0) return stripSize !== 0 ? tabs.length * tabH + 20 : 220
    var raw = 52 + rowsHeight + 12
    var maxH = Math.round(screenH * 0.68)
    return Math.max(220, Math.min(raw, maxH))
  }

  // ─── Modelos por aba ──────────────────────────────────────────────────────
  // Modelo filtrado: só itens válidos
  readonly property var validRows: (function() {
    var r = root.rows
    if (!r || !r.length) return []
    var out = []
    for (var i = 0; i < r.length; i++) {
      if (r[i] && typeof r[i] === "object") out.push(r[i])
    }
    return out
  })()

  readonly property var rows: {
    var s = sys || ({})
    var u = usage || ({})
    var tab = activeTab
    var out = []

    // ── Agentes ────────────────────────────────────────────────────────────
    if (tab === 0) {
      var zen = u.zen ? u.zen : ({})
      out.push({ kind: "header", label: "OPENCODE ZEN",
                 value: zen.ok === false ? "offline" : "online" })
      out.push({ kind: "big", label: "Requisições · janela 5h",
                 value: String(num(zen.used, 0)),
                 sub: zen.detail ? String(zen.detail) : "",
                 color: zen.blocked ? red : yellow,
                 alert: zen.blocked === true })
      out.push({ kind: "metric", label: "Próxima vaga",
                 value: zen.next_free ? String(zen.next_free) : "—",
                 color: aqua })
      out.push({ kind: "metric", label: "Bloqueio 429",
                 value: zen.blocked ? (zen.blocked_at ? String(zen.blocked_at) : "agora") : "nenhum",
                 color: zen.blocked ? red : green })

      out.push({ kind: "sep" })
      var provs = u.providers ? u.providers : []
      out.push({ kind: "header", label: "PROVEDORES", value: String(provs.length) })
      for (var i = 0; i < provs.length; i++) {
        var p = provs[i]
        var used = num(p.used, 0)
        var lim = p.limit
        var pct = (p.pct !== undefined && p.pct !== null) ? Number(p.pct) / 100 : -1
        var value = String(used)
        if (lim !== undefined && lim !== null && lim > 0) value = used + " / " + lim
        if (p.window) value = value + " · " + p.window
        out.push({
          kind: "metric",
          label: String(p.label ? p.label : p.id),
          badge: p.icon ? String(p.icon) : "",
          value: value,
          pct: pct,
          sub: p.detail ? String(p.detail) : "",
          color: p.blocked ? red : (pct >= 0 ? root.pctColor(pct) : blue)
        })
      }

      out.push({ kind: "sep" })
      out.push({ kind: "metric", label: "Tokens hoje",
                 value: u.today && u.today.total !== undefined ? String(u.today.total) : "—",
                 color: purple })
      out.push({ kind: "foot", label: "Atualizado", value: fmtTime(u.generated_at) })
    }

    // ── Sistema ────────────────────────────────────────────────────────────
    else if (tab === 1) {
      var cpu = s.cpu ? s.cpu : ({})
      var mem = s.mem ? s.mem : ({})
      var disk = s.disk ? s.disk : ({})
      var net = s.net ? s.net : ({})
      var load = s.load ? s.load : ({})
      var bat = s.battery ? s.battery : null

      out.push({ kind: "header", label: "DESEMPENHO", value: fmtTime(s.generated_at) })
      out.push({ kind: "metric", label: "CPU", value: Number(num(cpu.total, 0)).toFixed(1) + "%",
                 pct: num(cpu.total, 0) / 100, color: root.pctColor(num(cpu.total, 0) / 100) })
      if (cpu.cores && cpu.cores.length)
        out.push({ kind: "metric", label: "Núcleos",
                   value: cpu.cores.map(function (c) { return Math.round(c) }).join(" · "),
                   color: dim })
      out.push({ kind: "metric", label: "RAM", value: fmtBytes(mem.used) + " / " + fmtBytes(mem.total),
                 pct: num(mem.pct, 0) / 100, color: root.pctColor(num(mem.pct, 0) / 100) })
      out.push({ kind: "metric", label: "Swap", value: fmtBytes(mem.swap_used) + " / " + fmtBytes(mem.swap_total),
                 pct: num(mem.swap_pct, 0) / 100, color: root.pctColor(num(mem.swap_pct, 0) / 100) })
      out.push({ kind: "metric", label: "Disco /", value: fmtBytes(disk.used) + " / " + fmtBytes(disk.total),
                 pct: num(disk.pct, 0) / 100, color: root.pctColor(num(disk.pct, 0) / 100) })

      out.push({ kind: "sep" })
      out.push({ kind: "header", label: "TEMPERATURA / BATERIA", value: "" })
      var temps = s.temps ? s.temps : []
      for (var t = 0; t < temps.length; t++) {
        var tp = temps[t]
        var tv = num(tp.temp, 0)
        var tcrit = num(scfg.temp_crit, 85)
        out.push({ kind: "metric", label: String(tp.label),
                   value: tv.toFixed(1) + " °C",
                   pct: root.clamp01(tv / Math.max(1, tcrit)),
                   color: tv >= tcrit ? red : (tv >= num(scfg.temp_warn, 70) ? orange : aqua) })
      }
      if (bat) {
        var bp = num(bat.pct, 0)
        out.push({ kind: "metric", label: bat.plugged ? "Bateria (AC)" : "Bateria",
                   value: bp.toFixed(0) + "%",
                   pct: bp / 100,
                   color: bp <= num(scfg.battery_low, 20) ? red : green })
      }

      out.push({ kind: "sep" })
      out.push({ kind: "header", label: "REDE", value: net.ssid ? String(net.ssid) : (net.iface ? String(net.iface) : "—") })
      out.push({ kind: "metric", label: "Download", value: fmtRate(num(net.down_bps, 0)),
                 color: num(net.down_bps, 0) > 8000 ? green : gray })
      out.push({ kind: "metric", label: "Upload", value: fmtRate(num(net.up_bps, 0)),
                 color: num(net.up_bps, 0) > 8000 ? blue : gray })
      if (net.ip) out.push({ kind: "metric", label: "IP", value: String(net.ip), color: dim })
      if (net.gateway)
        out.push({ kind: "metric", label: "Gateway",
                   value: String(net.gateway) + (net.ping_ms !== undefined && net.ping_ms !== null ? " · " + net.ping_ms + " ms" : ""),
                   color: dim })
      if (net.dbm !== undefined && net.dbm !== null)
        out.push({ kind: "metric", label: "Sinal", value: String(net.dbm) + " dBm",
                   pct: root.clamp01((num(net.dbm, -100) + 90) / 60),
                   color: num(net.dbm, -100) > -60 ? green : (num(net.dbm, -100) > -75 ? orange : red) })

      var wea = s.weather
      if (wea && wea.temp !== undefined) {
        out.push({ kind: "sep" })
        out.push({ kind: "header", label: "CLIMA", value: wea.city ? String(wea.city) : "" })
        out.push({ kind: "metric", label: "Agora", value: Number(wea.temp).toFixed(1) + " °C", color: yellow })
        out.push({ kind: "metric", label: "Mín / Máx",
                   value: Number(wea.min).toFixed(0) + "° / " + Number(wea.max).toFixed(0) + "°", color: dim })
      }

      out.push({ kind: "sep" })
      out.push({ kind: "metric", label: "Load 1/5/15",
                 value: load.avg ? load.avg.map(function (v) { return Number(v).toFixed(2) }).join("  ") : "—",
                 color: dim })
      out.push({ kind: "metric", label: "Uptime", value: fmtUptime(load.uptime_s), color: dim })
      out.push({ kind: "metric", label: "Atualizações",
                 value: s.updates && s.updates.count !== undefined ? String(s.updates.count) : "—",
                 color: s.updates && s.updates.count > 0 ? orange : green })
    }

    // ── Processos ──────────────────────────────────────────────────────────
    else if (tab === 2) {
      var procs = (s.procs ? s.procs : []).slice(0, procsTop)
      out.push({ kind: "header", label: "TOP PROCESSOS", value: "CPU" })
      for (var j = 0; j < procs.length; j++) {
        var pr = procs[j]
        out.push({
          kind: "metric",
          label: String(pr.name),
          value: Number(pr.cpu).toFixed(1) + "%",
          pct: root.clamp01(Number(pr.cpu) / 100),
          sub: "PID " + pr.pid + " · " + fmtBytes(pr.mem),
          color: root.pctColor(Number(pr.cpu) / 100)
        })
      }
      out.push({ kind: "sep" })
      out.push({ kind: "metric", label: "Load 1/5/15",
                 value: s.load && s.load.avg ? s.load.avg.map(function (v) { return Number(v).toFixed(2) }).join("  ") : "—",
                 color: dim })
      out.push({ kind: "foot", label: "Atualizado", value: fmtTime(s.generated_at) })
    }

    // ── Info ───────────────────────────────────────────────────────────────
    else if (tab === 3) {
      var scr = root.shownScreen
      out.push({ kind: "header", label: "SISTEMA", value: "usage-widget" })
      out.push({ kind: "metric", label: "Host", value: hostname !== "" ? hostname : "—", color: dim })
      out.push({ kind: "metric", label: "Distro", value: distro !== "" ? distro : "—", color: dim })
      out.push({ kind: "metric", label: "Kernel", value: kernel !== "" ? kernel : "—", color: dim })
      out.push({ kind: "metric", label: "Compositor", value: "Hyprland", color: dim })
      out.push({ kind: "metric", label: "Tela",
                 value: scr ? (scr.name + " · " + scr.width + "×" + scr.height) : "—", color: dim })
      out.push({ kind: "metric", label: "Uptime", value: fmtUptime(s.load ? s.load.uptime_s : 0), color: dim })
      out.push({ kind: "metric", label: "Coleta",
                 value: s.generated_at ? String(s.generated_at).replace("T", " ") : "—", color: dim })
      out.push({ kind: "sep" })
      out.push({ kind: "header", label: "ATALHOS", value: "" })
      out.push({ kind: "metric", label: "Abrir / fechar", value: "SUPER+SHIFT+U", color: yellow })
      out.push({ kind: "metric", label: "Trocar aba", value: "clique no ícone", color: dim })
      out.push({ kind: "sep" })
      out.push({ kind: "foot", label: "usage-widget-portable", value: "QML v1.0" })
    }

    return out
  }

  // ─── Ações ────────────────────────────────────────────────────────────────
  function toggleTab(i) {
    activeTab = (activeTab === i) ? -1 : i
    if (activeTab >= 0) collapseTimer.restart()
  }

  Timer {
    id: collapseTimer
    interval: root.collapseSecs * 1000
    repeat: false
    onTriggered: { if (!root.hovered) root.activeTab = -1 }
  }

  // ─── Arquivos de estado ───────────────────────────────────────────────────
  FileView {
    id: cfgFile
    path: Quickshell.env("HOME") + "/.config/usage-widget/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || ""))
        if (parsed && typeof parsed === "object") root.cfg = parsed
      } catch (e) { console.warn("usage-widget: config inválida", e) }
    }
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/usage-widget/system.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || ""))
        root.sys = parsed && typeof parsed === "object" ? parsed : ({})
      } catch (e) { /* arquivo sendo reescrito */ }
    }
    onLoadFailed: root.sys = ({})
  }

  FileView {
    path: Quickshell.env("HOME") + "/.cache/usage-widget/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || ""))
        root.usage = parsed && typeof parsed === "object" ? parsed : ({})
      } catch (e) { /* arquivo sendo reescrito */ }
    }
    onLoadFailed: root.usage = ({})
  }

  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: root.hostname = String(text() || "").trim()
  }

  FileView {
    path: "/proc/sys/kernel/osrelease"
    printErrors: false
    onLoaded: root.kernel = String(text() || "").trim()
  }

  FileView {
    path: "/etc/os-release"
    printErrors: false
    onLoaded: {
      var t = String(text() || "")
      var m = t.match(/^PRETTY_NAME="?([^"\n]+)"?/m)
      root.distro = m ? m[1] : ""
    }
  }

  // ─── Janela ───────────────────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      required property var modelData

      screen: modelData
      visible: modelData === root.shownScreen

      anchors {
        top: true
        right: true
      }

      margins {
        top: Math.max(8, Math.round((modelData.height - root.cardH) / 2))
        right: root.edgeMargin
      }

      implicitWidth: root.stripSize + (root.expanded ? root.panelW + 10 : 0)
      implicitHeight: root.cardH

      color: "transparent"
      surfaceFormat.opaque: false
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "usage-widget"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Behavior on implicitWidth { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
      Behavior on implicitHeight { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
      Behavior on margins.top { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

      HoverHandler {
        onHoveredChanged: {
          root.hovered = hovered
          if (hovered) collapseTimer.stop()
          else if (root.activeTab >= 0) collapseTimer.restart()
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // ── Cartão de conteúdo ──────────────────────────────────────────
        Rectangle {
          id: card

          width: root.expanded ? root.panelW : 0
          height: root.cardH
          visible: width > 1
          radius: 14
          color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, root.glass)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.07)

          // Fio de acento no topo
          Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 0
            width: parent.width - 28
            height: 2
            radius: 1
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
          }

          Column {
            id: cardCol
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 00
            anchors.bottomMargin: 10
            spacing: 0

            // Cabeçalho
            Item {
              width: parent.width
              height: 30

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                radius: 8
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)

                Text {
                  anchors.centerIn: parent
                  text: root.activeTab >= 0 ? root.tabs[root.activeTab].icon : ""
                  color: root.accent
                  font.family: root.mono
                  font.pixelSize: 12
                }
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 36
                anchors.verticalCenter: parent.verticalCenter
                text: root.activeTab >= 0 ? root.tabs[root.activeTab].label : ""
                color: root.fg
                font.family: root.mono
                font.pixelSize: 14
                font.bold: true
              }

              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22; radius: 6
                color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "\uf00d"
                  color: root.gray
                  font.family: root.mono
                  font.pixelSize: 9
                }

                MouseArea {
                  id: closeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = -1
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Lista com scroll
            Flickable {
              width: parent.width
              height: Math.max(0, parent.height - 32)
              contentHeight: list.height
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: list
                width: parent.width
                topPadding: 4

                Repeater {
                  model: root.validRows

                                  delegate: Item {
                    id: self
                    required property var modelData
                    readonly property var md: modelData
                    readonly property bool valid: md !== undefined && md !== null && typeof md === "object"
                    readonly property string kind: valid ? (md.kind || "") : ""
                    readonly property bool hasBar: valid && md.pct !== undefined && md.pct >= 0
                    readonly property bool hasSub: valid && md.sub && md.sub !== ""
                    readonly property color tint: valid ? (parent.parent.tint || root.fg) : root.fg
                    readonly property string label: valid ? (md.label || "") : ""
                    readonly property string value: valid ? (md.value || "") : ""
                    readonly property string sub: valid ? (md.sub || "") : ""
                    readonly property string badge: valid ? (parent.parent.badge || "") : ""
                    readonly property var pct: valid ? md.pct : undefined
                    readonly property var alert: valid ? md.alert : false

                    width: list.width
                    height: valid ? root.rowHeight(md) : 0

                    // Separador
                    Rectangle {
                        visible: valid && kind === "sep"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.055)
                    }

                    // Cabeçalho de seção
                    Item {
                        visible: valid && kind === "header"
                        anchors.fill: parent

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 10; radius: 1.5
                            color: root.accent
                            opacity: 0.8
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.valid ? parent.parent.label : ""
                            color: root.accent
                            font.family: root.mono
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 1.1
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.valid ? parent.parent.value : ""
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                    }

                    // Número grande
                    Item {
                        visible: valid && kind === "big"
                        anchors.fill: parent

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: parent.valid ? parent.parent.label : ""
                            color: root.dim
                            font.family: root.mono
                            font.pixelSize: 9
                            font.letterSpacing: 0.3
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            text: parent.valid ? parent.parent.value : "" || "0"
                            color: root.fg
                            font.family: root.mono
                            font.pixelSize: 30
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 30
                            text: parent.valid ? parent.parent.sub : ""
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 9
                        }

                        Rectangle {
                            visible: valid && alert === true
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            width: 7; height: 7; radius: 3.5
                            color: root.red

                            SequentialAnimation on opacity {
                                running: parent.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 650 }
                                NumberAnimation { to: 1.0; duration: 650 }
                            }
                        }
                    }

                    // Rodapé
                    Item {
                        visible: valid && kind === "foot"
                        anchors.fill: parent

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: parent.valid ? parent.parent.label : ""
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            text: parent.valid ? parent.parent.value : ""
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                    }

                    // Linha de métrica
                    Item {
                        visible: valid && kind === "metric"
                        anchors.fill: parent

                        // Badge (letra do provedor)
                        Rectangle {
                            visible: valid && badge !== ""
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            width: 15; height: 15; radius: 5
                            color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)

                            Text {
                                anchors.centerIn: parent
                                text: badge
                                color: tint
                                font.family: root.mono
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        Text {
                            id: lbl
                            anchors.left: parent.left
                            anchors.leftMargin: (valid && badge !== "") ? 21 : 0
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            width: parent.width - val.width - lbl.leftMargin - 12
                            text: parent.valid ? parent.parent.label : ""
                            color: parent.valid && parent.parent.hasSub ? root.fg : root.dim
                            font.family: root.mono
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                        Text {
                            id: val
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            text: parent.valid ? parent.parent.value : ""
                            color: hasBar || hasSub ? tint : root.fg
                            font.family: root.mono
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Text {
                            visible: hasSub
                            anchors.left: parent.left
                            anchors.leftMargin: (valid && badge !== "") ? 21 : 0
                            anchors.top: parent.top
                            anchors.topMargin: 17
                            text: parent.valid ? parent.parent.sub : ""
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 9
                        }

                        Rectangle {
                            visible: hasBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.07)

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * root.clamp01(pct)
                                color: tint

                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                    // Cabeçalho de seção
                    Item {
                      visible: valid && kind === "header"
                      anchors.fill: parent

                      Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 10; radius: 1.5
                        color: root.accent
                        opacity: 0.8
                      }

                      Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.valid ? parent.parent.label : ""
                        color: root.accent
                        font.family: root.mono
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1.1
                      }

                      Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.valid ? parent.parent.value : ""
                        color: root.gray
                        font.family: root.mono
                        font.pixelSize: 8
                      }
                    }

                    // Número grande
                    Item {
                      visible: valid && kind === "big"
                      anchors.fill: parent

                      Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: parent.valid ? parent.parent.label : ""
                        color: root.dim
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.3
                      }

                      Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 00
                        text: parent.valid ? parent.parent.value : "" || "0"
                        color: root.fg
                        font.family: root.mono
                        font.pixelSize: 30
                        font.bold: true
                      }

                      Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 30
                        text: parent.valid ? parent.parent.sub : ""
                        color: root.gray
                        font.family: root.mono
                        font.pixelSize: 9
                      }

                      Rectangle {
                        visible: valid && alert === true
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        width: 7; height: 7; radius: 3.5
                        color: root.red

                        SequentialAnimation on opacity {
                          running: parent.visible
                          loops: Animation.Infinite
                          NumberAnimation { to: 0.2; duration: 650 }
                          NumberAnimation { to: 1.0; duration: 650 }
                        }
                      }
                    }

                    // Rodapé
                    Item {
                      visible: valid && kind === "foot"
                      anchors.fill: parent

                      Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: parent.valid ? parent.parent.label : ""
                        color: root.gray
                        font.family: root.mono
                        font.pixelSize: 8
                      }
                      Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: parent.valid ? parent.parent.value : ""
                        color: root.gray
                        font.family: root.mono
                        font.pixelSize: 8
                      }
                    }

                    // Linha de métrica (Loader: só carrega para itens "metric")
                    Loader {
                      id: metricLoader
                      visible: (parent.valid === true) && (parent.kind === "metric")
                      anchors.fill: parent
                      sourceComponent: (parent.kind === "metric") ? metricContent : null

                      Component {
                        id: metricContent
                        Item {
                          anchors.fill: parent

                          // Badge (letra do provedor)
                          Rectangle {
                            visible: parent.badge !== ""
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            width: 15; height: 15; radius: 5
                            color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, 0.16)

                            Text {
                              anchors.centerIn: parent
                              text: parent.badge !== "" ? String(parent.badge) : ""
                              color: parent.tint
                              font.family: root.mono
                              font.pixelSize: 7
                              font.bold: true
                            }
                          }

                          Text {
                            id: lbl
                            anchors.left: parent.left
                            anchors.leftMargin: (parent.badge !== "") ? 21 : 0
                            anchors.top: parent.top
                            anchors.topMargin: 0
                            width: parent.width - val.width - lbl.leftMargin - 12
                            text: parent.label
                            color: parent.hasSub ? root.fg : root.dim
                            font.family: root.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                          }

                          Text {
                            id: val
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 0
                            text: parent.value
                            color: parent.hasBar || parent.hasSub ? parent.tint : root.fg
                            font.family: root.mono
                            font.pixelSize: 9
                            font.bold: true
                          }

                          Text {
                            visible: parent.hasSub
                            anchors.left: parent.left
                            anchors.leftMargin: (parent.badge !== "") ? 21 : 0
                            anchors.top: parent.top
                            anchors.topMargin: 07
                            text: parent.sub
                            color: root.gray
                            font.family: root.mono
                            font.pixelSize: 8
                          }

                          Rectangle {
                            visible: parent.hasBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.07)

                            Rectangle {
                              height: parent.height
                              radius: parent.radius
                              width: parent.width * root.clamp01(parent.pct)
                              color: parent.tint

                              Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                Item { width: 1; height: 4 }
              }
            }
          }
        }

        // ── Tira de abas ────────────────────────────────────────────────
        Rectangle {
          id: strip

          width: root.stripSize
          height: root.cardH
          radius: 14
          color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, root.glass)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.07)

          Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Repeater {
              model: root.tabs

              delegate: Rectangle {
                id: tabBtn
                required property var modelData
                required property int index

                width: root.stripSize - 8
                height: root.tabH * 0.78
                radius: 10
                color: (root.activeTab === index) ? Qt.rgba(1, 1, 1, 0.08)
                     : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                Behavior on color { ColorAnimation { duration: 120 } }

                // Barra de acento (aba ativa)
                Rectangle {
                  visible: root.activeTab === index
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 2
                  width: 2
                  height: parent.height - 16
                  radius: 1
                  color: modelData.accent
                }

                Text {
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: -4
                  text: modelData.icon
                  color: (root.activeTab === index) ? modelData.accent : root.dim
                  font.family: root.mono
                  font.pixelSize: 14
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 5
                  text: modelData.short
                  color: (root.activeTab === index) ? root.fg : root.gray
                  font.family: root.mono
                  font.pixelSize: 7
                }

                // Alerta 429
                Rectangle {
                  visible: index === 0 && !!(root.usage.zen && root.usage.zen.blocked === true)
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.topMargin: 6
                  anchors.rightMargin: 6
                  width: 5; height: 5; radius: 2.5
                  color: root.red
                }

                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleTab(index)
                }
              }
            }
          }
        }
      }
    }
  }
