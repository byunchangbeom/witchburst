"""GUI가 없을 때의 빠른 환경 판정과 캡처 누락·위조된 headless 수용을 방지한다."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import host_gui


class HostGui(unittest.TestCase):
    def test_no_display_receipt_does_not_start_godot(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-contract-") as temporary:
            directory = Path(temporary)
            prompt, answer = directory / "prompt.json", directory / "answer.json"
            pins = {"schema_version": 1, "source_head": "test-source-pin", "inputs": [{"path": "test", "sha256": "pin"}]}
            prompt.write_text(json.dumps(pins), encoding="utf-8")
            with patch("sys.argv", ["host_gui.py", str(prompt), str(answer), str(directory)]), \
                 patch.object(host_gui, "display_unavailable", return_value=("no_display", {"main_display_id": 0})), \
                 patch.object(host_gui.shutil, "which", return_value="/test/godot"), \
                 patch.object(host_gui.platform, "platform", return_value="test-host"), \
                 patch.object(host_gui.subprocess, "run") as execute:
                host_gui.main()
            receipt = json.loads(answer.read_text(encoding="utf-8"))
            self.assertEqual(receipt["status"], "ENV_UNAVAILABLE")
            self.assertEqual(receipt["reason_code"], "no_display")
            self.assertEqual(receipt["source_head"], pins["source_head"])
            self.assertEqual(receipt["inputs"], pins["inputs"])
            self.assertEqual(receipt["captures"], [])
            self.assertEqual(receipt["visual_review"], "NOT_MEASURED")
            self.assertEqual(execute.call_count, 0, "환경 불가일 때 실행기를 시작하면 안 됨")

    def test_headless_or_missing_captures_cannot_pass(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-missing-") as temporary:
            directory = Path(temporary)
            manifest = directory / "capture-manifest.json"
            manifest.write_text(json.dumps({"display_server": "headless", "captures": []}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "headless"):
                host_gui.verify_captures(directory)
            manifest.write_text(json.dumps({"display_server": "macOS", "captures": []}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "누락"):
                host_gui.verify_captures(directory)

    def test_capture_cannot_escape_artifacts(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-path-") as temporary:
            directory = Path(temporary)
            (directory / "capture-manifest.json").write_text(json.dumps({"display_server": "macOS", "captures": [
                {"path": "../outside.png", "stage": "01-first", "size": [540, 960]}]}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "벗어"):
                host_gui.verify_captures(directory)


if __name__ == "__main__":
    unittest.main()
