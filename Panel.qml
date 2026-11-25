import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Activity.js" as Activity
import "ResultText.js" as ResultText

Panel {
  id: root
  moduleName: "kel.obsidian-companion"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool busy: false
  property string activeTab: "search"
  property string query: ""
  property string taskFilter: ""
  property var searchTerms: []
  property string searchTagDraft: ""
  property string searchFolderDraft: ""
  property string searchTag: ""
  property string searchFolder: ""
  property string selectedPath: ""
  property string selectedTitle: ""
  property bool previewVisible: false
  property string previewState: ""
  property string previewText: ""
  property bool previewTruncated: false
  property var taskTerms: []
  property string taskSort: "file"
  property string taskDueFilter: "all"
  property string noteTitle: ""
  property string createFolder: "Notes"
  property string createTemplate: ""
  property string captureText: ""
  property string searchAction: ""
  property var vaultSettings: ({})
  property var uiSettings: ({ defaultTab: "search", aiEnabled: true, aiPresets: [] })
  property string barSection: ""
  property bool showSettings: false
  property bool initialized: false
  property string reminderMode: "off"
  property string reminderTime: "09:00"
  property string selectedVault: ""
  property string errorMessage: ""
  property string notice: ""
  property string pluginVersion: ""
  property string aiQuestion: ""
  property bool aiRequested: false
  property var vaults: []
  property var results: []
  property var recent: []
  property var pinned: []
  property var tasks: []
  property var templates: []
  property var pendingRequest: ({})
  property string queuedAction: ""
  property var queuedPayload: ({})
  property string pendingAction: ""
  property var pendingPayload: ({})
  property var activityBaseline: null
  property var activityFiles: ({})
  property int activityChanges: 0
  property int activityDue: 0
  property bool activityDaily: false
  property string activityError: ""
  property string activityVault: ""
  property bool activityRescan: false
  property bool activityAcknowledgePending: false
  property bool activityFinishing: false
  readonly property int activityCount: activityChanges + activityDue + (activityDaily ? 1 : 0)
  readonly property int activityIntervalMinutes: vaultSettings.badgeIntervalMinutes || 1
  readonly property string activitySummary: activityError ? "Activity check failed: " + activityError
    : activityCount > 0 ? activityDue + " due tasks · " + activityChanges
      + " changed notes" + (activityDaily ? " · daily note missing" : "")
    : "No pending activity"
  readonly property string home: Quickshell.env("HOME")

  Component.onCompleted: request("init", {})

  ListModel {
    id: displayedNotes
  }

  function showItems(items) {
    var keepSelection = false
    var current = notesList.currentIndex >= 0 && notesList.currentIndex < displayedNotes.count
      ? displayedNotes.get(notesList.currentIndex) : null
    var currentPath = current ? current.path : ""
    var currentLine = current ? current.line : -1
    var currentIndex = -1
    for (var j = 0; j < items.length; j++)
      if (String(items[j].path || "") === selectedPath) keepSelection = true
    if (!keepSelection) selectNote(null)
    displayedNotes.clear()
    for (var i = 0; i < items.length; i++) {
      if (current && String(items[i].path || "") === currentPath
          && (activeTab !== "tasks" || items[i].line === currentLine)) currentIndex = i
      displayedNotes.append({
        path: String(items[i].path || ""),
        title: String(items[i].title || ""),
        preview: String(items[i].preview || ""),
        pinned: items[i].pinned === true,
        taskText: String(items[i].text || ""),
        due: String(items[i].due || ""),
        line: Number.isInteger(items[i].line) ? items[i].line : -1
      })
    }
    notesList.currentIndex = currentIndex
  }

  function addTerm(list, text) {
    var term = String(text || "").trim()
    if (!term) return list
    for (var i = 0; i < list.length; i++)
      if (list[i].toLowerCase() === term.toLowerCase()) return list
    return list.concat([term])
  }

  function commitSearchTerm() {
    searchDebounce.stop()
    searchTerms = addTerm(searchTerms, query)
    query = ""
    refreshCurrentView()
  }

  function commitTaskTerm() {
    taskFilterDebounce.stop()
    taskTerms = addTerm(taskTerms, taskFilter)
    taskFilter = ""
    refreshCurrentView()
  }

  function removeSearchTerm(index) {
    var next = searchTerms.slice()
    next.splice(index, 1)
    searchTerms = next
    if (!hasSearchInput()) {
      results = []
      showItems([])
    } else {
      refreshCurrentView()
    }
  }

  function removeTaskTerm(index) {
    var next = taskTerms.slice()
    next.splice(index, 1)
    taskTerms = next
    refreshCurrentView()
  }

  function clearSearchTerms() {
    searchDebounce.stop()
    searchTerms = []
    query = ""
    results = []
    showItems([])
    if (hasSearchInput()) refreshCurrentView()
  }

  function applySearchFilters() {
    searchTag = searchTagDraft.trim()
    searchFolder = searchFolderDraft.trim()
    searchDebounce.stop()
    results = []
    showItems([])
    if (hasSearchInput()) refreshCurrentView()
    else errorMessage = ""
  }

  function clearSearchFilters() {
    searchTagDraft = ""
    searchFolderDraft = ""
    applySearchFilters()
  }

  function clearTaskTerms() {
    taskFilterDebounce.stop()
    taskTerms = []
    taskFilter = ""
    refreshCurrentView()
  }

  function hasSearchInput() {
    return searchTerms.length > 0 || query.trim() !== "" || searchTag !== "" || searchFolder !== ""
  }

  function noteFromDelegate(row) {
    return {
      path: row.path,
      title: row.title,
      preview: row.preview,
      pinned: row.pinned,
      text: row.taskText,
      due: row.due,
      line: row.line
    }
  }

  function open() {
    root.controller.show()
    if (activityBaseline !== null) activityBaseline = activityFiles
    activityChanges = 0
    activityAcknowledgePending = true
    scheduleActivity()
    if (!initialized) {
      if (!busy || pendingAction !== "init") request("init", {})
    } else {
      showSettings = false
      changeTab(defaultTab())
    }
  }

  function defaultTab() {
    var tab = uiSettings && uiSettings.defaultTab
    return ["search", "recent", "pinned", "tasks"].indexOf(tab) >= 0 ? tab : "search"
  }

  function applySettings(response) {
    pluginVersion = response.pluginVersion || ""
    vaults = response.vaults || []
    selectedVault = response.selectedVault || ""
    templates = response.templates || []
    reminderMode = response.reminderMode || "off"
    reminderTime = response.reminderTime || "09:00"
    vaultSettings = response.vaultSettings || ({})
    uiSettings = response.uiSettings || ({ defaultTab: "search", aiEnabled: true, aiPresets: [] })
    if (uiSettings.aiEnabled === false) aiRequested = false
    barSection = response.barSection || ""
    createFolder = vaultSettings.newNoteFolder || "Notes"
    createTemplate = vaultSettings.newNoteTemplate || ""
  }

  function resetVaultData() {
    results = []
    recent = []
    pinned = []
    tasks = []
    query = ""
    searchTerms = []
    searchTagDraft = ""
    searchFolderDraft = ""
    searchTag = ""
    searchFolder = ""
    taskFilter = ""
    taskTerms = []
    taskDueFilter = "all"
    selectNote(null)
    aiRequested = false
    showItems([])
    activityBaseline = null
    activityFiles = ({})
    activityChanges = 0
    activityDue = 0
    activityDaily = false
    activityAcknowledgePending = false
  }

  function scheduleActivity() {
    if (!selectedVault) return
    if (activityProcess.running || activityFinishing) {
      activityRescan = true
      return
    }
    activityVault = selectedVault
    activityProcess.running = true
  }

  function finishActivity(exitCode, output, errorOutput) {
    if (activityVault === selectedVault) {
      var response
      try {
        response = JSON.parse(String(output || ""))
      } catch (error) {
        response = { ok: false, error: String(errorOutput || "").trim() || "Invalid activity response." }
      }
      if (exitCode !== 0 || !response || response.ok !== true) {
        activityError = response && response.error ? String(response.error) : "Activity check failed."
      } else {
        activityError = ""
        activityFiles = response.files || ({})
        activityDue = Number(response.due || 0)
        activityDaily = response.daily === true
        if (activityBaseline === null || opened || activityAcknowledgePending)
          activityBaseline = activityFiles
        activityAcknowledgePending = false
        activityChanges = Activity.changedCount(activityFiles, activityBaseline)
      }
    }
    if (activityRescan) {
      activityRescan = false
      Qt.callLater(root.scheduleActivity)
    }
  }

  function openSettings() {
    showSettings = true
    contentFlick.contentY = 0
  }

  function closeSettings() {
    showSettings = false
    changeTab(activeTab)
  }

  function openVaultPicker() {
    vaultPicker.open()
  }

  function moveBar(section) {
    if (barProcess.running) return
    errorMessage = ""
    notice = "Moving Obsidian Companion to the " + section + " of the bar…"
    barProcess.command = ["omarchy", "bar", "move", "kel.obsidian-companion", "--section", section]
    barProcess.running = true
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function helperPath() {
    var path = Qt.resolvedUrl("companion.py").toString()
    if (path.indexOf("file://") === 0) path = path.substring(7)
    try { path = decodeURIComponent(path) } catch (error) {}
    return path
  }

  function request(action, payload) {
    if (busy) {
      queuedAction = action
      queuedPayload = payload || ({})
      return
    }
    errorMessage = ""
    notice = ""
    pendingAction = action
    pendingPayload = payload || ({})
    pendingRequest = Object.assign({ action: action }, pendingPayload)
    helper.command = ["python3", helperPath()]
    busy = true
    helper.running = true
  }

  function handleResponse(action, payload, response) {
    if (action === "search" && (payload.vault !== selectedVault || payload.query !== query.trim()
        || JSON.stringify(payload.terms || []) !== JSON.stringify(searchTerms)
        || (payload.tag || "") !== searchTag || (payload.folder || "") !== searchFolder)) return
    if (action === "preview_note"
        && (payload.vault !== selectedVault || payload.path !== selectedPath || !previewVisible)) return
    if (action === "tasks" && (payload.vault !== selectedVault || payload.filter !== taskFilter.trim()
        || payload.sort !== taskSort || payload.dueFilter !== taskDueFilter
        || JSON.stringify(payload.terms || []) !== JSON.stringify(taskTerms))) return
    if (!response || response.ok !== true) {
      if (action === "preview_note") previewState = "error"
      errorMessage = response && response.error
        ? String(response.error).slice(0, 360)
        : "The request failed. Check the plugin output for details."
      return
    }

    if (action === "init") {
      applySettings(response)
      initialized = true
      if (opened) changeTab(defaultTab())
      scheduleActivity()
    } else if (action === "select_vault" || action === "add_vault" || action === "remove_vault") {
      var changed = (response.selectedVault || "") !== selectedVault
      applySettings(response)
      if (changed) resetVaultData()
      scheduleActivity()
      if (response.message) notice = response.message
      if (!showSettings) changeTab(activeTab)
    } else if (action === "save_vault_settings" || action === "save_ui_settings") {
      var previousExclusions = JSON.stringify(vaultSettings.excludedFolders || [])
      var previousChanges = vaultSettings.badgeChanges !== false
      applySettings(response)
      if (previousExclusions !== JSON.stringify(vaultSettings.excludedFolders || [])
          || previousChanges !== (vaultSettings.badgeChanges !== false))
        activityBaseline = null
      scheduleActivity()
      notice = response.message || "Settings saved."
    } else if (action === "clear_recent") {
      recent = []
      if (activeTab === "recent") showItems([])
      notice = response.message || "Cleared Companion's recent history."
    } else if (action === "search") {
      results = response.items || []
      if (activeTab === "search") showItems(results)
    } else if (action === "recent") {
      recent = response.items || []
      if (activeTab === "recent") showItems(recent)
    } else if (action === "pinned") {
      pinned = response.items || []
      if (activeTab === "pinned") showItems(pinned)
    } else if (action === "tasks") {
      tasks = response.items || []
      if (activeTab === "tasks") showItems(tasks)
    } else if (action === "preview_note") {
      previewText = String(response.text || "")
      previewTruncated = response.truncated === true
      previewState = "ready"
      Qt.callLater(function() {
        if (root.opened && root.previewVisible) root.ensureVisible(notePreview)
      })
    } else if (action === "copy_note_link") {
      notice = response.message || "Obsidian link copied to the clipboard."
    } else if (action === "open_vault") {
      if (response.uri && Qt.openUrlExternally(response.uri))
        notice = "Opening the selected vault in Obsidian."
      else
        errorMessage = "Could not open Obsidian. Check that its URI handler is installed."
    } else if (action === "open" || action === "daily" || action === "create") {
      if (action === "open" && payload.taskCompletion) {
        if (response.uri && Qt.openUrlExternally(response.uri))
          notice = "Complete the task in Obsidian."
        else
          errorMessage = "Could not open the task in Obsidian. Check that its URI handler is installed."
        return
      }
      if (response.uri) Qt.openUrlExternally(response.uri)
      notice = response.message || "Opened in Obsidian."
      refreshCurrentView()
      scheduleActivity()
    } else if (action === "capture") {
      captureText = ""
      notice = response.message || "Captured."
      scheduleActivity()
    } else if (action === "pin") {
      notice = response.message || "Updated pinned notes."
      function updatePin(rows) {
        return rows.map(function(row) {
          if (row.path !== response.path) return row
          return Object.assign({}, row, { pinned: response.pinned })
        })
      }
      results = updatePin(results)
      recent = updatePin(recent)
      pinned = updatePin(pinned)
      refreshCurrentView()
    } else if (action === "ai_prompt") {
      aiQuestion = ""
      notice = response.message
    } else if (action === "set_reminders") {
      reminderMode = response.reminderMode || "off"
      reminderTime = response.reminderTime || "09:00"
      notice = "Reminder preference saved."
    }
  }

  function finishProcess(exitCode, output, errorOutput) {
    busy = false
    var response = null
    try {
      response = JSON.parse(String(output || ""))
    } catch (error) {
      response = {
        ok: false,
        error: String(errorOutput || "").trim() || "The helper returned invalid data."
      }
    }
    if (exitCode !== 0 && response && response.ok === true) {
      response.ok = false
      response.error = String(errorOutput || "").trim() || "The helper exited with an error."
    }
    handleResponse(pendingAction, pendingPayload, response)
    Qt.callLater(root.dispatchQueuedRequest)
  }

  function dispatchQueuedRequest() {
    if (busy || !queuedAction) return
    var action = queuedAction
    var payload = queuedPayload
    queuedAction = ""
    queuedPayload = ({})
    request(action, payload)
  }

  function refreshCurrentView() {
    if (!selectedVault) return
    if (activeTab === "recent") request("recent", { vault: selectedVault })
    else if (activeTab === "pinned") request("pinned", { vault: selectedVault })
    else if (activeTab === "tasks") request("tasks", {
      vault: selectedVault,
      filter: taskFilter.trim(),
      terms: taskTerms,
      sort: taskSort,
      dueFilter: taskDueFilter
    })
    else if (hasSearchInput()) request("search", {
      vault: selectedVault,
      query: query.trim(),
      terms: searchTerms,
      tag: searchTag,
      folder: searchFolder
    })
  }

  function selectVault(path) {
    request("select_vault", { vault: path })
  }

  function openNote(note) {
    request("open", { vault: selectedVault, path: note.path,
                      taskCompletion: activeTab === "tasks" })
  }

  function togglePin(note) {
    request("pin", { vault: selectedVault, path: note.path })
  }

  function createNote() {
    var title = noteTitle.trim()
    if (!title) return
    request("create", {
      vault: selectedVault,
      title: title,
      folder: createFolder,
      template: createTemplate
    })
  }

  function capture(destination) {
    var text = captureText.trim()
    if (!text) return
    if (destination === "note" && !selectedPath) {
      errorMessage = "Select a note before capturing to it."
      return
    }
    request("capture", {
      vault: selectedVault,
      destination: destination || "",
      path: destination === "note" ? selectedPath : "",
      text: text
    })
  }

  function openDaily() {
    request("daily", { vault: selectedVault })
  }

  function openVault() {
    request("open_vault", { vault: selectedVault })
  }

  function ensureVisible(item) {
    var top = item.mapToItem(contentColumn, 0, 0).y
    var bottom = top + item.height
    if (item.height > contentFlick.height || top < contentFlick.contentY)
      contentFlick.contentY = Math.max(0, top)
    else if (bottom > contentFlick.contentY + contentFlick.height)
      contentFlick.contentY = Math.min(
        Math.max(0, contentFlick.contentHeight - contentFlick.height),
        bottom - contentFlick.height)
  }

  function showSearchAction(section) {
    searchAction = section
    if (!section) return
    Qt.callLater(function() {
      if (!root.opened || root.showSettings || root.activeTab !== "search"
          || root.searchAction !== section) return
      root.ensureVisible(section === "create" ? createSection : captureSection)
      if (section === "create") titleField.focusInput()
      else captureField.focusInput()
    })
  }

  function focusNoteResults() {
    if (notesList.focusResults()) ensureVisible(notesList)
  }

  function selectNote(note) {
    var path = note ? String(note.path || "") : ""
    if (path !== selectedPath) {
      previewVisible = false
      previewState = ""
      previewText = ""
      previewTruncated = false
    }
    selectedPath = path
    selectedTitle = note ? String(note.title || note.path || "") : ""
  }

  function togglePreview() {
    if (!selectedPath || busy) return
    if (previewVisible) {
      previewVisible = false
      previewText = ""
      previewState = ""
      previewTruncated = false
    } else {
      previewVisible = true
      previewState = "loading"
      request("preview_note", { vault: selectedVault, path: selectedPath })
      Qt.callLater(function() {
        if (root.opened && root.previewVisible) root.ensureVisible(notePreview)
      })
    }
  }

  function copyNoteLink() {
    if (!selectedPath || busy) return
    request("copy_note_link", { vault: selectedVault, path: selectedPath })
  }

  function showAi() {
    if (uiSettings.aiEnabled === false || !selectedVault || activeTab === "tasks" || busy) return
    aiRequested = true
    Qt.callLater(function() {
      if (!root.opened || root.showSettings || !aiSection.controlsVisible) return
      root.ensureVisible(aiSection)
      aiSection.focusQuestion()
    })
  }

  function askAgent() {
    if (uiSettings.aiEnabled === false || !selectedPath || !aiQuestion.trim()) return
    request("ai_prompt", {
      vault: selectedVault,
      path: selectedPath,
      question: aiQuestion.trim()
    })
  }

  function changeTab(tab) {
    activeTab = tab
    contentFlick.contentY = 0
    notesList.currentIndex = -1
    showItems(tab === "recent" ? recent
      : (tab === "pinned" ? pinned
      : (tab === "tasks" ? tasks : results)))
    if (opened && !showSettings) {
      Qt.callLater(function() {
        if (!root.opened || root.showSettings || root.activeTab !== tab) return
        if (tab === "search") searchField.focusInput()
        else if (tab === "tasks") taskField.focusInput()
        else if (!notesList.focusResults()) keyCatcher.forceActiveFocus()
      })
    }
    refreshCurrentView()
  }

  function noteIsPinned(note) {
    return note && note.pinned === true
  }

  Process {
    id: helper
    stdinEnabled: true
    stdout: StdioCollector { id: helperOutput; waitForEnd: true }
    stderr: StdioCollector { id: helperError; waitForEnd: true }
    onStarted: helper.write(JSON.stringify(root.pendingRequest) + "\n")
    onExited: function(exitCode) {
      Qt.callLater(function() {
        root.finishProcess(exitCode, String(helperOutput.text || ""), String(helperError.text || ""))
      })
    }
  }

  Process {
    id: activityProcess
    command: ["python3", root.helperPath()]
    stdinEnabled: true
    stdout: StdioCollector { id: activityOutput; waitForEnd: true }
    stderr: StdioCollector { id: activityStderr; waitForEnd: true }
    onStarted: activityProcess.write(JSON.stringify({ action: "activity", vault: root.activityVault }) + "\n")
    onExited: function(exitCode) {
      root.activityFinishing = true
      Qt.callLater(function() {
        root.finishActivity(exitCode, activityOutput.text, activityStderr.text)
        root.activityFinishing = false
      })
    }
  }

  Timer {
    interval: root.activityIntervalMinutes * 60000
    running: root.initialized && !!root.selectedVault
    repeat: true
    onTriggered: root.scheduleActivity()
  }

  Timer {
    interval: 60000
    running: !!root.selectedVault && root.reminderMode !== "off"
    repeat: true
    onTriggered: {
      if (!root.busy)
        root.request("reminder_check", { vault: root.selectedVault })
    }
  }

  Timer {
    id: searchDebounce
    interval: 250
    repeat: false
    onTriggered: {
      if (!root.selectedVault || root.activeTab !== "search") return
      if (root.hasSearchInput()) {
        root.refreshCurrentView()
      } else {
        root.results = []
        root.showItems([])
      }
    }
  }

  Timer {
    id: taskFilterDebounce
    interval: 250
    repeat: false
    onTriggered: {
      if (root.selectedVault && root.activeTab === "tasks") root.refreshCurrentView()
    }
  }

  FolderDialog {
    id: vaultPicker
    currentFolder: "file://" + root.home
    onAccepted: {
      var url = String(selectedFolder)
      if (url.indexOf("file://") === 0) url = decodeURIComponent(url.substring(7))
      root.request("add_vault", { vault: url })
    }
  }

  Process {
    id: barProcess
    stdout: StdioCollector {}
    stderr: StdioCollector { id: barError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.notice = ""
        root.errorMessage = String(barError.text || "").trim() || "Could not move the bar widget."
      } else {
        root.request("init", {})
      }
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: !root.showSettings && root.activeTab === "search" && root.selectedVault
      ? searchField.focusTarget
      : (!root.showSettings && root.activeTab === "tasks" && root.selectedVault
        ? taskField.focusTarget
        : (!root.showSettings && notesList.count > 0 ? notesList : keyCatcher))
    contentWidth: popup.fittedContentWidth(Style.space(540), 680)
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, 760)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0 && !root.showSettings) root.focusNoteResults()
      }

      Shortcut {
        sequence: "Ctrl+1"
        enabled: root.opened && !root.showSettings && !!root.selectedVault
        onActivated: root.changeTab("search")
      }
      Shortcut {
        sequence: "Ctrl+2"
        enabled: root.opened && !root.showSettings && !!root.selectedVault
        onActivated: root.changeTab("recent")
      }
      Shortcut {
        sequence: "Ctrl+3"
        enabled: root.opened && !root.showSettings && !!root.selectedVault
        onActivated: root.changeTab("pinned")
      }
      Shortcut {
        sequence: "Ctrl+4"
        enabled: root.opened && !root.showSettings && !!root.selectedVault
        onActivated: root.changeTab("tasks")
      }
      Shortcut {
        sequence: "Alt+N"
        enabled: root.opened && !root.showSettings && root.activeTab === "search"
          && !!root.selectedVault && !root.busy
        onActivated: root.showSearchAction("create")
      }
      Shortcut {
        sequence: "Alt+C"
        enabled: root.opened && !root.showSettings && root.activeTab === "search"
          && !!root.selectedVault && !root.busy
        onActivated: root.showSearchAction("capture")
      }
      Shortcut {
        sequence: "Alt+A"
        enabled: root.opened && !root.showSettings && root.activeTab !== "tasks"
          && !!root.selectedVault && root.uiSettings.aiEnabled !== false && !root.busy
        onActivated: root.showAi()
      }
      Shortcut {
        sequence: "Alt+P"
        enabled: root.opened && !root.showSettings && root.activeTab !== "tasks"
          && !!root.selectedPath && !root.busy
        onActivated: root.togglePreview()
      }
      Shortcut {
        sequence: "Alt+L"
        enabled: root.opened && !root.showSettings && root.activeTab !== "tasks"
          && !!root.selectedPath && !root.busy
        onActivated: root.copyNoteLink()
      }
      Shortcut {
        sequence: "Alt+D"
        enabled: root.opened && !root.showSettings && root.activeTab === "tasks"
          && !!root.selectedVault
        onActivated: {
          root.ensureVisible(taskDateControls)
          taskDateControls.openDueFilter()
        }
      }
      Shortcut {
        sequence: "Alt+T"
        enabled: root.opened && !root.showSettings && root.activeTab === "search"
          && !!root.selectedVault
        onActivated: {
          root.ensureVisible(searchFilters)
          searchFilters.focusTag()
        }
      }
      Shortcut {
        sequence: "Alt+F"
        enabled: root.opened && !root.showSettings && root.activeTab === "search"
          && !!root.selectedVault
        onActivated: {
          root.ensureVisible(searchFilters)
          searchFilters.focusFolder()
        }
      }
      Shortcut {
        sequence: "Alt+Shift+F"
        enabled: root.opened && !root.showSettings && root.activeTab === "search"
          && !!root.selectedVault && !root.busy
        onActivated: root.clearSearchFilters()
      }

      Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        RowLayout {
          width: parent.width
          spacing: Style.space(8)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: "Obsidian Companion" + (root.pluginVersion ? "  v" + root.pluginVersion : "")
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              visible: root.vaults.length <= 1
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: root.selectedVault ? root.selectedVault.split("/").pop() : "Add a vault in Settings to get started"
              color: Color.popups.text
              opacity: 0.72
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideMiddle
            }
            Choice {
              visible: root.vaults.length > 1
              Layout.fillWidth: true
              showLabel: false
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              enabled: !root.busy
              options: root.vaults.map(function(vault) { return { value: vault.path, label: vault.name } })
              bound: root.selectedVault
              tooltipText: "Switch to another vault"
              onPicked: function(value) { if (value !== root.selectedVault) root.selectVault(value) }
            }
          }
          Button {
            text: "Obsidian"
            tooltipText: "Open the selected vault in Obsidian"
            enabled: !!root.selectedVault && !root.busy
            onClicked: root.openVault()
          }
          Button {
            text: "Today"
            tooltipText: "Open today's daily note in Obsidian (created if missing)"
            enabled: !!root.selectedVault && !root.busy
            onClicked: root.openDaily()
          }
          Button {
            text: "⚙"
            fontSize: Style.font.display
            selected: root.showSettings
            tooltipText: root.showSettings ? "Close settings" : "Settings"
            enabled: !root.busy || root.showSettings
            onClicked: root.showSettings ? root.closeSettings() : root.openSettings()
          }
        }

        Text {
          visible: root.errorMessage !== ""
          textFormat: Text.PlainText
          width: parent.width
          text: root.errorMessage
          color: "#ff8a80"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.activityError !== ""
          textFormat: Text.PlainText
          width: parent.width
          text: "Activity check failed: " + root.activityError
          color: "#ff8a80"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.notice !== ""
          textFormat: Text.PlainText
          width: parent.width
          text: root.notice
          color: Color.popups.text
          opacity: 0.78
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.busy
          width: parent.width
          text: "Working…"
          color: Color.popups.text
          opacity: 0.72
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        SettingsView {
          visible: root.showSettings
          width: parent.width
          panel: root
        }

        Column {
          id: mainView
          visible: !root.showSettings
          width: parent.width
          spacing: Style.space(10)

          RowLayout {
            width: parent.width
            spacing: Style.space(4)
            Repeater {
              model: [
                { id: "search", label: "Search", tip: "Search note titles and contents" },
                { id: "recent", label: "Recent", tip: "Notes recently opened in Obsidian or from Companion" },
                { id: "pinned", label: "Pinned", tip: "Notes you starred (☆) in this vault" },
                { id: "tasks", label: "Tasks", tip: "Unchecked - [ ] tasks across the vault" }
              ]
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                tooltipText: modelData.tip
                selected: root.activeTab === modelData.id
                enabled: !!root.selectedVault && !root.busy
                onClicked: root.changeTab(modelData.id)
              }
            }
          }

          Text {
            visible: root.activeTab === "recent" && displayedNotes.count > 0
            width: parent.width
            text: displayedNotes.count + " recent notes"
            color: Color.popups.text
            opacity: 0.72
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          SearchFilterControls {
            id: searchFilters
            visible: root.activeTab === "search"
            width: parent.width
            tagDraft: root.searchTagDraft
            folderDraft: root.searchFolderDraft
            activeTag: root.searchTag
            activeFolder: root.searchFolder
            vaultAvailable: !!root.selectedVault
            busy: root.busy
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onTagEdited: function(value) { root.searchTagDraft = value }
            onFolderEdited: function(value) { root.searchFolderDraft = value }
            onApplyRequested: root.applySearchFilters()
            onClearRequested: root.clearSearchFilters()
          }

          ChipSearchField {
            id: searchField
            visible: root.activeTab === "search"
            width: parent.width
            terms: root.searchTerms
            text: root.query
            placeholderText: "Search notes… (Enter adds a term)"
            inputEnabled: !!root.selectedVault
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onEdited: function(text) {
              root.query = text
              root.results = []
              root.showItems([])
              searchDebounce.restart()
            }
            onAccepted: root.commitSearchTerm()
            onRemoveRequested: function(index) { root.removeSearchTerm(index) }
            onClearRequested: root.clearSearchTerms()
            onResultsRequested: root.focusNoteResults()
          }

          Column {
            visible: root.activeTab === "tasks"
            width: parent.width
            spacing: Style.space(6)
            ChipSearchField {
              id: taskField
              width: parent.width
              terms: root.taskTerms
              text: root.taskFilter
              placeholderText: "Filter tasks… (Enter adds a term)"
              inputEnabled: !!root.selectedVault
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onEdited: function(text) {
                root.taskFilter = text
                root.tasks = []
                root.showItems([])
                taskFilterDebounce.restart()
              }
              onAccepted: root.commitTaskTerm()
              onRemoveRequested: function(index) { root.removeTaskTerm(index) }
              onClearRequested: root.clearTaskTerms()
              onResultsRequested: root.focusNoteResults()
            }
            TaskDateControls {
              id: taskDateControls
              width: parent.width
              dueFilter: root.taskDueFilter
              sort: root.taskSort
              vaultAvailable: !!root.selectedVault
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onDueFilterPicked: function(value) {
                root.taskDueFilter = value
                taskFilterDebounce.stop()
                root.tasks = []
                root.showItems([])
                root.refreshCurrentView()
              }
              onSortPicked: function(value) {
                root.taskSort = value
                root.refreshCurrentView()
              }
            }
          }

          KeyboardResultList {
            id: notesList
            width: parent.width
            height: count > 0 ? Math.min(Style.space(300), Math.max(Style.space(72), contentHeight)) : 0
            visible: count > 0
            clip: true
            spacing: Style.space(4)
            model: displayedNotes
            boundsBehavior: Flickable.StopAtBounds
            onFilterRequested: {
              if (root.activeTab === "search") {
                root.ensureVisible(searchField)
                searchField.focusInput()
              } else if (root.activeTab === "tasks") {
                root.ensureVisible(taskField)
                taskField.focusInput()
              }
            }
            onOpenRequested: function(index) {
              if (!root.busy && index >= 0 && index < displayedNotes.count)
                root.openNote(displayedNotes.get(index))
            }
            onKeyboardSelectionChanged: function(index) {
              if (root.activeTab !== "tasks" && index >= 0 && index < displayedNotes.count)
                root.selectNote(displayedNotes.get(index))
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                  id: row
                  required property int index
                  required property string path
                  required property string title
                  required property string preview
                  required property bool pinned
                  required property string taskText
                  required property string due
                  required property int line
                  readonly property bool isLocationView: root.activeTab === "recent" || root.activeTab === "pinned"
                  width: notesList.width
                  height: rowContent.implicitHeight + Style.space(12)
                  radius: Math.min(4, Style.cornerRadius)
                  readonly property bool isSelected: (notesList.activeFocus && notesList.currentIndex === row.index)
                    || (root.activeTab !== "tasks" && root.selectedPath === row.path)
                  color: isSelected
                    ? Style.selectionFillFor(Color.popups.text, Color.accent)
                    : Color.popups.background
                  border.color: isSelected ? Color.accent : Color.popups.border
                  border.width: isSelected ? 2 : 1

                  RowLayout {
                    id: rowContent
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(8)
                    ColumnLayout {
                      visible: !row.isLocationView
                      Layout.fillWidth: true
                      spacing: Style.space(2)
                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: ResultText.primary(root.activeTab, row.title, row.taskText, row.path)
                        color: Color.popups.text
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                      }
                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        visible: !!row.preview || !!row.path
                        text: root.activeTab === "tasks" && row.due
                          ? "Due " + row.due + " · " + row.path
                          : (row.preview || row.path)
                        color: Color.popups.text
                        opacity: 0.7
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                      }
                    }
                    NoteLocationText {
                      id: locationText
                      visible: row.isLocationView
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      title: row.title
                      path: row.path
                      foreground: Color.popups.text
                      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                      titleSize: Style.font.body
                      pathSize: Style.font.bodySmall
                      spacing: Style.space(3)

                      NotePathToolTip {
                        visible: locationText.pathHovered && locationText.pathTruncated
                        notePath: row.path
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                      }
                    }
                    RowLayout {
                      spacing: Style.space(4)
                      Button {
                        visible: root.activeTab !== "tasks"
                        Layout.preferredWidth: row.isLocationView ? Style.space(72) : implicitWidth
                        text: row.isLocationView
                          ? (row.pinned ? "Unpin" : "Pin")
                          : (row.pinned ? "★" : "☆")
                        tooltipText: row.pinned ? "Unpin this note" : "Pin this note"
                        bordered: row.isLocationView
                        enabled: !root.busy
                        onClicked: root.togglePin(root.noteFromDelegate(row))
                      }
                      Button {
                        text: root.activeTab === "tasks" ? "Open task" : "Open"
                        tooltipText: root.activeTab === "tasks"
                          ? "Open the note and complete the task in Obsidian"
                          : "Open in Obsidian (or double-click the row)"
                        bordered: row.isLocationView
                        enabled: !root.busy
                        onClicked: root.openNote(root.noteFromDelegate(row))
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    z: -1
                    id: rowMouse
                    hoverEnabled: true
                    cursorShape: root.activeTab === "tasks" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                      notesList.currentIndex = row.index
                      if (root.activeTab !== "tasks") root.selectNote(root.noteFromDelegate(row))
                    }
                    onDoubleClicked: root.openNote(root.noteFromDelegate(row))
                    PanelToolTip {
                      visible: rowMouse.containsMouse && !(row.isLocationView
                        && locationText.pathHovered && locationText.pathTruncated)
                      text: root.activeTab === "tasks"
                        ? "Double-click to open this task's note"
                        : "Click to select · double-click to open"
                    }
                  }
                }
          }

          NotePreviewControls {
            id: notePreview
            width: parent.width
            visible: root.activeTab !== "tasks" && !!root.selectedPath
            selectedPath: root.selectedPath
            selectedTitle: root.selectedTitle
            busy: root.busy
            previewVisible: root.previewVisible
            previewState: root.previewState
            previewText: root.previewText
            truncated: root.previewTruncated
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onPreviewRequested: root.togglePreview()
            onCopyRequested: root.copyNoteLink()
          }

          Text {
            visible: root.activeTab !== "search" && displayedNotes.count === 0 && !root.busy
            width: parent.width
            text: root.activeTab === "recent"
              ? "No recent notes found. Open a note in Obsidian or from Companion."
              : (root.activeTab === "pinned"
              ? "No pinned notes yet. Pin one from Search or Recent."
              : ((root.taskFilter.trim() || root.taskTerms.length || root.taskDueFilter !== "all")
                ? "No open tasks match this filter." : "No open tasks found."))
            color: Color.popups.text
            opacity: 0.7
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }

          Text {
            visible: root.activeTab === "search" && root.results.length === 0 && !root.busy
              && root.hasSearchInput()
            width: parent.width
            text: "No matching notes."
            color: Color.popups.text
            opacity: 0.7
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }

          SearchActionControls {
            visible: root.activeTab === "search"
            width: parent.width
            expandedSection: root.searchAction
            actionsEnabled: !!root.selectedVault && !root.busy
            onSectionRequested: function(section) { root.showSearchAction(section) }
          }

          Column {
            id: createSection
            visible: root.activeTab === "search" && root.searchAction === "create"
            width: parent.width
            spacing: Style.space(6)
            RowLayout {
              width: parent.width
              SafeTextField {
                id: titleField
                Layout.fillWidth: true
                placeholderText: "New note title"
                text: root.noteTitle
                enabled: !!root.selectedVault && !root.busy
                onTextEdited: root.noteTitle = text
                onAccepted: root.createNote()
              }
              Button {
                text: "Create"
                tooltipText: "Create this note in the folder below, using the chosen template, and open it"
                enabled: !!root.selectedVault && !!root.noteTitle.trim() && !root.busy
                onClicked: root.createNote()
              }
            }
            RowLayout {
              width: parent.width
              SafeTextField {
                Layout.fillWidth: true
                placeholderText: "Folder in vault"
                PanelToolTip {
                  visible: parent.hovered
                  text: "Folder for the new note, relative to the vault (default set in Settings)"
                }
                text: root.createFolder
                enabled: !!root.selectedVault && !root.busy
                onTextEdited: root.createFolder = text
              }
              Choice {
                Layout.fillWidth: true
                showLabel: false
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                enabled: !root.busy
                options: [{ value: "", label: "No template" }].concat(root.templates.map(function(template) {
                  return { value: template.path, label: template.name }
                }))
                bound: root.createTemplate
                tooltipText: "Template applied to the new note"
                onPicked: function(value) { root.createTemplate = value }
              }
            }
          }

          Column {
            id: captureSection
            visible: root.activeTab === "search" && root.searchAction === "capture"
            width: parent.width
            spacing: Style.space(6)
            SafeTextField {
              id: captureField
              width: parent.width
              placeholderText: "Quick capture (Enter saves to " + (root.vaultSettings.captureTarget === "daily" ? "today's daily note" : "inbox") + ")"
              text: root.captureText
              enabled: !!root.selectedVault && !root.busy
              onTextEdited: root.captureText = text
              onAccepted: root.capture("")
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.selectedPath
                ? "Capture to selected note: " + root.selectedPath
                : "Select a search result to capture to an existing note."
              color: Color.popups.text
              opacity: 0.72
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideMiddle
            }
            RowLayout {
              width: parent.width
              spacing: Style.space(6)
              Item { Layout.fillWidth: true }
              Button {
                text: "Inbox"
                tooltipText: "Add the capture to today's inbox note ("
                  + (root.vaultSettings.captureFolder || "Inbox") + "/YYYY-MM-DD.md)"
                enabled: !!root.captureText.trim() && !!root.selectedVault && !root.busy
                onClicked: root.capture("inbox")
              }
              Button {
                text: "Daily"
                tooltipText: "Add the capture to the end of today's daily note"
                enabled: !!root.captureText.trim() && !!root.selectedVault && !root.busy
                onClicked: root.capture("daily")
              }
              Button {
                text: "Selected note"
                tooltipText: "Append the capture to the selected note"
                enabled: !!root.captureText.trim() && !!root.selectedVault && !!root.selectedPath && !root.busy
                onClicked: root.capture("note")
              }
            }
          }

          AiPromptControls {
            id: aiSection
            width: parent.width
            featureEnabled: root.uiSettings.aiEnabled !== false
            vaultAvailable: !!root.selectedVault
            activeTab: root.activeTab
            requested: root.aiRequested
            busy: root.busy
            selectedPath: root.selectedPath
            selectedTitle: root.selectedTitle
            question: root.aiQuestion
            presets: root.uiSettings.aiPresets || []
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onShowRequested: root.showAi()
            onQuestionEdited: function(value) { root.aiQuestion = value }
            onPresetPicked: function(value) { root.aiQuestion = value }
            onCopyRequested: root.askAgent()
          }
          }
        }
      }
    }
  }

  ShellIpc {
    target: "kel.obsidian-companion"
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function settings() {
      root.open()
      root.openSettings()
    }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        activeTab: root.activeTab,
        pluginVersion: root.pluginVersion,
        showSettings: root.showSettings,
        selectedVault: root.selectedVault,
        busy: root.busy,
        pendingAction: root.pendingAction,
        queuedAction: root.queuedAction,
        keyboardFocus: searchField.focusTarget.activeFocus ? "search"
          : (taskField.focusTarget.activeFocus ? "task-filter"
          : (searchFilters.tagFocused ? "tag-filter"
          : (searchFilters.folderFocused ? "folder-filter"
          : (titleField.focusTarget.activeFocus ? "new-note"
          : (captureField.focusTarget.activeFocus ? "capture"
          : (aiSection.questionFocused ? "ai-question"
          : (notesList.activeFocus ? "results" : "other"))))))),
        keyboardResultIndex: notesList.currentIndex,
        searchSection: root.searchAction,
        searchFiltersActive: !!(root.searchTag || root.searchFolder),
        taskDueFilter: root.taskDueFilter,
        previewVisible: root.previewVisible && root.activeTab !== "tasks",
        previewState: root.previewState,
        aiControlsVisible: aiSection.controlsVisible,
        activityCount: root.activityCount,
        activityDue: root.activityDue,
        activityChanges: root.activityChanges,
        activityDaily: root.activityDaily,
        activityError: root.activityError,
        activityIntervalMinutes: root.activityIntervalMinutes,
        recentCount: root.recent.length,
        visibleCount: displayedNotes.count,
        recentFirst: root.recent.length ? root.recent[0].path : "",
        error: root.errorMessage
      })
    }
  }
}
