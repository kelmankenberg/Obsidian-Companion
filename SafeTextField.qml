import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BorderSurface {
  id: root

  property alias text: input.text
  property alias font: input.font
  property alias focusTarget: input
  property string placeholderText: ""
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  readonly property bool hovered: hover.hovered
  signal textEdited()
  signal accepted()

  function focusInput() { input.forceActiveFocus() }

  implicitWidth: Style.space(160)
  implicitHeight: Math.max(Style.space(30), input.implicitHeight + 2 * Style.spacing.inputPaddingY)
  borderSpec: Border.controlSpec(input.activeFocus ? "focus" : (hovered ? "hover-cursor" : "normal"), foreground, accent)
  color: Style.controlFill(input.activeFocus, hovered, foreground, accent)
  radius: Style.cornerRadius
  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
  TapHandler { onTapped: input.forceActiveFocus() }

  InputViewport {
    id: viewport
    editor: input
    anchors.fill: parent
    anchors.leftMargin: Style.spacing.controlPaddingX + root.borderLeft
    anchors.rightMargin: Style.spacing.controlPaddingX + root.borderRight
    anchors.topMargin: Style.spacing.inputPaddingY
    anchors.bottomMargin: Style.spacing.inputPaddingY

    SafeTextEdit {
      id: input
      width: viewport.width
      height: viewport.height
      color: root.foreground
      selectionColor: Style.selectionFillFor(root.foreground, root.accent)
      selectedTextColor: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      onTextEdited: root.textEdited()
      Keys.onReturnPressed: root.accepted()
      Keys.onEnterPressed: root.accepted()

      Text {
        anchors.fill: parent
        textFormat: Text.PlainText
        text: root.placeholderText
        visible: input.text === "" && !input.preeditText
        color: Qt.darker(root.foreground, 1.6)
        font: input.font
        elide: Text.ElideRight
      }
    }
  }

  PanelToolTip {
    visible: input.pasteError !== "" && input.activeFocus
    text: input.pasteError
    fontFamily: input.font.family
  }

  ClipboardPaste { editor: input }
}
