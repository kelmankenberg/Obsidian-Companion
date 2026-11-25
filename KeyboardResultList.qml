import QtQuick

ListView {
  id: root

  signal openRequested(int index)
  signal filterRequested()
  signal keyboardSelectionChanged(int index)

  currentIndex: -1
  keyNavigationEnabled: false
  activeFocusOnTab: true

  function focusResults() {
    if (count === 0) return false
    if (currentIndex < 0 || currentIndex >= count) currentIndex = 0
    positionViewAtIndex(currentIndex, ListView.Contain)
    forceActiveFocus()
    keyboardSelectionChanged(currentIndex)
    return true
  }

  Keys.onPressed: function(event) {
    if (event.modifiers !== Qt.NoModifier) return
    if (event.key === Qt.Key_Down && count > 0) {
      currentIndex = currentIndex < 0 ? 0 : Math.min(count - 1, currentIndex + 1)
      positionViewAtIndex(currentIndex, ListView.Contain)
      keyboardSelectionChanged(currentIndex)
      event.accepted = true
    } else if (event.key === Qt.Key_Up && count > 0) {
      if (currentIndex <= 0) {
        filterRequested()
      } else {
        currentIndex--
        positionViewAtIndex(currentIndex, ListView.Contain)
        keyboardSelectionChanged(currentIndex)
      }
      event.accepted = true
    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
               && currentIndex >= 0 && currentIndex < count) {
      openRequested(currentIndex)
      event.accepted = true
    }
  }
}
