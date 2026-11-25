import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  Window {
    id: testWindow
    visible: true
    width: 600
    height: 200

    Plugin.SearchFilterControls {
      id: filters
      width: parent.width
      vaultAvailable: true
      property int applyCount: 0
      onTagEdited: function(value) { tagDraft = value }
      onFolderEdited: function(value) { folderDraft = value }
      onApplyRequested: {
        applyCount++
        activeTag = tagDraft.trim()
        activeFolder = folderDraft.trim()
      }
      onClearRequested: {
        tagDraft = ""
        folderDraft = ""
        activeTag = ""
        activeFolder = ""
      }
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
        var tag = testWindow.findItem(filters, "tagFilter")
        var folder = testWindow.findItem(filters, "folderFilter")
        var apply = testWindow.findItem(filters, "applyFilters")
        var clear = testWindow.findItem(filters, "clearFilters")
        var summary = testWindow.findItem(filters, "activeFilterSummary")
        if (!tag || !folder || !apply || !clear || !summary || clear.enabled || summary.visible) {
          console.error("Search filters should start empty")
          Qt.exit(1)
          return
        }
        tag.text = "#work"
        tag.textEdited()
        folder.text = "<b>Projects</b>"
        folder.textEdited()
        if (!clear.enabled || summary.visible) {
          console.error("Filter drafts must not apply automatically")
          Qt.exit(1)
          return
        }
        tag.accepted()
        if (filters.applyCount !== 1 || filters.activeTag !== "#work"
            || filters.activeFolder !== "<b>Projects</b>" || !summary.visible
            || summary.textFormat !== Text.PlainText
            || summary.text.indexOf("<b>Projects</b>") < 0) {
          console.error("Applying filters must show the active plain-text values")
          Qt.exit(1)
          return
        }
        filters.busy = true
        folder.accepted()
        if (filters.applyCount !== 1 || apply.enabled || clear.enabled) {
          console.error("Filter actions must wait while busy")
          Qt.exit(1)
          return
        }
        filters.busy = false
        clear.clicked()
        if (filters.tagDraft || filters.folderDraft || filters.activeTag
            || filters.activeFolder || summary.visible) {
          console.error("Clear must remove drafts and active filters")
          Qt.exit(1)
          return
        }
        console.log("Search filters passed")
        Qt.quit()
      }
    }
  }
}
