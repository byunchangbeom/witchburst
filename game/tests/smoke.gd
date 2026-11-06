extends SceneTree
## 실제 기본 씬을 불러와 전투를 조작한다. 사람 플레이 검사는 아니다.

var failures := 0
var checks := 0
var scene: PackedScene

func _initialize() -> void:
	_run.call_deferred()

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		quit(1)
	assert(condition, message)

func fresh() -> Control:
	var battle := scene.instantiate() as Control
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	return battle

func seconds(battle: Control, duration: float, fps: float = 60.0) -> void:
	for i in range(int(round(duration * fps))):
		battle.advance(1.0 / fps)
	battle._refresh_ui()

func until_phase(battle: Control, target: int, limit: float) -> bool:
	for i in range(int(limit * 60)):
		if battle.phase == target:
			return true
		battle.advance(1.0 / 60.0)
	return battle.phase == target

func _run_isolated() -> void:
	# Controller의 Godot 직접 실행도 같은 격리 실행기를 거친다.
	# 여기서는 씬을 로드하거나 user://에 진행·검사 파일을 쓰지 않는다.
	var runner := ProjectSettings.globalize_path("res://../tests/run.py").simplify_path()
	if not FileAccess.file_exists(runner):
		push_error("FAIL: 격리 실행기를 찾을 수 없다: " + runner)
		quit(1)
		return
	print("Godot 직접 검사 → 임시 프로젝트·사용자 경로에서 다시 실행")
	var output: Array = []
	var status := OS.execute("python3", PackedStringArray([runner, "--engine", OS.get_executable_path()]), output, true)
	for line in output:
		print(line)
	if status != 0:
		push_error("FAIL: 격리 검사 실행기 종료 코드 %d" % status)
	quit(0 if status == 0 else 1)

