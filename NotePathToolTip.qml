import QtQuick
import qs.Commons
import qs.Ui

PanelToolTip {
  id: root

  property string notePath: ""

  contentItem: Text {
    textFormat: Text.PlainText
    text: root.notePath
    color: root.panelForeground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    wrapMode: Text.WrapAnywhere
    width: Math.min(implicitWidth, Style.space(400))
    padding: Style.space(6)
  }
}
