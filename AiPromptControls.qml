import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
  id: root

  property bool featureEnabled: true
  property bool vaultAvailable: false
  property string activeTab: "search"
  property bool requested: false
  property bool busy: false
  property string selectedPath: ""
  property string selectedTitle: ""
  property string question: ""
  property var presets: []
  property string fontFamily: Style.font.family

  readonly property bool controlsVisible: visible && (requested || !!selectedPath)
  readonly property bool questionFocused: questionField.focusTarget.activeFocus

  signal showRequested()
  signal questionEdited(string value)
  signal presetPicked(string value)
  signal copyRequested()

  function focusQuestion() { questionField.focusInput() }

  visible: featureEnabled && vaultAvailable && activeTab !== "tasks"
  spacing: Style.space(6)

  Button {
    objectName: "askAiButton"
    visible: !root.controlsVisible
    text: "Ask AI"
    tooltipText: "Prepare a question about a note"
    bordered: true
    focusable: true
    enabled: !root.busy
    onClicked: root.showRequested()
  }

  Column {
    objectName: "aiControls"
    visible: root.controlsVisible
    width: parent.width
    spacing: Style.space(6)

    Text {
      objectName: "selectedNoteLabel"
      width: parent.width
      textFormat: Text.PlainText
      text: root.selectedPath
        ? "Selected: " + root.selectedTitle
        : "Search or select a note to use AI."
      color: Color.popups.text
      opacity: root.selectedPath ? 0.9 : 0.68
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: !!root.selectedPath
      elide: Text.ElideRight
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)
      SafeTextField {
        id: questionField
        Layout.fillWidth: true
        placeholderText: root.selectedPath
          ? "Write a question about this note"
          : "Select a note, then ask a question"
        text: root.question
        enabled: !root.busy
        onTextEdited: root.questionEdited(text)
        onAccepted: root.copyRequested()
      }
      Choice {
        visible: root.presets.length > 0
        Layout.preferredWidth: Style.space(130)
        showLabel: false
        fontFamily: root.fontFamily
        enabled: !root.busy
        options: [{ value: "", label: "Presets" }].concat(root.presets.map(function(preset) {
          return { value: preset, label: preset }
        }))
        bound: ""
        onPicked: function(value) { if (value) root.presetPicked(value) }
        tooltipText: "Fill in a saved question (manage presets in Settings)"
      }
      Button {
        objectName: "copyAiButton"
        text: "Copy AI prompt"
        tooltipText: "Copy the selected note and question; paste them into your AI agent"
        bordered: true
        enabled: !!root.selectedPath && !!root.question.trim() && !root.busy
        onClicked: root.copyRequested()
      }
    }

    Text {
      objectName: "clipboardWarning"
      width: parent.width
      textFormat: Text.PlainText
      text: "Copying puts the note and question on your clipboard. Other apps or clipboard managers may read or retain it. Paste it into your AI agent."
      color: Color.popups.text
      opacity: 0.68
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }
  }
}
