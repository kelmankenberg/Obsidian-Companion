import QtQuick
import QtTest
import ".." as Plugin

Item {
  width: 400
  height: 100

  Plugin.InputViewport {
    id: viewport
    editor: input
    width: 400
    height: 40
    Plugin.SafeTextEdit {
      id: input
      width: viewport.width
      height: viewport.height
    }
  }

  SignalSpy { id: edits; target: input; signalName: "textEdited" }
  SignalSpy { id: pastes; target: input; signalName: "pasteRequested" }

  TestCase {
    name: "SafeInput"
    when: windowShown

    function init() {
      input.text = ""
      input.readOnly = false
      input.forceActiveFocus()
      input.pasteError = ""
      input.pastePending = false
      edits.clear()
      pastes.clear()
    }

    function preparePaste(text, start, end) {
      input.text = text
      input.select(start, end)
      input.pasteOriginal = input.text
      input.pasteStart = input.selectionStart
      input.pasteEnd = input.selectionEnd
    }

    function test_typing_selection_and_no_newlines() {
      keyClick(Qt.Key_A)
      keyClick(Qt.Key_B)
      compare(input.text, "ab")
      keyClick(Qt.Key_Return)
      compare(input.text, "ab")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      keyClick(Qt.Key_C)
      compare(input.text, "c")
    }

    function test_bounded_plain_text_paste() {
      preparePaste("hello world", 6, 11)
      input.finishPaste(0, JSON.stringify({ok: true, text: "<b>note</b>\nnext"}))
      compare(input.text, "hello <b>note</b> next")
      compare(edits.count, 1)
      compare(input.textFormat, TextEdit.PlainText)
    }

    function test_rejects_failed_and_oversized_paste() {
      preparePaste("keep", 0, 4)
      input.finishPaste(1, JSON.stringify({ok: false, error: "Clipboard provider timed out."}))
      compare(input.text, "keep")
      verify(input.pasteError.indexOf("timed out") >= 0)
      input.finishPaste(0, JSON.stringify({ok: true, text: "a".repeat(16385)}))
      compare(input.text, "keep")
      verify(input.pasteError.indexOf("limit") >= 0)
    }

    function test_does_not_replace_text_changed_while_waiting() {
      preparePaste("old", 0, 3)
      input.text = "new"
      input.finishPaste(0, JSON.stringify({ok: true, text: "clipboard"}))
      compare(input.text, "new")
      verify(input.pasteError.indexOf("cancelled") >= 0)
    }

    function test_paste_shortcuts_do_not_use_native_paste() {
      input.text = "unchanged"
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(pastes.count, 1)
      compare(input.text, "unchanged")
      input.pastePending = false
      keyClick(Qt.Key_Insert, Qt.ShiftModifier)
      compare(pastes.count, 2)
      compare(input.text, "unchanged")
    }

    function test_middle_click_does_not_paste() {
      input.text = "unchanged"
      mouseClick(input, 20, 10, Qt.MiddleButton)
      compare(input.text, "unchanged")
      compare(pastes.count, 0)
    }

    function test_long_field_keeps_cursor_visible() {
      input.text = "a".repeat(500)
      input.cursorPosition = input.length
      verify(viewport.contentX > 0)
      input.cursorPosition = 0
      compare(viewport.contentX, 0)
    }
  }
}
