import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
  id: root

  property string expandedSection: ""
  property bool actionsEnabled: true
  signal sectionRequested(string section)

  spacing: Style.space(6)

  Button {
    objectName: "newNoteButton"
    Layout.fillWidth: true
    text: "New note"
    tooltipText: "Show or hide new note controls"
    bordered: true
    focusable: true
    enabled: root.actionsEnabled
    selected: root.expandedSection === "create"
    onClicked: root.sectionRequested(selected ? "" : "create")
  }
  Button {
    objectName: "quickCaptureButton"
    Layout.fillWidth: true
    text: "Quick capture"
    tooltipText: "Show or hide quick capture controls"
    bordered: true
    focusable: true
    enabled: root.actionsEnabled
    selected: root.expandedSection === "capture"
    onClicked: root.sectionRequested(selected ? "" : "capture")
  }
}
