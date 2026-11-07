# Witchburst 워크플로우·하네스 개선 대기열

## 2026-11-07 reference-motion-followup · 현재 작업 경계

attempt3 현행: 기반a517e2e와 선행CLOSED/논의DISCUSSED를 읽기 전용 확인했다. 이전timeout/전송종료·attempt1/2 import 실패·호출/원문을 보존하고 작은Python검사→격리 개별 제품 실행으로 접근을 바꿨다. 실제 제품 실패0과 환경오류/공식계약 미통과·새GPU/독립판독 대기를 [아트 현행 반환](art-direction.md#2026-11-07-reference-motion-followup--attempt3-회수와-현행-반환)에 연결했다. 기존HV-Q-002/005/006/007·EA-003/004/005/006/WLM003의 후속이며 새ID/사이클완료로 세지 않는다. 추가에이전트·DB/상태전이·중앙수정·commit/통합/push 없음. 기록커밋은 Controller 발행 대기다. 아래 attempt1 관측은 당시 이력이다.

현재 Worker의 기반은 `a724565a950179f0ce6b5dc65719497620f128a4`다. 공식 status의 선행 `storybook-visuals` CLOSED/attempt11/통합 a724565, `ui-design-discussion` DISCUSSED, 본 작업 WORK/attempt1을 확인한 뒤 수정했다. 현재 공식 집계는 완료1/OPEN1·실제70호출이며 아래 완료0/OPEN2·BLOCKED9·QUEUED·59호출 등은 당시 이력으로 보존한다. `task-recovery-20261107/initial-play-close-receipt.json`의 공식 최초 완료가 과거 거부 결과를 지우지는 않는다. 본 작업으로 사이클 수를 올리지 않는다.

`harness.lock`17d4e6b와 `harness-cycles.lock`7304344는 보존한다. 7304344 문서/전환 이력과, Controller가 이후 명시 채택한 bbf9f9c 실행기 receipt(`task-recovery-20261107/executor-adoption.json`)는 별개다. 후자의 기존 원장은 executor-adoptions.json, 진입점은 tools/hv-cycle이다. 이 Worker는 채택·상태전이·DB 수정·운영 run/close를 수행하지 않는다.

원본 Writer가 반환한 living-motion의 개선 대기열·사이클 기록·두 번째 lock·진입점·실행기 원장을 이 작업의 허용 경로로 보존 복사했다. 기존 ID/실패·STOP·호출·원 receipt는 수정하지 않는다. 제품 변경과 검증 한계는 art-direction.md의 reference-motion-followup 절에 연결한다. commit·고정 HEAD의 제품/렌더/보드/시퀀스 검사·독립 Experience/Art·통합/push/정리는 Controller 책임이다.


2026-11-07 현행 사이클/실행기·미완료 매핑은 [사이클 기록](production-cycles.md)을 따른다. 문서 선택은aa96f24로 갱신했다. 기존7304344 실행기의 공식 adopt-cycles 전환과 이력은 유지한다. 아래17d4e6b·4915f61·59/60 관측은 당시 이력이다. 원작 이탈/디자인·S모션 접합은 계속 OPEN이며 새 완료 사이클로 세지 않는다.


게임 소유 정본이다. Producer/Writer: 현재 Root, `work/living-motion` 단일 작성자. 발견일 2026-11-06, 게임 main `bfee10e`, 보존 아트 `ae8083b`, 하네스 `17d4e6b`다. 기존 활성 task·Writer·입력은 수정하지 않는다. 제품 아트/규칙 결함과 공통 실행/절차 제안을 구분한다.

## 기록과 중앙 전달

이전 세션이 중앙에 직접 기록했던 HV-Q-001~009를 ID·내용 그대로 아래에 보존한다. 앞으로는 이 게임에서 기록하며 중앙 파일을 직접 수정하지 않는다. 기존 중앙 기록의 존재는 중앙 담당자 수신/수정/게임 채택을 뜻하지 않는다. 최초 취합 원문 SHA와 현행 runtime은 `workflow-4915f61/before.json`에 고정했다. 중앙 원문은 이후 게임에서 동기화하지 않는다.

- 게임 경로: `/Users/nhn/brainspace/workspace/games/witchburst`, 상대 경로 `docs/improvement-queue.md`.
- 현재 작성 경로: `/Users/nhn/.local/state/harness-v/witchburst/worktrees/living-motion/docs/improvement-queue.md`.
- 전달 항목: HV-Q-001~009, WB-IMP-010~012.
- 기록 커밋: **미커밋 / NOT_SENT**. 정상 Controller commit 이후 실제 기록 커밋을 붙여 중앙 담당자에게 전달한다. 현재 기준 ae8083b/bfee10e를 이 기록이 들어 있는 커밋으로 표시하지 않는다. main 통합 전에는 작업 branch/경로도 함께 제공한다.
- 중앙 처리: **UNVERIFIED**. 이 세션은 중앙 대기열을 읽기만 했으며 중앙 수신/구현 완료를 주장하지 않는다.
- 게임 문서 채택: 현행aa96f24의 기록 위치·Writer 경계·상태 구분을 로컬 채택. 이전4915f61은 이력이다. 별도 공식 사이클 실행기 채택은 production-cycles.md·harness-cycles.lock을 따른다. 중앙 자동 전달/정식 수용과 별개다.

## 현행 대응과 게임 채택 상태

공통 발견 메타데이터는 위 게임/하네스/날짜와 아래 task·자료를 함께 읽는다. 기존 항목의 과거 상태는 아래 원문에서 보존하고, 현재 대응은 이 표로 구분한다.

| ID / 구분·영향 | 발견 task·근거 | 실제 게임 대응 / 미실행 제안 | 중앙 처리 / 게임 채택·검증 |
|---|---|---|---|
| HV-Q-001 / WORKFLOW · 디자인 반려 | first-battle, 사용자 캐릭터·배경·UI 반려; 기존 원문13장 | 원작·공식 비교 이미지 직접 판독, 아트 기준·실제 렌더 비교를 기존 문서에 연결 | 중앙 UNVERIFIED / 문서·로컬 비교 적용, 사용자 반려 OPEN |
| HV-Q-002 / WORKFLOW · 정지 그림 액션 | storybook-visuals 및 Root 후속, 사용자 정적 이동·방향 반려 | 기존 그림/셰이더/입자 재사용. 방향×행동×전환 계약과 부족한 실제 자세 제작. 새 기능·전체 재제작 아님 | 중앙 UNVERIFIED / 프레임·실행·독립 판독 결과는 art-direction.md, 기술 PASS와 아트 수용 분리 |
| HV-Q-003 / HARNESS · 검사 진입점 불일치 | first-battle 초기 Controller 검사 오류 | tests/run.py가 격리 환경·동일 제품 검사를 수행. 등록 argv와 실제 실행 계약 일치 제안 | 중앙 UNVERIFIED / 로컬 래퍼 검사, 관리 task의 검사 선언 변경 없음 |
| HV-Q-004 / HARNESS · 수동 상태 복구 위험 | storybook-visuals BLOCKED attempt9, 이전 수동 복구 이력 | 기존 task/DB 불변. 공식 변경/회수 API 제안; 미커밋 후속 보존 | 중앙 UNVERIFIED / 재개·입력 변경 미실행 |
| HV-Q-005 / HARNESS · GPU와 OS 증거 혼동 | 기존 화면 잠금/창 선택 관측, 실제 GPU 캡처 | GPU·엔진 입력·OS 조작·청취·실기기 별도 상태. 현재 OS 조작/청취 미검증 | 중앙 UNVERIFIED / 로컬 격리 GPU 경로 적용 |
| HV-Q-006 / WORKFLOW · 리뷰 입력 실체 | ui-design-discussion-discussion-2, ui-review-source.json | 실제 검토 사본 SHA와 이미지 지정. cwd source_commit은 실제 검토 소스와 분리 | 중앙 UNVERIFIED / 과거3세션 설계 논의만 확인, 새 독립 판독 별도 |
| HV-Q-007 / WORKFLOW · 환경 진단 반복 | 원본 엔진과 사본 실행차이, 이전900초 timeout | 기존 엔진·고유 격리 저장 경로로 제품 검사와 host 진단 분리. Worker 도구 부재는 실제 imagegen 가용 호스트로 배정 | 중앙 UNVERIFIED / 설치·인증서/권한 변경 없이 로컬 검사, 자산 출처 보존 |
| HV-Q-008 / WORKFLOW · 복귀 finding 승격 | growth-save attempt4/5, ae8083b 수정 후보 | 복귀 보상 회귀를 보존. 기존 technical PASS로 finding 삭제 안 함 | 중앙 UNVERIFIED / 후속 로컬 규칙 통과와 관리 독립 수용 미완료 구분 |
| HV-Q-009 / HARNESS · fixture 포커스 변동 | ae8083b check-1 빈 bullet/제작 실패, diagnose_focus.py | 제품 lifecycle 유지, capture_battle.gd만 host 알림 기록/통제. 이전 실패 보존 | 중앙 UNVERIFIED / 동일 후속 소스 로컬 제품·GPU 검사. 관리 check-1 실패는 미해결 상태 유지 |

## 보존 원문: 기존 ID와 발견·제안·수용 조건

아래는 이전 중앙 기록에서 가져온 역사적 원문이다. ‘현재’·누적56/60 등 당시 수치는 현행 상태가 아니다. 현행 조회는 위 표와 art-direction.md를 따른다.

### HV-Q-001 · 레퍼런스 직접 판독과 시각 품질 기준

- 관측: 인계의 텍스트 관찰만 읽고 원본 13장을 제작 시작 전에 다시 직접 보지 않았다. 도형 기반 화면이 만들어졌고, 가독성·기능 중심 독립 PASS 뒤 사용자가 캐릭터·배경·버튼의 디자인을 명시적으로 반려했다.
- 중앙 책임: 레퍼런스가 주어진 게임의 제작·Experience·독립 QA에 실제 이미지와 아트 의도, 비교 기준을 전달하는 절차.
- 제안: 첫 시각 제작 전에 대표 이미지 직접 판독과 팔레트·선·형태·캐릭터 비율·필드 공간·UI·연출의 짧은 기준을 남긴다. 임시 기능 화면과 대표 아트 화면의 상태를 구분한다. 작은 플레이에서도 핵심 체험의 아트·조작·반응을 평가한다.
- 수용 조건: 독립 담당자가 레퍼런스와 실제 게임 화면을 직접 비교하고 차이·의도·잔여 문제를 설명한다. 가독성 PASS·코드 PASS를 아트 품질·사용자 취향 수용·재미 PASS로 승격하지 않는다.
- 게임 책임: Witchburst의 실제 마녀·배경·버튼 디자인과 에셋 제작은 해당 게임 저장소에서 처리한다.
- 상태: PROPOSED. 공통 절차 미수정.

### HV-Q-002 · 엔진의 표현 기능과 에셋 제작 배정

- 관측: Godot 게임이 대부분 `draw_circle`·`draw_polygon` 임시 그림으로 만들어졌고, 스프라이트·애니메이션·재질·셰이더 활용이 거의 없었다. 사용자가 Godot 에셋·셰이더로 개선 가능한지 지적했다.
- 중앙 책임: Director/Experience/Engineer가 목표 화풍에 맞는 자산·표현 수단을 선택하고 실제 화면 변화로 검증하도록 배정하는 공통 지침.
- 제안: 프로젝트에 맞춰 신규 제작·허용 라이선스 에셋, Sprite2D/AnimatedSprite2D·AnimationPlayer, 타일/레이어, CanvasItem 셰이더·파티클·UI 테마를 선택한다. 모든 기술을 일괄 필수화하지 않는다. 라이선스·출처와 모바일 효과 비용을 확인한다.
- 수용 조건: 노드·셰이더 존재 수가 아니라 실제 발사·적중·성장·UI의 개선 화면과 영향 범위의 성능 자료로 판정한다. 에셋 형태·아트 방향의 문제를 후처리만으로 해결했다고 표시하지 않는다.
- 상태: PROPOSED. 게임별 에셋·셰이더를 중앙에 복사하지 않음.

### HV-Q-003 · 작업 검사 명령과 제품 진입 계약

- 관측: task는 Godot smoke 직접 호출로 등록됐으나 Worker의 smoke는 격리 환경을 구성하는 Python 래퍼를 요구했다. Worker 안에서는 52개 검사가 통과해도 Controller 호출은 실패하여 재작업이 발생했다.
- 제안: 제작자가 등록된 실제 checks argv를 확인하고 같은 진입점에서 검증한다. 테스트 격리 방식·필수 환경·실패 종료 코드가 task 선언과 일치하는지 첫 작업에서 확인한다.
- 수용 조건: Worker 검증과 Controller/통합 검증이 같은 제품 검사 계약을 사용하며, 격리 누락·assert·임포트 오류가 nonzero로 전파된다. 테스트를 약화해 통과시키지 않는다.
- 상태: PROPOSED. 게임 로컬 선언만 수정해 진행했으며 공통 runner는 미수정.

### HV-Q-004 · 작업 선언의 안전한 수정 경로

- 관측: 현재 CLI는 실행 중 add도 Controller lock 때문에 거부하고 기존 task 수정 기능도 없어, 새 사용자 지시를 작업에 반영하거나 검사 계약을 보완할 때 Controller 프로세스를 회수하고 Store의 배타 lock/API로 checks·goal을 수정했다. 실제 실패·시도·호출 기록은 보존했으나 반복 운용할 정상 UX가 부족하다.
- 제안: 허용 필드·활성 호출·고정 소스·검사 revision을 검증하는 공식 수정/재검사 경로를 검토한다. 이전 선언·사유·수정자를 보존하고 진행 중 Writer의 입력이 바뀌었다고 간주하지 않는다.
- 수용 조건: 실제 STOP·UNKNOWN·승인·누적 사용량·과거 receipt를 초기화하거나 덮지 않는다. 활성 Controller/Worker와 경합하지 않고 수정 적용 경계를 명시한다. 임의 DB 수정이 정상 운영 절차가 되지 않는다.
- 추가 관측: 시각 작업이 기본5회 후 BLOCKED에 도달했다. 실제 Director→QA→Director 3세션 합동진단으로 두 확인 결함만 좁혀, attempt6·기존 이력·총60호출 상한을 유지한 한 번의 운영자 복구를 별도 metadata로 기록했다. 회의는 사용자 승인·수용을 대신하지 않으며 새 검사/독립 리뷰가 필요하다. 공식 재개 API 부재를 이러한 수동 처리의 상시 정당화로 사용하지 않는다.
- 추가 관측: `.pyc` 추적 삭제와 새 ignore 규칙이 함께 들어오자 commit_scoped의 `git add -- <전체 변경 경로>`가 이미 stage된 캐시 삭제 경로를 ignored로 거부해 COMMIT에 머물렀다. allowed 경로·실제 index tree를 확인해 정상 commit하고 기존 tree/parent 복구 계약으로 이어갔다. 중앙에서 추적 삭제·기존 staged 삭제·새 ignore를 함께 다루는 실제 Git 회귀를 추가할 후보이며 게임에서 gitops.py를 수정하지 않았다.
- 후속 관측: 제한 복구의 회귀 스크립트 타입 오류와 실제 배경 하단 경계 오판 때문에 Root가 추가 Worker 없이 좁은 수정 후 COMMIT/CHECK로 수동 전환했다. attempt8·누적54호출·60상한과 반려 원문을 보존했지만, 이러한 반복 수동 전환 역시 공식 상태 전이·복구 범위·잔여 예산 검증의 부재를 보여준다. 복구라는 이름으로 재시도 제한을 우회하는 정상 절차로 채택하지 않는다.
- 상태: PROPOSED. 공통 CLI/API 및 staging 수정 미구현.

### HV-Q-005 · 실제 렌더러와 OS 창·입력 검증의 분리

- 관측: sandbox Worker에는 GUI 세션이 없었다. 호스트 화면 잠금 상태에서도 Godot OpenGL 내부 캡처 18장은 성공했으나 OS 창 도구는 접근하지 못했다. 이후 사용자가 잠금을 해제하자 실제 창의 강화 클릭·드래그가 확인됐다.
- 제안: headless 규칙 검사, 실제 renderer fixture 캡처, OS 창 조작, 음향 청취, 사람 플레이, 실기기를 독립 관측으로 유지한다. OS 입력의 잠금 제한을 입력 없는 내부 렌더링 전체의 불가로 확대하지 않는다. 화면 잠금·권한을 자동 변경하지 않는다.
- 수용 조건: 각 검사에 실제 수행 방식·소스·환경·관측을 연결한다. Renderer 캡처만으로 OS 입력·재미·음향 PASS를 만들지 않으며, 창 입력 불가 때문에 가능한 코드·렌더링 작업을 불필요하게 반복하지 않는다.
- 후속 관측: 여러 게임이 같은 Godot bundle ID로 실행되면 창 도구가 다른 게임 창을 선택했다. 다른 게임은 조작하지 않고 고유 ID의 격리된 임시 실행본으로 구분했으나 안정적인 현재 창 조작 증거를 확보하지 못했다. 새 아트의 렌더러 캡처와 과거 소스의 클릭·드래그 증거를 합쳐 현재 OS 입력 PASS로 표시하지 않는다.
- 상태: PROPOSED. 게임 로컬 호스트 캡처 경로로 대응.

### HV-Q-006 · 독립 시각 리뷰에 실제 자료 연결

- 관측: Controller가 생성한 headless receipt만 리뷰어에게 전달되어, 호스트에서 이미 얻은 이미지가 첫 독립 리뷰에 연결되지 않았다. 보완 뒤 검토 커밋의 6상태×3화면비 18장과 소스 11개 SHA를 연결했고 리뷰어가 직접 판독했다.
- 제안: 게임 작업에 필요한 캡처를 해당 check receipt의 고정 커밋·원본 입력 SHA·이미지 SHA와 연결하고, 리뷰어가 직접 열 수 있는 안정 경로를 제공한다. 시각 판독 전에는 PENDING/NOT_MEASURED를 유지한다.
- 수용 조건: 다른 소스의 이미지·가짜 화면·존재 검사만으로 시각 PASS가 불가능하며, 리뷰어가 실제 본 범위와 못 본 범위를 남긴다. 판독 PASS 뒤에도 사용자 디자인 반려는 별도 미해결 요구로 보존한다. 소스 문서의 임시 NOT_MEASURED/실패 스냅샷을 현재 runtime 결과와 혼동하지 않게 시점·대상과 정본 조회 경로를 표시한다. 판정 뒤 문서를 다시 수정해 검토 소스를 무한 갱신하는 순환을 만들지 않는다.
- 후속 관측: 고정pin의 discuss 회의 레코드 source_commit은 실행 cwd인 main을 가리켰지만 실제 논의 입력은 다른 후속 소스의 동결 사본이었다. 게임에서 사본48파일/해시와 이미지 입력을 별도로 연결하고 main 검수로 표시하지 않았다. 중앙에서는 회의의 실행 cwd 커밋과 실제 검토 source/input을 구분하는 계약을 검토할 후보이며 현재 schema/코드는 수정하지 않았다.
- 상태: PROPOSED. 원문은 게임 runtime의 first-battle attempt 3/4 review 및 check-1 자료에 있음.

### HV-Q-007 · 환경 진단에 소진되는 제작 반복 줄이기

- 관측: 엔진 사본 실행 `-9`, 사용자 경로·에디터 디렉터리·인증서 문제 진단이 제품 구현보다 길어졌고 900초 호출 한도에 도달했다. 원본 엔진을 쓰는 호스트 진단은 임포트에 성공했다.
- 제안: 기존 설치본과 테스트 전용 저장 경로를 사용하는 작고 검증된 호스트 실행 예제를 제공한다. sandbox에서 불가능한 GUI 호출·엔진 복제·동일 환경 실험을 반복하지 않고 실제 환경 근거를 넘긴다. 설치·전역 설정·인증 복사를 하지 않는다.
- 수용 조건: 같은 환경 실패는 정해진 횟수 뒤 경로를 전환하며, 고유 저장 데이터 보존과 실패 기록을 유지한다. 게임 소스 변화 없이 테스트 행정만 늘어나는 반복을 Producer가 진단한다.
- 상태: PROPOSED. 중앙 도구 추가·하네스 버전 채택은 별도 세션에서 검토.

### HV-Q-008 · 이전 리뷰 지적의 개별 해결 추적

- 관측: growth-save attempt4 독립 리뷰가 모바일 백그라운드 복귀 보상 누락과 문서 불일치를 지적했다. attempt5에서 문서는 수정했으나 복귀 로직은 그대로였고 새 독립 리뷰는 PASS를 반환했다. Producer가 미해결 복귀 결함을 별도 수정 대상으로 보존했다.
- 제안: 새 리뷰에 직전 finding별 해결 커밋·반증·잔여 상태를 전달하고, 일부 수정이나 새 리뷰 PASS로 이전의 확인된 결함을 자동 소거하지 않는다. 원래 검토 커밋과 이후 코드의 실제 변경을 대조한다.
- 수용 조건: 이전 지적별 해결 근거/명시적 반증/열린 후속 이슈가 남고, 재리뷰가 해결되지 않은 확인 결함을 누락하면 전체 수용으로 승격하지 않는다. 누적 호출·실패 기록과 사용자 요구는 그대로 유지한다.
- 상태: PROPOSED. 게임의 복귀 보상 결함은 후속 소스에 수정과 회귀를 추가했다. 최종 소스 ae8083b의 독립 재검토·통합 결과는 게임 runtime에서 별도로 조회하며 이 기록 자체가 해결 수용을 뜻하지 않는다. 중앙 실행기 변경은 미적용.


### HV-Q-009 · 실제 렌더러 fixture의 호스트 이벤트 재현성

- 관측: 시각 개선 후보 `ae8083b5467ab3f3f0e398fa5ffb82d0c1871081`의 관리 check-0에서 8,005개 제품 검사가 통과했으나 check-1 실제 렌더러는 `capture.gd:140`의 빈 발사체 배열 접근과 제작/합성 준비 실패로 종료1이었다. 같은 입력 파일의 직전 로컬 실행은 129장 생성에 성공했다. 최신 실패를 이전 성공으로 덮지 않는다.
- 자료: 게임 runtime의 `artifacts/bdffcc216c60488aad04e43cc9b183c9`(제품 검사), `artifacts/c7c5ec0cd5914182b6942a449e2bebd6`(실패 렌더러), `root-final-render/source-manifest.json`(직전 로컬 실행; 당시 dirty 파일 해시를 확인해야 하며 HEAD만으로 고정 근거가 아님).
- 추정: 이번에 추가한 실제 focus/pause 처리와 OS 창 포커스 변경이 fixture에 영향을 줄 가능성이 있다. 오류 로그만으로 원인을 확정하지 않았다. 초점·정지·재개 알림과 fixture 준비 상태의 작은 재현이 필요하다.
- 중앙 책임: 호스트 이벤트와 fixture 제어의 경계를 명시하고 같은 커밋의 실패·성공·실행환경을 연결하는 검사 절차. 게임 책임: capture.gd의 안전한 상태 준비와 실제 lifecycle 회귀는 게임에서 수정한다.
- 수용 조건: 원인을 작은 재현으로 확인하고 실제 lifecycle 제품 동작을 약화하지 않으면서 fixture의 입력을 통제한다. 단순 배열 존재 가드로 필수 발사 장면을 생략하거나 캡처 수만으로 통과시키지 않는다. 정확한 소스의 관리 검사·독립 리뷰를 다시 거쳐야 한다.
- 현재: `storybook-visuals` BLOCKED, attempt9, 누적56/60호출. 새 독립 리뷰와 main 통합·push 미실행. 추가 자동 재시도·상한 초기화 없음.
- 상태: PROPOSED. 중앙 코드·절차 채택 미실행.


### WB-IMP-010 · 호스트 후속 제작의 소유권·예산·통합 연결

- 발견: 2026-11-06 / Producer Root / storybook-visuals BLOCKED attempt9, work/living-motion 미커밋 / game main bfee10e·base ae8083b / harness17d4e6b.
- 구분·영향: WORKFLOW·HARNESS / 관리 task는 BLOCKED이고 누적59/60이나 후속 호스트 자산/문서/코드는 별도 트리에 있다. 이 결과를 새 task·새 세션이라는 이유로 관리 수용·예산 초기화로 표시할 위험.
- 근거: readonly state.sqlite tasks/calls, workflow-4915f61/before.json, 이전 final-local-source.json 및 현재 Git worktree 목록.
- 실제 대응: 기존 task·calls·control·pin 불변. 호스트 제작과 독립 자료 판독은 관리 파이프라인 결과와 분리. 독립 Experience/Art 1회가 실행되면 별도 보수적 사용 원장에 예약/결과를 남겨 관리59+호스트 독립1=60으로 합산하고 추가 모델 리뷰를 시작하지 않는다. DB에 가짜 관리 receipt를 쓰지 않는다. 최종 관리 리뷰/commit/통합은 미실행으로 남긴다.
- 제안: 중앙에서 고정 manifest의 호스트 자산/직접 판독 결과를 안전하게 접수하고 기존 attempt·전체 예산·Writer 경계를 유지한 채 후속 경로를 연결하는 공식 계약 검토. 현재 코드 수정·새 실행기 채택 없음.
- 중앙 처리: PROPOSED / NOT_SENT / 중앙 담당자 검토 및 실제 기록 커밋 연결 전.
- 게임 채택·검증: 문서와 보존·사용량 대조 적용. 공식 관리 접수/독립 수용/main 통합·push 미실행. 이 항목 기록을 BLOCKED 해제 권한으로 사용하지 않는다.

현행 추가 근거: 독립 Experience/Art의 EA-001~004(시트 경계, 무기 손 연속성, 이동 시전의 정적 발, 방향별 실행 공백)는 HV-Q-002/006의 게임 로컬 사례로 연결한다. 실제 수정·재판정은 art-direction.md에서 추적하고 중앙 문제 해결로 표시하지 않는다. 관리 DB59/60은 그대로이며 호스트 독립1회를 보수적으로 합산60으로 기록한다. 기존 원문·수정 전 보드/소스/검사 실패는 보존한다.

### HV-Q-001 현행 추가: 제작 도중 원작 기준 이탈

- 발견: 2026-11-06 사용자 「제작하면서 원작 게임을 계속 참고…지금 너무 동떨어져서」 / Root·work/living-motion / 관리 storybook-visuals BLOCKED 보존, 고정 미커밋 사본 review-source-v2(66파일)·하네스17d4e6b.
- 구분·영향: WORKFLOW / 처음 한 번의 원본 판독과 내부 디자인 논의만으로는 후속 제작의 표현 이탈을 막지 못함. 기술/프레임 개선이 진행돼도 사용자의 기준작 경험과 멀어질 수 있음.
- 실제 근거: 원작85/89/2/8과 renderer-final-v2의 첫 전투/공방/승패 직접 비교, 사용자 반려. 아트 문서의 현행 비교표 참조.
- 실제 대응: 원작 우선과 매 묶음 전후 직접 대조를 AGENTS·설계·아트에 연결. 독립 Experience/Art에게 최신 반려와 원작 비교를 현재 검토 입력으로 전달. 기존 활성 task 입력·DB·중앙 파일은 미수정.
- 제안: 공통 제작 절차에서 최초 조사뿐 아니라 대표 품질 변경마다 동일 단계 원작↔목표↔실제 비교와 기존 반려 해결 여부를 명시 입력으로 유지.
- 중앙 처리: UNVERIFIED / NOT_SENT. 게임 문서 채택: 로컬 지침 적용. 표현 개선/사용자 재수용: OPEN. 실제 기록 커밋은 정상 Controller 경계 전이므로 미커밋이며 중앙 전달 완료로 표시하지 않음.

최종 독립 판정 연결: `/root/experience_art_review` CHANGES_REQUIRED, EA-001/002 범위 한정 해소·EA-003 부분 보완·EA-004 검토 범위 확대/미검증·EA-005 연결부 미해결·EA-006 원작 이탈 중대 OPEN. 원문 `workflow-4915f61/independent-experience-art-review.md`, 게임 적용 정본 art-direction.md. 중앙 처리/기록 커밋/전달은 여전히 UNVERIFIED·미커밋·NOT_SENT다. 관측 runtime은 약3.4GiB로 초기2GiB 경고 기준을 넘었으며 보호할 이전/현재 자료를 임의 삭제하거나 보관 상한을 바꾸지 않았다.


### WB-IMP-011 · 고정 실행기 비동기 Git 시험의 선택적 index 잠금 경합

- 발견: 2026-11-07 / Root / 사이클 실행기 채택 검사 / game main bfee10e·후속 ae8083b / runner7304344.
- 구분·영향: HARNESS·검증 환경 / 전체92시험 중 test_integration_candidate_stays_fixed_while_check_runs가 격리 hv-test-*/game/.git/index.lock으로1회 실패.
- 근거: cycle-adoption-20261107/runner-tests.log. 실제 게임 저장소 lock 오류나 데이터 손상 관측은 아니다.
- 실제 대응: 원문/소스 유지, 전역 설정 없이 GIT_OPTIONAL_LOCKS=0에서 전체92시험 OK. 동일 환경을 명시 entrypoint에 국소 적용. 선택적 refresh만 억제하며 실제 수정/Controller 잠금은 유지한다.
- 제안: 중앙에서 비동기 시험의 main 진행과 선택적 Git 상태 refresh를 명시적으로 동기화/환경 고정. 현재 중앙 코드 수정 없음.
- 중앙 처리: PROPOSED / NOT_SENT. 게임 채택: 고정 바이트7304344와 선언 환경의 회귀 확인. 최초 실패를 지우거나 무조건 전체PASS로 요약하지 않음.

### WB-IMP-012 · 레거시 CLOSED task의 최초 제품 범위와 사이클 완료 근거 연결

- 발견: 2026-11-07 / Root / initial-play cycle close / main bfee10e, first-battle42b43f1·growth-save2e20be8 / runner7304344.
- 구분·영향: HARNESS / adopt-cycles는 성공하나 실제 초기 게임이 있어도 완료 제출이 제품 변경 부재로 거부되어 완료0/OPEN2.
- 근거: adoption-plan.json·adoption-receipt.json·initial-play-completion.json·initial-play-close-result.json. first-battle worker_base e09cadf→42b43f1 diff는문서/검사, growth-save b16dc16→2e20be8 diff는문서다. 게임 코드는 이미 이전 시도에서 존재한다. 현재mainbfee의 성공 통합 command receipt와 신규 제품102실패0도 보존했다.
- 실제 대응: 공식 거부/0완료 유지. cycle_base 직접수정, game/tests의 제품 위장, 무의미한 제품 주석 변경으로 통과시키지 않았다. 과거 호출/실패/시도/STOP와 task 원문은 유지했다.
- 제안: 중앙에서 검증 가능한 원래 제품 범위·Git ancestry·수용/최종HEAD 실행 근거를 명시 채택하는 공식 legacy 완료 경로 검토. 최초/최종 시도 제품 범위를 보존하는 계약과 회귀가 필요하다. 현재 중앙 코드 수정 없음.
- 관련 경계: 논의 전용 ui-design-discussion은 실제 회의가 끝나도 QUEUED work task이며 원문이 Worker/run을 금지한다. 임의 실행/완료로 고치지 않는다. 공식 종료/Writer 회수 경로가 필요하면 별도 중앙 판단 후보로 남긴다.
- 중앙 처리: PROPOSED / NOT_SENT / 기록 커밋 미발행. 게임 채택: 공식 전환만 완료, 초기 cycle close는 거부·수용 아님.

2026-11-07 전환 후 후보의 독립 재검토도 CHANGES_REQUIRED다. 원작 위계의 일부 개선과 S/SW 접합·후기 화력·공방/결과 OPEN을 art-direction.md에 취합했다. 기록 커밋/중앙 전달은 계속 미커밋·NOT_SENT다. 앞선 전체runtime3.4GiB 관측은 관리artifacts212MiB와 다른 범위이며 현재 보호값은 production-cycles.md를 따른다.

2026-11-07 aa96f24 문서 선택 채택: 사전 전달 후 연속 사이클·순차close·자료원장을 적용했다. 게임 실행기7304344는 유지, storage-audit만 고정aa 진단사본에서 read-only 실행했다. 59call receipt 경로 누락관측0/DB행불변이며 로그·영상전체검증/정리수용이아니다. docs/storage-ledger.json에 실제현재참조·owner/UNKNOWN·보존/재검토를 기록했고 삭제없음. WB-IMP-010/012의공식경로부재는 control-path-review.md로추가확인했으며 중앙구현/공식접수는미해결이다. 기록커밋미발행/NOT_SENT.

WB-IMP-010/012 공식 경로 재대조(2026-11-07): control-path-review.md는7304344의BLOCKED회수·호스트소스인수·논의task종료·legacy제품범위정정CLI부재를확인했다. official-run-boundary.json의실제run도complete=false/호출59/완료0/OPEN2,회수목록없음으로반환했다. 반환자체로제작을중단하지않고기존Root호스트입력의접합·공방/결과·성장표현을수정·검사중이다.

중앙에 필요한 계약(제안, 미구현): (a) Controller잠금·콜원결과·STOP/UNKNOWN·소스/allowed범위·원작성권을대조한기존BLOCKED작업의호스트결과인수와COMMIT/CHECK/독립REVIEW/통합경로. 시도/실패를새task나재init로초기화하지않음. (b) 실제완료논의receipt에기반한논의전용task의공식종료. (c) original제품Git범위·최종수용HEAD·현재최종실행근거를검증하는legacycycle완료근거연결. game/tests위장·무의미한제품수정·직접cycle_base/DB변경금지. 고정aa문서는문서운영채택이며이런API를게임에서구현했다고하지않음.

중앙전달주소/기록: 게임 /Users/nhn/brainspace/workspace/games/witchburst, Writer work/living-motion, 항목WB-IMP-010·012(연계HV-Q-004/009). 기록커밋은정상Controller접수부재로아직미발행/NOT_SENT. 게임세션은중앙대기열을수정하지않으며현재공통정책의중앙/게임Writer경계안에서공식처리보완을요청할필요가있다.

현행후속검증: 경험/아트최초CHANGES_REQUIRED를보존한뒤 NE82px/결과후공방3비율만POSITIVE_SCOPED로재확인했다. 실제OS입력중창변경/오프스크린캡처는HV-Q-005/007의현재사례로연결하고실제수행한강화/제작/합성/정령/재도전/드래그와미수행보스스킬을구분했다. 실제앱을닫은뒤get_app_state의자동재기동으로ProjectManager가열린것도기록하고소유bundle을정상종료·공유gui-input해제했다. 사용자디자인/재미수용·관리통합·중앙처리/기록커밋은미완료다.

## 2026-11-07 중앙 공식 복구 보완 접수 · 현재 우선 상태

WB-IMP-010/012의 중앙 접수와 공식 복구 구현은 bbf9f9c341f55a3b21e0d44850f5e6c288037cc6의 docs/handoffs/task-recovery-2026-11-07.md 및 docs/task-recovery.md로 확인했다. 위 NOT_SENT/UNVERIFIED는 당시 원문이다. 현재 중앙 처리는 RECEIVED_IMPLEMENTED이고 게임의 실제 기록 커밋 연결은 PENDING_PUBLICATION이다. ae8083b/bfee10e를 기록 커밋으로 쓰지 않는다.

게임 대응: 동일bbf 고정 실행기를 별도 채택하고 legacy 연결·논의 종결·Writer 반환 후 호스트 인수를 공식 명령으로 수행한다. 각 실제 적용/관리 수용 결과는 runtime/task-recovery-20261107 receipt를 기준으로 후속 docs 소유 정상 Controller 작업에서 확정한다. 호스트 부분 Art의 긍정 판정은 관리 수용을 대체하지 않으며 전체 디자인/EA-006은 OPEN이다. 실제 파일이 포함된 정상 Controller 커밋을 git log/show로 검증한 뒤 게임 경로·WB-IMP-010/012·커밋을 중앙 담당자에게 전달하고 중앙 대기열은 직접 수정하지 않는다.

## WB-IMP-010/012 · 이번 반환과 중앙 전달 준비

현재 작성 경로는 `/Users/nhn/.local/state/harness-v/witchburst/worktrees/reference-motion-followup/docs/improvement-queue.md`다. 게임 정본 경로 `/Users/nhn/brainspace/workspace/games/witchburst`와 기존 HV-Q-001~009/WB-IMP-010~012를 유지한다. 중앙의 공식 복구 구현 RECEIVED_IMPLEMENTED와 선행 CLOSED를 현재 receipt로 구분하되, 이 기록의 실제 커밋은 **PENDING_CONTROLLER_COMMIT**, 중앙 전달은 **NOT_SENT**다. Controller는 이 파일이 포함된 실제 커밋을 발행/확인한 뒤 게임 경로·WB-IMP-010/012·그 SHA를 중앙 담당자에게 전달한다. Worker는 가짜 SHA·중앙 수신 기록을 만들지 않는다.

이번 sandbox에서 tests/run.py는 Godot 사용자/편집기 디렉터리 접근 거부와 시스템 인증서 오류로 import 로그 검사를 실패했다(`/tmp/witchburst-reference-motion-followup-product-1/import.log`). 이후 Python 전체 진입점 검사도 14개 중3개 실패했다. `test_entrypoints.py`가 실제 엔진을 재실행한다는 것을 실행 뒤 확인했으며 추가 엔진 진단은 중단했다. HV-Q-007의 호스트 검사 인계 사례이며 제품/GPU PASS로 표시하지 않는다. 전역 설정·엔진 복제·인증서 변경·새 서비스는 수행하지 않았다.
