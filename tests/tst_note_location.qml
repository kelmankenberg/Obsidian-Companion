import QtQuick
import QtTest
import ".." as Plugin

Item {
  width: 240
  height: 200

  Plugin.NoteLocationText {
    id: location
    width: 200
    height: implicitHeight
    titleSize: 16
    pathSize: 13
  }

  TestCase {
    name: "NoteLocation"
    when: windowShown

    function test_title_and_path_are_plain_text() {
      location.title = "<b>Planning</b>"
      location.path = "Projects/<img src='https://invalid.example/x'>/Planning.md"
      var title = findChild(location, "noteTitle")
      var path = findChild(location, "notePath")
      compare(title.text, location.title)
      compare(path.text, location.path)
      compare(title.textFormat, Text.PlainText)
      compare(path.textFormat, Text.PlainText)
      verify(path.y >= title.y + title.height)
    }

    function test_long_paths_are_wrapped_and_truncated() {
      location.title = "Meeting"
      location.path = "folder/".repeat(40) + "Meeting.md"
      var path = findChild(location, "notePath")
      tryVerify(function() { return location.pathTruncated })
      verify(path.lineCount <= 2)
      verify(path.lineCount > 1)
    }

    function test_missing_title_falls_back_to_path() {
      location.title = ""
      location.path = "Projects/Meeting.md"
      compare(findChild(location, "noteTitle").text, location.path)
      tryVerify(function() { return !location.pathTruncated })
    }
  }
}
