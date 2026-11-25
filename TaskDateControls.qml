import QtQuick
import QtQuick.Layouts
import qs.Commons

RowLayout {
  id: root

  property string dueFilter: "all"
  property string sort: "file"
  property bool vaultAvailable: false
  property string fontFamily: Style.font.family

  signal dueFilterPicked(string value)
  signal sortPicked(string value)

  function openDueFilter() { dueFilterChoice.open() }

  spacing: Style.space(6)

  Choice {
    id: dueFilterChoice
    objectName: "dueFilter"
    Layout.fillWidth: true
    showLabel: false
    fontFamily: root.fontFamily
    enabled: root.vaultAvailable
    options: [
      { value: "all", label: "All due dates" },
      { value: "overdue", label: "Overdue" },
      { value: "today", label: "Due today" },
      { value: "upcoming", label: "Upcoming" },
      { value: "undated", label: "Undated" }
    ]
    bound: root.dueFilter
    tooltipText: "Filter tasks by due date"
    onPicked: function(value) { root.dueFilterPicked(value) }
  }
  Choice {
    objectName: "taskSort"
    Layout.fillWidth: true
    showLabel: false
    fontFamily: root.fontFamily
    enabled: root.vaultAvailable
    options: [
      { value: "file", label: "File order" },
      { value: "due_asc", label: "Due date ↑" },
      { value: "due_desc", label: "Due date ↓" }
    ]
    bound: root.sort
    tooltipText: "Sort by file order or by 📅 due date; undated tasks go last"
    onPicked: function(value) { root.sortPicked(value) }
  }
}
