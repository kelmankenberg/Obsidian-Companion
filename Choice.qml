import QtQuick
import qs.Ui

// Dropdown whose value always follows `bound`. Ui/Dropdown assigns its own
// `value` on selection, which would otherwise break the caller's binding.
Dropdown {
  id: root

  property string bound: ""
  property string tooltipText: ""
  property bool _hovering: false
  signal picked(string value)

  onHovered: function(isHovered) { root._hovering = isHovered }

  PanelToolTip {
    visible: root.tooltipText !== "" && root._hovering && !root.popupOpen
    text: root.tooltipText
    fontFamily: root.fontFamily
  }

  value: bound
  onChanged: function(selected) {
    root.picked(selected)
    root.value = Qt.binding(function() { return root.bound })
  }
}
