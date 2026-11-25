import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root

  property string title: ""
  property string path: ""
  property color foreground: "white"
  property string fontFamily: ""
  property real titleSize: 14
  property real pathSize: 12
  property alias pathTruncated: pathText.truncated
  readonly property bool pathHovered: pathHover.hovered

  spacing: 3

  Text {
    objectName: "noteTitle"
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    text: root.title || root.path
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.titleSize
    font.bold: true
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    maximumLineCount: 2
    elide: Text.ElideRight
  }

  Text {
    id: pathText
    objectName: "notePath"
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    visible: !!root.path
    textFormat: Text.PlainText
    text: root.path
    color: root.foreground
    opacity: 0.85
    font.family: root.fontFamily
    font.pixelSize: root.pathSize
    wrapMode: Text.WrapAnywhere
    maximumLineCount: 2
    elide: Text.ElideRight
    HoverHandler { id: pathHover }
  }
}
