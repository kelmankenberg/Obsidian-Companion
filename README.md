# Obsidian Companion

An Omarchy bar widget for everyday Obsidian vault access: search, recent and
pinned notes, daily notes, quick capture, note creation, open tasks, and an
explicit handoff to Omarchy's configured AI agent.

The plugin is an independent community project and is not affiliated with
Obsidian or Omarchy.

## Features

- Search Markdown note titles and contents across the selected vault. Press
  Enter to keep a term as a removable chip; results must match every chip plus
  any text still being typed. Backspace in the empty box removes the last chip.
- Open recent or pinned notes in Obsidian.
- Open or create today's daily note using Obsidian's Daily Notes settings
  (`.obsidian/daily-notes.json`) when available.
- Capture a bullet, task, or timestamped line into a dated Inbox note or
  today's daily note.
- Create a note in a chosen folder, optionally from a vault template.
- Review unchecked Markdown tasks, filter them by text or note path (using the
  same removable term chips as Search), sort by
  due date (ascending or descending; undated tasks last), and explicitly mark
  them done.
- Choose optional daily task summaries or alerts for due/overdue Obsidian
  Tasks items, with a configurable local time.
- Ask the configured Omarchy agent a question about a selected note. Click a
  note in Search, Recent, or Pinned to select it; use **Open** (or double-click)
  to open it in Obsidian.

The AI handoff is an explicit action. It sends the selected note text (up to
30,000 characters) and the user's question to `omarchy agent prompt`; the
generated prompt asks the agent not to change files, but that instruction is
not a sandbox. Agent providers may process the note according to their own
service and privacy terms. The prompt is passed to the agent CLI as a command
argument and may be visible to local process inspection tools while it runs.

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

## Use

Click the Obsidian icon. The plugin detects vaults from Obsidian's local
configuration; when more than one vault is known, switch between them from
the dropdown in the header.
Search, recent, pinned, and task views are separate tabs. Use **Today** to open
the current daily note. Captures go to an Inbox note or directly to today's
note. New notes are created in the folder you enter (default from Settings)
and can start from any template in the vault's configured templates folder.

**Recent** combines Obsidian's own history (`.obsidian/workspace.json`
`lastOpenFiles`) with notes opened from Companion. **Pinned** notes are saved
per vault. Companion's state lives in
`~/.local/state/obsidian-companion/state.json`.

Search, capture, and vault operations are local; no
search index, background service, or plugin-initiated network request is
created. AI handoff invokes the configured agent, which may send the selected
note to its provider.

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
- **Panel** — tab shown when the panel opens and bar position.
- **Recent** — include or hide Obsidian's own recent files, and clear the
  notes Companion has recorded (Obsidian's history is never modified).
- **AI** — show or hide Ask AI and manage preset questions.

Vault-specific settings apply to the current vault. Panel and AI settings
apply to all vaults. `omarchy-shell kel.obsidian-companion settings` opens the
panel directly on Settings.

## Requirements and permissions

- Omarchy Quattro with the Quickshell shell and plugin CLI.
- Python 3.
- Obsidian, for opening notes through `obsidian://` links.

Plugins run unsandboxed inside the Omarchy shell with your user permissions.
This plugin reads Markdown notes under the selected vault and writes only for
the explicit create, capture, and task-completion actions. Review the source
before enabling it.

## Development

```sh
python3 -m unittest discover -s tests
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" -I . BarWidget.qml Panel.qml SettingsView.qml ChipSearchField.qml Choice.qml
```

To try local changes, copy the plugin into
`~/.config/omarchy/plugins/kel.obsidian-companion` and run
`omarchy-restart-shell`. A plugin rescan alone may keep a cached copy of the
QML loaded.

## License

MIT
