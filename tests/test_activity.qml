import QtQuick
import "../Activity.js" as Activity

Item {
  Component.onCompleted: {
    const baseline = { "old.md": "1:5", "removed.md": "2:4" }
    const current = { "old.md": "3:6", "new.md": "1:2" }
    if (Activity.changedCount(current, null) !== 0
        || Activity.changedCount(current, baseline) !== 2
        || Activity.changedCount(current, current) !== 0
        || Activity.changedCount({}, baseline) !== 0
        || Activity.changedCount({ "toString": "1" }, {}) !== 1) {
      console.error("Activity snapshot comparison failed")
      Qt.exit(1)
      return
    }
    Qt.quit()
  }
}
