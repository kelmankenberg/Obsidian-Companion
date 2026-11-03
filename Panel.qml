import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "kel.obsidian-companion"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool busy: false
  property string activeTab: "search"
  property string query: ""
  property string noteTitle: ""
  property string createFolder: "Notes"
  property string createTemplate: ""
  property string captureText: ""
  property string captureFolder: "Inbox"
  property string reminderMode: "off"
  property string reminderTime: "09:00"
  property string selectedVault: ""
  property string errorMessage: ""
  property string notice: ""
  property string aiQuestion: ""
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
  readonly property string home: Quickshell.env("HOME")

  ListModel {
    id: displayedNotes
  }

  function showItems(items) {
    displayedNotes.clear()
    for (var i = 0; i < items.length; i++)
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
    if (root.vaults.length === 0) request("init", {})
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
    if (!response || response.ok !== true) {
      errorMessage = response && response.error
        ? String(response.error).slice(0, 360)
        : "The request failed. Check the plugin output for details."
      return
    }

    if (action === "init" || action === "select_vault") {
      vaults = response.vaults || []
      selectedVault = response.selectedVault || ""
      captureFolder = response.captureFolder || "Inbox"
      templates = response.templates || []
      reminderMode = response.reminderMode || "off"
      reminderTime = response.reminderTime || "09:00"
      refreshCurrentView()
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
    } else if (action === "open" || action === "daily" || action === "create") {
      if (response.uri) Qt.openUrlExternally(response.uri)
      notice = response.message || "Opened in Obsidian."
      refreshCurrentView()
    } else if (action === "capture") {
      captureText = ""
      notice = response.message || "Captured."
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
    } else if (action === "complete_task") {
      notice = response.message || "Task completed."
      refreshCurrentView()
    } else if (action === "ai_prompt") {
      aiQuestion = ""
      notice = response.message || "Opening your configured Omarchy agent."
      agentProcess.command = ["omarchy", "agent", "prompt", response.prompt]
      agentProcess.running = true
    } else if (action === "set_capture_folder") {
      captureFolder = response.captureFolder || captureFolder
      notice = "Capture folder saved."
    } else if (action === "set_reminders") {
      reminderMode = response.reminderMode || "off"
      reminderTime = response.reminderTime || "09:00"
      notice = "Reminder preference saved."
    } else if (action === "reminder_check") {
      if (response.notifications && response.notifications.length > 0) {
        notificationProcess.command = [
          "omarchy", "notification", "send", "--app-name", "Obsidian Companion",
          "Obsidian Companion", response.notifications[0]
        ]
        notificationProcess.running = true
      }
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
    else if (activeTab === "tasks") request("tasks", { vault: selectedVault })
    else if (query.trim()) request("search", { vault: selectedVault, query: query.trim() })
  }

  function selectVault(path) {
    request("select_vault", { vault: path })
  }

  function openNote(note) {
    request("open", { vault: selectedVault, path: note.path })
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
    request("capture", {
      vault: selectedVault,
      destination: destination,
      folder: captureFolder,
      text: text
    })
  }

  function openDaily() {
    request("daily", { vault: selectedVault })
  }

  function askAgent(note) {
    if (!note || !aiQuestion.trim()) return
    request("ai_prompt", {
      vault: selectedVault,
      path: note.path,
      question: aiQuestion.trim()
    })
  }

  function changeTab(tab) {
    activeTab = tab
    showItems(tab === "recent" ? recent
      : (tab === "pinned" ? pinned
      : (tab === "tasks" ? tasks : results)))
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
    id: agentProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorMessage = "Could not launch the configured Omarchy agent."
      }
    }
  }

  Process {
    id: notificationProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("Obsidian Companion: could not send task reminder notification.")
    }
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
      if (root.selectedVault && root.activeTab === "search")
        root.request("search", { vault: root.selectedVault, query: root.query.trim() })
    }
  }

  FolderDialog {
    id: vaultPicker
    currentFolder: "file://" + root.home
    onAccepted: {
      var url = String(selectedFolder)
      if (url.indexOf("file://") === 0) url = decodeURIComponent(url.substring(7))
      root.selectVault(url)
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(540), 680)
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, 760)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
              text: "Obsidian Companion"
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              Layout.fillWidth: true
              text: selectedVault ? selectedVault.split("/").pop() : "Select a vault to get started"
              color: Color.popups.text
              opacity: 0.72
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideMiddle
            }
          }
          Button {
            text: "Today"
            enabled: !!root.selectedVault && !root.busy
            onClicked: root.openDaily()
          }
          Button {
            text: "⚙"
            enabled: !root.busy
            onClicked: vaultPicker.open()
          }
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            model: [
              { id: "search", label: "Search" },
              { id: "recent", label: "Recent" },
              { id: "pinned", label: "Pinned" },
              { id: "tasks", label: "Tasks" }
            ]
            delegate: Button {
              required property var modelData
              Layout.fillWidth: true
              text: modelData.label
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

        TextField {
          id: searchField
          visible: root.activeTab === "search"
          width: parent.width
          placeholderText: "Search note titles and contents"
          text: root.query
          enabled: !!root.selectedVault && !root.busy
          onTextEdited: {
            root.query = text
            searchDebounce.restart()
          }
          Keys.onReturnPressed: {
            searchDebounce.stop()
            root.refreshCurrentView()
          }
        }

        Column {
          visible: root.activeTab === "search"
          width: parent.width
          spacing: Style.space(6)
          RowLayout {
            width: parent.width
            TextField {
              id: titleField
              Layout.fillWidth: true
              placeholderText: "New note title"
              text: root.noteTitle
              enabled: !!root.selectedVault && !root.busy
              onTextEdited: root.noteTitle = text
              Keys.onReturnPressed: root.createNote()
            }
            Button {
              text: "Create"
              enabled: !!root.selectedVault && !!root.noteTitle.trim() && !root.busy
              onClicked: root.createNote()
            }
          }
          RowLayout {
            width: parent.width
            TextField {
              Layout.fillWidth: true
              placeholderText: "Folder in vault"
              text: root.createFolder
              enabled: !!root.selectedVault && !root.busy
              onTextEdited: root.createFolder = text
            }
            ComboBox {
              Layout.fillWidth: true
              model: ["No template"].concat(root.templates.map(function(template) { return template.name }))
              enabled: !root.busy
              currentIndex: {
                for (var i = 0; i < root.templates.length; i++) {
                  if (root.templates[i].path === root.createTemplate) return i + 1
                }
                return 0
              }
              onActivated: function(index) {
                root.createTemplate = index === 0 ? "" : root.templates[index - 1].path
              }
            }
          }
          TextField {
            id: captureField
            width: parent.width
            placeholderText: "Quick capture"
            text: root.captureText
            enabled: !!root.selectedVault && !root.busy
            onTextEdited: root.captureText = text
            Keys.onReturnPressed: root.capture("inbox")
          }
          RowLayout {
            width: parent.width
            spacing: Style.space(6)
            TextField {
              Layout.fillWidth: true
              text: root.captureFolder
              placeholderText: "Inbox folder"
              enabled: !!root.selectedVault && !root.busy
              onTextEdited: root.captureFolder = text
              Keys.onReturnPressed: root.request("set_capture_folder", {
                vault: root.selectedVault,
                folder: root.captureFolder
              })
            }
            Button {
              text: "Save"
              enabled: !!root.selectedVault && !!root.captureFolder.trim() && !root.busy
              onClicked: root.request("set_capture_folder", {
                vault: root.selectedVault,
                folder: root.captureFolder
              })
            }
            Button {
              text: "Inbox"
              enabled: !!root.captureText.trim() && !!root.selectedVault && !root.busy
              onClicked: root.capture("inbox")
            }
            Button {
              text: "Daily"
              enabled: !!root.captureText.trim() && !!root.selectedVault && !root.busy
              onClicked: root.capture("daily")
            }
          }
        }

        Text {
          visible: root.errorMessage !== ""
          width: parent.width
          text: root.errorMessage
          color: "#ff8a80"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.notice !== ""
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

        Column {
          visible: root.activeTab === "tasks"
          width: parent.width
          spacing: Style.space(6)
          RowLayout {
            width: parent.width
            Text {
              Layout.fillWidth: true
              text: "Task reminders"
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
            ComboBox {
              id: reminderModePicker
              model: ["Off", "Daily summary", "Due-date alerts"]
              currentIndex: root.reminderMode === "daily_summary"
                ? 1 : (root.reminderMode === "due_dates" ? 2 : 0)
              onActivated: function(index) {
                root.reminderMode = index === 1
                  ? "daily_summary" : (index === 2 ? "due_dates" : "off")
              }
            }
            TextField {
              id: reminderTimeField
              Layout.preferredWidth: Style.space(76)
              text: root.reminderTime
              placeholderText: "09:00"
              inputMethodHints: Qt.ImhTime
              validator: RegularExpressionValidator {
                regularExpression: /^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/
              }
              onTextEdited: root.reminderTime = text
            }
            Button {
              text: "Save"
              enabled: !!root.selectedVault && reminderTimeField.acceptableInput && !root.busy
              onClicked: root.request("set_reminders", {
                vault: root.selectedVault,
                mode: root.reminderMode,
                time: root.reminderTime
              })
            }
          }
          Text {
            width: parent.width
            text: root.reminderMode === "due_dates"
              ? "Due-date alerts use Obsidian Tasks dates (📅 YYYY-MM-DD), once at this time on or after the due date."
              : "Daily summary counts open tasks once a day at this time."
            visible: root.reminderMode !== "off"
            color: Color.popups.text
            opacity: 0.68
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }
        }

        ListView {
          id: notesList
          width: parent.width
          height: count > 0 ? Math.min(Style.space(300), Math.max(Style.space(72), contentHeight)) : 0
          visible: count > 0
          clip: true
          spacing: Style.space(4)
          model: displayedNotes
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Rectangle {
                id: row
                required property string path
                required property string title
                required property string preview
                required property bool pinned
                required property string taskText
                required property string due
                required property int line
                width: notesList.width
                height: rowContent.implicitHeight + Style.space(12)
                radius: Math.min(4, Style.cornerRadius)
                color: Color.popups.background
                border.color: Color.popups.border
                border.width: 1

                RowLayout {
                  id: rowContent
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  spacing: Style.space(8)
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)
                    Text {
                      Layout.fillWidth: true
                      text: row.title || row.taskText || row.path
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
                  Button {
                    visible: root.activeTab === "tasks"
                    text: "Done"
                    enabled: !root.busy
                    onClicked: root.request("complete_task", {
                      vault: root.selectedVault,
                      path: row.path,
                      line: row.line,
                      text: row.taskText
                    })
                  }
                  Button {
                    visible: root.activeTab === "search"
                    text: "Ask AI"
                    enabled: !!root.aiQuestion.trim() && !root.busy
                    onClicked: root.askAgent(root.noteFromDelegate(row))
                  }
                  Button {
                    visible: root.activeTab !== "tasks"
                    text: root.noteIsPinned(root.noteFromDelegate(row)) ? "★" : "☆"
                    enabled: !root.busy
                    onClicked: root.togglePin(root.noteFromDelegate(row))
                  }
                  Button {
                    text: root.activeTab === "tasks" ? "Open" : "Open"
                    enabled: !root.busy
                    onClicked: root.openNote(root.noteFromDelegate(row))
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  z: -1
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openNote(root.noteFromDelegate(row))
                }
              }
        }

        Text {
          visible: root.activeTab !== "search" && displayedNotes.count === 0 && !root.busy
          width: parent.width
          text: root.activeTab === "recent"
            ? "No recent notes found. Open a note in Obsidian or from Companion."
            : (root.activeTab === "pinned"
            ? "No pinned notes yet. Pin one from Search or Recent."
            : "No open tasks found.")
          color: Color.popups.text
          opacity: 0.7
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.activeTab === "search" && root.results.length === 0 && !root.busy
            && root.query.trim() !== ""
          width: parent.width
          text: "No matching notes."
          color: Color.popups.text
          opacity: 0.7
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Column {
          visible: root.activeTab === "search" && displayedNotes.count > 0
          width: parent.width
          spacing: Style.space(6)
          TextField {
            id: aiQuestionField
            width: parent.width
            placeholderText: "Ask your configured AI about a search result"
            text: root.aiQuestion
            enabled: !root.busy
            onTextEdited: root.aiQuestion = text
          }
          Text {
            width: parent.width
            text: "AI actions send the selected note's text to your configured Omarchy agent. The prompt asks it not to modify files."
            color: Color.popups.text
            opacity: 0.68
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
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
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        activeTab: root.activeTab,
        selectedVault: root.selectedVault,
        busy: root.busy,
        pendingAction: root.pendingAction,
        queuedAction: root.queuedAction,
        recentCount: root.recent.length,
        visibleCount: displayedNotes.count,
        recentFirst: root.recent.length ? root.recent[0].path : "",
        error: root.errorMessage
      })
    }
  }
}
