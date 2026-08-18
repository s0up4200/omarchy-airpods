import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Bar widget for AirPods: the AirPods icon with the lowest pod's battery, and a
// popup that switches noise control mode. All device work happens in bin/airpods,
// which holds one AAP channel open and prints a JSON line per change. Mode
// changes go back to it on stdin, because the AirPods obey only the client
// that holds the channel.
Panel {
  id: root
  moduleName: "soup.airpods"
  ipcTarget: "soup.airpods"

  // The script ships inside the plugin directory, so the widget works from any
  // checkout path without anything on PATH.
  readonly property string script: Qt.resolvedUrl("bin/airpods").toString().replace("file://", "")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool showBattery: setting("showBattery", true) === true
  readonly property bool autoPause: setting("autoPause", true) === true

  property bool connected: false
  property string address: ""
  property string mode: ""
  property string deviceName: ""
  property string model: ""
  property var battery: ({})
  property bool inEar: true
  // PipeWire names a Bluetooth sink after the MAC address, with underscores.
  readonly property bool isOutput: {
    var sink = Pipewire.defaultAudioSink
    if (!sink || !address) return false
    return String(sink.name || "").indexOf(address.replace(/:/g, "_")) >= 0
  }
  // Only a pod that we paused gets resumed, so a track the user stopped by
  // hand stays stopped when the pods go back in.
  property var pausedPlayer: null

  readonly property var modeOptions: [
    { value: "off", label: "Off" },
    { value: "transparency", label: "Transparency" },
    { value: "adaptive", label: "Adaptive" },
    { value: "anc", label: "ANC" }
  ]

  readonly property int lowestBattery: {
    var levels = []
    for (var key in battery)
      if (key !== "case" && battery[key] !== null) levels.push(battery[key])
    return levels.length ? Math.min.apply(null, levels) : -1
  }

  readonly property bool showsPercent: showBattery && lowestBattery >= 0 && !button.vertical

  function batteryText(component) {
    var level = battery ? battery[component] : undefined
    return (level === undefined || level === null) ? "—" : level + "%"
  }

  function applyStatus(text) {
    var data = {}
    try {
      data = JSON.parse(text)
    } catch (e) {
      connected = false
      return
    }
    connected = data.connected === true
    address = connected ? (data.address || "") : ""
    mode = connected ? (data.mode || "") : ""
    deviceName = connected ? (data.name || "") : ""
    model = connected ? (data.model || "") : ""
    battery = connected && data.battery ? data.battery : ({})

    var ear = connected ? data.ear : null
    if (ear) {
      // A pod out of your ear stops the music, even when the other one is
      // still in. A pod resting in the case does not: that is how you listen
      // with one pod.
      var wearing = ear.indexOf("out_of_ear") < 0 && ear.indexOf("in_ear") >= 0
      if (wearing !== inEar) {
        inEar = wearing
        applyEarChange()
      }
    }
  }

  // Apple's rule: take one pod out and the sound stops, put it back and it
  // continues. The ear packet arrives on the same stream as everything else.
  function applyEarChange() {
    // Pausing whenever a pod moves would also stop music that is playing on
    // the speakers while the AirPods sit connected in a pocket.
    if (!autoPause || !isOutput) return

    if (!inEar) {
      var players = Mpris.players ? Mpris.players.values : []
      pausedPlayer = players.find(function(player) {
        return player.isPlaying && player.canPause
      }) || null
      if (pausedPlayer) pausedPlayer.pause()
      return
    }

    if (pausedPlayer) {
      if (pausedPlayer.canPlay) pausedPlayer.play()
      pausedPlayer = null
    }
  }

  // Same persistence path the power widget uses for its percentage toggle:
  // write the value into this widget's inline entry in shell.json.
  function updateSetting(key, value) {
    var patch = {}
    patch[key] = value
    settings = Object.assign({}, settings, patch)
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, settings)
  }

  function setMode(value) {
    if (!connected) return
    // Paint the new mode straight away; the next line from the watcher confirms it.
    mode = value
    aap.write("mode " + value + "\n")
  }

  Process {
    id: aap
    command: [root.script, "watch"]
    running: true
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.applyStatus(line) } }
    onExited: {
      root.connected = false
      restart.start()
    }
  }

  Timer {
    id: restart
    interval: 2000
    onTriggered: aap.running = true
  }

  component SettingRow: Item {
    property string label: ""
    property bool checked: false
    signal toggled()

    width: parent ? parent.width : 0
    implicitHeight: Math.max(rowLabel.implicitHeight, rowSwitch.implicitHeight)

    Text {
      id: rowLabel
      text: parent.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    ToggleSwitch {
      id: rowSwitch
      checked: parent.checked
      foreground: root.foreground
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      onToggled: parent.toggled()
    }
  }

  // Bar.qml collapses a slot whose item is invisible, so the widget leaves the
  // bar with the pods, as the Agents panel does when it finds no usage. IPC
  // still opens the panel, which is how the settings stay reachable.
  visible: connected

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // WidgetButton rather than BarIconButton: the icon slot of the latter holds
  // a glyph or a drawn icon, never a drawn icon beside a label.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : barContent.implicitWidth + scaledHorizontalMargin * 2
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: root.deviceName || "AirPods"
    onPressed: function(b) { root.toggle() }

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(5)

      AirPodsIcon {
        iconSize: Style.bar.iconFont
        color: root.barForeground
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.showsPercent
        text: root.lowestBattery + "%"
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The floor holds the chip row inside the card. modeGroup.implicitWidth is
    // still 0 when this first binds, so it cannot be the only source of width.
    contentWidth: panel.fittedContentWidth(Math.max(Style.space(340), modeGroup.implicitWidth))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Sections stand apart here. Inside a section the header sits close to
        // the rows it introduces.
        spacing: Style.space(18)

        PanelHero {
          width: parent.width
          title: root.deviceName || "AirPods"
          meta: root.connected ? root.model : "Not connected"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.connected ? 1.0 : 0.5
          iconComponent: Component {
            AirPodsIcon {
              iconSize: Style.font.display
              color: root.foreground
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.connected

          PanelSectionHeader {
            width: parent.width
            text: "Battery"
          }

          Row {
            id: batteryRow
            width: parent.width
            spacing: Style.space(18)

            Repeater {
              model: [
                { label: "Left", key: "left" },
                { label: "Right", key: "right" },
                { label: "Case", key: "case" }
              ]

              delegate: Column {
                required property var modelData
                width: (batteryRow.width - batteryRow.spacing * 2) / 3
                spacing: Style.space(2)

                Text {
                  text: modelData.label
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: root.batteryText(modelData.key)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.connected

          PanelSectionHeader {
            width: parent.width
            text: "Noise control"
          }

          Row {
            id: modeGroup
            spacing: Style.spacing.md

            Repeater {
              model: root.modeOptions

              Button {
                required property var modelData

                text: modelData.label
                // `selected` is the whole state model. A cursor flag as well
                // would latch on and light a second chip.
                selected: modelData.value === root.mode
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.setMode(modelData.value)
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            width: parent.width
            text: "Settings"
          }

          SettingRow {
            label: "Pause when a pod comes out"
            checked: root.autoPause
            onToggled: root.updateSetting("autoPause", !root.autoPause)
          }

          SettingRow {
            label: "Battery percent in the bar"
            checked: root.showBattery
            onToggled: root.updateSetting("showBattery", !root.showBattery)
          }
        }
      }
    }
  }
}
