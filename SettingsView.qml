import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Settings page for Obsidian Companion. Edits a draft copy of the panel's
// settings and saves them in one request; vault, bar, and history actions
// apply immediately.
Item {
  id: settings

  property var panel: null
  readonly property string fontFamily: panel && panel.bar ? panel.bar.fontFamily : Style.font.family

  property string newNoteFolder: "Notes"
  property string newNoteTemplate: ""
  property string captureFolder: "Inbox"
  property string captureFormat: "bullet"
  property string captureTarget: "inbox"
  property bool dailyOverride: false
  property string dailyFolder: ""
  property string dailyFormat: "YYYY-MM-DD"
  property string dailyTemplate: ""
  property var excludedFolders: []
  property string excludeText: ""
  property bool includeObsidianRecent: true
  property string reminderMode: "off"
  property string reminderTime: "09:00"
  property string defaultTab: "search"
  property bool aiEnabled: true
  property var aiPresets: []
  property string presetText: ""

  implicitHeight: header.implicitHeight + Style.space(8)
    + Math.min(Style.space(520), body.implicitHeight)

  function load() {
    if (!panel) return
    var vault = panel.vaultSettings || {}
    var ui = panel.uiSettings || {}
    newNoteFolder = vault.newNoteFolder || "Notes"
    newNoteTemplate = vault.newNoteTemplate || ""
    captureFolder = vault.captureFolder || "Inbox"
    captureFormat = vault.captureFormat || "bullet"
    captureTarget = vault.captureTarget || "inbox"
    dailyOverride = vault.dailyOverride === true
    dailyFolder = vault.dailyFolder || ""
    dailyFormat = vault.dailyFormat || "YYYY-MM-DD"
    dailyTemplate = vault.dailyTemplate || ""
    excludedFolders = (vault.excludedFolders || []).slice()
    excludeText = ""
    includeObsidianRecent = vault.includeObsidianRecent !== false
    reminderMode = panel.reminderMode || "off"
    reminderTime = panel.reminderTime || "09:00"
    defaultTab = ui.defaultTab || "search"
    aiEnabled = ui.aiEnabled !== false
    aiPresets = (ui.aiPresets || []).slice()
    presetText = ""
  }

  function save() {
    if (!/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/.test(reminderTime)) {
      panel.errorMessage = "Enter the reminder time as HH:MM (for example 09:00)."
      return
    }
    var folders = excludedFolders.slice()
    if (excludeText.trim()) folders = panel.addTerm(folders, excludeText)
    var presets = aiPresets.slice()
    if (presetText.trim()) presets = panel.addTerm(presets, presetText)
    panel.request("save_vault_settings", {
      vault: panel.selectedVault,
      settings: {
        newNoteFolder: newNoteFolder,
        newNoteTemplate: newNoteTemplate,
        captureFolder: captureFolder,
        captureFormat: captureFormat,
        captureTarget: captureTarget,
        dailyOverride: dailyOverride,
        dailyFolder: dailyFolder,
        dailyFormat: dailyFormat,
        dailyTemplate: dailyTemplate,
        excludedFolders: folders,
        includeObsidianRecent: includeObsidianRecent
      },
      reminders: { mode: reminderMode, time: reminderTime },
      ui: { defaultTab: defaultTab, aiEnabled: aiEnabled, aiPresets: presets }
    })
  }

  function templateOptions() {
    var templates = panel ? panel.templates : []
    return [{ value: "", label: "No template" }].concat(templates.map(function(template) {
      return { value: template.path, label: template.name }
    }))
  }

  function sectionOf(section) {
    if (section === "left") return "left"
    if (section === "right" || section === "tray") return "right"
    if (section) return "center"
    return ""
  }

  onVisibleChanged: if (visible) load()

  Connections {
    target: settings.panel
    function onVaultSettingsChanged() { settings.load() }
    function onUiSettingsChanged() { settings.load() }
  }

  component Caption: Text {
    color: Color.popups.text
    opacity: 0.72
    font.family: settings.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  component Hint: Text {
    color: Color.popups.text
    opacity: 0.62
    font.family: settings.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }

  component LabeledField: Column {
    id: field
    property string label: ""
    property string value: ""
    property string placeholder: ""
    property string tooltip: ""
    signal edited(string value)
    spacing: Style.spacing.labelGap
    Caption { text: field.label }
    TextField {
      width: field.width
      text: field.value
      placeholderText: field.placeholder
      font.family: settings.fontFamily
      onTextEdited: field.edited(text)
      PanelToolTip {
        visible: field.tooltip !== "" && parent.hovered
        text: field.tooltip
        fontFamily: settings.fontFamily
      }
    }
  }

  RowLayout {
    id: header
    width: parent.width
    spacing: Style.space(8)
    Button {
      text: "‹ Back"
      tooltipText: "Leave Settings; unsaved changes are discarded"
      enabled: !settings.panel.busy
      onClicked: settings.panel.closeSettings()
    }
    Text {
      Layout.fillWidth: true
      text: "Settings"
      color: Color.popups.text
      font.family: settings.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
    Button {
      text: "Save"
      tooltipText: "Save the changes on this page"
      bordered: true
      enabled: !!settings.panel.selectedVault && !settings.panel.busy
      onClicked: settings.save()
    }
  }

  Flickable {
    id: scroller
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    height: Math.min(Style.space(520), body.implicitHeight)
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: body
      width: scroller.width - Style.space(12)
      spacing: Style.space(10)

      // Vaults
      PanelSectionHeader { text: "Vaults"; fontFamily: settings.fontFamily }
      Repeater {
        model: settings.panel ? settings.panel.vaults : []
        delegate: RowLayout {
          id: vaultRow
          required property var modelData
          readonly property bool current: modelData.path === settings.panel.selectedVault
          width: body.width
          spacing: Style.space(8)
          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text {
              width: parent.width
              text: vaultRow.modelData.name + (vaultRow.current ? "  · current" : "")
                + (vaultRow.modelData.custom ? "  · added" : "")
              color: Color.popups.text
              font.family: settings.fontFamily
              font.pixelSize: Style.font.body
              font.bold: vaultRow.current
              elide: Text.ElideRight
            }
            Hint {
              width: parent.width
              text: vaultRow.modelData.path
              wrapMode: Text.NoWrap
              elide: Text.ElideMiddle
            }
          }
          Button {
            visible: !vaultRow.current
            text: "Use"
            tooltipText: "Switch Companion to this vault"
            enabled: !settings.panel.busy
            onClicked: settings.panel.selectVault(vaultRow.modelData.path)
          }
          Button {
            visible: vaultRow.modelData.custom === true
            text: "Remove"
            tooltipText: "Remove this added vault from Companion (no files are deleted)"
            enabled: !settings.panel.busy
            onClicked: settings.panel.request("remove_vault", { vault: vaultRow.modelData.path })
          }
        }
      }
      Button {
        text: "Add vault folder…"
        tooltipText: "Choose a folder that Obsidian hasn't registered as a vault"
        bordered: true
        enabled: !settings.panel.busy
        onClicked: settings.panel.openVaultPicker()
      }
      Hint {
        width: body.width
        text: "Vaults registered in Obsidian appear automatically. Settings below apply to the current vault."
      }

      // New notes
      PanelSectionHeader { text: "New notes"; fontFamily: settings.fontFamily }
      RowLayout {
        width: body.width
        spacing: Style.space(8)
        LabeledField {
          Layout.fillWidth: true
          label: "Default folder"
          tooltip: "Folder for new notes, relative to the vault"
          value: settings.newNoteFolder
          placeholder: "Notes"
          onEdited: function(value) { settings.newNoteFolder = value }
        }
        Choice {
          Layout.fillWidth: true
          label: "Default template"
          tooltipText: "Template preselected when creating a note"
          fontFamily: settings.fontFamily
          options: settings.templateOptions()
          bound: settings.newNoteTemplate
          onPicked: function(value) { settings.newNoteTemplate = value }
        }
      }

      // Capture
      PanelSectionHeader { text: "Quick capture"; fontFamily: settings.fontFamily }
      LabeledField {
        width: body.width
        label: "Inbox folder"
        tooltip: "Folder for dated inbox notes (YYYY-MM-DD.md) used by Capture → Inbox"
        value: settings.captureFolder
        placeholder: "Inbox"
        onEdited: function(value) { settings.captureFolder = value }
      }
      RowLayout {
        width: body.width
        spacing: Style.space(8)
        Choice {
          Layout.fillWidth: true
          label: "Format"
          tooltipText: "How each captured line is written"
          fontFamily: settings.fontFamily
          options: [
            { value: "bullet", label: "Bullet  (- text)" },
            { value: "task", label: "Task  (- [ ] text)" },
            { value: "timestamp", label: "Timestamped  (- 14:05 text)" }
          ]
          bound: settings.captureFormat
          onPicked: function(value) { settings.captureFormat = value }
        }
        Choice {
          Layout.fillWidth: true
          label: "Enter sends to"
          tooltipText: "Where Enter in Quick capture saves the text"
          fontFamily: settings.fontFamily
          options: [
            { value: "inbox", label: "Inbox note" },
            { value: "daily", label: "Today's daily note" }
          ]
          bound: settings.captureTarget
          onPicked: function(value) { settings.captureTarget = value }
        }
      }

      // Daily notes
      PanelSectionHeader { text: "Daily notes"; fontFamily: settings.fontFamily }
      Toggle {
        width: body.width
        label: "Use custom daily note settings"
        description: "Off follows Obsidian's Daily Notes settings for this vault."
        fontFamily: settings.fontFamily
        titleSize: Style.font.body
        checked: settings.dailyOverride
        onClicked: settings.dailyOverride = !settings.dailyOverride
      }
      Column {
        visible: settings.dailyOverride
        width: body.width
        spacing: Style.space(8)
        RowLayout {
          width: parent.width
          spacing: Style.space(8)
          LabeledField {
            Layout.fillWidth: true
            label: "Folder"
            tooltip: "Daily notes folder, relative to the vault; blank uses the vault root"
            value: settings.dailyFolder
            placeholder: "Vault root"
            onEdited: function(value) { settings.dailyFolder = value }
          }
          LabeledField {
            Layout.fillWidth: true
            label: "Date format"
            tooltip: "Moment-style file name format, e.g. YYYY-MM-DD or YYYY/MM/DD-dddd"
            value: settings.dailyFormat
            placeholder: "YYYY-MM-DD"
            onEdited: function(value) { settings.dailyFormat = value }
          }
        }
        Choice {
          width: parent.width
          label: "Template"
          tooltipText: "Template used when Companion creates a daily note"
          fontFamily: settings.fontFamily
          options: settings.templateOptions()
          bound: settings.dailyTemplate
          onPicked: function(value) { settings.dailyTemplate = value }
        }
      }

      // Exclusions
      PanelSectionHeader { text: "Search and tasks"; fontFamily: settings.fontFamily }
      Caption { text: "Excluded folders" }
      ChipSearchField {
        width: body.width
        terms: settings.excludedFolders
        text: settings.excludeText
        placeholderText: "Add a folder to exclude (Enter)"
        morePlaceholderText: "Add another folder…"
        fontFamily: settings.fontFamily
        onEdited: function(text) { settings.excludeText = text }
        onAccepted: {
          settings.excludedFolders = settings.panel.addTerm(settings.excludedFolders, settings.excludeText)
          settings.excludeText = ""
        }
        onRemoveRequested: function(index) {
          var next = settings.excludedFolders.slice()
          next.splice(index, 1)
          settings.excludedFolders = next
        }
        onClearRequested: {
          settings.excludedFolders = []
          settings.excludeText = ""
        }
      }
      Hint {
        width: body.width
        text: "Folder paths are relative to the vault, e.g. Templates or Archive/2024. Subfolders are excluded too."
      }

      // Reminders
      PanelSectionHeader { text: "Task reminders"; fontFamily: settings.fontFamily }
      RowLayout {
        width: body.width
        spacing: Style.space(8)
        Choice {
          Layout.fillWidth: true
          label: "Reminders"
          tooltipText: "Off, a daily count of open tasks, or alerts for 📅 due/overdue tasks"
          fontFamily: settings.fontFamily
          options: [
            { value: "off", label: "Off" },
            { value: "daily_summary", label: "Daily summary" },
            { value: "due_dates", label: "Due-date alerts" }
          ]
          bound: settings.reminderMode
          onPicked: function(value) { settings.reminderMode = value }
        }
        LabeledField {
          Layout.preferredWidth: Style.space(110)
          label: "Time"
          tooltip: "24-hour local time, HH:MM"
          value: settings.reminderTime
          placeholder: "09:00"
          onEdited: function(value) { settings.reminderTime = value }
        }
      }
      Hint {
        visible: settings.reminderMode !== "off"
        width: body.width
        text: settings.reminderMode === "due_dates"
          ? "Alerts use Obsidian Tasks dates (📅 YYYY-MM-DD), once at this time on or after the due date."
          : "Counts open tasks once a day at this time."
      }

      // Panel
      PanelSectionHeader { text: "Panel"; fontFamily: settings.fontFamily }
      Choice {
        width: body.width
        label: "Open on tab"
        tooltipText: "Tab shown each time the panel opens"
        fontFamily: settings.fontFamily
        options: [
          { value: "search", label: "Search" },
          { value: "recent", label: "Recent" },
          { value: "pinned", label: "Pinned" },
          { value: "tasks", label: "Tasks" }
        ]
        bound: settings.defaultTab
        onPicked: function(value) { settings.defaultTab = value }
      }
      Caption { text: "Bar position (applies immediately)" }
      RowLayout {
        width: body.width
        spacing: Style.space(4)
        Repeater {
          model: [
            { id: "left", label: "Left" },
            { id: "center", label: "Center" },
            { id: "right", label: "Right" }
          ]
          delegate: Button {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            tooltipText: "Move the Companion icon to the " + modelData.label.toLowerCase() + " of the bar"
            bordered: true
            selected: settings.sectionOf(settings.panel.barSection) === modelData.id
            enabled: !settings.panel.busy
            onClicked: settings.panel.moveBar(modelData.id)
          }
        }
      }

      // Recent
      PanelSectionHeader { text: "Recent"; fontFamily: settings.fontFamily }
      Toggle {
        width: body.width
        label: "Include Obsidian's recent files"
        description: "Off shows only notes opened from Companion."
        fontFamily: settings.fontFamily
        titleSize: Style.font.body
        checked: settings.includeObsidianRecent
        onClicked: settings.includeObsidianRecent = !settings.includeObsidianRecent
      }
      Button {
        text: "Clear notes opened from Companion"
        tooltipText: "Forget notes recorded by Companion for this vault; Obsidian's own history is unchanged"
        bordered: true
        enabled: !!settings.panel.selectedVault && !settings.panel.busy
        onClicked: settings.panel.request("clear_recent", { vault: settings.panel.selectedVault })
      }

      // AI
      PanelSectionHeader { text: "AI"; fontFamily: settings.fontFamily }
      Toggle {
        width: body.width
        label: "Show Ask AI"
        description: "Sends the selected note to your configured Omarchy agent only when you click Ask AI."
        fontFamily: settings.fontFamily
        titleSize: Style.font.body
        checked: settings.aiEnabled
        onClicked: settings.aiEnabled = !settings.aiEnabled
      }
      Column {
        visible: settings.aiEnabled
        width: body.width
        spacing: Style.space(6)
        Caption { text: "Question presets" }
        Repeater {
          model: settings.aiPresets
          delegate: RowLayout {
            id: presetRow
            required property var modelData
            required property int index
            width: body.width
            spacing: Style.space(8)
            Text {
              Layout.fillWidth: true
              text: presetRow.modelData
              color: Color.popups.text
              font.family: settings.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
            }
            Button {
              text: "×"
              tooltipText: "Remove preset"
              onClicked: {
                var next = settings.aiPresets.slice()
                next.splice(presetRow.index, 1)
                settings.aiPresets = next
              }
            }
          }
        }
        RowLayout {
          width: body.width
          spacing: Style.space(8)
          TextField {
            id: presetField
            Layout.fillWidth: true
            placeholderText: "Add a preset question"
            text: settings.presetText
            enabled: settings.aiPresets.length < 10
            onTextEdited: settings.presetText = text
            Keys.onReturnPressed: addPreset.clicked()
          }
          Button {
            id: addPreset
            text: "Add"
            tooltipText: "Add this question to the Ask AI presets"
            enabled: !!settings.presetText.trim() && settings.aiPresets.length < 10
            onClicked: {
              settings.aiPresets = settings.panel.addTerm(settings.aiPresets, settings.presetText)
              settings.presetText = ""
            }
          }
        }
      }

      Item { width: 1; height: Style.space(4) }
    }
  }
}
