import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
  id: root

  property string tagDraft: ""
  property string folderDraft: ""
  property string activeTag: ""
  property string activeFolder: ""
  property bool vaultAvailable: false
  property bool busy: false
  property string fontFamily: Style.font.family
  readonly property bool tagFocused: tagField.focusTarget.activeFocus
  readonly property bool folderFocused: folderField.focusTarget.activeFocus

  signal tagEdited(string value)
  signal folderEdited(string value)
  signal applyRequested()
  signal clearRequested()

  function focusTag() { tagField.focusInput() }
  function focusFolder() { folderField.focusInput() }

  spacing: Style.space(6)

  RowLayout {
    width: parent.width
    spacing: Style.space(6)
    SafeTextField {
      id: tagField
      objectName: "tagFilter"
      Layout.fillWidth: true
      placeholderText: "Tag (e.g. #work)"
      text: root.tagDraft
      enabled: root.vaultAvailable
      onTextEdited: root.tagEdited(text)
      onAccepted: if (!root.busy) root.applyRequested()
    }
    SafeTextField {
      id: folderField
      objectName: "folderFilter"
      Layout.fillWidth: true
      placeholderText: "Folder (or . for root)"
      text: root.folderDraft
      enabled: root.vaultAvailable
      onTextEdited: root.folderEdited(text)
      onAccepted: if (!root.busy) root.applyRequested()
    }
    Button {
      objectName: "applyFilters"
      text: "Apply"
      tooltipText: "Apply tag and folder filters"
      enabled: root.vaultAvailable && !root.busy
      onClicked: root.applyRequested()
    }
    Button {
      objectName: "clearFilters"
      text: "Clear"
      tooltipText: "Clear tag and folder filters"
      enabled: root.vaultAvailable && !root.busy
        && !!(root.tagDraft || root.folderDraft || root.activeTag || root.activeFolder)
      onClicked: root.clearRequested()
    }
  }

  Text {
    objectName: "activeFilterSummary"
    visible: !!(root.activeTag || root.activeFolder)
    width: parent.width
    textFormat: Text.PlainText
    text: "Active filters: "
      + (root.activeTag ? "tag " + root.activeTag : "")
      + (root.activeTag && root.activeFolder ? " · " : "")
      + (root.activeFolder ? "folder " + root.activeFolder : "")
    color: Color.popups.text
    opacity: 0.75
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideMiddle
  }
}
