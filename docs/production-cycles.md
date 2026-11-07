# Witchburst 제작 사이클

## 2026-11-07 reference-motion-followup · 현재 작업 경계

현재 Worker의 기반은 `a724565a950179f0ce6b5dc65719497620f128a4`다. 공식 status의 선행 `storybook-visuals` CLOSED/attempt11/통합 a724565, `ui-design-discussion` DISCUSSED, 본 작업 WORK/attempt1을 확인한 뒤 수정했다. 현재 공식 집계는 완료1/OPEN1·실제70호출이며 아래 완료0/OPEN2·BLOCKED9·QUEUED·59호출 등은 당시 이력으로 보존한다. `task-recovery-20261107/initial-play-close-receipt.json`의 공식 최초 완료가 과거 거부 결과를 지우지는 않는다. 본 작업으로 사이클 수를 올리지 않는다.

`harness.lock`17d4e6b와 `harness-cycles.lock`7304344는 보존한다. 7304344 문서/전환 이력과, Controller가 이후 명시 채택한 bbf9f9c 실행기 receipt(`task-recovery-20261107/executor-adoption.json`)는 별개다. 후자의 기존 원장은 executor-adoptions.json, 진입점은 tools/hv-cycle이다. 이 Worker는 채택·상태전이·DB 수정·운영 run/close를 수행하지 않는다.

원본 Writer가 반환한 living-motion의 개선 대기열·사이클 기록·두 번째 lock·진입점·실행기 원장을 이 작업의 허용 경로로 보존 복사했다. 기존 ID/실패·STOP·호출·원 receipt는 수정하지 않는다. 제품 변경과 검증 한계는 art-direction.md의 reference-motion-followup 절에 연결한다. commit·고정 HEAD의 제품/렌더/보드/시퀀스 검사·독립 Experience/Art·통합/push/정리는 Controller 책임이다.


공통 문서 정본은 Harness V aa96f24c8f13fcb4a461d570a07aade2d70d1df0:docs/production-cycles.md다. 게임 실행기는7304344를 유지한다. 이 문서는 게임 매핑·근거·미완료만 유지한다. [설계](design.md), [아트/모션](art-direction.md), [게임 개선 대기열](improvement-queue.md)을 연결한다.

## 공식 전환

2026-11-07 사용자 명시 요청으로 고정 소스50파일을 확인했다. 기본 환경의 전체92시험 중 격리 비동기 Git 시험1건이 index.lock 경합으로 실패했다. 코드 변경/전역 설정 없이 GIT_OPTIONAL_LOCKS=0에서 전체92시험 OK였다. 원 실패와 조건을 보존했고 실제 변경/Controller 잠금은 유지한다.

공식 adopt-cycles는 Controller 잠금·59개 호출receipt/UNKNOWN 검사·SQLite backup/integrity·설정/작업 재대조·단일 transaction으로 성공했다. 백업은 runtime/backups/pre-cycles-7c127f9b66364192ba38e1bbe6d5a1ea.sqlite(0600, integrity ok)다. 과거 task 원문과 호출·실패·STOP/control·attempt는 그대로이며 공식 cycle_id/revision/scope/base 주석만 추가했다. 중앙 공유 checkout reset·재init·직접DB수정 없음.

| 사이클 | 공식 상태 | 소속/범위 |
|---|---|---|
| initial-play | OPEN revision1 | first-battle CLOSED attempt4 / growth-save CLOSED attempt5. 최초 실행 가능한 첫 지역 전투·성장·종료/재도전 |
| reference-aligned-improvement | OPEN revision2 | storybook-visuals BLOCKED attempt9 / ui-design-discussion QUEUED rev1 / 새 reference-motion-followup QUEUED rev2. 사용자 디자인·원작·UI·방향/행동·실제 논의와 EA finding 통합 |

현재 공식 완료0/OPEN2다. 기존 CLOSED task나59호출을 완료 사이클로 자동 환산하지 않는다. 최초 버전 완성1회·개선 버전 완성1회라는 집계 의미는 유지하되 실제 제출 수용 뒤에만 올린다.

