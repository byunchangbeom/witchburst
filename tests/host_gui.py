"""Controller 호스트에서 격리 캡처를 실행하고 gui-v1 영수증을 남긴다."""

import ctypes
import hashlib
import json
import math
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import sys


STATES = ("01-first", "02-grown", "03-boss", "04-skill", "05-won", "06-lost", "07-workshop", "08-rebirth", "09-merge",
          "10-first-shot", "11-grown-shot", "12-first-flight", "13-grown-flight", "14-boss-shot", "15-boss-flight")
PARTY_CASES = ("default", "top-left", "top-right", "bottom-left", "bottom-right", "edge-top", "edge-right",
               "edge-bottom", "edge-left", "counterexample", "enter", "exit", "moving", "return")
STATES += tuple(f"party-{weapon}-{case}" for weapon in ("starter", "cannon") for case in PARTY_CASES)
SIZES = ((540, 960), (540, 1200), (720, 960))


def display_unavailable():
    """권한 요청·변경 없이 현재 GUI 세션만 진단한다. OS 입력은 보내지 않는다."""
    if sys.platform != "darwin":
        return "tool_unavailable", {"detail": "이 호스트 검사는 macOS용입니다"}
    cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    cg.CGSessionCopyCurrentDictionary.restype = ctypes.c_void_p
    cg.CGMainDisplayID.restype = ctypes.c_uint32
    cf.CFRelease.argtypes = [ctypes.c_void_p]
    cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
    cf.CFStringCreateWithCString.restype = ctypes.c_void_p
    cf.CFDictionaryGetValue.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    cf.CFDictionaryGetValue.restype = ctypes.c_void_p
    cf.CFBooleanGetValue.argtypes = [ctypes.c_void_p]
    cf.CFBooleanGetValue.restype = ctypes.c_bool
    session = cg.CGSessionCopyCurrentDictionary()
    display = cg.CGMainDisplayID()
    diagnostics = {"session_available": bool(session), "main_display_id": display}
    if not session:
        return "no_display", diagnostics
    try:
        key = cf.CFStringCreateWithCString(None, b"CGSSessionScreenIsLocked", 0x08000100)
        try:
            value = cf.CFDictionaryGetValue(session, key)
            if value and cf.CFBooleanGetValue(value):
                return "screen_locked", diagnostics
        finally:
            cf.CFRelease(key)
    finally:
        cf.CFRelease(session)
    return (None if display else "no_display"), diagnostics


