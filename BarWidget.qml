import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "kel.obsidian-companion"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property int activityCount: panelLoader.item ? panelLoader.item.activityCount : 0

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? root.barSize : Style.bar.iconSlot
    fixedHeight: root.vertical ? Style.bar.iconSlot : root.barSize
    tooltipText: "Obsidian Companion · " + (panelLoader.item
      ? panelLoader.item.activitySummary : "Loading activity")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }

    Image {
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: width
      source: Qt.resolvedUrl("icon.svg")
      sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
      sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
      fillMode: Image.PreserveAspectFit
      scale: button.pressScale
    }

    Rectangle {
      visible: root.activityCount > 0
      anchors.top: parent.top
      anchors.right: parent.right
      width: Math.max(Style.space(13), badgeLabel.implicitWidth + Style.space(4))
      height: Style.space(13)
      radius: height / 2
      color: Color.urgent
      border.color: Color.popups.background
      border.width: 1
      Text {
        id: badgeLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.activityCount > 99 ? "99+" : String(root.activityCount)
        color: "white"
        font.family: button.fontFamily
        font.pixelSize: Style.space(9)
        font.bold: true
      }
    }
  }
}
