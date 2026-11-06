extends SceneTree
## 실제 기본 씬을 불러와 전투를 조작한다. 사람 플레이 검사는 아니다.

var failures := 0
var checks := 0
var fixture_id := 0
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

func fresh(existing_path: String = "") -> Control:
	var battle := scene.instantiate() as Control
	fixture_id += 1
	battle.save_path = existing_path if not existing_path.is_empty() else OS.get_environment("WITCHBURST_TEST_ROOT").path_join("smoke-%d.json" % fixture_id)
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
	var project_path := ProjectSettings.globalize_path("res://").simplify_path()
	if not project_path.begins_with(isolation + "/"):
		require(false, "실제 사용자 저장 경로 격리 실패: 임시 프로젝트에서만 실행한다")
		return
	require(project_path.begins_with(isolation + "/"), "임시 프로젝트 경로 격리")
	print("검사 전용 저장 루트 = ", isolation)
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
	_growth_checks()
	_save_checks()
	_muzzle_checks()
	_visual_checks()
	await _input_checks()
	print("제품 자동 검사: ", checks, "개, 실패 ", failures)
	quit(1 if failures else 0)

func _muzzle_checks() -> void:
	var battle := fresh()
	var visual: Node2D = battle.visuals
	visual.breath.pause()
	# 같은 좌표 헬퍼끼리 비교하지 않고, 원본 그림에서 판독한 포구 픽셀을
	# 실제 Sprite2D 변환으로 옮겨 그리기에 쓰는 탄·입자 좌표와 대조한다.
	for dimensions in [Vector2(540, 960), Vector2(540, 1200), Vector2(720, 960)]:
		battle.size = dimensions
		battle._layout_ui()
		for tier in range(4):
			battle.equipped = tier - 1
			for breathing in [-1.0, 0.0, 1.0]:
				visual.breath_amount = breathing
				battle.bullets.clear()
				visual.emitter_life.fill(0.0)
				battle._fire()
				visual.shot_tween.pause()
				visual.sync(0.0)
				var bullet: Dictionary = battle.bullets[0]
				var sprite: Sprite2D = visual.witch_sprite
				var pixel := Vector2(1061, 504.5) if tier == 0 else Vector2(1250, 504.5)
				var actual_tip: Vector2 = visual.to_local(sprite.to_global(pixel - sprite.texture.get_size() * 0.5))
				require(visual.kick == 1.0 and absf(sprite.rotation + 0.035 * tier) < 0.0001, "최대 반동의 회전까지 적용한 재현")
				require(actual_tip.distance_to(battle._world(battle.muzzle_position())) > 1.0, "변환 전 포구와 다른 비자명 재현")
				require(visual.projectile_position(bullet).distance_to(actual_tip) < 0.01, "세 비율·네 성장·호흡별 실제 그림 포구에서 탄 표시")
				require(visual.projectile_tail(bullet).distance_to(actual_tip) < 0.01, "비행거리 0의 꼬리는 포구에서 길이 0")
				require(visual.emitters[0].position.distance_to(actual_tip) < 0.01, "실제 그림 포구에서 발사 입자 생성")
				require(bullet.pos == battle.muzzle_position(), "표현 반동이 규칙상 발사 좌표를 바꾸지 않음")
				require(visual.shot_origins.size() == 1, "이전 사격 표현 자료 회수")
				var launch: Vector2 = bullet.pos
				battle.witch.x += 12.0
				visual.kick = 0.0
				visual.sync(0.0)
				require(visual.projectile_position(bullet).distance_to(actual_tip) < 0.01 and visual.emitters[0].position.distance_to(actual_tip) < 0.01, "발사 후 포구가 움직여도 탄·입자 출발점 유지")
				var unit: float = battle.content_width / 540.0
				var previous_length := 0.0
				for travel in [1.0, 8.0, 24.0, 48.0, 80.0]:
					bullet.pos = launch + Vector2(0, -travel)
					var head: Vector2 = visual.projectile_position(bullet)
					var tail: Vector2 = visual.projectile_tail(bullet)
					var flight := head - actual_tip
					var along: float = (tail - actual_tip).dot(flight) / flight.length_squared()
					var length := head.distance_to(tail)
					require(along >= -0.0001 and along <= 1.0001 and absf((tail - actual_tip).cross(flight)) < 0.01, "꼬리 끝은 발사 포구와 탄 머리 사이에 제한")
					require(length <= travel * unit + 0.01 and length <= (12 + tier * 12) * unit + 0.01, "꼬리가 실제 비행거리·성장별 길이 상한 준수")
					require(length + 0.01 >= previous_length, "짧은 비행에서 꼬리가 점진적으로 성장")
					previous_length = length
					var target: Dictionary = battle._enemy_by_id(bullet.target)
					var target_pos: Vector2 = target.pos
					target.pos = bullet.pos + Vector2(100, 80)
					require(visual.projectile_tail(bullet).distance_to(tail) < 0.01, "표적 방향 전환으로 꼬리가 비행 경로 밖에 생기지 않음")
					target.pos = target_pos
				require(is_equal_approx(previous_length, (12 + tier * 12) * unit), "충분히 비행하면 성장별 최대 꼬리 유지")
				bullet.pos = launch + Vector2(0, -80)
				require(visual.projectile_position(bullet).distance_to(battle._world(bullet.pos)) < 0.01, "비행 중 규칙 궤도로 합류")
				battle.witch.x -= 12.0
	battle.bullets.clear()
	visual.sync(0.0)
	require(visual.shot_origins.is_empty(), "남은 탄이 없으면 표현 자료 전체 회수")
	battle.spirit = true
	battle.total_shots = 2
	battle._fire()
	var linked: Dictionary = battle.bullets[-1]
	var linked_start: Vector2 = linked.pos
	require(linked.get("spirit", false) and visual.projectile_tail(linked) == battle._world(linked_start), "정령 연계탄도 출발점에서 꼬리 길이 0")
	linked.pos += Vector2(0, -8)
	require(visual.projectile_position(linked).distance_to(visual.projectile_tail(linked)) <= 8.0 * battle.content_width / 540.0 + 0.01, "정령 연계탄도 비행거리만큼 꼬리 성장")
	# 표현 Tween과 sync 호출 횟수가 달라도 실제 전투 궤도·피해는 같아야 한다.
	var reference := fresh()
	var animated := fresh()
	for i in range(120):
		animated.visuals.breath_amount = sin(i)
		animated.visuals.kick = float(i % 2)
		animated.visuals.sync(0.0)
		reference.advance(1.0 / 60.0)
		animated.advance(1.0 / 60.0)
	require(reference.bullets == animated.bullets and reference.enemies == animated.enemies and reference.total_hits == animated.total_hits and reference.random.state == animated.random.state, "호흡·반동·렌더 횟수가 달라도 전투 규칙 동일")
	reference.free()
	animated.free()
	battle.free()