초기 완료는 현재 main bfee10e 제품·독립PASS·성공 통합 검사 키와 신규 제품102실패0을 연결해 제출했다. 그러나 legacy task 최종 worker_base 이후 diff가 문서/검사뿐이라 새 검증기가 원래 제품 변경을 인식하지 못했다. 원문은 runtime/cycle-adoption-20261107/initial-play-close-result.json이다. game/tests를 제품으로 속이거나 무의미한 제품 주석 변경으로 통과시키지 않았고 DB의 cycle_base를 고치지 않았다. WB-IMP-012의 공식 legacy 근거 연결 경로가 필요하다. 게임이 이미 실행 가능하다는 사실과 이 공식 검증 공백은 별개다.

## 같은 OPEN 범위의 추가 요구

cycle extend revision2는 사용자2026-11-07 요구와 전환/완료 거부를 출처로 남겼다. 기존 두 작업의 scope는 revision1 그대로, 새 reference-motion-followup만 revision2다. 새 작업은 storybook-visuals에 의존하므로 기존 BLOCKED를 자동 해제/재시도하지 않는다. 논의 전용 ui-design-discussion의 QUEUED도 임의 CLOSED로 고치지 않는다.

기존 work/living-motion 자산/코드·66파일 고정 사본·독립 CHANGES_REQUIRED와 원작85/89/2/8을 재사용한다. 호스트의 원작 대조 자산·대표 장면 준비는 같은 OPEN 범위의 입력 제작이며 Worker 시작/성공·사이클 완료로 세지 않는다. 기존 물리/입력/판정을 보존하고 실제 자산/시선·무기·효과·전환을 검토한다. 없는 점프/마녀HP는 추가하지 않는다.

호출은 tools/hv-cycle이다. harness.lock17d4e6b를 보존하고 새 실행기7304344는 harness-cycles.lock에 별도 고정했다. 과거60호출은 cycles 모드의 중단 기준이 아니지만 비용·STOP·UNKNOWN·timeout·attempt·자료 보호는 유지한다. 이전 호스트 독립1회는 외부 원장에 남기며 DB에 가짜 receipt를 추가하지 않는다.

관리 artifacts는 약212MiB로2GiB 보호 기준 아래다. 전체 runtime 약3.4GiB는 호스트 loose 자료/후속 소스를 포함한 별도 값이다. 두 값을 혼동해 중단/상한 변경 근거로 쓰지 않는다.

전환·범위·후속 task 원문/검증은 runtime/cycle-adoption-20261107/에 보존한다. 게임 기록은 현재 후속 Writer 트리에 미커밋이다. 중앙 전달 시 게임 경로·항목ID·실제 기록 커밋을 제공하고 중앙 파일을 직접 수정하지 않는다.

## 전환 후 같은 사이클의 실제 진행

사용자 계속 제작 지시에 따라 Root host Art/Engineer가 원작85/89 재판독→실제 reference-meadow 신규 자산→캐릭터/필드 비율·민트3강화/HUD·보상 표현→Godot 제품/129화면·17실제배율 보드·400연속 프레임으로 진행했다. 이전 자산/66파일 사본/실패는 보존했다. 신규 입력52파일의 review-source.json과 독립 재검토는 runtime/cycle-adoption-20261107/reference-profile/에 보존한다. 같은 OPEN revision2의 입력 제작이며 새 완료/새 사이클이 아니다.

