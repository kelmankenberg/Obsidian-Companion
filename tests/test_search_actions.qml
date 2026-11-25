import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    visible: true
    width: 400
    height: 100

    Plugin.SearchActionControls {
      id: actions
      width: parent.width
      onSectionRequested: function(section) { expandedSection = section }
    }

    Timer {
      interval: 100
      running: true
      onTriggered: {
        var create = actions.children.find(function(item) { return item.objectName === "newNoteButton" })
        var capture = actions.children.find(function(item) { return item.objectName === "quickCaptureButton" })
        if (!create || !capture || !create.activeFocusOnTab || !capture.activeFocusOnTab) {
          console.error("Search actions are missing or not keyboard focusable")
          Qt.exit(1)
          return
        }
        create.clicked()
        if (actions.expandedSection !== "create" || !create.selected || capture.selected) {
          console.error("New note did not expand")
          Qt.exit(1)
          return
        }
        capture.clicked()
        if (actions.expandedSection !== "capture" || create.selected || !capture.selected) {
          console.error("Quick capture did not replace New note")
          Qt.exit(1)
          return
        }
        capture.clicked()
        if (actions.expandedSection !== "") {
          console.error("Quick capture did not collapse")
          Qt.exit(1)
          return
        }
        console.log("Search action controls passed")
        Qt.quit()
      }
    }
  }
}
