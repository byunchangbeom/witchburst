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
        self.assertEqual(set(cells), {str(i) for i in [4, 5, 6, 7, 12, 13, 14, 15, 36, 37, 38, 39]})
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

    def test_south_whole_body_raw_contract(self):
        game = Path(__file__).resolve().parents[1] / "game"
        raw = json.loads((game / "tests/south-moving-observations.json").read_text())
        image = (game / "assets/art/cannon-south-moving-skills.png").read_bytes()
        self.assertEqual(hashlib.sha256(image).hexdigest(), raw["png_sha256"])
        self.assertEqual(struct.unpack(">II", image[16:24]), (1774, 887))
        cells = json.loads((game / "assets/art/cannon-south-moving-skills.json").read_text())["cells"]
        self.assertEqual(len(cells), 8)
        self.assertEqual(len({tuple(c["region"]) for c in cells}), 8)
        for record, cell in zip(raw["records"], cells):
            self.assertEqual(cell["region"], record["region"])
            self.assertEqual(cell["leg_regions"], [], "전신 셀은 절단용 마스크를 쓰지 않음")
            self.assertEqual(cell["file_override"], record.get("file", "cannon-south-moving-skills.png"))
            for key, observed in [("muzzle_uv", "front"), ("breech_uv", "back")]:
                for axis in range(2):
                    decoded = cell[key][axis]*cell["region"][axis+2]+cell["trim_offset"][axis]
                    self.assertAlmostEqual(decoded, record[observed][axis])
            self.assertGreater(record["front"][1], record["back"][1], "실제 S 포구는 뒤점보다 아래")
            for axis in range(2):
                self.assertEqual(cell["foot"][axis]+cell["trim_offset"][axis], record["sole"][axis])

    def test_right_step_preserves_source_scale_and_independent_axis(self):
        game = Path(__file__).resolve().parents[1] / "game"
        image = (game / "assets/art/cannon-south-release-right-step.png").read_bytes()
        self.assertEqual(hashlib.sha256(image).hexdigest(), "64a622a039522fdcdce45417011c81519ededf16ed29cdd7c0bdfe72db2c33e6")
        self.assertEqual(struct.unpack(">II", image[16:24]), (1199, 1312))
        cells = json.loads((game / "assets/art/cannon-south-moving-skills.json").read_text())["cells"]
        cell = cells[7]
        self.assertEqual([c["file_override"] for c in cells[:7]], ["cannon-south-moving-skills.png"]*7)
        # 독립 raw 판독의 관구631,859/뒤점625,708과 발 기준626.5,1159.
        for key, point in [("muzzle_uv", [631, 859]), ("breech_uv", [625, 708])]:
            for axis in range(2):
                self.assertAlmostEqual(cell[key][axis]*cell["region"][axis+2]+cell["trim_offset"][axis], point[axis])
        self.assertEqual([cell["foot"][a]+cell["trim_offset"][a] for a in range(2)], [626.5,1159])
        self.assertAlmostEqual(1092 / cell["display_canvas_height"], 397/410, delta=.005)

    def test_stationary_coverage_rejects_motion_wrong_s_axis_and_trigger(self):
        records = self.records()
        for r in records:
            step = r["index"] % 30
            r.update(stationary_fixture=True, max_speed_fixture=False, actual_rule_speed=0,
                     rule_position=[270,575], stride=0, lower_visible=False,
                     skill_uses=0 if step < 12 else 1, cooldown=0 if step < 12 else 8)
            if (r["case_tier"], r["case_direction"]) == (3, "S"):
                r.update(whole_body=True, pose_key="witch-cannon-south-skills", muzzle=[270,600],
                         breech=[270,580], upper_frame=4 if r["state"] in ("skill_release", "skill_recover") else 0)
        self.assertEqual(validate_directions(records, stationary=True)["cases"], 16)
        for key, value, message in [("stride", 1, "이동/보행 잔류"),
                                    ("rule_position", [271,575], "이동/보행 잔류"),
                                    ("skill_uses", 2, "횟수·쿨다운 불일치")]:
            broken = copy.deepcopy(records)
            broken[0][key] = value
            with self.assertRaisesRegex(ValueError, message):
                validate_directions(broken, stationary=True)
        for key, value in [("muzzle", [270,570]), ("whole_body", False)]:
            broken = copy.deepcopy(records)
            next(r for r in broken if (r["case_tier"],r["case_direction"]) == (3,"S"))[key] = value
            with self.assertRaisesRegex(ValueError, "정지 S 실제 전신/포구축 누락"):
                validate_directions(broken, stationary=True)

    def test_whole_body_gait_is_measured_and_cannot_hide_single_frame(self):
        records = self.records()
        for record in records:
            if (record["case_tier"], record["case_direction"]) == (3, "S"):
                record.update(whole_body=True, pose_key="witch-cannon-south-skills", lower_visible=False,
                              upper_frame=record["index"] % 8)
        self.assertEqual(validate_directions(records, True)["cases"], 16)
        for record in records:
            if record.get("whole_body"):
                record["upper_frame"] = 0
        with self.assertRaisesRegex(ValueError, "실제 하체 프레임 진행 누락"):
            validate_directions(records, True)

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
