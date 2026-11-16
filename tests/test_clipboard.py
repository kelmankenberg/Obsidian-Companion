import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import clipboard


class ClipboardTests(unittest.TestCase):
    def provider(self, source):
        return [sys.executable, "-c", source]

    def test_reads_utf8_and_preserves_whitespace(self):
        self.assertEqual(clipboard.read_clipboard(self.provider(
            "import sys; sys.stdout.buffer.write('  café\\n'.encode())"
        )), "  café\n")

    def test_accepts_exact_size_limit(self):
        self.assertEqual(len(clipboard.read_clipboard(self.provider(
            f"import sys; sys.stdout.write('a' * {clipboard.MAX_CLIPBOARD_BYTES})"
        ))), clipboard.MAX_CLIPBOARD_BYTES)

    def test_rejects_oversized_and_continuous_providers(self):
        for source in (
            f"import sys; sys.stdout.write('a' * {clipboard.MAX_CLIPBOARD_BYTES + 1})",
            "import os\nwhile True: os.write(1, b'a' * 4096)",
        ):
            with self.subTest(source=source):
                with self.assertRaisesRegex(ValueError, "16 KiB"):
                    clipboard.read_clipboard(self.provider(source))

    def test_times_out_stalled_provider_and_provider_holding_after_eof(self):
        for source in (
            "import time; time.sleep(10)",
            "import os,time; os.close(1); time.sleep(10)",
        ):
            with self.subTest(source=source), patch.object(clipboard, "CLIPBOARD_TIMEOUT", 0.1):
                with self.assertRaisesRegex(ValueError, "timed out"):
                    clipboard.read_clipboard(self.provider(source))

    def test_reports_failed_missing_and_invalid_utf8_providers(self):
        for command in (
            self.provider("raise SystemExit(1)"),
            self.provider("import os; os.write(1, b'\\xff')"),
            ["/nonexistent/obsidian-companion-clipboard-test"],
        ):
            with self.subTest(command=command):
                with self.assertRaisesRegex(ValueError, "Could not read"):
                    clipboard.read_clipboard(command)

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell is needed for the paste integration test")
    def test_paste_helper_integration(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            for name in ("SafeTextEdit.qml", "ClipboardPaste.qml", "clipboard.py"):
                shutil.copyfile(root / name, config / name)
            shutil.copyfile(root / "tests/test_paste_helper.qml", config / "shell.qml")
            environment = {
                **os.environ,
                "QT_QPA_PLATFORM": "offscreen",
                "PATH": str(root / "tests/fixtures") + os.pathsep + os.environ["PATH"],
            }
            result = subprocess.run(
                ["quickshell", "-p", str(config)],
                env=environment, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Clipboard helper integration passed", result.stdout + result.stderr)
