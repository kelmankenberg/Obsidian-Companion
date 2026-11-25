import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    id: testWindow
    visible: true
    width: 600
    height: 300

    Plugin.NotePreviewControls {
      id: controls
      width: parent.width
      property int previews: 0
      property int copies: 0
      onPreviewRequested: previews++
      onCopyRequested: copies++
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
        var label = testWindow.findItem(controls, "selectedLabel")
        var previewButton = testWindow.findItem(controls, "previewButton")
        var copyButton = testWindow.findItem(controls, "copyLinkButton")
        var preview = testWindow.findItem(controls, "previewText")
        var truncated = testWindow.findItem(controls, "truncatedLabel")
        if (!label || !previewButton || !copyButton || !preview || !truncated || controls.visible) {
          console.error("Preview controls must be hidden until a note is selected")
          Qt.exit(1)
          return
        }
        controls.selectedPath = "example.md"
        controls.selectedTitle = "<b>Example</b>"
        controls.previewVisible = true
        controls.previewState = "ready"
        controls.previewText = "<img src='https://invalid.example/tracker'>\n# Note"
        controls.truncated = true
        if (!controls.visible || label.textFormat !== Text.PlainText
            || label.text !== "Selected: <b>Example</b>"
            || preview.textFormat !== Text.PlainText || preview.text !== controls.previewText
            || !truncated.visible) {
          console.error("Selected note and preview must display as plain text with truncation")
          Qt.exit(1)
          return
        }
        previewButton.clicked()
        copyButton.clicked()
        if (controls.previews !== 1 || controls.copies !== 1) {
          console.error("Preview and copy actions must be explicit")
          Qt.exit(1)
          return
        }
        controls.busy = true
        if (previewButton.enabled || copyButton.enabled) {
          console.error("Actions must be disabled while busy")
          Qt.exit(1)
          return
        }
        controls.previewText = ""
        if (preview.text !== "This note is empty.") {
          console.error("Empty previews must be identified")
          Qt.exit(1)
          return
        }
        console.log("Note preview controls passed")
        Qt.quit()
      }
    }
  }
}
