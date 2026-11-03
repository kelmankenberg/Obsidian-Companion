import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Search box with removable term chips inline, a leading search glyph, and a
// trailing clear-all button. Styled with the same tokens as Ui/TextField.
BorderSurface {
  id: root

  property var terms: []
  property string text: ""
  property string placeholderText: "Search"
  property string morePlaceholderText: "Narrow by another term…"
  property bool inputEnabled: true
  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent

  signal edited(string text)
  signal accepted()
  signal removeRequested(int index)
  signal clearRequested()

  readonly property bool _focused: input.activeFocus
  readonly property bool _hot: hover.hovered
  readonly property real _pad: Style.spacing.controlPaddingX

  function focusInput() { input.forceActiveFocus() }

  borderSpec: Border.controlSpec(_focused ? "focus" : (_hot ? "hover-cursor" : "normal"), foreground, accent)
  color: Style.controlFill(_focused, _hot, foreground, accent)
  radius: Style.cornerRadius
  implicitHeight: Math.max(Style.space(36), layout.implicitHeight + Style.space(8))

  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
  TapHandler { onTapped: root.focusInput() }

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: root._pad + root.borderLeft
    anchors.rightMargin: Style.space(4) + root.borderRight
    anchors.topMargin: Style.space(4)
    anchors.bottomMargin: Style.space(4)
    spacing: Style.space(8)

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "⌕"
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.body + 2
    }

    Flow {
      id: flow
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.space(6)

      Repeater {
        model: root.terms
        delegate: BorderSurface {
          id: chip
          required property var modelData
          required property int index
          borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
          color: Style.normalFillFor(root.foreground, root.accent)
          radius: Style.cornerRadius
          implicitWidth: chipRow.implicitWidth + Style.space(14)
          implicitHeight: chipRow.implicitHeight + Style.space(8)
          width: implicitWidth
          height: implicitHeight

          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: chip.modelData
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              id: closeGlyph
              anchors.verticalCenter: parent.verticalCenter
              text: "×"
              color: root.foreground
              opacity: closeArea.containsMouse ? 1 : 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -Style.space(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.inputEnabled
                onClicked: root.removeRequested(chip.index)
              }
              PanelToolTip {
                visible: closeArea.containsMouse
                text: "Remove \"" + chip.modelData + "\""
                fontFamily: root.fontFamily
              }
            }
          }
        }
      }

      TextInput {
        id: input
        readonly property real _remaining: flow.width - flow._usedOnLastLine
        width: _remaining >= Style.space(140) ? _remaining : flow.width
        height: Math.max(implicitHeight, Style.space(24))
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        enabled: root.inputEnabled
        clip: true
        color: root.foreground
        selectionColor: Style.selectionFillFor(root.foreground, root.accent)
        selectedTextColor: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        onTextEdited: root.edited(text)
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Backspace && text === "" && root.terms.length) {
            root.removeRequested(root.terms.length - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Escape && (text !== "" || root.terms.length)) {
            root.clearRequested()
            event.accepted = true
          }
        }

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          visible: input.text === "" && !input.preeditText
          text: root.terms.length ? root.morePlaceholderText : root.placeholderText
          color: Qt.darker(root.foreground, 1.6)
          font: input.font
          elide: Text.ElideRight
        }
      }

      // Width taken by chips on the row the input will share.
      property real _usedOnLastLine: {
        var used = 0
        for (var i = 0; i < children.length; i++) {
          var item = children[i]
          if (item === input || !item.visible || item.width <= 0) continue
          if (item.y !== lastChipY) continue
          used += item.width + spacing
        }
        return used
      }
      property real lastChipY: {
        var y = 0
        for (var i = 0; i < children.length; i++) {
          var item = children[i]
          if (item !== input && item.visible && item.width > 0) y = Math.max(y, item.y)
        }
        return y
      }
    }

    Button {
      Layout.alignment: Qt.AlignVCenter
      visible: root.text !== "" || root.terms.length > 0
      text: "×"
      bordered: true
      tooltipText: "Clear all terms"
      enabled: root.inputEnabled
      onClicked: root.clearRequested()
    }
  }
}
