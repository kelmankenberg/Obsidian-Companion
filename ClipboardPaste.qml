import QtQuick
import Quickshell.Io

Item {
  id: root
  required property SafeTextEdit editor

  Connections {
    target: root.editor
    function onPasteRequested() { reader.running = true }
  }

  Process {
    id: reader
    command: ["python3", decodeURIComponent(Qt.resolvedUrl("clipboard.py").toString().replace(/^file:\/\//, ""))]
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      Qt.callLater(function() { root.editor.finishPaste(exitCode, output.text) })
    }
  }
}
