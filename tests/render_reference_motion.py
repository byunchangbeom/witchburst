#!/usr/bin/env python3
"""호스트용: 같은 제품 사본에서 원작 대조·1x 보드·방향/최고속480장을 생성한다."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs(source):
    return {str(p.relative_to(source)): digest(p) for p in sorted(source.rglob("*"))
            if p.is_file() and ".godot" not in p.parts}


def validate_directions(records, maximum=False):
    """자료 누락/라벨만8방향인 자료/최고속 미도달을 거부한다. 시각 수용은 별도다."""
    expected = {(tier, direction) for tier in (0, 3)
                for direction in ("N", "NE", "E", "SE", "S", "SW", "W", "NW")}
    groups = {}
    if len(records) != 480:
        raise ValueError("방향 시퀀스480프레임 필요")
    for index, record in enumerate(records):
        if record["index"] != index or record["max_speed_fixture"] != maximum:
            raise ValueError("프레임 순서/최고속 입력 불일치")
        key = record["case_tier"], record["case_direction"]
        groups.setdefault(key, []).append(record)
    if set(groups) != expected:
        raise ValueError("두 무기×8방향 누락")
    for (tier, direction), frames in groups.items():
        states = {r["state"] for r in frames}
        if len(frames) != 30 or not {"skill_prepare", "skill_release", "skill_recover", "skill_settle"} <= states:
            raise ValueError(f"시전/취소 전환 누락: {tier}/{direction}")
        if any(r["facing"] != direction for r in frames if r["state"].startswith("skill_")):
            raise ValueError(f"실제 시전 방향 불일치: {tier}/{direction}")
        if len({r["lower_frame"] for r in frames if r["lower_visible"]}) < 2:
            raise ValueError(f"실제 하체 프레임 진행 누락: {tier}/{direction}")
        if maximum and sum(abs(r["actual_rule_speed"]-520) < .1 for r in frames) < 20:
            raise ValueError(f"최고속520 실제 이동 부족: {tier}/{direction}")
    return {"cases": len(groups), "frames": len(records), "visual_acceptance": "PENDING_INDEPENDENT_REVIEW"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--engine", default=shutil.which("godot"))
    args = parser.parse_args()
    if not args.engine:
        raise SystemExit("기존 Godot4.7.2 필요")
    if not subprocess.check_output([args.engine, "--version"], text=True).startswith("4.7.2."):
        raise SystemExit("고정 Godot4.7.2 필요")
    repo = Path(__file__).resolve().parents[1]
    source = repo / "game"
    pinned = inputs(source)
    head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(repo), "status", "--porcelain"], text=True)
    output = args.artifacts.resolve()
    # 이전 실패/이미지를 덮지 않는다.
    output.mkdir(parents=True, exist_ok=False)
    manifest = {"source_head": head, "source_dirty": dirty, "game_inputs": pinned,
                "checker_sha256": digest(Path(__file__)), "suites": {},
                "method": "Godot 실제 렌더러의 통제 fixture; 자연성장은 획득 봇",
                "visual_review": "PENDING_INDEPENDENT_REVIEW", "os_input": "NOT_MEASURED",
                "audio": "NOT_HEARD", "human_fun": "NOT_MEASURED", "device": "NOT_MEASURED"}
    receipt = output / "source-manifest.json"
    user = None
    try:
        with tempfile.TemporaryDirectory(prefix="witchburst-motion-") as temporary:
            work = Path(temporary).resolve()
            project = work / "game"
            shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot"))
            settings = project / "project.godot"
            user_name = f"witchburst-tests/{work.name}"
            settings.write_text(settings.read_text().replace(
                'config/custom_user_dir_name="witchburst"', f'config/custom_user_dir_name="{user_name}"'))
            if os.uname().sysname != "Darwin":
                raise RuntimeError("현재 렌더 회수 계약은 macOS 호스트 전용")
            user = Path.home() / "Library/Application Support" / user_name
            if user.exists():
                user = None
                raise RuntimeError("이미 존재하는 사용자 디렉터리 사용 거부")
            env = dict(os.environ, WITCHBURST_TEST_ROOT=str(work))

            def execute(name, options, count=None):
                dest = output / name
                dest.mkdir()
                env["WITCHBURST_ARTIFACTS"] = str(dest)
                command = [args.engine, "--path", str(project), "--log-file", str(dest / "engine.log"), *options]
                try:
                    result = subprocess.run(command, env=env, cwd=project, text=True,
                                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
                    log = result.stdout
                except subprocess.TimeoutExpired as error:
                    log = error.stdout or b""
                    if isinstance(log, bytes):
                        log = log.decode("utf-8", errors="replace")
                    (dest / "run.log").write_text(log)
                    raise RuntimeError(f"{name}: 타임아웃") from error
                (dest / "run.log").write_text(log)
                if result.returncode or re.search(r"SCRIPT ERROR:|ERROR:|Assertion failed|FAIL:", log):
                    raise RuntimeError(f"{name}: 엔진/제품 실패, run.log 확인")
                pngs = sorted(dest.glob("*.png"))
                if count is not None and len(pngs) != count:
                    raise RuntimeError(f"{name}: 캡처 {len(pngs)}/{count}")
                record = {"captures": {p.name: digest(p) for p in pngs}, "returncode": result.returncode}
                observations = dest / "skill-observations.json"
                if observations.exists():
                    record["coverage"] = validate_directions(json.loads(observations.read_text()), name == "skills-max")
                record["observations"] = {p.name: digest(p) for p in dest.glob("*.json")}
                manifest["suites"][name] = record
                print(f"PASS {name}: {len(pngs)}PNG", flush=True)

            execute("import", ["--headless", "--import", "--quit"])
            for name, script, count, extra in [
                ("stages", "capture", 129, []), ("boards", "frame_board", 17, []),
                ("actions", "action_preview", 400, []),
                ("skills", "skill_direction_preview", 480, []),
                ("skills-max", "skill_direction_preview", 480, ["--", "--max-speed"]),
                ("natural", "natural_growth_preview", 240, [])]:
                execute(name, ["--audio-driver", "Dummy", "--script", f"res://tests/{script}.gd", *extra], count)
        if inputs(source) != pinned:
            raise RuntimeError("검사 도중 제품 입력 변경; 같은 소스 근거로 사용 불가")
        manifest["generation"] = "PASS_CAPTURE_COMPLETENESS_ONLY"
    except Exception as error:
        manifest["generation"] = "FAIL"
        manifest["failure"] = str(error)
        raise
    finally:
        receipt.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
        if user is not None and user.is_dir():
            shutil.rmtree(user)


if __name__ == "__main__":
    main()