func _run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	var isolation := OS.get_environment("WITCHBURST_TEST_ROOT")
	if isolation.is_empty():
		_run_isolated()
		return
	require(not isolation.is_empty(), "검사는 tests/run.py의 격리 경로가 필요하다")
	var actual_user := OS.get_user_data_dir()
	if not actual_user.is_absolute_path():
		actual_user = ProjectSettings.globalize_path("res://").path_join(actual_user)
	actual_user = actual_user.simplify_path()
	if not actual_user.begins_with(isolation + "/"):
		require(false, "실제 사용자 저장 경로 격리 실패: 쓰기를 중단한다")
		return
	require(actual_user.begins_with(isolation + "/"), "실제 사용자 저장 경로 격리")
	var marker := FileAccess.open("user://isolation.txt", FileAccess.WRITE)
	require(marker != null, "격리 저장 경로 쓰기 가능")
	if marker:
		marker.store_string("자동 검사 전용")
		marker.close()
	print("격리 user:// = ", actual_user)
	scene = load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	require(scene != null, "기본 씬 실제 로드")
	var battle := fresh()
	require(battle.phase == battle.Phase.FOREST and battle.enemies.size() == 1, "첫 화면부터 숲 전투")
	require(not battle.buy_upgrade("attack"), "재화 부족 강화 거부")
	require(not battle.cast_skill(), "보스 전 스킬 거부")
	var start: Vector2 = battle.witch
	seconds(battle, 0.1)
	require(battle.total_shots > 0 and battle.bullets.size() > 0, "발사체 실제 생성")
	var first_target: Dictionary = battle._enemy_by_id(battle.bullets[0].target)
	seconds(battle, 1.0)
	require(battle.total_hits > 0 and first_target.hp < first_target.max_hp, "발사체 이동 뒤 조준한 적 적중·피해")
	seconds(battle, 7.0)
	require(battle.kills >= 1 and battle.coins > 0 and battle.materials > 0, "파괴 뒤 재화와 재료 지급")
	require(battle.witch.distance_to(start) > 5.0, "무입력 자동 이동")
	var old_damage: float = battle.attack_damage()
	var old_coins: int = battle.coins
	var price: int = battle.upgrade_cost("attack")
	require(battle.buy_upgrade("attack"), "실제 획득 재화로 공격 강화")
	require(battle.attack_damage() > old_damage and battle.coins == old_coins - price, "공격 배율·가격 차감")
	# 수치 경계 검사는 충분한 재화 fixture를 사용한다. 승리 검사는 아래 자연 보상 루프다.
	battle.coins = 1000
	var old_interval: float = battle.shot_interval()
	require(battle.buy_upgrade("speed") and battle.shot_interval() < old_interval, "사격 속도 강화")
	var old_yield: int = battle.reward_amount()
	require(battle.buy_upgrade("yield") and battle.reward_amount() > old_yield, "획득량 강화 수치")
	var before_reward: int = battle.total_rewards
	var before_kills: int = battle.kills
	for i in range(600):
		battle.advance(1.0 / 60.0)
		if battle.kills > before_kills:
			break
	require(battle.total_rewards - before_reward == battle.reward_amount(), "획득량 강화 후 실제 지급")
	require(battle.buy_upgrade("attack") and battle.power_tier() == 1, "공격 2단계 대형 마도구")
	battle.buy_upgrade("attack")
	battle.buy_upgrade("attack")
	require(battle.power_tier() == 2, "공격 4단계 거대 마도구·정령 시각 상태")
	battle.free()
	# 저성장 무입력 경로: 숲 진행 → 실제 보스 피해 → 시간초과 → UI 재시도.
	battle = fresh()
	require(until_phase(battle, battle.Phase.BOSS, 100.0), "자동 사격으로 숲 12마리 정화 후 보스")
	var boss_coins: int = battle.coins
	seconds(battle, 2.0)
	require(battle.boss_hp < battle.BOSS_HP and battle.boss_time < battle.BOSS_LIMIT, "보스 HP와 제한시간 동작")
	require(until_phase(battle, battle.Phase.LOST, 30), "저성장 자동 전투 시간초과 패배")
	require(battle.boss_time == 0 and battle.boss_hp > 0, "실패 원인은 보스 시간초과")
	var shots_at_end: int = battle.total_shots
	seconds(battle, 2.0)
	require(battle.total_shots == shots_at_end and battle.coins == boss_coins, "결과 화면 뒤 공격·보상 중지")
	require(not battle.cast_skill(), "패배 후 스킬 차단")
	battle._refresh_ui()
	require(battle.result_panel.visible, "패배 결과 표시")
	battle.result_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.kills == 0 and battle.round_number == 2, "재시도 버튼 새 전투")
	require(battle.coins == boss_coins, "재시도 재화 보존")
	battle.free()
	# 수동 스킬은 보스에서만 발동하고 쿨다운 동안 중복 피해가 없다.
	battle = fresh()
	require(until_phase(battle, battle.Phase.BOSS, 100), "수동 스킬 검사 보스 도달")
	var hp: float = battle.boss_hp
	require(battle.cast_skill() and battle.boss_hp < hp, "수동 스킬 실제 피해")
	hp = battle.boss_hp
	require(not battle.cast_skill() and battle.boss_hp == hp, "쿨다운 연속 사용 거부")
	seconds(battle, 8.1)
	require(battle.cooldown == 0 and battle.cast_skill(), "경과 시간 후 스킬 재사용")
	seconds(battle, 8.1)
	battle.cast_skill()
	require(battle.phase == battle.Phase.WON, "수동 스킬 보조 승리")
	battle.free()
	# 실제 획득 재화만 사용하는 정책: 드래그·스킬 없이 강화하고 재도전해 승리.
	battle = fresh()
	var simulation_time := 0.0
	while battle.phase != battle.Phase.WON and simulation_time < 400.0:
		if battle.levels.attack < 4 and battle.coins >= battle.upgrade_cost("attack"):
			battle.buy_upgrade("attack")
		elif battle.levels.attack >= 4 and battle.levels.speed < 3:
			battle.buy_upgrade("speed")
		if battle.phase == battle.Phase.LOST:
			battle.result_button.pressed.emit()
		battle.advance(1.0 / 30.0)
		simulation_time += 1.0 / 30.0
	require(battle.phase == battle.Phase.WON and battle.skill_uses == 0, "자연 보상·강화로 수동 스킬 없이 승리")
	require(battle.materials >= 17 and battle.total_rewards > 96, "보스 정화 재화·재료 지급")
	var retained: Dictionary = battle.levels.duplicate()
	var retained_coins: int = battle.coins
	battle.result_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.levels == retained and battle.coins == retained_coins, "승리 후 다시 전투·강화 보존")
	print("자연 강화 자동 승리: 시뮬레이션 초=", snappedf(simulation_time, 0.1), " 단계=", retained)
	battle.free()
	# 서로 다른 프레임 간격에서 같은 상태·보상·발사 수로 진행한다.
	var a := fresh()
	var b := fresh()
	var c := fresh()
	seconds(a, 18, 30)
	seconds(b, 18, 144)
	for dt in [0.011, 0.089, 0.2, 0.7, 1.0, 16.0]:
		c.advance(dt)
	require(a.total_shots == b.total_shots and b.total_shots == c.total_shots, "30/144 FPS·가변 delta 발사 수 동일")
	require(a.kills == b.kills and b.kills == c.kills and a.coins == c.coins, "FPS별 처치·보상 동일")
	require(a.witch.distance_to(b.witch) < 0.01 and a.witch.distance_to(c.witch) < 0.01, "FPS별 이동 동일")
	a.free()
	b.free()
	c.free()
	a = fresh()
	b = fresh()
	b.coins = 100
	b.buy_upgrade("speed")
	seconds(a, 8)
	seconds(b, 8)
	require(b.total_shots > a.total_shots, "속도 강화가 실제 발사 횟수 증가")
	a.free()
	b.free()
	await _input_checks()
	print("제품 자동 검사: ", checks, "개, 실패 ", failures)
	quit(1 if failures else 0)

