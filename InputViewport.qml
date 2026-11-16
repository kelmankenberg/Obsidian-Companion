import QtQuick

Flickable {
  id: root
  required property SafeTextEdit editor
  clip: true
  interactive: false
  contentWidth: Math.max(width, editor.contentWidth + editor.cursorRectangle.width)
  contentHeight: height

  function revealCursor() {
    var cursor = editor.cursorRectangle
    if (cursor.x < contentX) contentX = cursor.x
    else if (cursor.x + cursor.width > contentX + width)
      contentX = cursor.x + cursor.width - width
    contentX = Math.max(0, Math.min(contentX, contentWidth - width))
  }

  onWidthChanged: revealCursor()
  onContentWidthChanged: revealCursor()
  Connections {
    target: root.editor
    function onCursorRectangleChanged() { root.revealCursor() }
  }
}
