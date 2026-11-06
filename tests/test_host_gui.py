"""GUI가 없을 때의 빠른 환경 판정과 캡처 누락·위조된 headless 수용을 방지한다."""

import json
import struct
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import host_gui


class HostGui(unittest.TestCase):
    def capture_fixture(self, directory, states=None):
        # PNG 헤더만 사용하는 호스트 행렬 계약 fixture다. 렌더링 증거가 아니다.
        items = []
        for stage in host_gui.STATES if states is None else states:
            for width, height in host_gui.SIZES:
                path = f"{stage}-{width}x{height}.png"
                (directory / path).write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height))
                item = {"path": path, "stage": stage, "size": [width, height]}
                if stage in ("10-first-shot", "11-grown-shot"):
                    item["shot_alignment"] = {"sprite_muzzle": [301, 600], "projectile": [301, 600],
                                              "emitter": [301, 600], "kick": 1.0, "breath": 1.0}
                items.append(item)
        return {"display_server": "macOS", "captures": items}

    def test_shot_frames_are_required_in_matrix(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-shots-") as temporary:
            directory = Path(temporary)
            manifest = directory / "capture-manifest.json"
            manifest.write_text(json.dumps(self.capture_fixture(directory, host_gui.STATES[:9])), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "누락"):
                host_gui.verify_captures(directory)
            manifest.write_text(json.dumps(self.capture_fixture(directory)), encoding="utf-8")
            self.assertEqual(len(host_gui.verify_captures(directory)), 33)

    def test_shot_origin_must_match_sprite_after_recoil(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-muzzle-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            shot = fixture["captures"][-1]["shot_alignment"]
            for field, value in (("projectile", [310, 605]), ("emitter", [310, 605]),
                                 ("kick", 0.0), ("sprite_muzzle", [float("nan"), 600])):
                with self.subTest(field=field):
                    original = shot[field]
                    shot[field] = value
                    (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "포구 정렬"):
                        host_gui.verify_captures(directory)
                    shot[field] = original

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
