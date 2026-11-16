#!/usr/bin/env python3
"""Read an explicitly requested paste outside the shared shell."""

import json
import os
import selectors
import subprocess
import time


MAX_CLIPBOARD_BYTES = 16 * 1024
CLIPBOARD_TIMEOUT = 2


def read_clipboard(command=None):
    command = command or ["wl-paste", "--no-newline", "--type", "text"]
    try:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as process:
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    deadline = time.monotonic() + CLIPBOARD_TIMEOUT
                    content = bytearray()
                    while True:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0 or not selector.select(remaining):
                            raise ValueError("Clipboard provider timed out.")
                        chunk = os.read(process.stdout.fileno(), min(4096, MAX_CLIPBOARD_BYTES + 1 - len(content)))
                        content.extend(chunk)
                        if len(content) > MAX_CLIPBOARD_BYTES:
                            raise ValueError("Clipboard text exceeds the 16 KiB paste limit.")
                        if not chunk:
                            break
                    try:
                        exit_code = process.wait(timeout=max(0.001, deadline - time.monotonic()))
                    except subprocess.TimeoutExpired as error:
                        raise ValueError("Clipboard provider timed out.") from error
                    if exit_code:
                        raise ValueError("Could not read clipboard text.")
                    return content.decode("utf-8")
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
    except (OSError, UnicodeError) as error:
        raise ValueError("Could not read UTF-8 clipboard text. Check that wl-paste is installed.") from error


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, "text": read_clipboard()}))
    except ValueError as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        raise SystemExit(1)