def verify_captures(directory):
    """이미지의 존재·치수·상태 행렬을 확인한다. 시각 판독 PASS를 만들지 않는다."""
    manifest = json.loads((directory / "capture-manifest.json").read_text(encoding="utf-8"))
    if manifest["display_server"] == "headless":
        raise ValueError("headless 결과는 GUI 캡처로 수용할 수 없습니다")
    expected = {(state, width, height) for state in STATES for width, height in SIZES}
    found = set()
    captures = []
    for item in manifest["captures"]:
        path = directory / item["path"]
        if path.is_symlink() or not path.resolve().is_relative_to(directory.resolve()):
            raise ValueError("캡처 경로가 자료 폴더를 벗어납니다")
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError("PNG 파일이 아닙니다")
        size = struct.unpack(">II", data[16:24])
        key = (item["stage"], *size)
        if key not in expected or key in found or list(size) != item["size"]:
            raise ValueError("캡처 상태·치수 행렬 불일치")
        launch = item["stage"] in ("10-first-shot", "11-grown-shot", "14-boss-shot")
        flight = item["stage"] in ("12-first-flight", "13-grown-flight", "15-boss-flight")
        if launch or flight:
            shot = item.get("shot_alignment", {})
            names = ("sprite_muzzle", "projectile", "emitter", "tail", "sprite_breech", "initial_projectile")
            points = [shot.get(name, []) for name in names]
            if (shot.get("kick") != 1.0 or shot.get("breath") != 1.0
                    or any(len(point) != 2 or not all(math.isfinite(n) for n in point) for point in points)
                    or math.dist(points[0], points[2]) >= 0.01
                    or (launch and any(math.dist(points[0], points[i]) >= 0.01 for i in (1, 3)))):
                raise ValueError("발사 직후 최대 반동·호흡 포구 정렬 불일치")
            axis = [points[0][i] - points[4][i] for i in (0, 1)]
            initial = [points[5][i] - points[0][i] for i in (0, 1)]
            axis_length, initial_length = math.hypot(*axis), math.hypot(*initial)
            unit = min(size[0], 600) / 540
            if (axis_length < 1 or abs(initial_length - 8 * unit) > 0.01
                    or sum(a * b for a, b in zip(axis, initial)) / max(axis_length * initial_length, 1e-9) < 0.9999):
                raise ValueError("포신과 초기 탄도 방향 불일치")
            if (shot.get("travel") != (80.0 if flight else 0.0)
                    or (flight and (math.dist(points[0], points[1]) < 1
                                    or math.dist(points[1], points[3]) > 48 * unit + 0.01))):
                raise ValueError("비행 프레임·꼬리 불일치")
        if item["stage"].startswith("party-"):
            party = item.get("party", {})
            low, high = party.get("min_diagonal", 0), party.get("max_diagonal", 1500)
            if (not all(math.isfinite(n) for n in (low, high))
                    or not 650 < low <= high < 1480 or party.get("samples", 0) <= 100):
                raise ValueError("드래그 발·그림자 풀밭 기록 불일치")
            shot = item.get("party_shot", {})
            points = [shot.get(name, []) for name in
                      ("muzzle", "launch", "emitter", "spirit_tip", "spirit_launch", "initial", "breech")]
            if (shot.get("kick") != 1.0
                    or any(len(point) != 2 or not all(math.isfinite(n) for n in point) for point in points)
                    or any(math.dist(points[0], points[i]) >= 0.01 for i in (1, 2))
                    or math.dist(points[3], points[4]) >= 0.01):
                raise ValueError("드래그 주탄·정령탄 포구 불일치")
            axis = [points[0][i] - points[6][i] for i in (0, 1)]
            initial = [points[5][i] - points[0][i] for i in (0, 1)]
            lengths = math.hypot(*axis) * math.hypot(*initial)
            if lengths <= 0 or sum(a * b for a, b in zip(axis, initial)) / lengths < 0.9999:
                raise ValueError("드래그 포신 초기 탄도 불일치")
        terrain = item.get("terrain")
        if not isinstance(terrain, list) or (item["stage"] in ("01-first", "08-rebirth") and not terrain):
            raise ValueError("풀밭 배치 기록 누락")
        for ground in terrain:
            foot, radius = ground.get("foot", []), ground.get("shadow_half_width", -1)
            if (len(foot) != 2 or not all(math.isfinite(n) for n in (*foot, radius)) or radius <= 0
                    or not 0 <= foot[0] <= 1052 or not 0 <= foot[1] <= 1495
                    or foot[1] <= 650 - (foot[0] - radius) * 0.5
                    or foot[1] >= 1480 - (foot[0] + radius) * 0.5):
                raise ValueError("발·그림자가 풀밭 경계를 벗어남")
        found.add(key)
        captures.append({"path": path.name, "sha256": hashlib.sha256(data).hexdigest()})
    if found != expected:
        raise ValueError("필수 화면 캡처 누락")
    return captures


def main():
    prompt, answer, directory = map(Path, sys.argv[1:4])
    directory.mkdir(parents=True, exist_ok=True)
    receipt = json.loads(prompt.read_text(encoding="utf-8"))
    receipt.update(status="PRODUCT_FAIL", reason_code="", observations=[], captures=[],
                   platform=platform.platform(), visual_review="NOT_MEASURED", human_play="NOT_MEASURED",
                   os_input="NOT_MEASURED", audio="NOT_MEASURED", device="NOT_MEASURED")
    try:
        reason, diagnostics = display_unavailable()
        receipt["diagnostics"] = diagnostics
        if not shutil.which("godot"):
            reason = "tool_unavailable"
        # 화면 잠금은 OS 입력 제약이다. GPU 내부 캡처 실패로 추정하지 않는다.
        if reason == "screen_locked":
            reason = None
        if reason:
            receipt.update(status="ENV_UNAVAILABLE", reason_code=reason)
            return
        target = directory / "product-check"
        # 이전 PNG를 재사용하지 않는다. Controller는 호출마다 새 자료 경로를 넘긴다.
        if target.exists():
            raise ValueError("사용하지 않은 자료 폴더가 필요합니다")
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("run.py")),
                                 "--capture", "--artifacts", str(target)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=420)
        (directory / "host-run.log").write_text(result.stdout, encoding="utf-8")
        if result.returncode:
            raise ValueError(f"격리 게임 검사 종료 코드 {result.returncode}")
        captures = verify_captures(target)
        receipt.update(status="PASS", captures=[{**item, "path": "product-check/" + item["path"]} for item in captures],
                       observations=[{"name": "rendered_states", "status": "PASS"},
                                     {"name": "capture_matrix", "status": "PASS"}])
    except (OSError, ValueError, KeyError, TypeError, struct.error, subprocess.SubprocessError) as error:
        receipt.update(status="PRODUCT_FAIL", detail=str(error),
                       observations=[{"name": "rendered_states", "status": "FAIL"}])
    finally:
        answer.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