func _visual_checks() -> void:
	# 텍스처·재질의 실제 연결과 표현 계층의 상한을 검사한다. GPU 판정은 아니다.
	var battle := fresh()
	var visual: Node2D = battle.visuals
	visual.sync(0.0)
	require(visual.background.texture.get_size() == Vector2(1052, 1495), "신규 풀밭 배경 실제 로드")
	require(is_equal_approx(visual.background.scale.x, visual.background.scale.y), "풀밭·수목 원본 종횡비 보존")
	require(visual.witch_sprite.texture.resource_path.ends_with("witch-starter.png"), "시작 마녀 그림 실제 적용")
	require(visual.witch_sprite.texture.get_image().get_format() == Image.FORMAT_RGBA8, "마녀 투명 텍스처 로드")
	require(visual.enemy_sprites.size() == 1 and visual.seed_texture.atlas == visual.CREATURES, "저주씨앗 아틀라스 실제 적용")
	var enemy: Dictionary = battle.enemies[0]
	var sprite: Sprite2D = visual.enemy_sprites[enemy.id]
	battle._hit(enemy, 1.0)
	visual.sync(0.0)
	require(sprite.material is ShaderMaterial and sprite.material.shader == visual.FLASH and sprite.material.get_shader_parameter("flash") == 1.0, "피격 흰색 셰이더 실제 연결·값")
	var snapshot: Dictionary = battle.progress_data()
	var shots: int = battle.total_shots
	var random_state: int = battle.random.state
	for i in range(30):
		visual.sync(1.0 / 60.0)
	require(battle.progress_data() == snapshot and battle.total_shots == shots and battle.random.state == random_state, "렌더링이 성장·저장·전투 난수에 영향 없음")
	battle._fire()
	require(battle.bullets[-1].pos == battle.muzzle_position(), "초기 규칙 발사 좌표 보존")
	battle.equipped = 2
	battle.spirit = true
	visual.sync(0.0)
	require(visual.witch_sprite.texture.resource_path.ends_with("witch-cannon.png") and visual.spirit_sprite.visible, "성장 마법포·여우정령 실제 적용")
	require(visual.spirit_sprite.material.shader == visual.PULSE and visual.spirit_sprite.material.get_shader_parameter("pulse") > 0.0, "정령 맥동 셰이더 실제 적용")
	battle._fire()
	require(battle.bullets[-1].pos == battle.muzzle_position() and battle.bullets[-1].tier == 3, "성장 규칙 발사 좌표·단계 보존")
	var baseline: int = visual.get_child_count()
	for i in range(100):
		battle._burst(battle.witch, battle.MINT, 40)
	require(visual.get_child_count() == baseline and visual.emitters.size() == 12, "입자 100회에도 12슬롯 재사용·노드 증가 없음")
	require(visual.emitters.all(func(emitter: CPUParticles2D) -> bool: return emitter.amount <= 18 and emitter.one_shot), "동시 입자 상한 216·일회 방출")
	require(visual.emitters.all(func(emitter: CPUParticles2D) -> bool: return visual.z_index + emitter.z_index < battle.workshop.z_index), "보상 입자가 공방·결과 창과 강화 UI를 덮지 않음")
	battle.advance(1.0)
	visual.sync(1.0)
	battle._burst(battle.witch, battle.MINT, 25)
	require(visual.emitter_life.any(func(until: float) -> bool: return until > battle.elapsed), "만료 후 입자 슬롯 재사용")
	battle.enemies.clear()
	visual.sync(0.0)
	require(visual.enemy_sprites.is_empty() and visual.get_child_count() < baseline, "정화된 적 스프라이트 회수")
	battle._start_boss()
	visual.sync(0.0)
	sprite = visual.enemy_sprites[battle.enemies[0].id]
	require(sprite.texture == visual.boss_texture and sprite.material.shader == visual.FLASH, "큰 가시왕 그림·피격 재질 적용")
	battle._refresh_ui()
	require(battle.upgrades.attack.get("value") == str(roundi(battle.attack_damage())) and battle.upgrades.speed.get("value").ends_with("/초"), "강화 카드 현재 능력값 표시")
	battle.free()

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
	battle.workshop_button.pressed.emit()
	var paused_kills: int = battle.kills
	var paused_shots: int = battle.total_shots
	seconds(battle, 3)
	require(battle.workshop.visible and battle.kills == paused_kills and battle.total_shots == paused_shots, "장비 메뉴 열기·전투 일시정지")
	battle.workshop.get_node("닫기").pressed.emit()
	require(not battle.workshop.visible, "장비 메뉴 닫고 전투 복귀")
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

