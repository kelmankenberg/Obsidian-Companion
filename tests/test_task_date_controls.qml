import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    id: testWindow
    visible: true
    width: 600
    height: 200

    Plugin.TaskDateControls {
      id: controls
      width: parent.width
      vaultAvailable: true
      onDueFilterPicked: function(value) { dueFilter = value }
      onSortPicked: function(value) { sort = value }
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
        var filter = testWindow.findItem(controls, "dueFilter")
        var sort = testWindow.findItem(controls, "taskSort")
        if (!filter || !sort || filter.value !== "all" || sort.value !== "file"
            || filter.currentLabel() !== "All due dates") {
          console.error("Task date controls must default to all dates and file order")
          Qt.exit(1)
          return
        }
        filter.changed("today")
        sort.changed("due_desc")
        if (controls.dueFilter !== "today" || filter.value !== "today"
            || filter.currentLabel() !== "Due today"
            || controls.sort !== "due_desc" || sort.value !== "due_desc") {
          console.error("Task date and sort choices must retain the selected values")
          Qt.exit(1)
          return
        }
        controls.dueFilter = "all"
        controls.vaultAvailable = false
        if (filter.value !== "all" || filter.enabled || sort.enabled) {
          console.error("Controls must follow resets and require a vault")
          Qt.exit(1)
          return
        }
        console.log("Task date controls passed")
        Qt.quit()
      }
    }
  }
}
