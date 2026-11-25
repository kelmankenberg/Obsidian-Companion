# Obsidian Companion

An Omarchy bar widget for everyday Obsidian vault access: search, recent and
pinned notes, daily notes, quick capture, note creation, open tasks, and an
an explicit AI prompt you can copy into your preferred agent.

The plugin is an independent community project and is not affiliated with
Obsidian or Omarchy.

## Features

- Search Markdown note titles and contents across the selected vault. Press
  Enter to keep a term as a removable chip; results must match every chip plus
  any text still being typed. Backspace in the empty box removes the last chip.
  Filter by an inline or YAML-property tag and/or a vault-relative folder.
- Open the selected vault or recent and pinned notes in Obsidian. Recent and
  Pinned show each note's title and path beside its Pin/Unpin and Open actions.
- Preview the beginning of a selected note as plain text or copy its Obsidian
  link from Search, Recent, and Pinned.
- Open or create today's daily note using Obsidian's Daily Notes settings
  (`.obsidian/daily-notes.json`) when available.
- Capture a bullet, task, or timestamped line into a dated Inbox note, today's
  daily note, or an existing note selected from search results.
- Create a note in a chosen folder, optionally from a vault template.
- Review unchecked Markdown tasks, filter them by text or note path (using the
  same removable term chips as Search) and by due-date category, sort by due
  date (ascending or descending; undated tasks last), and explicitly mark them
  done.
- Choose optional daily task summaries or alerts for due/overdue Obsidian
  Tasks items, with a configurable local time.
- Show an activity count on the bar icon for due tasks, changed notes, and a
  missing daily note. Configure these independently in Settings.
- Prepare an AI question about a selected note. The AI controls appear when
  you select a note in Search, Recent, or Pinned, or choose **Ask AI**. Use
  **Copy AI prompt** and paste it into your agent. Use **Open** (or double-click)
  to open the note in Obsidian.

Copying is explicit: the prompt contains up to 30,000 characters of the note
and your question. It is sent to `wl-copy` via standard input, not process
arguments, with a sensitive-clipboard hint. Other applications or clipboard
managers may still read or retain clipboard contents; clear it when finished.
The generated prompt asks the agent not to change files, but that instruction
is not a sandbox. Agent providers may process the note according to their own
service and privacy terms.

## Install

```sh
omarchy plugin add https://github.com/kelmankenberg/Obsidian-Companion.git --enable
```

The widget defaults to the right side of the bar. Move it from **Settings →
Panel → Bar position**, or with Omarchy's standard bar command:

```sh
omarchy bar move kel.obsidian-companion --section left
omarchy bar move kel.obsidian-companion --section center
omarchy bar move kel.obsidian-companion --section right
```

## Remove

```sh
omarchy plugin remove kel.obsidian-companion
rm -rf ~/.local/state/obsidian-companion   # optional: pinned notes, recent history, settings
```

Removing the plugin never touches your vaults. Notes and tasks you created or
captured stay in Obsidian.

## Keyboard navigation

To open or close Companion with a global shortcut, add a Hyprland binding in
`~/.config/hypr/bindings.lua` using a key combination that is free on your
system, for example:

```lua
o.bind("SUPER + ALT + O", "Obsidian Companion", { panel = "kel.obsidian-companion" })
```

Use Ctrl+1 through Ctrl+4 to switch between Search, Recent, Pinned, and Tasks.
In Search or Tasks, type to filter and press Down to select a result. Use
Up/Down to move, Enter to open the selected note, and Up on the first result
to return to the filter. Enter in a filter still adds a term chip. Recent and
Pinned lists also support Up/Down and Enter. Escape clears a nonempty filter
first; otherwise it closes the panel.
In Search, use Alt+N to open New note, Alt+C for Quick capture, Alt+T for the
tag filter, Alt+F for the folder filter, or Alt+Shift+F to clear both filters.
Use Alt+A to show Ask AI on Search, Recent, or Pinned; with a selected note,
Alt+P toggles its preview and Alt+L copies its link. In Tasks, Alt+D opens the
due-date filter; use Up/Down and Enter to choose an option.

## Use

Click the Obsidian icon. The plugin detects vaults from Obsidian's local
configuration; when more than one vault is known, switch between them from
the dropdown in the header.
Search, recent, pinned, and task views are separate tabs. Use **Obsidian** in
the header to open or focus the selected vault (the vault must first be opened
in Obsidian). Use **Today** to open the current daily note. Search results
appear directly below the search field. Use **New note** or **Quick capture**
below the results to expand the corresponding controls; drafts are retained
when switching sections. To capture to an existing note, select its search
result by clicking it or navigating to it with the keyboard, open **Quick
capture**, enter the capture, and click **Selected note**. The capture is
appended to the end of that Markdown note using the configured capture format.
The Inbox and Daily buttons and Enter's configured default still work as
before. New notes are created in the folder you enter (default from Settings)
and can start from any template in the vault's configured templates folder.

Select a note in Search, Recent, or Pinned and choose **Preview** to read up to
4,000 characters of its raw Markdown as plain text. Choose **Copy link** to
copy an `obsidian://` link without copying the note itself. The link uses the
registered vault ID when available, otherwise the vault folder name; open a
custom vault in Obsidian first if its name is ambiguous. Clipboard managers
and other applications may read or retain copied links.

Enter a tag and/or folder above Search and press **Apply** (or Enter) to filter
results. Filters work with search terms or on their own; **Clear** removes
them without clearing search terms. Tags are case-insensitive, include nested
tags, and match inline tags or the YAML `tags` property. Inline code, fenced
code, and HTML comments are not treated as tags. Folder paths are relative to
the vault and include subfolders; use `.` for notes directly in the vault
root. Excluded folders remain excluded.

