function issueUrl(template, version) {
  return "https://github.com/kelmankenberg/Obsidian-Companion/issues/new?template="
    + encodeURIComponent(template) + "&plugin-version=" + encodeURIComponent(version)
}
