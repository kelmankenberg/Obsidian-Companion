# Changelog

## Unreleased

## 0.4.1 - 2026-11-24

- Open task notes for completion in Obsidian instead of rewriting notes, avoiding
  lost concurrent edits.
- Record reminders only after successful notification delivery and retry failures.
- Refresh the marketplace preview to reflect the current clipboard-based AI flow.

## 0.4.0 - 2026-11-24

- Show task text prominently in task rows, above the note path and due date.
- Add keyboard navigation for search, task filters, and note lists, plus a
  documented shortcut setup for opening Companion.
- Allow quick capture to append to an existing note selected in Search.
- Add a header action to open the selected vault in Obsidian.
- Place search results directly beneath the search field, with expandable
  New note and Quick capture controls below the results.
- Make titles and paths easier to read in Recent and Pinned, with consistent
  labeled Pin/Unpin and Open controls.
- Show AI controls only when a note is selected or Ask AI is chosen, while
  keeping the clipboard privacy warning visible.
- Add tag and folder filters to Search, including nested tags and YAML tag
  properties. Tag filtering requires PyYAML.
- Preview selected notes as plain text and copy Obsidian links from Search,
  Recent, and Pinned.
- Filter tasks by overdue, today, upcoming, or undated alongside text and sort
  controls.

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
