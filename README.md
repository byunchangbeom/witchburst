# 마녀포격단 · Witchburst

꼬마 마녀와 정령이 저주를 정화하는 모바일 우선 방치형 RPG.

제작 방향: [GAME-BRIEF.md](GAME-BRIEF.md). 첫 지역과 보스의 플레이 가능한 전투 프로토타입이다. 출시 패키지는 아직 없다.

Godot **4.7.2**가 설치된 환경에서 저장소 루트 기준으로 실행한다. 추가 플러그인·다운로드는 필요 없다.

```sh
godot --path game
# 편집기로 열기
godot --editor --path game
```

첫 화면부터 자동 이동·자동 사격한다. 적 정화로 얻은 별빛으로 하단의 공격력·사격 속도·획득량을 강화한다. 공격력 +2에서 마법포, +4에서 거대 마도구와 정령 무리가 보인다. 전투 영역을 마우스나 손가락으로 끌면 선택적으로 위치를 바꾼다. 손을 놓고 2초가 지나면 자동 이동으로 돌아간다.

숲의 적 12마리를 정화하면 가시왕이 등장한다. HP와 남은 24초가 상단에 표시되며, ‘별비’는 보스전에서만 쓰는 8초 쿨다운 수동 스킬이다. 스킬 없이도 강화를 쌓아 승리할 수 있다. 시간초과 뒤에는 재화·재료·강화를 유지한 채 재도전하고, 승리 뒤에도 다시 전투할 수 있다. 우측 상단에서 효과음을 켜거나 끈다.

현재 진행은 실행 중에만 유지된다. **저장·최대 24시간 오프라인 보상·뽑기·제작/합성·정령 해금·환생은 후속 구현**이며 활성 버튼을 가장해 노출하지 않는다. 후속 IdP 로그인·기기 간 공유·기존 로컬 진행 이전도 필수 요구로 남아 있다.

제품 자동 검사는 다음 명령을 사용한다. `game/tests/smoke.gd`를 실제 기본 씬에 연결해 발사체 이동·피해·처치·보상, 세 강화, 보스 시간초과와 재도전, 스킬 쿨다운, 자연 보상만으로 강화한 스킬 없는 승리, 승리 후 반복 전투를 assert한다. 30/144 FPS·가변 delta, Viewport 마우스/터치 라우팅과 화면 비율별 배치도 검사한다. 캡처 스크립트의 6개 전투 상태 × 3개 화면 크기 준비 경로와 한국어 글리프 fallback도 headless로 확인하되 PNG는 생성하지 않는다.

```sh
python3 tests/run.py
# Controller의 Godot 직접 검사도 같은 격리 실행기로 연결 (Python 3 필요)
godot --headless --path game --script res://tests/smoke.gd
# 진입 경로·격리 거부·실패 종료 코드 회귀 (임시 사본에서 실제 Godot 실행)
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
# macOS 호스트의 디스플레이가 있는 환경에서 실제 렌더러 캡처 추가
python3 tests/run.py --capture
# 로그와 캡처를 지정 경로에 보관
python3 tests/run.py --capture --artifacts /tmp/witchburst-review
```

Python 실행기는 임시 프로젝트 사본과 별도의 사용자·에디터 경로를 만들고, `user://`가 격리 경로 안인지 확인한다. 원래 프로젝트의 캐시·사용자 진행·전역 설정은 바꾸지 않는다. 검사 폴더는 종료 시 제거하고 로그·캡처는 출력한 자료 경로에 남긴다. Godot 직접 검사는 격리 환경변수가 없으면 씬 로드·진행 파일 접근 전에 Python 실행기로 넘기고 같은 Godot 실행 파일로 임포트·제품 검사를 수행한다. 잘못 지정된 격리 경로는 쓰기 전에 거부한다. 임포트 종료 코드가 0이어도 오류 로그가 있으면 실패하며, 제품 assert·오류·90초 타임아웃과 자식 검사 실패 역시 최초 실행에 0이 아닌 코드로 반환한다.

Controller는 [tests/host-gui-check.json](tests/host-gui-check.json)의 항목을 작업 `checks`에 추가해 호스트 GUI 검사로 실행한다. 현재 작업 선언에는 headless 실행기만 등록되어 있으므로 이 등록은 Controller 후속 작업이다. 이 작업 트리에서 공통 하네스나 Controller 상태는 수정하지 않는다. 호스트 진입점은 `python3 tests/host_gui.py @PROMPT@ @ANSWER@ @ARTIFACTS@`이며, Controller가 소스 커밋·입력 SHA를 제공하고 GUI 자원 잠금을 관리한다. GUI 세션 없음·화면 잠금은 권한 변경 없이 `ENV_UNAVAILABLE`로 반환한다. 실행 실패·타임아웃은 제품/검사 실패로 남기며 디스플레이 부재로 추정하지 않는다.

호스트는 첫 사격(`01-first`), 공격 +4 성장(`02-grown`), 보스 HP/남은 시간(`03-boss`), 별비/쿨다운(`04-skill`), 승리(`05-won`), 시간초과(`06-lost`)를 각각 **540×960 / 540×1200 / 720×960**으로 캡처한다. `product-check/capture-manifest.json`에 상태·강화·사격/피해/보상 누계·폰트·실제 치수를 남기고 `answer.json`에는 PNG 18개의 SHA를 기록한다. 성장 화면만 별빛 1,000의 비교 fixture를 사용한다. 자연 보상 승리는 별도 smoke 결과다. PNG 누락·치수 불일치·단색 빈 화면·headless 결과는 GUI 성공으로 수용하지 않는다.

호스트 영수증의 PASS는 실행·PNG 수집 범위다. **독립 리뷰어는 18개 PNG를 열어** 작은 지팡이/탄과 성장한 대형 마도구/큰 탄/정령의 대비, 한국어 글자 깨짐·잘림, 상단 보스 정보, 하단 세 강화와 스킬 버튼, 승리/패배 안내와 재도전 버튼, 화면 비율별 겹침·잘림을 직접 판독하고 파일명별 근거를 남겨야 한다. `capture-stages.json`에는 이미지가 없으며 시각 근거로 사용할 수 없다. 캡처가 수집되어도 이 판독 전에는 `visual_review=NOT_MEASURED`다.

자동 규칙 검사와 렌더러 캡처는 OS 실제 터치·음향 청취·사람 재미·실기기 검사와 구분한다. 해당 검증은 수행 전 **NOT_MEASURED**다. Android/iOS/Windows/웹 내보내기와 실제 설치·실행도 미검증이다. 독립 최종 리뷰·커밋·통합·push는 Controller의 후속 단계다.

수치와 체험 가설은 [docs/design.md](docs/design.md), 직접 만든 절차적 그림·효과음과 폰트 출처는 [docs/asset-sources.json](docs/asset-sources.json)에 기록한다.
