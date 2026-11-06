#!/usr/bin/env python3
"""기존 설치 엔진으로 임시 프로젝트·진행 파일을 검사한다. 호스트에서 실행한다."""
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
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--capture", action="store_true")
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
    engine = str(args.engine.resolve()) if args.engine else shutil.which("godot")
    if not engine:
        raise SystemExit("Godot 실행 파일이 필요합니다.")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2."):
        raise SystemExit(f"요구 엔진 4.7.2, 현재 {version}")
    artifacts = (args.artifacts or Path(tempfile.mkdtemp(prefix="witchburst-evidence-"))).resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parents[1] / "game"
    failed = []
    with tempfile.TemporaryDirectory(prefix="witchburst-test-") as temporary:
        work = Path(temporary).resolve()
        project = work / "game"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot", "override.cfg"))
        env = os.environ.copy()
        # HOME/CODEX_HOME 및 설치 엔진을 변경하지 않는다. 실제 진행 파일은
        # 테스트 씬이 WITCHBURST_TEST_ROOT 아래의 고유 경로로 주입한다.
        env["WITCHBURST_TEST_ROOT"] = str(work)
        env["WITCHBURST_ARTIFACTS"] = str(artifacts)
        system = platform.system()
        if system == "Darwin":
            data_base = Path.home() / "Library/Application Support"
        elif system == "Windows":
            data_base = Path(os.environ["APPDATA"])
        else:
            data_base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        user = data_base / "witchburst-tests" / work.name
        if user.exists():
            raise SystemExit("새 검사 사용자 경로가 필요합니다.")
        settings_file = project / "project.godot"
        settings = settings_file.read_text(encoding="utf-8")
        settings = settings.replace("config/use_custom_user_dir=false", "config/use_custom_user_dir=true")
        settings = re.sub(r'config/custom_user_dir_name="[^"]*"',
                          f'config/custom_user_dir_name="witchburst-tests/{work.name}"', settings)
        settings_file.write_text(settings, encoding="utf-8")
        checks = [("import", ["--headless", "--import", "--quit"]),
                  ("smoke", ["--headless", "--script", "res://tests/smoke.gd"]),
                  ("capture-stages", ["--headless", "--script", "res://tests/capture.gd", "--", "--verify-stages"])]
        if args.capture:
            checks.append(("capture", ["--audio-driver", "Dummy", "--script", "res://tests/capture.gd"]))
        try:
            for name, options in checks:
                if failed:
                    break
                command = [engine, "--path", str(project), "--log-file", str(artifacts / f"{name}-engine.log"), *options]
                try:
                    result = subprocess.run(command, cwd=project, env=env, text=True,
                                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
                except subprocess.TimeoutExpired as error:
                    output = error.stdout or b""
                    if isinstance(output, bytes):
                        output = output.decode("utf-8", errors="replace")
                    (artifacts / f"{name}.log").write_text(output, encoding="utf-8")
                    raise SystemExit(f"FAIL {name}: 90초 타임아웃")
                (artifacts / f"{name}.log").write_text(result.stdout, encoding="utf-8")
                print(result.stdout, end="")
                engine_log = artifacts / f"{name}-engine.log"
                logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
                bad = re.search(r"(?im)(SCRIPT ERROR:|ERROR:|Parse Error:|Assertion failed|FAIL:)", logs)
                if result.returncode or bad:
                    failed.append(name)
                    print(f"FAIL {name}: 종료 {result.returncode}")
                else:
                    print(f"PASS {name}")
        finally:
            # 이 호출이 새로 만든 고유 엔진 사용자 디렉터리만 회수한다.
            if user.is_dir():
                shutil.rmtree(user)
    print(f"검사 자료: {artifacts}")
    if failed:
        raise SystemExit("실패 검사: " + ", ".join(failed))

if __name__ == "__main__":
    main()
