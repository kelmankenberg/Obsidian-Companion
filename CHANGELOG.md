# Changelog

## 0.3.1 - 2026-11-16

- Replace native TextInput-based fields with plain-text editors that do not
  retrieve clipboard payloads on clipboard changes.
- Handle explicit keyboard paste outside the shared shell with a 16 KiB limit
  and a two-second timeout. Disable native middle-click paste.

## 0.3.0 - 2026-11-13

- Allow configuring activity checks from every minute to every 90 minutes.

## 0.2.0 - 2026-11-13

- Replace the bar glyph with a purple, faceted-gem icon inspired by Obsidian.
- Add a configurable activity-count badge for due tasks, note changes, and a
  missing daily note.
- Organize settings into categories with a sidebar.
- Add Settings links and GitHub issue forms for bug reports and feature requests.
- Show the installed plugin version and include it in feedback forms.
