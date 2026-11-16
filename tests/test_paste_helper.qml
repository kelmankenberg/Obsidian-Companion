import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    visible: true
    width: 400
    height: 100

    Plugin.SafeTextEdit {
      id: editor
      anchors.fill: parent
      onTextEdited: {
        if (text !== "<b>clipboard fixture</b> second line") {
          console.error("Unexpected paste result")
          Qt.exit(1)
        } else {
          console.log("Clipboard helper integration passed")
          Qt.quit()
        }
      }
      onPasteFailed: function(message) {
        console.error(message)
        Qt.exit(1)
      }
    }

    Plugin.ClipboardPaste { editor: editor }
  }

  Timer {
    interval: 100
    running: true
    onTriggered: {
      editor.forceActiveFocus()
      editor.requestPaste()
    }
  }

  Timer {
    interval: 5000
    running: true
    onTriggered: {
      console.error("Clipboard helper integration timed out")
      Qt.exit(1)
    }
  }
}
