import QtQuick
import QtTest
import ".." as Plugin

Item {
  width: 400
  height: 150

  ListModel {
    id: results
    ListElement { label: "First" }
    ListElement { label: "Second" }
    ListElement { label: "Third" }
  }

  Plugin.KeyboardResultList {
    id: list
    width: 400
    height: 120
    model: results
    delegate: Item { required property string label; width: list.width; height: 40 }
  }

  SignalSpy { id: opened; target: list; signalName: "openRequested" }
  SignalSpy { id: filter; target: list; signalName: "filterRequested" }
  SignalSpy { id: selected; target: list; signalName: "keyboardSelectionChanged" }

  TestCase {
    name: "KeyboardResults"
    when: windowShown

    function init() {
      list.currentIndex = -1
      opened.clear()
      filter.clear()
      selected.clear()
      list.forceActiveFocus()
    }

    function test_move_open_and_return_to_filter() {
      keyClick(Qt.Key_Down)
      compare(list.currentIndex, 0)
      compare(selected.signalArguments[0][0], 0)
      keyClick(Qt.Key_Down)
      compare(list.currentIndex, 1)
      compare(selected.signalArguments[1][0], 1)
      keyClick(Qt.Key_Return)
      compare(opened.count, 1)
      compare(opened.signalArguments[0][0], 1)
      keyClick(Qt.Key_Up)
      compare(list.currentIndex, 0)
      compare(selected.signalArguments[2][0], 0)
      keyClick(Qt.Key_Up)
      compare(filter.count, 1)
    }

    function test_boundaries_and_modifiers() {
      list.currentIndex = 2
      keyClick(Qt.Key_Down)
      compare(list.currentIndex, 2)
      keyClick(Qt.Key_Up, Qt.ControlModifier)
      compare(list.currentIndex, 2)
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(opened.count, 0)
    }

    function test_focus_results_and_empty_list() {
      verify(list.focusResults())
      compare(list.currentIndex, 0)
      compare(selected.count, 1)
      compare(selected.signalArguments[0][0], 0)
      list.model = null
      list.currentIndex = -1
      verify(!list.focusResults())
      keyClick(Qt.Key_Return)
      compare(opened.count, 0)
      list.model = results
    }
  }
}
