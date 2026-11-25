import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
  id: root

  property string selectedPath: ""
  property string selectedTitle: ""
  property bool busy: false
  property bool previewVisible: false
  property string previewState: ""
  property string previewText: ""
  property bool truncated: false
  property string fontFamily: Style.font.family

  signal previewRequested()
  signal copyRequested()

  visible: !!selectedPath
  spacing: Style.space(6)

  RowLayout {
    width: parent.width
    spacing: Style.space(6)
    Text {
      objectName: "selectedLabel"
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      textFormat: Text.PlainText
      text: "Selected: " + root.selectedTitle
      color: Color.popups.text
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
    Button {
      objectName: "previewButton"
      text: root.previewVisible ? "Hide preview" : "Preview"
      tooltipText: "Show or hide a plain-text excerpt of the selected note"
      bordered: true
      focusable: true
      enabled: !root.busy
      onClicked: root.previewRequested()
    }
    Button {
      objectName: "copyLinkButton"
      text: "Copy link"
      tooltipText: "Copy an Obsidian link to the selected note"
      bordered: true
      focusable: true
      enabled: !root.busy
      onClicked: root.copyRequested()
    }
  }

  Flickable {
    objectName: "previewViewport"
    visible: root.previewVisible
    width: parent.width
    height: visible ? Math.min(Style.space(200), Math.max(Style.space(40), preview.implicitHeight)) : 0
    contentWidth: width
    contentHeight: preview.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Text {
      id: preview
      objectName: "previewText"
      width: parent.width
      textFormat: Text.PlainText
      text: root.previewState === "loading" ? "Loading preview…"
        : root.previewState === "error" ? "Could not load preview."
        : root.previewText || "This note is empty."
      color: Color.popups.text
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }
  }

  Text {
    objectName: "truncatedLabel"
    visible: root.previewVisible && root.previewState === "ready" && root.truncated
    width: parent.width
    textFormat: Text.PlainText
    text: "Preview truncated. Open the note to see the rest."
    color: Color.popups.text
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
}
