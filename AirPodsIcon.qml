import QtQuick
import qs.Commons

// A pair of AirPods drawn from primitives, in the manner of the first-party
// TailscaleIcon and DropboxIcon: no font glyph, so it cannot fall back to a
// box on a machine with a different Nerd Font build, and it stays sharp at
// any bar size. Each pod is a round head with a stem under its inner edge,
// which is what gives the pair its inward-facing silhouette.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real headSize: iconSize * 0.42
  readonly property real stemWidth: iconSize * 0.14
  readonly property real headY: iconSize * 0.10
  readonly property real stemY: headY + headSize * 0.62
  readonly property real stemHeight: iconSize * 0.52

  component Head: Rectangle {
    y: root.headY
    width: root.headSize
    height: root.headSize
    radius: width / 2
    color: root.color
  }

  component Stem: Rectangle {
    y: root.stemY
    width: root.stemWidth
    height: root.stemHeight
    radius: width / 2
    color: root.color
  }

  Head { x: 0 }
  Stem { x: root.headSize - root.stemWidth }

  Head { x: root.width - root.headSize }
  Stem { x: root.width - root.headSize }
}
