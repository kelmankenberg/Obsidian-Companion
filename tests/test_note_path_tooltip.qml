import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    visible: true
    width: 400
    height: 100

    Plugin.NotePathToolTip {
      id: tooltip
      visible: true
      notePath: "<img src='https://invalid.example/tracker'>/Note.md"
    }

    Timer {
      interval: 700
      running: true
      onTriggered: {
        if (!tooltip.opened || tooltip.contentItem.textFormat !== Text.PlainText
            || tooltip.contentItem.text !== tooltip.notePath) {
          console.error("Note path tooltip must display plain text")
          Qt.exit(1)
          return
        }
        console.log("Note path tooltip passed")
        Qt.quit()
      }
    }
  }
}
