import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Minimized-window preview tray for Omarchy.
//
// Watches the named special workspace `special:minimized` (where the
// minimize.py helper parks minimized windows) and renders a horizontal strip
// of preview thumbnails. Left-click a thumbnail to restore the window,
// right-click (or the × button) to close it. The tray hides itself while
// nothing is minimized.
Item {
  id: root

  // Injected by the Omarchy shell host.
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null

  property string home: Quickshell.env("HOME")
  property string cacheDir: home + "/.cache/omarchy-minimize"
  readonly property string scriptPath:
    Qt.resolvedUrl("scripts/minimize.py").toString().replace(/^file:\/\//, "")

  // Visual tuning (feel free to adjust).
  property int bottomMargin: 64
  property int cardHeight: 96
  property int cardWidth: 148

  property var minimized: []
  readonly property bool hasMinimized: minimized.length > 0

  function restore(addr) { Util.execArgv(["python3", scriptPath, "restore", addr]) }
  function close(addr) { Util.execArgv(["python3", scriptPath, "close", addr]) }

  function refresh() {
    var list = []
    if (typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
      var tops = Hyprland.toplevels.values
      for (var i = 0; i < tops.length; i++) {
        var t = tops[i]
        if (!t) continue
        var ws = t.workspace ? String(t.workspace.name || "") : ""
        if (ws.indexOf("special:minimized") !== 0) continue
        var addr = String(t.address || "")
        if (addr && addr.indexOf("0x") !== 0) addr = "0x" + addr
        list.push({
          address: addr,
          title: String(t.title || t.appId || "Window"),
          appClass: String(t.appId || ""),
          preview: addr ? Util.fileUrl(cacheDir + "/" + addr + ".png") : ""
        })
      }
    }
    root.minimized = list
  }

  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
  Component.onCompleted: root.refresh()

  PanelWindow {
    id: trayWindow
    screen: (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
    visible: root.hasMinimized

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-minimize-tray"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: trayCard }

    Rectangle {
      id: trayCard
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.bottomMargin
      width: Math.min(rowContent.implicitWidth + 24, parent.width - 24)
      height: cardHeight + 20
      radius: Style.cornerRadius > 0 ? Style.cornerRadius : 12
      color: Color.bar.background
      opacity: root.hasMinimized ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      Row {
        id: rowContent
        anchors.centerIn: parent
        spacing: 10

        Repeater {
          model: root.minimized
          delegate: Rectangle {
            width: cardWidth
            height: cardHeight
            radius: 10
            color: Util.alpha(Color.foreground, 0.06)
            border.color: Util.alpha(Color.accent, 0.25)
            border.width: 1
            clip: true

            scale: hoverHandler.hovered ? 1.05 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Image {
              anchors.fill: parent
              source: modelData.preview
              fillMode: Image.PreserveAspectCrop
              opacity: 0.85
              asynchronous: true
            }

            // Title scrim along the bottom of the thumbnail.
            Rectangle {
              anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
              height: 24
              gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Util.alpha(Color.background, 0.85) }
              }
            }
            Text {
              anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              anchors.bottomMargin: 5
              text: modelData.title
              elide: Text.ElideRight
              font.family: Style.fontFamily
              font.pixelSize: 11
              color: Color.bar.text
            }

            // Close affordance, shown on hover.
            Rectangle {
              anchors { top: parent.top; right: parent.right; margins: 4 }
              width: 18
              height: 18
              radius: 9
              color: Util.alpha(Color.urgent, 0.9)
              opacity: hoverHandler.hovered ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: 13
                color: "white"
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.close(modelData.address)
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              id: hoverHandler
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) root.close(modelData.address)
                else root.restore(modelData.address)
              }
            }
          }
        }
      }
    }
  }
}
