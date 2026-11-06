"""실제 Godot 프로세스로 직접 검사 진입·격리 거부·실패 전파를 회귀 검사한다."""

import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest


class Entrypoints(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="witchburst-entry-")
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name).resolve()
        self.project = self.work / "game"
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / "game", self.project, ignore=shutil.ignore_patterns(".godot", "override.cfg"))
        (self.work / "tests").mkdir()
        shutil.copy2(source / "tests/run.py", self.work / "tests/run.py")
        self.engine = shutil.which("godot")
        self.assertIsNotNone(self.engine, "Godot 4.7.2 실행 파일 필요")
        self.env = os.environ.copy()
        self.env.pop("WITCHBURST_TEST_ROOT", None)
        self.env.pop("WITCHBURST_ARTIFACTS", None)
        self.user = self.work / "outer-user"
        self.user.mkdir()
        # 최초 Godot 프로세스도 임시 사용자 경로로 한정한다.
        if platform.system() == "Darwin":
            self.env["HOME"] = str(self.user)
        elif platform.system() == "Windows":
            self.env["APPDATA"] = str(self.user)
        else:
            for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
                self.env[key] = str(self.user)
        if platform.system() == "Darwin" and Path("/etc/ssl/cert.pem").exists():
            with (self.project / "project.godot").open("a", encoding="utf-8") as settings:
                settings.write('\n[network]\ntls/certificate_bundle_override="/etc/ssl/cert.pem"\n')
        self.sentinel = self.user / "progress-sentinel.txt"
        self.sentinel.write_text("기존 진행 보존", encoding="utf-8")

    def direct(self):
        result = subprocess.run(
            [self.engine, "--headless", "--path", str(self.project), "--script", "res://tests/smoke.gd"],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        self.assertEqual(self.sentinel.read_text(encoding="utf-8"), "기존 진행 보존")
        self.assertFalse(list(self.user.rglob("isolation.txt")), "최초 사용자 경로에 검사 파일을 쓰면 안 됨")
        return result

    def test_direct_bootstraps_isolated_product_checks(self):
        result = self.direct()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("PASS import", result.stdout)
        self.assertIn("PASS smoke", result.stdout)
        self.assertRegex(result.stdout, r"제품 자동 검사: [1-9]\d*개, 실패 0")
        self.assertNotIn("ERROR:", result.stdout)

    def test_invalid_isolation_refuses_before_scene_load(self):
        self.env["WITCHBURST_TEST_ROOT"] = str(self.work / "unrelated")
        result = self.direct()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("실제 사용자 저장 경로 격리 실패", result.stdout)
        self.assertNotIn("자연 강화 자동 승리", result.stdout)

    def test_product_failure_reaches_direct_exit_code(self):
        smoke = self.project / "tests/smoke.gd"
        smoke.write_text(smoke.read_text(encoding="utf-8").replace(
            '\tscene = load(', '\trequire(false, "의도한 제품 회귀 실패")\n\tscene = load(', 1), encoding="utf-8")
        result = self.direct()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("의도한 제품 회귀 실패", result.stdout)
        self.assertIn("FAIL smoke", result.stdout)
        self.assertNotIn("PASS smoke", result.stdout)

    def test_capture_stage_failure_reaches_direct_exit_code(self):
        capture = self.project / "tests/capture.gd"
        capture.write_text(capture.read_text(encoding="utf-8").replace(
            'capture_matrix("05-won", battle.Phase.WON)',
            'capture_matrix("05-won", battle.Phase.LOST)', 1), encoding="utf-8")
        result = self.direct()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("PASS smoke", result.stdout)
        self.assertIn("FAIL capture-stages", result.stdout)

    def test_import_log_error_reaches_direct_exit_code(self):
        (self.project / "broken.gd").write_text("extends Node\nfunc broken(\n", encoding="utf-8")
        # 사용하지 않는 스크립트는 임포트에서 파싱되지 않을 수 있으므로 실제 오토로드로 연결한다.
        with (self.project / "project.godot").open("a", encoding="utf-8") as settings:
            settings.write('\n[autoload]\nBroken="*res://broken.gd"\n')
        result = self.direct()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("FAIL import", result.stdout)


if __name__ == "__main__":
    unittest.main()
