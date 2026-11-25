import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    id: testWindow
    visible: true
    width: 600
    height: 300

    Plugin.AiPromptControls {
      id: ai
      width: parent.width
      vaultAvailable: true
      property int copyCount: 0
      onShowRequested: requested = true
      onCopyRequested: copyCount++
    }

    function findItem(item, name) {
      if (item.objectName === name) return item
      for (var i = 0; i < item.children.length; i++) {
        var result = findItem(item.children[i], name)
        if (result) return result
      }
      return null
    }

    Timer {
      interval: 100
      running: true
      onTriggered: {
        var trigger = testWindow.findItem(ai, "askAiButton")
        var copy = testWindow.findItem(ai, "copyAiButton")
        var warning = testWindow.findItem(ai, "clipboardWarning")
        var selectedLabel = testWindow.findItem(ai, "selectedNoteLabel")
        if (!trigger || !copy || !warning || !selectedLabel || ai.controlsVisible || !trigger.visible) {
          console.error("AI controls should initially be hidden behind Ask AI")
          Qt.exit(1)
          return
        }
        trigger.clicked()
        ai.question = "Summarize"
        if (!ai.controlsVisible || !warning.visible || copy.enabled
            || warning.textFormat !== Text.PlainText
            || warning.text.indexOf("clipboard") < 0) {
          console.error("Requested AI controls must warn and require a selected note")
          Qt.exit(1)
          return
        }
        ai.requested = false
        if (ai.controlsVisible || ai.question !== "Summarize") {
          console.error("Hiding AI controls must retain the question")
          Qt.exit(1)
          return
        }
        ai.selectedPath = "Notes/example.md"
        ai.selectedTitle = "<b>Example</b>"
        if (!ai.controlsVisible || !warning.visible || !copy.enabled || ai.copyCount !== 0
            || selectedLabel.textFormat !== Text.PlainText
            || selectedLabel.text !== "Selected: <b>Example</b>") {
          console.error("Selecting a note must reveal AI without copying")
          Qt.exit(1)
          return
        }
        ai.busy = true
        if (copy.enabled) {
          console.error("Copy must be disabled while busy")
          Qt.exit(1)
          return
        }
        ai.busy = false
        ai.activeTab = "tasks"
        if (ai.controlsVisible || trigger.visible) {
          console.error("AI must be hidden in Tasks")
          Qt.exit(1)
          return
        }
        ai.activeTab = "recent"
        ai.featureEnabled = false
        if (ai.controlsVisible || trigger.visible) {
          console.error("Disabled AI must be hidden")
          Qt.exit(1)
          return
        }
        ai.featureEnabled = true
        ai.vaultAvailable = false
        if (ai.controlsVisible || trigger.visible) {
          console.error("AI requires a selected vault")
          Qt.exit(1)
          return
        }
        console.log("AI prompt controls passed")
        Qt.quit()
      }
    }
  }
}
