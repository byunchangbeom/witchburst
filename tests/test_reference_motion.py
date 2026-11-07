"""독립 원본 관측의 좌표 계약과 연속 자료의 누락/허위 방향을 검사한다."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import unittest

from render_reference_motion import validate_directions


class ReferenceMotion(unittest.TestCase):
    def test_independent_raw_points_survive_trim_and_display_scale(self):
        game = Path(__file__).resolve().parents[1] / "game"
        raw = json.loads((game / "tests/single-port-observations.json").read_text())
        image = (game / "assets/art/cannon-single-port-skills.png").read_bytes()
        self.assertEqual(hashlib.sha256(image).hexdigest(), raw["png_sha256"])
        self.assertEqual(struct.unpack(">II", image[16:24]), (1774, 887))
        cells = json.loads((game / "assets/art/motion-overrides.json").read_text())["cells"]["witch-cannon-actions"]
        self.assertEqual(set(cells), {str(i) for i in [4, 5, 6, 7, 12, 13, 14, 15]})
        for record in raw["records"]:
            cell = cells[str(record["index"])]
            self.assertEqual(cell["region"], record["region"])
            self.assertEqual(cell["source_cell"], record["source_cell"])
            for key, observed in [("muzzle_uv", "front"), ("breech_uv", "back")]:
                for axis in range(2):
                    decoded = cell[key][axis] * cell["region"][axis+2] + cell["trim_offset"][axis]
                    self.assertAlmostEqual(decoded, record[observed][axis], places=5)
            for axis in range(2):
                self.assertAlmostEqual(cell["foot"][axis]+cell["trim_offset"][axis], record["sole"][axis])
            if record["index"] >= 12:
                self.assertGreater(record["front"][0], record["back"][0], "NE 관구는 실제 관측상 오른쪽")
            self.assertLess(record["front"][1], record["back"][1], "관구의 앞이 실제 관측상 위쪽")
            self.assertLessEqual(len(cell["leg_regions"]), 64)

    def records(self):
        result = []
        states = ["skill_prepare", "skill_settle", "skill_release", "skill_recover"]
        for tier in [0, 3]:
            for direction in ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]:
                for frame in range(30):
                    result.append({"index": len(result), "case_direction": direction,
                                   "case_tier": tier, "state": states[frame % 4],
                                   "facing": direction, "lower_visible": True,
                                   "lower_frame": frame % 4, "max_speed_fixture": True,
                                   "actual_rule_speed": 520.0})
        return result

    def test_complete_synthetic_matrix_only_checks_evidence_shape(self):
        self.assertEqual(validate_directions(self.records(), True)["cases"], 16)

    def test_labels_cannot_hide_n_only_runtime(self):
        records = self.records()
        for record in records:
            record["facing"] = "N"
        with self.assertRaisesRegex(ValueError, "실제 시전 방향 불일치"):
            validate_directions(records, True)

    def test_missing_transition_and_false_maximum_are_rejected(self):
        for key, value, message in [("state", "skill_prepare", "시전/취소 전환 누락"),
                                    ("actual_rule_speed", 72, "최고속520 실제 이동 부족"),
                                    ("lower_frame", 0, "실제 하체 프레임 진행 누락")]:
            records = copy.deepcopy(self.records())
            for record in records:
                record[key] = value
            with self.assertRaisesRegex(ValueError, message):
                validate_directions(records, True)


if __name__ == "__main__":
    unittest.main()
