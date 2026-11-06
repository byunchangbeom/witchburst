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
                item = {"path": path, "stage": stage, "size": [width, height],
                        "terrain": [{"foot": [500, 700], "shadow_half_width": 32}]}
                if stage.startswith("party-"):
                    item["party"] = {"min_diagonal": 700, "max_diagonal": 1400, "samples": 200}
                    item["party_shot"] = {"muzzle": [300, 500], "launch": [300, 500], "emitter": [300, 500],
                                          "spirit_tip": [250, 490], "spirit_launch": [250, 490],
                                          "initial": [308, 492], "breech": [290, 510], "kick": 1.0}
                if stage in ("10-first-shot", "11-grown-shot", "14-boss-shot", "12-first-flight", "13-grown-flight", "15-boss-flight"):
                    item["shot_alignment"] = {"sprite_muzzle": [301, 600], "projectile": [301, 600],
                                              "emitter": [301, 600], "tail": [301, 600], "kick": 1.0, "breath": 1.0,
                                              "sprite_breech": [291, 610], "initial_projectile": [301 + 8 * min(width, 600) / 540 / 2**0.5, 600 - 8 * min(width, 600) / 540 / 2**0.5], "travel": 0.0}
                    if stage.endswith("flight"):
                        item["shot_alignment"].update(projectile=[340, 560], tail=[320, 580], travel=80.0)
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
            self.assertEqual(len(host_gui.verify_captures(directory)), 129)

    def test_shot_origin_must_match_sprite_after_recoil(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-muzzle-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            shot = next(item["shot_alignment"] for item in fixture["captures"] if item["stage"] == "11-grown-shot")
            for field, value in (("projectile", [310, 605]), ("emitter", [310, 605]),
                                 ("kick", 0.0), ("sprite_muzzle", [float("nan"), 600])):
                with self.subTest(field=field):
                    original = shot[field]
                    shot[field] = value
                    (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "포구 정렬"):
                        host_gui.verify_captures(directory)
                    shot[field] = original

    def test_launch_tail_cannot_extend_behind_muzzle(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-tail-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            for item in fixture["captures"]:
                if item["stage"] not in ("10-first-shot", "11-grown-shot", "14-boss-shot"):
                    continue
                shot = item["shot_alignment"]
                with self.subTest(stage=item["stage"], size=item["size"]):
                    # 기존 성장탄처럼 머리/입자는 맞아도 꼬리가 48px 뒤면 거부한다.
                    for tail in ([301, 648], [], [float("nan"), 600]):
                        shot["tail"] = tail
                        (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
                        with self.assertRaisesRegex(ValueError, "포구 정렬"):
                            host_gui.verify_captures(directory)
                    shot["tail"] = shot["sprite_muzzle"]
            (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
            self.assertEqual(len(host_gui.verify_captures(directory)), 129)

    def test_muzzle_match_does_not_hide_wrong_initial_direction(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-axis-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            for item in fixture["captures"]:
                if "shot_alignment" not in item:
                    continue
                shot = item["shot_alignment"]
                with self.subTest(stage=item["stage"], size=item["size"]):
                    original = shot["initial_projectile"]
                    shot["initial_projectile"] = [301, 592]  # 기존 수직 탄도 재현
                    (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "초기 탄도"):
                        host_gui.verify_captures(directory)
                    shot["initial_projectile"] = original

    def test_cliff_placement_and_missing_flight_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-grass-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            for item in fixture["captures"]:
                if item["stage"] not in ("01-first", "08-rebirth"):
                    continue
                original = item["terrain"]
                for value in ([], [{"foot": [200, 300], "shadow_half_width": 32}],
                              [{"foot": [500, 1400], "shadow_half_width": 32}]):
                    item["terrain"] = value
                    (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "풀밭"):
                        host_gui.verify_captures(directory)
                item["terrain"] = original
            fixture["captures"] = [item for item in fixture["captures"] if not item["stage"].endswith("flight")]
            (directory / "capture-manifest.json").write_text(json.dumps(fixture), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "누락"):
                host_gui.verify_captures(directory)

    def test_party_matrix_and_real_transform_receipts_are_required(self):
        with tempfile.TemporaryDirectory(prefix="witchburst-gui-party-") as temporary:
            directory = Path(temporary)
            fixture = self.capture_fixture(directory)
            manifest = directory / "capture-manifest.json"
            removed = fixture["captures"].pop()
            manifest.write_text(json.dumps(fixture), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "누락"):
                host_gui.verify_captures(directory)
            fixture["captures"].append(removed)
            for section, key, value in (("party", "max_diagonal", 1480),
                                        ("party", "min_diagonal", float("nan")),
                                        ("party", "samples", 0),
                                        ("party_shot", "spirit_launch", [250, 500]),
                                        ("party_shot", "initial", [300, 492])):
                with self.subTest(section=section, key=key):
                    original = removed[section][key]
                    removed[section][key] = value
                    manifest.write_text(json.dumps(fixture), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "드래그"):
                        host_gui.verify_captures(directory)
                    removed[section][key] = original

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