func _growth_checks() -> void:
	var battle := fresh()
	require(battle.draw_tool() == -1 and not battle.craft_tool() and not battle.merge_tool(0), "재화·재료·동급 장비 부족 거부")
	require(not battle.equip_tool(2) and not battle.unlock_spirit() and not battle.rebirth(), "미소유 장착·정령·보스 전 환생 거부")
	# 실제 RNG의 확률 구간 양끝을 시드로 찾아 실제 뽑기 함수에 통과시킨다.
	var rng := RandomNumberGenerator.new()
	for boundary in [1, 80, 81, 98, 99, 100]:
		var seed_value := 0
		while true:
			rng.seed = seed_value
			if rng.randi_range(1, 100) == boundary:
				break
			seed_value += 1
		battle.coins = 120
		battle.growth_random.seed = seed_value
		var previous: Array = battle.inventory.duplicate()
		var expected := 0 if boundary <= 80 else (1 if boundary <= 98 else 2)
		require(battle.draw_tool() == expected and battle.inventory[expected] == previous[expected] + 1 and battle.coins == 108, "실제 뽑기 확률 경계 %d·장비 획득·가격" % boundary)
	battle.free()
	battle = fresh()
	battle.materials = 10
	require(battle.craft_tool() and battle.craft_tool() and battle.materials == 4 and battle.inventory == [2, 0, 0], "정화 재료 6으로 실제 장비 2개 제작")
	var damage: float = battle.attack_damage()
	var small: int = battle.power_tier()
	require(battle.merge_tool(0) and battle.inventory == [0, 1, 0] and battle.equipped == 1, "동급 2개 소모·상위 1개 자동 장착")
	require(battle.attack_damage() > damage and battle.power_tier() > small and battle.projectile_radius(battle.power_tier()) > battle.projectile_radius(small), "합성 장비가 화력·외형·발사체 크기에 반영")
	require(not battle.merge_tool(-1) and not battle.merge_tool(2) and not battle.merge_tool(0), "잘못된 등급·최대 등급·재료 없는 합성 거부")
	require(battle.equip_tool(-1), "기본 지팡이 장착")
	damage = battle.attack_damage()
	battle.equip_tool(1)
	require(battle.attack_damage() > damage, "장착 변경이 공격 배율에 반영")
	battle._fire()
	require(battle.bullets[-1].damage == battle.attack_damage() and battle.bullets[-1].tier == battle.power_tier(), "실제 전투 발사체에 장착 공격·외형 전달")
	var enemy: Dictionary = battle.enemies[0]
	var hp: float = enemy.hp
	seconds(battle, 0.7)
	require(enemy.hp < hp, "장비 발사체 이동·실제 적 피해")
	require(battle.unlock_spirit() and battle.materials == 0 and not battle.unlock_spirit(), "정령 잎4 소모·중복 해금 거부")
	var linked: int = battle.spirit_shots
	for i in range(3):
		battle._fire()
	require(battle.spirit_shots == linked + 1 and battle.bullets.any(func(b: Dictionary) -> bool: return b.get("spirit", false) and is_equal_approx(b.damage, battle.attack_damage() * 0.65)), "정령 매 3발 연계탄 실제 생성·65% 피해")
	battle.free()
	# 첫 플레이 전체 경로: 재화 주입 없이 제작·합성·뽑기·정령·보스·환생.
	battle = fresh()
	battle.growth_random.seed = 725194
	var drawn := false
	var crafted := 0
	var merged := false
	var simulated := 0.0
	while battle.phase != battle.Phase.WON and simulated < 240:
		if not battle.spirit and battle.materials >= 4:
			battle.unlock_spirit()
		if not merged and battle.inventory[0] < 2 and battle.materials >= 3:
			if battle.craft_tool():
				crafted += 1
		if not merged and battle.inventory[0] >= 2:
			merged = battle.merge_tool(0)
		if not drawn and battle.coins >= battle.DRAW_COST:
			battle.draw_tool()
			drawn = true
		if battle.levels.attack < 4:
			battle.buy_upgrade("attack")
		else:
			battle.buy_upgrade("speed")
		if battle.phase == battle.Phase.LOST:
			battle.restart_battle()
		battle.advance(1.0 / 30)
		simulated += 1.0 / 30
	require(drawn and crafted > 0 and merged and battle.spirit and battle.equipped >= 1 and battle.phase == battle.Phase.WON and battle.boss_cleared, "자연 보상만으로 뽑기·제작·합성·정령·보스 첫 승리")
	var owner: String = battle.local_owner_id
	var progress_path: String = battle.save_path
	battle.pending_coins = 10
	require(battle.rebirth(), "첫 보스 뒤 환생")
	require(battle.coins == 0 and battle.materials == 0 and battle.levels == {"attack": 0, "speed": 0, "yield": 0} and battle.inventory == [0, 0, 0] and battle.equipped == -1 and battle.pending_coins == 0 and not battle.boss_cleared, "환생 별빛·재료·강화·장비·미수령 보상·승리 자격 초기화")
	require(battle.spirit and battle.rebirths == 1 and battle.local_owner_id == owner and battle.phase == battle.Phase.FOREST and battle.kills == 0 and is_equal_approx(battle.attack_damage(), 7.5), "환생 정령·소유자 보존·영구 공격25%·첫 전투 재시작")
	require(not battle.rebirth(), "승리 자격 소모 후 중복 환생 거부")
	battle.free()
	battle = fresh(progress_path)
	require(battle.rebirths == 1 and battle.spirit and battle.local_owner_id == owner and battle.inventory == [0, 0, 0] and battle.levels.attack == 0, "환생 후 새 씬의 실제 파일 reload도 보존·초기화 동일")
	print("성장 루프 자연 첫 승리·환생: ", snappedf(simulated, 0.1), " 시뮬레이션 초 (사람 재미 NOT_MEASURED)")
	battle.free()

