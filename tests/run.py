#!/usr/bin/env python3
"""임시 프로젝트·사용자 경로에서 Godot 임포트와 제품 검사를 실행한다."""

import argparse
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, help="직접 검사를 시작한 Godot 실행 파일 (기본: PATH의 godot)")
    parser.add_argument("--capture", action="store_true", help="실제 렌더러 캡처 추가 (OS 입력 검증 아님)")
    parser.add_argument("--artifacts", type=Path, help="로그·캡처 보관 경로 (기본: 새 임시 폴더)")
    args = parser.parse_args()
    engine = str(args.engine.resolve()) if args.engine else shutil.which("godot")
    if not engine:
        raise SystemExit("Godot 4.7.2 실행 파일이 필요합니다. 설치는 수행하지 않습니다.")
    if args.capture:
        from host_gui import display_unavailable
        reason, diagnostics = display_unavailable()
        if reason:
            raise SystemExit(f"ENV_UNAVAILABLE {reason}: {diagnostics}. Controller 호스트 GUI 검사를 사용하세요.")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2."):
        raise SystemExit(f"요구 엔진: 4.7.2, 현재: {version}")
    artifacts = (args.artifacts or Path(tempfile.mkdtemp(prefix="witchburst-evidence-"))).resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parents[1] / "game"
    with tempfile.TemporaryDirectory(prefix="witchburst-test-") as work:
        work = Path(work).resolve()
        project = work / "game"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot", "override.cfg"))
        system = platform.system()
        env = os.environ.copy()
        if system == "Darwin":
            # 검사 자식의 홈 디렉터리만 격리한다. 부모 환경·실제 홈은 변경하지 않는다.
            # 홈을 생략하면 4.7.2의 상대 user://에서 ObjectDB 임포트 오류가 난다.
            test_home = work / "home"
            test_home.mkdir()
            env["HOME"] = str(test_home)
            editor_dir = test_home / "Library/Application Support/Godot"
        elif system == "Windows":
            env["APPDATA"] = str(work / "data")
            editor_dir = work / "data/Godot"
        else:
            for variable, folder in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
                env[variable] = str(work / folder)
            editor_dir = work / "config/godot"
        settings_file = project / "project.godot"
        settings = settings_file.read_text(encoding="utf-8")
        settings = settings.replace('config/custom_user_dir_name="witchburst"', 'config/custom_user_dir_name="test-user"')
        # 에디터에는 override.cfg가 적용되지 않으므로 검사 사본의 설정만 변경한다.
        if system == "Darwin" and Path("/etc/ssl/cert.pem").exists():
            settings += '\n[network]\ntls/certificate_bundle_override="/etc/ssl/cert.pem"\n'
            editor_dir.mkdir(parents=True, exist_ok=True)
            (editor_dir / "editor_settings-4.7.tres").write_text(
                '[gd_resource type="EditorSettings" format=3]\n[resource]\n'
                'network/tls/editor_tls_certificates="/etc/ssl/cert.pem"\n'
                'network/connection/network_mode=0\n', encoding="utf-8")
        settings_file.write_text(settings, encoding="utf-8")
        env["WITCHBURST_TEST_ROOT"] = str(work)
        env["WITCHBURST_ARTIFACTS"] = str(artifacts)
        checks = [("import", ["--headless", "--import", "--quit"]),
                  ("smoke", ["--headless", "--script", "res://tests/smoke.gd"]),
                  ("capture-stages", ["--headless", "--script", "res://tests/capture.gd", "--", "--verify-stages"])]
        if args.capture:
            checks.append(("capture", ["--audio-driver", "Dummy", "--script", "res://tests/capture.gd"]))
        failed = []
        for name, options in checks:
            if name == "capture" and failed:
                print("SKIP capture: 앞선 제품 검사 실패를 먼저 수정해야 합니다.")
                break
            command = [engine, "--path", str(project), "--log-file", str(artifacts / f"{name}-engine.log"), *options]
            try:
                result = subprocess.run(command, cwd=project, env=env, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, timeout=90)
            except subprocess.TimeoutExpired as error:
                output = error.stdout or b""
                if isinstance(output, bytes):
                    output = output.decode("utf-8", errors="replace")
                (artifacts / f"{name}.log").write_text(output, encoding="utf-8")
                raise SystemExit(f"FAIL {name}: 90초 타임아웃. 자료: {artifacts}")
            (artifacts / f"{name}.log").write_text(result.stdout, encoding="utf-8")
            print(result.stdout, end="")
            # 임포트는 오류를 출력하고도 0을 반환할 수 있다.
            engine_log = artifacts / f"{name}-engine.log"
            logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
            has_error = re.search(r"(?im)(SCRIPT ERROR:|ERROR:|Parse Error:|Assertion failed|FAIL:)", logs)
            if result.returncode or has_error:
                failed.append(name)
                print(f"FAIL {name}: 종료 {result.returncode}. 자료: {artifacts}")
            else:
                print(f"PASS {name}")
    print(f"검사 자료: {artifacts}")
    if failed:
        raise SystemExit("실패 검사: " + ", ".join(failed))


if __name__ == "__main__":
    main()