공식 전환 독립 검토는 SCOPED_PASS(운영/집계 안전성 범위), CA-001/002 문서 시점/전달 목록은 실제 수정 확인 뒤 RESOLVED다. 원문은 independent-cycle-adoption-review.md다. 제품/원작/모션 수용을 포함하지 않는다. 아트 재검토는 CHANGES_REQUIRED이며 EA-003/005/006·사용자 디자인 반려는 별도 미완료다. 보드17·제품8·행동29·방향시전8프레임의 직접 판독 범위와 전체 실시간 재생/OS·청취·기기 미검증을 보존한다. 실제 다음 플레이 변화/표현 목표/잔여 완료 조건은 [아트 후보](art-direction.md#2026-11-07-같은-open-사이클의-원작-대조-후보)·[설계](design.md#2026-11-07-사이클-전환-후-실제-제작)에 연결한다.

전환 후 호스트 독립 검토 원장은 runtime/cycle-adoption-20261107/external-review-ledger.json이다. 이전 host-review-budget.json은 당시60호출 경계의 이력으로 보존하고 새 DB receipt·완료 사이클로 환산하지 않는다.

## 2026-11-07 aa96f24 선택 채택과 연속 사이클 계획

착수 전에 현재 대화에서 목표·내용·순서·완료 조건·승인 경계를 마스터에게 전달했다. 정상 계획 전달에는 답변을 기다리지 않는다. 한 사이클 완료/리뷰/검사/run 구간 반환 뒤에도 승인 범위의 다음 사이클을 이어간다. 진단·접근 변경 후에도 반복되는 오류 또는 실제 마스터 판단이 필요한 부분만 보류하고 가능한 독립 작업을 계속한다. STOP·UNKNOWN·시도·원 receipt·자료 보호는 유지한다.

| 순서 / 완결 결과 | 작업과 의존성 | 완료 조건 / 승인 경계 |
|---|---|---|
| 기존 initial-play | 현재 main의 최초 게임·성장/저장 구현과 과거 제품 변경 범위/검사/통합 근거를 연결 | 공식 cycle close 수용. 현재 WB-IMP-012 제품-base 연결 거부로 OPEN 유지. 제품 위장/DB변경으로 처리하지 않음 |
| 기존 reference-aligned-improvement | 위 close 뒤 정상 관리 task 배정/실행. 원작 대조·S/SW 접합·방향/전환·후기 화력·미술/UI·공방/결과·완결 플레이. 기존 호스트 입력은 계속 보완/보존 | 필요한 독립검토·현재HEAD 제품/GPU/연속 검사·Controller commit/통합·origin/main push·정리·cycle close. 사용자 반려·미검증 별도 |
| 계획: 모바일 플레이 버전 | 위 개선 close 후 Android/iPhone 패키지·터치·복귀·화면·성능·음향. macOS/Windows/web 테스트 지원 범위 함께 확인 | 실제 빌드·기기 실행/성능 근거와 미검증 구분. 새 설치/권한이 필요하면 해당 부분만 마스터 판단. 아직 task/사이클 미등록 |
| 계획: 계정/기기 공유 버전 | 앞 버전 close 및 제공자·비용·이전/충돌 정책 결정 후 IdP·로컬 이전·원격 동기화·중복 보상/재전송 방지 | 실제 연동/복구/충돌 검증. 서비스·비용·덮기 정책은 마스터 판단 전 임의 선택하지 않음. 아직 task/사이클 미등록 |

새 지역/콘텐츠 수·최종 엔딩·공개 출시·결제는 이 계획으로 임의 승인하거나 자동 사이클화하지 않는다. 현재 승인된 본 제작 범위를 늘리지 않는다. 자료/절차 보완은 게임 사이클의 근거 관리이며 별도 제작 완료로 세지 않는다. 순서 있는 뒤 사이클의 새 task는 앞 사이클의 실제 cycle close 뒤 등록한다. 기존 두 OPEN 매핑과 기존5task는 보존한다. initial-play가 거부된 동안 다음 버전 main을 전진시키지 않고, 기존 작성권 안의 독립 호스트 입력 보완을 보존한다.

현행 문서 기준은 aa96f24다. 별도 게임 실행기 pin7304344와 원래 harness.lock17d4e6b는 그대로다. storage-audit는 aa96f24의14개 진단 소스만 고정한 진단 사본에서 읽기 전용으로 실행했으며 게임 실행기를 교체하지 않았다. DB5테이블 행 hash는 조회 전후 동일했다.

| 채택 문서 커밋 | 경로 | SHA-256 |
|---|---|---|
| aa96f24c8f13fcb4a461d570a07aade2d70d1df0 | AGENTS.md | 46df2f93dd3e202a4007ea89bbd7cf2929552c403e89bc2a8b449b205e641568 |
| aa96f24c8f13fcb4a461d570a07aade2d70d1df0 | docs/production-cycles.md | c4e5efe7e1d2646e47546b257b48018b23a9b9a0b77514a6eee741e3df995f55 |
| aa96f24c8f13fcb4a461d570a07aade2d70d1df0 | docs/game-production-workflow.md | e406eeb2df569a0181d7e53139c639696891fc495ac0dab13141b3bd8a8a4dcb |
| aa96f24c8f13fcb4a461d570a07aade2d70d1df0 | docs/data-lifecycle.md | a464af891f41bf8f884323bf49bc7166fa06582c76ff903273e47f73c52f5857 |
| aa96f24c8f13fcb4a461d570a07aade2d70d1df0 | docs/handoffs/production-workflow-update.md | 52b4f324bcc83d35303c0e465a682c7756df590b250c4be94318c46eed0854c5 |

채택: 사전 전달/연속 진행·순차 close·실제 자산/프레임/동일 소스 비교·독립 검토·게임 개선 대기열·자료 원장. 미채택: aa96f24 게임 실행기 교체, 기존 task 입력/상태 변경, 공유 checkout 변경, 재init, DB직접수정, STOP/이력 초기화. 미검증: 정상 Controller 후속 접수·최종 통합, 사용자 디자인/재미·실기기·청취. 문서 기록 커밋은 현재 미발행이며 중앙 전달 NOT_SENT다.

현재마스터사전전달뒤실제수행: Root가같은OPEN의모션연결·NE고립조각진단/수정·공방/결과·성장탄/적중을보완했다. 실제획득봇600초와선택실행자료, 네이티브GUI 강화/제작/합성/정령/재시도/드래그를추가했다. 최종53입력/product-5/GPU129+17+480+240+3/한계는 art-direction.md의aa현행후보절이정본이다. 최초관리run은complete=false/59호출/완료0·OPEN2/회수0으로반환했고반환뒤에도독립작업을계속했다. 공식회수/초기완료연결의중앙판단은현재대화에요청해대기중이며새task등록·원장수정·실행기교체로우회하지않았다.

## 공식 복구 실행기 전환 · 2026-11-07

현재 실행기는 `bbf9f9c341f55a3b21e0d44850f5e6c288037cc6` 고정 사본이다. [별도 채택 기록](executor-adoptions.json)에 원문59파일·새 회귀127 PASS·보존 lock SHA·실제 경로를 기록했다. 이전7304344 호출은 이력이며 이후 운영에 사용하지 않는다. 현재 집계는 cycles이고 재전환/재초기화하지 않는다.

착수 전 마스터에게 초기 플레이 정식 종료→논의 disposition→기존 아트 호스트 인수와 관리 재검증→등록 후속/기록 발행 순서와 완료 기준을 전달했다. 원 receipt·attempt9·실패·cycle_base·원 입력은 보존하며, 정상 반환마다 멈추지 않는다. 실제 적용 결과는 runtime/task-recovery-20261107의 공식 명령 receipt와 후속 정상 docs 작업에서 연결한다. 기술 통과와 아트/사용자 수용을 구분하고 전체 디자인은 OPEN으로 유지한다.

실제 적용: first-battle/growth-save의 link-legacy-product가 각각 APPLIED이고 initial-play 공식 cycle close가 성공했다(완료1/OPEN1). ui-design-discussion은 기존 회의에 연결된 DISCUSSED이며 제품 수용이 아니다. 근거: task-recovery-20261107/{first-battle-legacy-receipt,growth-save-legacy-receipt,initial-play-close-receipt,ui-design-discussion-receipt}.json.