func _save_checks() -> void:
	var battle := fresh()
	var filename: String = battle.save_path
	battle.coins = 151
	battle.materials = 19
	battle.craft_tool()
	battle.unlock_spirit()
	battle.buy_upgrade("attack")
	var state: Dictionary = battle.progress_data()
	require(battle.save_progress(), "실제 JSON 원자 저장 성공")
	require(FileAccess.file_exists(filename) and FileAccess.file_exists(filename + ".bak") and not FileAccess.file_exists(filename + ".tmp"), "실제 파일·최신 백업 생성·임시 파일 교체")
	battle.free()
	battle = fresh(filename)
	require(battle.coins == state.coins and battle.materials == state.materials and battle.levels == state.levels and battle.inventory == state.inventory and battle.equipped == state.equipped and battle.spirit == state.spirit and battle.local_owner_id == state.local_owner_id, "메모리 공유 없는 새 씬 JSON reload")
	var store = battle.store
	# 실제 게임이 사용하는 저장 클래스의 디스크 로드·보상 기준을 조작한다.
	state = battle.progress_data()
	state.reward_cursor = 100000
	state.saved_at = 100000
	state.pending_coins = 0
	state.rebirths = 0
	require(store.write(state), "오프라인 파일 기준 fixture 저장")
	var loaded: Dictionary = store.load_progress(100000 + 86400 * 3)
	require(loaded.pending_coins == 2880 and loaded.reward_cursor == 100000 + 86400 * 3, "오프라인 3일도 최대24시간·분당2 별빛")
	loaded = store.load_progress(100000 + 86400 * 3)
	require(loaded.pending_coins == 2880, "같은 시각 중복 파일 로드 보상 추가 없음")
	loaded = store.load_progress(100000 + 86400 * 4)
	require(loaded.pending_coins == 2880, "미수령 보상을 남긴 재접속도 누적24시간 상한")
	battle._apply_progress(loaded)
	var coins_before: int = battle.coins
	require(battle.claim_offline() and battle.coins == coins_before + 2880 and not battle.claim_offline(), "수령은 한 번만·실제 저장 확정")
	battle._load_progress()
	require(battle.pending_coins == 0 and battle.coins == coins_before + 2880, "수령 뒤 reload 재지급 없음")
	# 종료 저장으로 기준이 전진한 뒤 짧은 재접속을 반복해도 보상 없음.
	state.reward_cursor = 100000
	state.saved_at = 100000
	store.write(state)
	for timestamp in [99999, -100, 100020, 100040, 100059]:
		loaded = store.load_progress(timestamp)
		require(loaded.pending_coins == 0, "음수·시간 역행·짧은 재접속 보상 없음: %d" % timestamp)
	state.reward_cursor = 500000
	state.saved_at = 500000
	store.write(state)
	loaded = store.load_progress(100000)
	require(loaded.pending_coins == 0 and loaded.reward_cursor == 500000, "미래 저장시계 기준 후퇴·즉시 보상 금지")
	loaded = store.load_progress(500060)
	require(loaded.pending_coins == 2, "미래 기준을 실제로 지나면 새 구간만 지급")
	battle._apply_progress(loaded)
	battle.save_progress(500120)
	loaded = store.load_progress(500140)
	require(loaded.pending_coins == 2, "종료 저장 시점 이전 활성 구간을 오프라인으로 재산정하지 않음")
	var broken := FileAccess.open(filename, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	loaded = store.load_progress(600000)
	require(store.recovered and store.valid(loaded) and loaded.local_owner_id == state.local_owner_id and loaded.pending_coins == 0, "불량 JSON 최신 백업 복구·보상 재발행 금지")
	var invalid: Dictionary = loaded.duplicate(true)
	invalid.inventory = [1, -1, 0]
	require(not store.valid(invalid) and not store.write(invalid), "음수 장비 저장 거부")
	invalid = loaded.duplicate(true)
	invalid.levels.attack = "문자"
	require(not store.valid(invalid), "잘못된 필드 타입 거부")
	invalid = loaded.duplicate(true)
	invalid.schema_version = 999
	require(not store.valid(invalid), "미지원 schema version 거부")
	# 디렉터리가 없는 테스트 전용 경로로 저장 실패를 재현한다.
	battle._apply_progress(loaded)
	battle.pending_coins = 12
	coins_before = battle.coins
	store.path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("missing/progress.json")
	require(not battle.claim_offline() and battle.pending_coins == 12 and battle.coins == coins_before, "저장 실패 시 수령·재화 변경 롤백")
	battle.materials = 10
	var previous: Array = battle.inventory.duplicate()
	require(not battle.craft_tool() and battle.materials == 10 and battle.inventory == previous, "저장 실패 시 제작 비용·장비 롤백")
	store.path = filename
	# 양쪽 파일이 불량이면 새 로컬 진행으로 복구하고 원문을 보존한다.
	for target in [filename, filename + ".bak"]:
		var invalid_file := FileAccess.open(target, FileAccess.WRITE)
		invalid_file.store_string("not-json")
		invalid_file.close()
	battle.free()
	battle = fresh(filename)
	require(battle.coins == 0 and battle.rebirths == 0 and battle.store.valid(battle.progress_data()), "주·백업 모두 불량이어도 새 진행 복구")
	require(Array(DirAccess.get_files_at(filename.get_base_dir())).any(func(entry: String) -> bool: return entry.begins_with(filename.get_file() + ".invalid-")), "불량 저장 원문 별도 보존")
	battle.free()
