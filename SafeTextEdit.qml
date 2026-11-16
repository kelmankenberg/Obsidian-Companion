import QtQuick

// TextEdit checks MIME formats, not clipboard payloads, on clipboard changes.
TextEdit {
  id: root

  signal pasteFailed(string message)
  signal pasteRequested()
  signal unhandledKey(var event)
  property string pasteError: ""
  property bool pastePending: false
  property int pasteStart: 0
  property int pasteEnd: 0
  property string pasteOriginal: ""

  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  selectByMouse: true
  activeFocusOnTab: true
  clip: true

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onPressed: function(mouse) { mouse.accepted = true }
    onReleased: function(mouse) { mouse.accepted = true }
  }

  function requestPaste() {
    if (readOnly || !enabled || pastePending) return
    pasteError = ""
    pasteStart = selectionStart
    pasteEnd = selectionEnd
    pasteOriginal = text
    pastePending = true
    pasteRequested()
  }

  function finishPaste(exitCode, output) {
    pastePending = false
    var response
    try {
      response = JSON.parse(output)
    } catch (error) {
      response = { ok: false, error: "Could not read clipboard text." }
    }
    if (exitCode !== 0 || !response || response.ok !== true) {
      pasteError = response && response.error ? String(response.error) : "Clipboard helper failed."
      pasteFailed(pasteError)
      return
    }
    if (!activeFocus || readOnly || !enabled || text !== pasteOriginal
        || selectionStart !== pasteStart || selectionEnd !== pasteEnd) {
      pasteError = "Paste cancelled because the field changed or lost focus. Try again."
      pasteFailed(pasteError)
      return
    }
    var value = String(response.text).replace(/[\r\n\u2028\u2029]+/g, " ")
    if (text.length - (pasteEnd - pasteStart) + value.length > 16384) {
      pasteError = "Pasting would exceed the 16 KiB field limit."
      pasteFailed(pasteError)
      return
    }
    remove(pasteStart, pasteEnd)
    insert(pasteStart, value)
    cursorPosition = pasteStart + value.length
    textEdited()
  }

  Keys.onPressed: function(event) {
    if (event.matches(StandardKey.Paste)) {
      event.accepted = true
      root.requestPaste()
    } else {
      root.unhandledKey(event)
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        event.accepted = true
    }
  }
}
