import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path
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

    def test_search_skips_obsidian_metadata_and_returns_matching_preview(self):
        (self.root / "note.md").write_text("# Project\nA useful phrase here.\n", encoding="utf-8")
        (self.root / ".obsidian" / "private.md").write_text("useful phrase", encoding="utf-8")
        results = self.run_action("search", query="useful phrase")["items"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["path"], "note.md")
        self.assertEqual(results[0]["preview"], "A useful phrase here.")

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

    def test_note_paths_cannot_escape_vault(self):
        with self.assertRaises(companion.CompanionError):
            companion._relative_path(self.root, "../outside.md")

    def test_task_completion_checks_the_original_line_before_writing(self):
        (self.root / "tasks.md").write_text("- [ ] Ship this\n", encoding="utf-8")
        task = self.run_action("tasks")["items"][0]
        self.run_action("complete_task", **task)
        self.assertEqual((self.root / "tasks.md").read_text(encoding="utf-8"), "- [x] Ship this\n")

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

        with patch.object(companion.dt, "datetime", FixedDateTime):
            first = self.run_action("reminder_check")["notifications"]
            second = self.run_action("reminder_check")["notifications"]
        self.assertEqual(len(first), 1)
        self.assertIn("1 open task", first[0])
        self.assertEqual(second, [])

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

        with patch.object(companion.dt, "datetime", FixedDateTime):
            first = self.run_action("reminder_check")["notifications"]
            second = self.run_action("reminder_check")["notifications"]
        self.assertEqual(len(first), 1)
        self.assertIn("1 task due or overdue", first[0])
        self.assertEqual(second, [])

    def test_ai_handoff_is_explicit_and_does_not_change_the_note(self):
        path = self.root / "note.md"
        path.write_text("A private project note.", encoding="utf-8")
        response = self.run_action("ai_prompt", path="note.md", question="Summarize this")
        self.assertIn("A private project note.", response["prompt"])
        self.assertIn("Do not edit", response["prompt"])
        self.assertEqual(path.read_text(encoding="utf-8"), "A private project note.")


if __name__ == "__main__":
    unittest.main()
