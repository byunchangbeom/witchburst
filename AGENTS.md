# Witchburst 제작 지침

설명·보고·주석은 한국어로 작성한다. 게임 방향 정본은 GAME-BRIEF.md다.
Harness V `/Users/nhn/brainspace/workspace/harness-v`의 커밋 `17d4e6b58e5ad7ed8c62dab0db1f6efe652633ed`을 고정 채택한다.
해당 커밋의 DIRECTION.md, USAGE.md, docs/game-session-start.md를 제작 절차로 따른다. harness.lock을 참조한다. 공통 하네스는 이 게임 작업에서 수정하지 않는다.

- 합의 범위의 로컬 제작·테스트·독립 리뷰·커밋·통합·지정 origin/main 소스 push·완료 트리 정리를 위임받았다. 출시·결제는 별도 승인이다.
- 작업별 branch/worktree에서 한 작성자가 수정한다. Harness V Controller가 commit·통합·push를 수행한다. 구현과 최종 리뷰는 별도 실제 Codex 세션으로 실행한다.
- 작은 마녀의 약한 사격에서 대형 마도구·정령 연계로 화력이 자라는 대비를 실제 플레이로 확인한다. 자동 진행을 기본으로 선택 드래그·보스 스킬을 제공한다.
- 레퍼런스 자산을 복사하지 않는다. 신규 코드·그림·소리를 만들고 출처를 docs/asset-sources.json에 남긴다.
- 첫 버전은 과금·로그인 없이 로컬 저장, 최대 24시간 오프라인 보상이다. 후속 IdP 로그인·기기 간 공유와 로컬 진행 이전은 필수 후속 요구다.
- 컴파일·자동 규칙 검사·실제 GUI·시각·음향·사람 재미·실기기 검증은 구분한다. 미검증을 PASS로 표시하지 않는다.
- 기존 파일·STOP·미결 결과를 보존한다. 설치·전역 설정·새 서비스·원격 생성·강제 push는 하지 않는다.

## 후속 제작과 기록

- 디자인 제작은 [고정 제작 절차](docs/game-production-workflow.md)를 따른다. 원작85/89/2/8과 같은 단계·표시 크기의 실제 실행을 묶음 전후 비교하며, 새 실행/이미지를 얻지 못하면 미검증으로 남긴다.
- 게임 소유 기록은 [개선 대기열](docs/improvement-queue.md), 집계·기존 실패 이력은 [사이클 기록](docs/production-cycles.md)에 연결한다. 중앙 전달은 게임 경로·기존 ID·Controller가 발행한 실제 기록 커밋으로 준비하며 중앙 파일은 수정하지 않는다.
- `harness.lock`17d4e6b와 `harness-cycles.lock`7304344는 보존한다. 문서 선택 채택과 실행기 채택은 별개다. 후속 Controller의 별도 명시 채택 bbf9f9c는 [실행기 원장](docs/executor-adoptions.json)의 기존 receipt를 따른다. `tools/hv-cycle`은 그 고정 실행기의 진입점이며 이 Worker가 새 채택·운영 호출을 수행한 것은 아니다.
- Worker는 배정 경로의 구현·검사 결과만 반환한다. commit·checkout·통합·push·다른 실제 세션의 독립 리뷰는 Controller가 수행한다. 기존 반려와 EA-004/006 OPEN은 기술 PASS로 닫지 않는다.
