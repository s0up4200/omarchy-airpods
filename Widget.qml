import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget for AirPods: headphone icon with the lowest pod's battery, and a
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

  readonly property bool showBattery: setting("showBattery", true) === true

  property bool connected: false
  property string mode: ""
  property string deviceName: ""
  property string model: ""
  property var battery: ({})

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

  readonly property bool showsPercent: showBattery && connected
    && lowestBattery >= 0 && !button.vertical

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
    mode = connected ? (data.mode || "") : ""
    deviceName = connected ? (data.name || "") : ""
    model = connected ? (data.model || "") : ""
    battery = connected && data.battery ? data.battery : ({})
  }

  function setMode(value) {
    if (!connected) return
    // Paint the new mode straight away; the next line from the watcher confirms it.
    mode = value
    aap.write(value + "\n")
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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showsPercent ? "󰋋 " + root.lowestBattery + "%" : "󰋋"
    slotSize: Style.bar.iconSlot * (root.showsPercent ? 2 : 1)
    foreground: root.connected ? root.barForeground : Qt.darker(root.barForeground, 1.6)
    tooltipText: root.connected ? "AirPods" : "AirPods disconnected"
    onPressed: function(b) { root.toggle() }
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
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          iconOpacity: root.connected ? 1.0 : 0.5
          iconComponent: Component {
            Text {
              text: "󰋋"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
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
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: root.batteryText(modelData.key)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
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
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.setMode(modelData.value)
              }
            }
          }
        }
      }
    }
  }
}
