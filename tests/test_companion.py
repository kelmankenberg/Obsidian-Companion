import datetime as dt
import builtins
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import companion


class CompanionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "Vault"
        self.root.mkdir()
        self.state_path = Path(self.temp.name) / "state.json"
        companion.STATE_PATH = self.state_path
        (self.root / ".obsidian").mkdir()
        config = Path(self.temp.name) / "obsidian.json"
        config.write_text(json.dumps({
            "vaults": {"one": {"path": str(self.root), "open": True}}
        }), encoding="utf-8")
        self.config_path = Path.home() / ".config" / "obsidian" / "obsidian.json"
        self.original_config = companion._obsidian_config
        companion._obsidian_config = lambda: json.loads(config.read_text(encoding="utf-8"))
        self.addCleanup(setattr, companion, "_obsidian_config", self.original_config)
        self.root_argument = str(self.root)

    def run_action(self, action, **values):
        return companion._handle({"action": action, "vault": self.root_argument, **values})

    def test_settings_payload_reads_version_from_installed_manifest(self):
        manifest_dir = Path(self.temp.name) / "plugin"
        manifest_dir.mkdir()
        (manifest_dir / "manifest.json").write_text(
            json.dumps({"version": "2.3.4-beta"}), encoding="utf-8"
        )
        with patch.object(companion, "__file__", str(manifest_dir / "companion.py")):
            self.assertEqual(self.run_action("init")["pluginVersion"], "2.3.4-beta")
            (manifest_dir / "manifest.json").write_text('{"version": ""}', encoding="utf-8")
            with self.assertRaisesRegex(companion.CompanionError, "version.*empty"):
                self.run_action("init")

    def test_state_saves_are_private_with_permissive_umask(self):
        self.state_path = Path(self.temp.name) / "private-state" / "state.json"
        companion.STATE_PATH = self.state_path
        previous_umask = os.umask(0o022)
        try:
            for value in ("first save", "replacement save"):
                companion._write_state({"vault": value})
                self.assertEqual(stat.S_IMODE(self.state_path.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(self.state_path.parent.stat().st_mode), 0o700)
                self.assertEqual(json.loads(self.state_path.read_text()), {"vault": value})
                self.assertEqual(list(self.state_path.parent.iterdir()), [self.state_path])
        finally:
            os.umask(previous_umask)

    def test_loading_existing_state_repairs_permissions_without_changing_data(self):
        self.state_path = Path(self.temp.name) / "existing-state" / "state.json"
        companion.STATE_PATH = self.state_path
        self.state_path.parent.mkdir()
        self.state_path.write_text('{"vault": "existing vault"}', encoding="utf-8")
        self.state_path.parent.chmod(0o755)
        self.state_path.chmod(0o644)
        original = self.state_path.read_bytes()
        self.assertEqual(companion._state()["vault"], "existing vault")
        self.assertEqual(stat.S_IMODE(self.state_path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.state_path.parent.stat().st_mode), 0o700)
        self.assertEqual(self.state_path.read_bytes(), original)

    def test_search_skips_obsidian_metadata_and_returns_matching_preview(self):
        (self.root / "note.md").write_text("# Project\nA useful phrase here.\n", encoding="utf-8")
        (self.root / ".obsidian" / "private.md").write_text("useful phrase", encoding="utf-8")
        results = self.run_action("search", query="useful phrase")["items"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["path"], "note.md")
        self.assertEqual(results[0]["preview"], "A useful phrase here.")

    def test_search_filters_folders_including_nested_and_root(self):
        (self.root / "Work" / "Nested").mkdir(parents=True)
        (self.root / "Workshops").mkdir()
        (self.root / "Work" / "a.md").write_text("Alpha needle", encoding="utf-8")
        (self.root / "Work" / "Nested" / "b.md").write_text("Beta needle", encoding="utf-8")
        (self.root / "Workshops" / "c.md").write_text("Other needle", encoding="utf-8")
        (self.root / "root.md").write_text("Root needle", encoding="utf-8")
        found = self.run_action("search", folder="Work")["items"]
        self.assertEqual([item["path"] for item in found], ["Work/a.md", "Work/Nested/b.md"])
        found = self.run_action("search", folder="Work", query="beta")["items"]
        self.assertEqual([item["path"] for item in found], ["Work/Nested/b.md"])
        found = self.run_action("search", folder=".")["items"]
        self.assertEqual([item["path"] for item in found], ["root.md"])
        self.run_action("save_vault_settings", settings={"excludedFolders": ["Work/Nested"]})
        found = self.run_action("search", folder="Work")["items"]
        self.assertEqual([item["path"] for item in found], ["Work/a.md"])

    def test_search_filters_inline_and_yaml_tags_and_nested_tags(self):
        (self.root / "inline.md").write_text("Useful #Work/Meeting\n", encoding="utf-8")
        (self.root / "metadata.md").write_text(
            '---\n"tags": ["work", "research/β", "café"]\n---\nUseful text\n',
            encoding="utf-8",
        )
        (self.root / "list.md").write_text(
            "---\ntags:\n  - work/meeting\n  - 'other'\n---\nUseful text\n", encoding="utf-8"
        )
        (self.root / "different.md").write_text("#workshop\n", encoding="utf-8")
        (self.root / "code.md").write_text(
            "```\n#work\n```\n`#work` \\#work <!-- #work -->\n"
            "<a href='#work'>link</a>\n", encoding="utf-8"
        )
        found = self.run_action("search", tag="#WORK")["items"]
        self.assertEqual({item["path"] for item in found}, {"inline.md", "metadata.md", "list.md"})
        found = self.run_action("search", tag="work/meeting", terms=["useful"])["items"]
        self.assertEqual({item["path"] for item in found}, {"inline.md", "list.md"})
        self.assertEqual([item["path"] for item in self.run_action("search", tag="CAFÉ")["items"]],
                         ["metadata.md"])
        self.assertEqual([item["path"] for item in self.run_action("search", tag="research/β")["items"]],
                         ["metadata.md"])

    def test_search_rejects_invalid_filters_and_reports_invalid_yaml(self):
        for folder in ("../outside", "/tmp", "folder/../other", ".obsidian"):
            with self.subTest(folder=folder), self.assertRaises(companion.CompanionError):
                self.run_action("search", folder=folder)
        for tag in ("#", "two words", "123", "tag//child"):
            with self.subTest(tag=tag), self.assertRaises(companion.CompanionError):
                self.run_action("search", tag=tag)
        (self.root / "bad.md").write_text("---\ntags: [broken\n---\n", encoding="utf-8")
        with self.assertRaisesRegex(companion.CompanionError, "YAML tags in bad.md"):
            self.run_action("search", tag="work")

    def test_search_tag_filter_handles_unmatched_and_multiline_code_spans(self):
        (self.root / "note.md").write_text(
            "Unmatched `` marker and #visible\n"
            "A `code span\n#hidden` and #also-visible\n",
            encoding="utf-8",
        )
        for tag in ("visible", "also-visible"):
            self.assertEqual(len(self.run_action("search", tag=tag)["items"]), 1)
        self.assertEqual(self.run_action("search", tag="hidden")["items"], [])

    def test_search_reports_missing_yaml_only_for_tag_filters(self):
        original_import = builtins.__import__

        def import_without_yaml(name, *args, **kwargs):
            if name == "yaml":
                raise ModuleNotFoundError("No module named 'yaml'", name="yaml")
            return original_import(name, *args, **kwargs)

        (self.root / "note.md").write_text("needle #work", encoding="utf-8")
        with patch("builtins.__import__", side_effect=import_without_yaml):
            self.assertEqual(len(self.run_action("search", query="needle")["items"]), 1)
            with self.assertRaisesRegex(companion.CompanionError, "requires python-yaml"):
                self.run_action("search", tag="work")

    def test_activity_counts_due_tasks_and_missing_daily_note(self):
        today = dt.date.today()
        yesterday = (today - dt.timedelta(days=1)).isoformat()
        tomorrow = (today + dt.timedelta(days=1)).isoformat()
        (self.root / "tasks.md").write_text(
            f"- [ ] Overdue 📅 {yesterday}\n"
            f"- [ ] Due today 📅 {today.isoformat()}\n"
            f"- [ ] Future 📅 {tomorrow}\n"
            "- [ ] Invalid 📅 2026-99-99\n"
            f"- [x] Done 📅 {yesterday}\n",
            encoding="utf-8",
        )
        response = self.run_action("activity")
        self.assertEqual(response["due"], 2)
        self.assertTrue(response["daily"])
        self.assertEqual(list(response["files"]), ["tasks.md"])
        self.assertFalse((self.root / f"{today.isoformat()}.md").exists())
        (self.root / f"{today.isoformat()}.md").write_text("# Today\n", encoding="utf-8")
        self.assertFalse(self.run_action("activity")["daily"])

    def test_activity_respects_settings_exclusions_and_daily_override(self):
        (self.root / "Archive").mkdir()
        (self.root / "Archive" / "hidden.md").write_text(
            "- [ ] Hidden 📅 2000-01-01\n", encoding="utf-8"
        )
        (self.root / "visible.md").write_text("- [ ] Visible 📅 2000-01-01\n", encoding="utf-8")
        self.run_action("save_vault_settings", settings={
            "excludedFolders": ["Archive"],
            "dailyOverride": True,
            "dailyFolder": "Journal",
            "dailyFormat": "YYYY-MM-DD",
        })
        (self.root / "Journal").mkdir()
        (self.root / "Journal" / f"{dt.date.today().isoformat()}.md").write_text("# Today\n")
        result = self.run_action("activity")
        self.assertEqual(result["due"], 1)
        self.assertFalse(result["daily"])
        self.assertNotIn("Archive/hidden.md", result["files"])
        first = result["files"]["visible.md"]
        (self.root / "visible.md").write_text("Changed note content\n")
        self.assertNotEqual(first, self.run_action("activity")["files"]["visible.md"])
        self.run_action("save_vault_settings", settings={
            "badgeDue": False, "badgeChanges": False, "badgeDaily": False,
        })
        result = self.run_action("activity")
        self.assertEqual((result["due"], result["daily"], result["files"]), (0, False, {}))
        payload = self.run_action("save_vault_settings", settings={"newNoteFolder": "Notes"})
        self.assertEqual(
            [payload["vaultSettings"][key] for key in ("badgeDue", "badgeChanges", "badgeDaily")],
            [False, False, False],
        )

    def test_activity_rejects_non_boolean_badge_settings(self):
        with self.assertRaisesRegex(companion.CompanionError, "badgeDue must be true or false"):
            self.run_action("save_vault_settings", settings={"badgeDue": "false"})

    def test_activity_check_interval_persists_per_vault(self):
        self.assertEqual(self.run_action("init")["vaultSettings"]["badgeIntervalMinutes"], 1)
        for interval in (1, 5, 10, 15, 30, 60, 90):
            with self.subTest(interval=interval):
                result = self.run_action("save_vault_settings", settings={"badgeIntervalMinutes": interval})
                self.assertEqual(result["vaultSettings"]["badgeIntervalMinutes"], interval)
                self.assertEqual(self.run_action("init")["vaultSettings"]["badgeIntervalMinutes"], interval)
        other_vault = self.root.parent / "Other"
        other_vault.mkdir()
        self.assertEqual(companion._vault_settings(companion._state(), other_vault)["badgeIntervalMinutes"], 1)

    def test_activity_check_interval_rejects_invalid_values(self):
        self.run_action("save_vault_settings", settings={"badgeIntervalMinutes": 15})
        for interval in (0, 2, 91, True, "15", None):
            with self.subTest(interval=interval):
                with self.assertRaisesRegex(companion.CompanionError, "valid activity check interval"):
                    self.run_action("save_vault_settings", settings={"badgeIntervalMinutes": interval})
                self.assertEqual(self.run_action("init")["vaultSettings"]["badgeIntervalMinutes"], 15)

    def test_daily_note_uses_vault_daily_notes_settings(self):
        (self.root / ".obsidian" / "daily-notes.json").write_text(
            json.dumps({
                "folder": "Journal",
                "format": "YYYY/MMMM/YYYY-MM-DD",
                "template": "Templates/Daily.md",
            }),
            encoding="utf-8",
        )
        (self.root / "Templates").mkdir()
        (self.root / "Templates" / "Daily.md").write_text(
            "# {{date:YYYY-MM-DD}}\n\n{{title}}\n", encoding="utf-8"
        )
        response = self.run_action("daily")
        self.assertTrue(response["uri"].startswith("obsidian://open?"))
        today = dt.date.today()
        expected = self.root / "Journal" / str(today.year) / today.strftime("%B") / f"{today.isoformat()}.md"
        self.assertTrue(expected.is_file())
        self.assertIn(f"# {today.isoformat()}", expected.read_text(encoding="utf-8"))

    def test_capture_is_appended_to_selected_destination(self):
        response = self.run_action("capture", destination="inbox", folder="Inbox", text="Remember this")
        self.assertIn("Inbox/", response["message"])
        capture = self.root / "Inbox" / f"{dt.date.today().isoformat()}.md"
        self.assertIn("- Remember this", capture.read_text(encoding="utf-8"))

    def test_open_vault_uses_obsidian_id_for_selected_path(self):
        other = Path(self.temp.name) / "Other" / self.root.name
        other.mkdir(parents=True)
        self.addCleanup(setattr, companion, "_obsidian_config", companion._obsidian_config)
        companion._obsidian_config = lambda: {
            "vaults": {
                "first&vault": {"path": str(self.root)},
                "second": {"path": str(other)},
            }
        }
        self.assertEqual(self.run_action("open_vault")["uri"],
                         "obsidian://open?vault=first%26vault")
        response = companion._handle({"action": "open_vault", "vault": str(other)})
        self.assertEqual(response["uri"], "obsidian://open?vault=second")

    def test_open_vault_rejects_unregistered_or_missing_vault(self):
        custom = Path(self.temp.name) / "Custom"
        custom.mkdir()
        with self.assertRaisesRegex(companion.CompanionError, "Open this vault in Obsidian"):
            companion._handle({"action": "open_vault", "vault": str(custom)})
        custom.rmdir()
        with self.assertRaisesRegex(companion.CompanionError, "existing Obsidian vault"):
            companion._handle({"action": "open_vault", "vault": str(custom)})

    def test_preview_reads_bounded_literal_text_and_empty_notes(self):
        note = self.root / "note.md"
        content = "<img src='https://invalid.example/a'>\n" + "x" * companion.MAX_PREVIEW_CHARS
        note.write_text(content, encoding="utf-8")
        response = self.run_action("preview_note", path="note.md")
        self.assertEqual(response["text"], content[:companion.MAX_PREVIEW_CHARS])
        self.assertTrue(response["truncated"])
        self.assertEqual(note.read_text(encoding="utf-8"), content)
        note.write_text("x" * companion.MAX_PREVIEW_CHARS, encoding="utf-8")
        self.assertFalse(self.run_action("preview_note", path="note.md")["truncated"])
        note.write_text("", encoding="utf-8")
        self.assertEqual(self.run_action("preview_note", path="note.md"),
                         {"ok": True, "text": "", "truncated": False})
        note.write_bytes(b"\xff")
        with self.assertRaisesRegex(companion.CompanionError, "Could not read note"):
            self.run_action("preview_note", path="note.md")

    def test_preview_and_copy_reject_unavailable_or_outside_notes(self):
        (self.root / "not-note.txt").write_text("private", encoding="utf-8")
        for action in ("preview_note", "copy_note_link"):
            for path in ("missing.md", "not-note.txt", "../outside.md"):
                with self.subTest(action=action, path=path), self.assertRaises(companion.CompanionError):
                    self.run_action(action, path=path)

    def test_copy_note_link_uses_registered_vault_id_and_encoded_path(self):
        folder = self.root / "Work & projects"
        folder.mkdir()
        (folder / "café #1.md").write_text("Secret body", encoding="utf-8")
        with patch.object(companion.subprocess, "run") as copy:
            response = self.run_action("copy_note_link", path="Work & projects/café #1.md")
        args, kwargs = copy.call_args
        self.assertEqual(args[0], ["wl-copy", "--sensitive"])
        parsed = urlparse(kwargs["input"])
        self.assertEqual((parsed.scheme, parsed.netloc), ("obsidian", "open"))
        self.assertEqual(parse_qs(parsed.query),
                         {"vault": ["one"], "file": ["Work & projects/café #1"]})
        self.assertNotIn("Secret body", kwargs["input"])
        self.assertNotIn("uri", response)

    def test_copy_note_link_supports_custom_vault_and_reports_clipboard_failure(self):
        custom = self.root.parent / "Custom vault"
        custom.mkdir()
        (custom / "note.md").write_text("note", encoding="utf-8")
        with patch.object(companion.subprocess, "run") as copy:
            companion._handle({"action": "copy_note_link", "vault": str(custom), "path": "note.md"})
        self.assertEqual(parse_qs(urlparse(copy.call_args.kwargs["input"]).query)["vault"],
                         ["Custom vault"])
        with patch.object(companion.subprocess, "run", side_effect=OSError("missing")):
            with self.assertRaisesRegex(companion.CompanionError, "Could not copy the note link"):
                companion._handle({"action": "copy_note_link", "vault": str(custom), "path": "note.md"})

    def test_capture_to_existing_note_preserves_boundaries_and_capture_format(self):
        folder = self.root / "Notes"
        folder.mkdir()
        note = folder / "meeting.md"
        for contents, capture_format, expected in (
            ("", "bullet", "- New idea\n"),
            ("# Meeting\n", "task", "# Meeting\n- [ ] New idea\n"),
            ("# Meeting", "bullet", "# Meeting\n- New idea\n"),
        ):
            with self.subTest(contents=contents, capture_format=capture_format):
                note.write_text(contents, encoding="utf-8")
                self.run_action("save_vault_settings", settings={"captureFormat": capture_format})
                response = self.run_action("capture", destination="note", path="Notes/meeting.md",
                                           text="New idea")
                self.assertIn("Notes/meeting.md", response["message"])
                self.assertEqual(note.read_text(encoding="utf-8"), expected)
        note.write_text("Existing\n", encoding="utf-8")
        self.run_action("save_vault_settings", settings={"captureFormat": "timestamp"})
        self.run_action("capture", destination="note", path="Notes/meeting.md", text="New idea")
        self.assertRegex(note.read_text(encoding="utf-8"), r"^Existing\n- \d{2}:\d{2} New idea\n$")

    def test_capture_to_existing_note_rejects_invalid_and_unsafe_targets(self):
        outside = Path(self.temp.name) / "outside.md"
        outside.write_text("Outside", encoding="utf-8")
        (self.root / "real.md").write_text("Real", encoding="utf-8")
        (self.root / "text.txt").write_text("Text", encoding="utf-8")
        (self.root / "file-link.md").symlink_to(outside)
        (self.root / "internal-link.md").symlink_to(self.root / "real.md")
        (self.root / "directory-link").symlink_to(Path(self.temp.name), target_is_directory=True)
        (self.root / "Archive").mkdir()
        (self.root / "Archive" / "hidden.md").write_text("Hidden", encoding="utf-8")
        os.mkfifo(self.root / "pipe.md")
        self.run_action("save_vault_settings", settings={"excludedFolders": ["Archive"]})
        for target in (None, "", "missing.md", "../outside.md", str(outside), "text.txt",
                       ".obsidian/private.md", "file-link.md", "internal-link.md",
                       "directory-link/outside.md", "Archive/hidden.md", "pipe.md"):
            with self.subTest(target=target), self.assertRaises(companion.CompanionError):
                self.run_action("capture", destination="note", path=target, text="Must not write")
        self.assertEqual(outside.read_text(encoding="utf-8"), "Outside")
        self.assertEqual((self.root / "real.md").read_text(encoding="utf-8"), "Real")
        self.assertFalse((self.root / "missing.md").exists())

    def test_selected_note_cannot_be_a_default_capture_destination(self):
        with self.assertRaises(companion.CompanionError):
            self.run_action("save_vault_settings", settings={"captureTarget": "note"})

    def test_note_paths_cannot_escape_vault(self):
        with self.assertRaises(companion.CompanionError):
            companion._relative_path(self.root, "../outside.md")

    def test_tasks_are_opened_for_completion_without_writing_the_note(self):
        note = self.root / "tasks.md"
        note.write_text("- [ ] Ship this\n", encoding="utf-8")
        task = self.run_action("tasks")["items"][0]
        response = self.run_action("open", path=task["path"])
        self.assertTrue(response["uri"].startswith("obsidian://open?"))
        with self.assertRaisesRegex(companion.CompanionError, "Unknown action"):
            self.run_action("complete_task", **task)
        self.assertEqual(note.read_text(encoding="utf-8"), "- [ ] Ship this\n")

    def test_tasks_filter_and_sort_by_due_date_with_undated_last(self):
        (self.root / "a.md").write_text(
            "- [ ] Undated report\n"
            "- [ ] Late report 📅 2026-03-01\n"
            "- [ ] Early report 📅 2026-01-01\n"
            "- [ ] Buy milk 📅 2026-02-01\n",
            encoding="utf-8",
        )
        ascending = self.run_action("tasks", filter="REPORT", sort="due_asc")["items"]
        descending = self.run_action("tasks", filter="report", sort="due_desc")["items"]
        self.assertEqual(
            [task["text"] for task in ascending],
            ["Early report 📅 2026-01-01", "Late report 📅 2026-03-01", "Undated report"],
        )
        self.assertEqual(
            [task["text"] for task in descending],
            ["Late report 📅 2026-03-01", "Early report 📅 2026-01-01", "Undated report"],
        )

    def test_task_due_filters_combine_with_text_sort_and_exclusions(self):
        today = dt.date.today()
        yesterday = (today - dt.timedelta(days=1)).isoformat()
        tomorrow = (today + dt.timedelta(days=1)).isoformat()
        next_week = (today + dt.timedelta(days=7)).isoformat()
        (self.root / "tasks.md").write_text(
            f"- [ ] Overdue report 📅 {yesterday}\n"
            f"- [ ] Today report 📅 {today.isoformat()}\n"
            f"- [ ] Later report 📅 {next_week}\n"
            f"- [ ] Tomorrow report 📅 {tomorrow}\n"
            "- [ ] Undated report\n"
            "- [ ] Invalid report 📅 2026-99-99\n"
            f"- [x] Completed report 📅 {yesterday}\n",
            encoding="utf-8",
        )
        (self.root / "Archive").mkdir()
        (self.root / "Archive" / "hidden.md").write_text(
            f"- [ ] Hidden report 📅 {yesterday}\n", encoding="utf-8"
        )
        self.run_action("save_vault_settings", settings={"excludedFolders": ["Archive"]})
        expected = {
            "overdue": ["Overdue"],
            "today": ["Today"],
            "upcoming": ["Later", "Tomorrow"],
            "undated": ["Undated", "Invalid"],
        }
        for due_filter, names in expected.items():
            with self.subTest(due_filter=due_filter):
                result = self.run_action("tasks", dueFilter=due_filter, terms=["REPORT"])["items"]
                self.assertEqual([task["text"].split()[0] for task in result], names)
        result = self.run_action("tasks", dueFilter="upcoming", filter="report", sort="due_asc")["items"]
        self.assertEqual([task["text"].split()[0] for task in result], ["Tomorrow", "Later"])
        result = self.run_action("tasks", sort="due_asc")["items"]
        self.assertEqual([task["text"].split()[0] for task in result],
                         ["Overdue", "Today", "Tomorrow", "Later", "Undated", "Invalid"])
        self.assertEqual(len(self.run_action("tasks")["items"]), 6)
        self.assertEqual(self.run_action("tasks", dueFilter="today", filter="missing")["items"], [])
        for value in ("invalid", "", None, 1):
            with self.subTest(value=value), self.assertRaisesRegex(companion.CompanionError, "due-date filter"):
                self.run_action("tasks", dueFilter=value)

    def test_task_due_filter_applies_before_result_limit(self):
        today = dt.date.today().isoformat()
        (self.root / "tasks.md").write_text(
            "".join(f"- [ ] Undated {index}\n" for index in range(companion.MAX_RESULTS))
            + f"- [ ] Visible today 📅 {today}\n", encoding="utf-8"
        )
        self.assertEqual([task["text"] for task in self.run_action("tasks", dueFilter="today")["items"]],
                         [f"Visible today 📅 {today}"])

    def test_search_and_task_terms_must_all_match(self):
        (self.root / "both.md").write_text("ESV notes on Hebrews\n", encoding="utf-8")
        (self.root / "one.md").write_text("ESV notes on Romans\n", encoding="utf-8")
        (self.root / "tasks.md").write_text(
            "- [ ] Read ESV Hebrews\n- [ ] Read ESV Romans\n", encoding="utf-8"
        )
        notes = self.run_action("search", terms=["esv"], query="Hebrews")["items"]
        self.assertEqual([note["path"] for note in notes], ["both.md", "tasks.md"])
        tasks = self.run_action("tasks", terms=["ESV", "romans"])["items"]
        self.assertEqual([task["text"] for task in tasks], ["Read ESV Romans"])

    def test_create_note_can_use_a_configured_template(self):
        (self.root / ".obsidian" / "templates.json").write_text(
            json.dumps({"folder": "Templates"}), encoding="utf-8"
        )
        (self.root / "Templates").mkdir()
        (self.root / "Templates" / "Meeting.md").write_text(
            "# {{title}}\nCreated {{date:YYYY-MM-DD}}\n", encoding="utf-8"
        )
        response = self.run_action(
            "create", title="Planning", folder="Projects", template="Templates/Meeting.md"
        )
        self.assertTrue(response["uri"].startswith("obsidian://open?"))
        content = (self.root / "Projects" / "Planning.md").read_text(encoding="utf-8")
        self.assertIn("# Planning", content)
        self.assertIn(dt.date.today().isoformat(), content)

    def test_recent_notes_include_obsidian_workspace_history(self):
        (self.root / "opened.md").write_text("# Opened\n", encoding="utf-8")
        (self.root / ".obsidian" / "workspace.json").write_text(
            json.dumps({"lastOpenFiles": ["opened.md"]}), encoding="utf-8"
        )
        recent = self.run_action("recent")["items"]
        self.assertEqual([item["path"] for item in recent], ["opened.md"])

    def test_pin_state_is_returned_for_search_results(self):
        (self.root / "pinned.md").write_text("# Pinned\nneedle\n", encoding="utf-8")
        self.run_action("pin", path="pinned.md")
        results = self.run_action("search", query="needle")["items"]
        self.assertTrue(results[0]["pinned"])

    def test_daily_reminder_notifies_once_after_configured_time(self):
        (self.root / "tasks.md").write_text("- [ ] Prepare review\n", encoding="utf-8")
        self.run_action("set_reminders", mode="daily_summary", time="09:00")
        real_datetime = dt.datetime

        class FixedDateTime(real_datetime):
            @classmethod
            def now(cls, tz=None):
                return cls.combine(dt.date.today(), real_datetime.min.time()).replace(
                    hour=10, minute=0, tzinfo=tz
                )

        with patch.object(companion.dt, "datetime", FixedDateTime), \
                patch.object(companion.subprocess, "run") as notify:
            first = self.run_action("reminder_check")["delivered"]
            second = self.run_action("reminder_check")["delivered"]
        self.assertTrue(first)
        self.assertFalse(second)
        self.assertEqual(notify.call_count, 1)
        self.assertIn("1 open task", notify.call_args.args[0][-1])
        self.assertTrue(notify.call_args.kwargs["check"])

    def test_due_date_reminder_uses_obsidian_tasks_marker_once(self):
        due = dt.date.today().isoformat()
        (self.root / "tasks.md").write_text(
            f"- [ ] Submit report 📅 {due}\n", encoding="utf-8"
        )
        self.run_action("set_reminders", mode="due_dates", time="09:00")
        real_datetime = dt.datetime

        class FixedDateTime(real_datetime):
            @classmethod
            def now(cls, tz=None):
                return cls.combine(dt.date.today(), real_datetime.min.time()).replace(
                    hour=10, minute=0, tzinfo=tz
                )

        with patch.object(companion.dt, "datetime", FixedDateTime), \
                patch.object(companion.subprocess, "run") as notify:
            first = self.run_action("reminder_check")["delivered"]
            second = self.run_action("reminder_check")["delivered"]
        self.assertTrue(first)
        self.assertFalse(second)
        self.assertEqual(notify.call_count, 1)
        self.assertIn("1 task due or overdue", notify.call_args.args[0][-1])

    def test_reminder_delivery_failure_retries_without_marking_sent(self):
        due = dt.date.today().isoformat()
        (self.root / "tasks.md").write_text(f"- [ ] Retry reminder 📅 {due}\n", encoding="utf-8")
        real_datetime = dt.datetime

        class FixedDateTime(real_datetime):
            @classmethod
            def now(cls, tz=None):
                return cls.combine(dt.date.today(), real_datetime.min.time()).replace(
                    hour=10, minute=0, tzinfo=tz
                )

        failures = [
            subprocess.CalledProcessError(1, ["omarchy"]),
            subprocess.TimeoutExpired("omarchy", 10),
            FileNotFoundError("omarchy"),
        ]
        with patch.object(companion.dt, "datetime", FixedDateTime):
            for mode in ("daily_summary", "due_dates"):
                self.run_action("set_reminders", mode=mode, time="09:00")
                for failure in failures:
                    with self.subTest(mode=mode, failure=type(failure).__name__):
                        with patch.object(companion.subprocess, "run", side_effect=failure):
                            with self.assertRaisesRegex(companion.CompanionError, "will be retried"):
                                self.run_action("reminder_check")
                        self.assertEqual(companion._reminder_settings(companion._state(), self.root)["sent"], {})
                with patch.object(companion.subprocess, "run") as notify:
                    self.assertTrue(self.run_action("reminder_check")["delivered"])
                    self.assertFalse(self.run_action("reminder_check")["delivered"])
                    self.assertEqual(notify.call_count, 1)
                self.run_action("set_reminders", mode=mode, time="09:00")
                state = companion._state()
                companion._reminder_settings(state, self.root)["sent"] = {}
                companion._write_state(state)

    def test_reminder_does_not_save_history_before_delivery(self):
        (self.root / "tasks.md").write_text("- [ ] Prepare review\n", encoding="utf-8")
        self.run_action("set_reminders", mode="daily_summary", time="00:00")

        def verify_during_delivery(*args, **kwargs):
            settings = companion._reminder_settings(companion._state(), self.root)
            self.assertEqual(settings["sent"], {})

        with patch.object(companion.subprocess, "run", side_effect=verify_during_delivery) as notify:
            with patch.object(companion, "_write_state", side_effect=OSError("disk error")):
                with self.assertRaisesRegex(OSError, "disk error"):
                    self.run_action("reminder_check")
            self.assertEqual(companion._reminder_settings(companion._state(), self.root)["sent"], {})
            self.assertTrue(self.run_action("reminder_check")["delivered"])
            self.assertFalse(self.run_action("reminder_check")["delivered"])
            self.assertEqual(notify.call_count, 2)

    def test_ai_handoff_is_explicit_and_does_not_change_the_note(self):
        path = self.root / "note.md"
        path.write_text("A private project note.", encoding="utf-8")
        with patch.object(companion.subprocess, "run") as copy:
            response = self.run_action("ai_prompt", path="note.md", question="Summarize this")
        args, kwargs = copy.call_args
        self.assertEqual(args[0], ["wl-copy", "--sensitive"])
        self.assertIn("A private project note.", kwargs["input"])
        self.assertIn("Summarize this", kwargs["input"])
        self.assertIn("Do not edit", kwargs["input"])
        self.assertNotIn("prompt", response)
        self.assertEqual(path.read_text(encoding="utf-8"), "A private project note.")

    def test_ai_clipboard_failure_is_reported(self):
        (self.root / "note.md").write_text("Private note", encoding="utf-8")
        with patch.object(companion.subprocess, "run", side_effect=subprocess.TimeoutExpired("wl-copy", 10)):
            with self.assertRaisesRegex(companion.CompanionError, "Could not copy"):
                self.run_action("ai_prompt", path="note.md", question="Summarize")

    def test_ai_clipboard_process_receives_prompt_only_on_stdin(self):
        (self.root / "note.md").write_text("Private test note", encoding="utf-8")
        bin_dir = Path(self.temp.name) / "bin"
        bin_dir.mkdir()
        capture = Path(self.temp.name) / "capture.json"
        copy = bin_dir / "wl-copy"
        copy.write_text(
            "#!" + sys.executable + "\n"
            "import json, sys\n"
            f"with open({str(capture)!r}, 'w') as f:\n"
            "    json.dump({'args': sys.argv[1:], 'text': sys.stdin.read()}, f)\n",
            encoding="utf-8",
        )
        copy.chmod(0o700)
        with patch.dict(os.environ, {"PATH": str(bin_dir)}):
            self.run_action("ai_prompt", path="note.md", question="Private test question")
        received = json.loads(capture.read_text(encoding="utf-8"))
        self.assertEqual(received["args"], ["--sensitive"])
        self.assertIn("Private test note", received["text"])
        self.assertIn("Private test question", received["text"])


    def test_excluded_folders_are_skipped_by_search_and_tasks(self):
        (self.root / "Templates").mkdir()
        (self.root / "Templates" / "t.md").write_text("- [ ] Template task alpha\n", encoding="utf-8")
        (self.root / "real.md").write_text("- [ ] Real task alpha\n", encoding="utf-8")
        self.run_action("save_vault_settings", settings={"excludedFolders": ["Templates"]})
        notes = self.run_action("search", query="alpha")["items"]
        tasks = self.run_action("tasks")["items"]
        self.assertEqual([note["path"] for note in notes], ["real.md"])
        self.assertEqual([task["path"] for task in tasks], ["real.md"])

    def test_capture_uses_saved_format_target_and_folder(self):
        self.run_action("save_vault_settings", settings={
            "captureFolder": "Captures", "captureFormat": "task", "captureTarget": "inbox",
        })
        self.run_action("capture", text="Call Bob")
        note = self.root / "Captures" / f"{dt.date.today().isoformat()}.md"
        self.assertTrue(note.read_text(encoding="utf-8").endswith("- [ ] Call Bob\n"))

    def test_daily_override_replaces_obsidian_daily_settings(self):
        self.run_action("save_vault_settings", settings={
            "dailyOverride": True, "dailyFolder": "Journal", "dailyFormat": "YYYY-MM-DD",
        })
        self.run_action("daily")
        self.assertTrue((self.root / "Journal" / f"{dt.date.today().isoformat()}.md").is_file())

    def test_custom_vault_can_be_added_and_removed(self):
        other = Path(self.temp.name) / "Other"
        other.mkdir()
        added = companion._handle({"action": "add_vault", "vault": str(other)})
        self.assertIn(str(other.resolve()), [vault["path"] for vault in added["vaults"]])
        self.assertEqual(added["selectedVault"], str(other.resolve()))
        removed = companion._handle({"action": "remove_vault", "vault": str(other)})
        self.assertNotIn(str(other.resolve()), [vault["path"] for vault in removed["vaults"]])
        self.assertEqual(removed["selectedVault"], str(self.root.resolve()))
        with self.assertRaises(companion.CompanionError):
            companion._handle({"action": "remove_vault", "vault": str(self.root)})

    def test_clear_recent_and_hiding_obsidian_history_empty_recent(self):
        (self.root / "a.md").write_text("# A\n", encoding="utf-8")
        (self.root / ".obsidian" / "workspace.json").write_text(
            json.dumps({"lastOpenFiles": ["a.md"]}), encoding="utf-8"
        )
        self.run_action("open", path="a.md")
        self.run_action("clear_recent")
        self.assertEqual(len(self.run_action("recent")["items"]), 1)
        self.run_action("save_vault_settings", settings={"includeObsidianRecent": False})
        self.assertEqual(self.run_action("recent")["items"], [])

    def test_ai_can_be_disabled_in_settings(self):
        (self.root / "note.md").write_text("Text", encoding="utf-8")
        self.run_action("save_vault_settings", settings={}, ui={"aiEnabled": False})
        with self.assertRaises(companion.CompanionError):
            self.run_action("ai_prompt", path="note.md", question="Summarize")


if __name__ == "__main__":
    unittest.main()
