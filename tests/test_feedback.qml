import QtQuick
import "../Feedback.js" as Feedback

Item {
  Component.onCompleted: {
    const root = "https://github.com/kelmankenberg/Obsidian-Companion/issues/new?template="
    if (Feedback.issueUrl("bug_report.yml", "0.1.0") !== root + "bug_report.yml&plugin-version=0.1.0"
        || Feedback.issueUrl("feature_request.yml", "1.0+build 1") !== root + "feature_request.yml&plugin-version=1.0%2Bbuild%201") {
      console.error("Feedback issue URL test failed")
      Qt.exit(1)
      return
    }
    Qt.quit()
  }
}