func _input_checks() -> void:
	var battle := fresh()
	await process_frame
	print("입력 검사 화면: ", root.size, " 논리=", root.get_visible_rect(), " 전투=", battle.size)
	# Viewport 입력 라우팅을 거쳐 장식 UI가 전투 드래그를 막지 않는지 검사한다.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = battle._world(Vector2(410, 560))
	touch.pressed = true
	root.push_input(touch, true)
	require(battle.dragging and battle.active_touch == 0, "터치가 전투 영역에 도달")
	seconds(battle, 0.4)
	require(battle.witch.x > 350, "터치 위치로 실제 이동")
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = battle.upgrades.attack.get_global_rect().get_center()
	touch.pressed = false
	root.push_input(touch, true)
	require(not battle.dragging, "UI 위 터치 해제도 드래그 종료")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = battle._world(Vector2(160, 560))
	mouse.pressed = true
	root.push_input(mouse, true)
	require(battle.dragging, "마우스 선택 드래그 시작")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(10, 10)
	mouse.pressed = false
	root.push_input(mouse, true)
	require(not battle.dragging, "마우스 외부 해제")
	battle.coins = 100
	battle._refresh_ui()
	var before: int = battle.levels.attack
	var center: Vector2 = battle.upgrades.attack.get_global_rect().get_center()
	for pressed in [true, false]:
		mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = center
		mouse.pressed = pressed
		root.push_input(mouse, true)
	require(battle.levels.attack == before + 1 and not battle.dragging, "강화 UI 클릭 소비·전투 드래그 비활성")
	before = battle.levels.attack
	# Input 싱글턴으로 전달하여 모바일 터치→GUI 마우스 변환도 거친다.
	for pressed in [true, false]:
		touch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * center
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame
	require(battle.levels.attack == before + 1 and not battle.dragging, "터치 탭으로 실제 강화 버튼 동작")
	for viewport_size in [Vector2i(540, 960), Vector2i(540, 1200), Vector2i(720, 960)]:
		root.content_scale_size = viewport_size
		battle.size = Vector2(viewport_size)
		battle._layout_ui()
		require(battle.upgrades.attack.position.y > battle.field_bottom and battle.upgrades["yield"].get_global_rect().end.x <= battle.size.x, "화면 비율별 강화 영역 배치")
		require(battle.skill_button.size.y >= 48 and battle.result_button.size.y >= 48, "주요 버튼 48 이상 터치 영역")
	battle.free()