In **Tasks**, choose **All due dates**, **Overdue**, **Due today**, **Upcoming**,
or **Undated**. These filters use the local date and can be combined with text
terms and sorting. Upcoming includes all future dates; undated includes tasks
with missing or invalid `📅 YYYY-MM-DD` dates. The all-dates view remains the
default, and changing vaults resets the date filter.

**Recent** combines Obsidian's own history (`.obsidian/workspace.json`
`lastOpenFiles`) with notes opened from Companion. **Pinned** notes are saved
per vault. Companion's state lives in
`~/.local/state/obsidian-companion/state.json`.
The state directory is owner-only (`0700`) and its files are owner-readable
and writable (`0600`); existing state permissions are repaired when loaded.
Note titles and previews are displayed as plain text, never rendered as HTML.

Search, capture, and vault operations are local; no
search index, background service, or plugin-initiated network request is
created. When you paste an AI prompt into an agent, that agent may send the
selected note to its provider.

Reminder settings are per vault and off by default. Due-date alerts recognize
the Obsidian Tasks `📅 YYYY-MM-DD` marker; they notify once at the chosen time
on the due date or later if the shell was not running then. Daily summaries
count open tasks without including task text in the notification.

## Settings

Click the large ⚙ button to open Settings, then **Save** to apply edits.
Vault, bar-position, and history actions apply immediately.

- **Vaults** — switch vaults, add a vault folder that Obsidian has not
  registered, or remove an added vault.
- **New notes** — default folder and template.
- **Quick capture** — Inbox folder, line format (bullet, task, or
  timestamped), and whether Enter sends to the Inbox or today's daily note.
- **Daily notes** — optionally override Obsidian's daily note folder, date
  format, and template.
- **Search and tasks** — folders to exclude (relative to the vault, including
  subfolders).
- **Task reminders** — off, daily summary, or due-date alerts, and the time.
- **Panel & badge** — default tab, bar position, and activity badge triggers.
- **Recent** — include or hide Obsidian's own recent files, and clear the
  notes Companion has recorded (Obsidian's history is never modified).
- **AI** — show or hide Ask AI and manage preset questions.
- **Feedback** — open a GitHub form to report a bug or request a feature.
  The installed version is prefilled. Issues are public; remove private vault
  information before submitting.

Vault-specific settings apply to the current vault. Panel and AI settings
apply to all vaults. `omarchy-shell kel.obsidian-companion settings` opens the
panel directly on Settings.

The badge checks the selected vault every minute by default; Settings can
change the interval to 5, 10, 15, 30, 60, or 90 minutes per vault. It also
checks when Companion opens and after certain actions. It counts open tasks
due today or earlier, new or modified Markdown files, and a missing daily
note. Excluded folders are ignored for tasks and note changes. Opening
Companion acknowledges note changes; tasks and the missing daily note remain
until resolved. Note-change tracking starts with a fresh baseline when the
shell restarts or the vault changes, and detects changes made by any
application.

## Requirements and permissions

- Omarchy Quattro with the Quickshell shell and plugin CLI.
- Python 3.
- PyYAML 6 (`omarchy pkg add python-yaml` on Omarchy), for tag filtering.
- `wl-clipboard` (`wl-copy` for AI prompts and note links, `wl-paste` for pasting).
- Obsidian, for opening notes through `obsidian://` links.

Plugins run unsandboxed inside the Omarchy shell with your user permissions.
This plugin reads Markdown notes under the selected vault and writes only for
the explicit create, capture, and task-completion actions. Review the source
before enabling it.

Text fields do not read clipboard payloads just because the clipboard changes.
Use Ctrl+V or Shift+Insert to paste. Explicit pastes run in a separate helper
with a 16 KiB limit and a two-second timeout; failures appear by the field.
Multiline clipboard text is flattened to a single line. Native middle-click
paste is disabled.

## Development

```sh
python3 -m unittest discover -s tests
QT_QPA_PLATFORM=offscreen qml6 tests/test_activity.qml
QT_QPA_PLATFORM=offscreen qml6 tests/test_feedback.qml
QT_QPA_PLATFORM=offscreen qml6 tests/test_result_text.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_safe_input.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_keyboard_results.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_note_location.qml
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" -I . BarWidget.qml Panel.qml SettingsView.qml ChipSearchField.qml Choice.qml SafeTextEdit.qml SafeTextField.qml ClipboardPaste.qml InputViewport.qml KeyboardResultList.qml SearchActionControls.qml SearchFilterControls.qml TaskDateControls.qml NoteLocationText.qml NotePathToolTip.qml NotePreviewControls.qml AiPromptControls.qml
```

The Python suite includes an offscreen Quickshell paste integration test using
a fictional clipboard provider. With Qt development headers and `pkg-config`,
the native clipboard-offer regression can also be run:

```sh
build_dir=$(mktemp -d)
c++ -std=c++17 tests/test_clipboard_offer.cpp -o "$build_dir/clipboard-offer-test" $(pkg-config --cflags --libs Qt6Quick Qt6Gui Qt6Qml)
QT_QPA_PLATFORM=offscreen "$build_dir/clipboard-offer-test" "$PWD/SafeTextEdit.qml"
rm "$build_dir/clipboard-offer-test"
rmdir "$build_dir"
```

To try local changes, copy the plugin into
`~/.config/omarchy/plugins/kel.obsidian-companion` and run
`omarchy-restart-shell`. A plugin rescan alone may keep a cached copy of the
QML loaded.

## License

MIT
