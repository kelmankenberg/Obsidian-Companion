import QtQuick
import "../ResultText.js" as ResultText

Item {
  Component.onCompleted: {
    if (ResultText.primary("tasks", "Project", "Call the team", "Project.md") !== "Call the team"
        || ResultText.primary("tasks", "Project", "", "Project.md") !== "Project"
        || ResultText.primary("tasks", "", "", "Project.md") !== "Project.md"
        || ResultText.primary("search", "Project", "Call the team", "Project.md") !== "Project"
        || ResultText.primary("recent", "", "", "Project.md") !== "Project.md") {
      console.error("Result row text test failed")
      Qt.exit(1)
      return
    }
    Qt.quit()
  }
}
