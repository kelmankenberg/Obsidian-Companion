import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class SearchActionTests(unittest.TestCase):
    def run_qml_fixture(self, components, fixture, expected):
        root = Path(__file__).resolve().parents[1]
        shell = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell"
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            for component in components:
                shutil.copyfile(root / component, config / component)
            shutil.copyfile(root / "tests" / fixture, config / "shell.qml")
            (config / "qs").symlink_to(shell, target_is_directory=True)
            environment = {
                **os.environ,
                "QT_QPA_PLATFORM": "offscreen",
                "QML_IMPORT_PATH": str(config) + os.pathsep + os.environ.get("QML_IMPORT_PATH", ""),
            }
            result = subprocess.run(
                ["quickshell", "-p", str(config)],
                env=environment, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(expected, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_expanding_search_actions(self):
        self.run_qml_fixture(["SearchActionControls.qml"], "test_search_actions.qml",
                             "Search action controls passed")

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_note_path_tooltip_displays_untrusted_text_as_plain_text(self):
        self.run_qml_fixture(["NotePathToolTip.qml"], "test_note_path_tooltip.qml",
                             "Note path tooltip passed")

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_ai_controls_visibility_and_clipboard_warning(self):
        self.run_qml_fixture(
            ["AiPromptControls.qml", "Choice.qml", "SafeTextField.qml", "SafeTextEdit.qml",
             "InputViewport.qml", "ClipboardPaste.qml", "clipboard.py"],
            "test_ai_prompt_controls.qml", "AI prompt controls passed",
        )

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_search_filter_controls_apply_and_clear(self):
        self.run_qml_fixture(
            ["SearchFilterControls.qml", "SafeTextField.qml", "SafeTextEdit.qml",
             "InputViewport.qml", "ClipboardPaste.qml", "clipboard.py"],
            "test_search_filters.qml", "Search filters passed",
        )

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_note_preview_and_copy_controls(self):
        self.run_qml_fixture(
            ["NotePreviewControls.qml"], "test_note_preview.qml", "Note preview controls passed",
        )

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
    def test_task_due_date_controls(self):
        self.run_qml_fixture(
            ["TaskDateControls.qml", "Choice.qml"], "test_task_date_controls.qml",
            "Task date controls passed",
        )
