extends SceneTree
## 실제 렌더러 캡처와 headless 상태 준비 검사를 명시적으로 구분한다.

const SIZES := [Vector2i(540, 960), Vector2i(540, 1200), Vector2i(720, 960)]
var fixture_id := 0
var battle: Control
var directory: String
var verify_only := false
var records: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
	assert(condition, message)

func fresh() -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = load("res://main.tscn").instantiate()
	battle.set_script(load("res://tests/capture_battle.gd"))
	fixture_id += 1
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("capture-%d.json" % fixture_id)
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false

func until_phase(target: int, limit: float) -> void:
	var started: float = battle.visuals.motion.clock
	var steps := 0
	for i in range(int(limit * 60)):
		if battle.phase == target:
			break
		battle.advance(1.0 / 60.0)
		battle.visuals.sync(1.0 / 60.0)
		steps += 1
	require(battle.phase == target, "캡처할 전투 상태 도달 실패: %d" % target)
	require(absf(battle.visuals.motion.clock - started - steps / 60.0) < .001, "상태 도달 중 규칙·표현 시간이 함께 진행")

func advance_motion(seconds: float) -> void:
	# 실제 _process와 같은 순서로 규칙과 표현을 갱신한다.
	for frame in range(int(ceil(seconds * 60.0))):
		var dt := minf(1.0 / 60.0, seconds - frame / 60.0)
		battle.advance(dt)
		battle.visuals.sync(dt)

func _run() -> void:
	var isolation := OS.get_environment("WITCHBURST_TEST_ROOT")
	var project_path := ProjectSettings.globalize_path("res://").simplify_path()
	if isolation.is_empty() or not project_path.begins_with(isolation + "/"):
		push_error("FAIL: 격리 임시 프로젝트에서만 캡처 가능")
		quit(1)
		return
	verify_only = "--verify-stages" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify_only:
		push_error("FAIL: 캡처에는 실제 디스플레이가 필요")
		quit(1)
		return
	directory = OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	fresh()
	for character in "마녀포격단숲정화공격력사속도획득량별빛시간재도전":
		require(battle.font.has_char(character.unicode_at(0)), "한국어 글리프 fallback: " + character)
	advance_motion(0.1)
	require(battle.total_shots > 0 and not battle.bullets.is_empty(), "첫 사격 표시 준비")
	await capture_matrix("01-first", battle.Phase.FOREST)
	await capture_matrix("10-first-shot", battle.Phase.FOREST, true)
	await capture_matrix("12-first-flight", battle.Phase.FOREST, false, 80.0)
	# 외형 비교 fixture다. 자연 보상만의 승리는 smoke.gd에서 별도로 확인한다.
	battle.coins = 1000
	battle.materials = 16
	for i in range(4):
		require(battle.craft_tool(), "실제 코드 재료 제작")
	battle.toggle_workshop()
	require(not battle.merge_button.disabled, "동급 장비 합성 버튼 사용 가능")
	await capture_matrix("09-merge", battle.Phase.FOREST)
	battle.toggle_workshop()
	require(battle.merge_tool(0) and battle.merge_tool(0) and battle.merge_tool(1), "성운포까지 동급 합성")
	require(battle.unlock_spirit(), "실제 정령 해금")
	for i in range(2):
		require(battle.buy_upgrade("attack"), "공격 강화 준비")
	for i in range(3):
		require(battle.buy_upgrade("speed"), "속도 강화 준비")
	require(battle.buy_upgrade("yield"), "획득 강화 준비")
	advance_motion(0.2)
	require(battle.power_tier() == 3 and battle.bullets.any(func(b: Dictionary) -> bool: return b.tier == 3), "성장한 마도구와 큰 탄 표시 준비")
	await capture_matrix("02-grown", battle.Phase.FOREST)
	await capture_matrix("11-grown-shot", battle.Phase.FOREST, true)
	await capture_matrix("13-grown-flight", battle.Phase.FOREST, false, 80.0)
	battle.toggle_workshop()
	await capture_matrix("07-workshop", battle.Phase.FOREST)
	battle.toggle_workshop()
	until_phase(battle.Phase.BOSS, 100)
	advance_motion(0.25)
	require(battle.boss_hp > 0 and battle.boss_time < battle.BOSS_LIMIT, "보스 HP·시간 표시 준비")
	await capture_matrix("03-boss", battle.Phase.BOSS)
	await capture_matrix("14-boss-shot", battle.Phase.BOSS, true)
	await capture_matrix("15-boss-flight", battle.Phase.BOSS, false, 80.0)
	battle.skill_button.pressed.emit()
	advance_motion(0.1)
	require(battle.skill_uses == 1 and battle.cooldown > 0 and battle.skill_flash > 0, "스킬 효과·쿨다운 표시 준비")
	await capture_matrix("04-skill", battle.Phase.BOSS)
	until_phase(battle.Phase.WON, 30)
	await capture_matrix("05-won", battle.Phase.WON)
	battle.rebirth_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.round_number == 2 and battle.rebirths == 1 and battle.spirit and battle.equipped == -1, "환생 후 초기 장비·정령 보존")
	await capture_matrix("08-rebirth", battle.Phase.FOREST)
	fresh()
	until_phase(battle.Phase.LOST, 150)
	await capture_matrix("06-lost", battle.Phase.LOST)
	battle.result_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.round_number == 2, "패배 후 재도전")
	require(records.size() == 45, "기존 15상태 × 3비율 캡처 행렬 보존")
	await capture_party()
	require(records.size() == 129, "기존45 + 두 무기 × 드래그14상태 × 3비율 완성")
	var unique := {}
	for item in records:
		require(not unique.has(item.path), "드래그 행렬 중복·누락 거부")
		unique[item.path] = true
	var manifest := {"display_server": DisplayServer.get_name(), "captures": records,
		"visual_review": "NOT_MEASURED", "human_play": "NOT_MEASURED",
		"fixture": "성장 비교는 별빛1000·잎16 주입 후 실제 제작·합성·정령 해금. 발사·비행 비교는 _fire 직접 호출 후 반동·호흡1 고정, 비행은 규칙 탄을 표적 쪽으로80단위 이동한 표현 fixture; 나머지는 전투 시뮬레이션"}
	var filename := "capture-stages.json" if verify_only else "capture-manifest.json"
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	require(file != null, "상태 기록 저장")
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("캡처 상태 준비 검사 완료 (PNG 없음)." if verify_only else "실제 렌더러 PNG 129개 저장. 독립 시각 판독은 별도 필요.")
	battle.free()
	quit(0)

func capture_matrix(stage: String, phase: int, launch: bool = false, flight: float = 0.0) -> void:
	if phase in [battle.Phase.WON,battle.Phase.LOST]:
		advance_motion(.5)
	for dimensions in SIZES:
		root.size = dimensions
		# 창 크기와 stretch가 적용된 뒤 레이아웃을 읽는다.
		await process_frame
		await process_frame
		battle._layout_ui()
		if launch or flight > 0.0:
			# 이동 전, 최대 반동·호흡 직후의 한 프레임을 세 비율에서 고정한다.
			battle.visuals.breath.pause()
			battle.visuals.breath_amount = 1.0
			battle.bullets.clear()
			battle.visuals.emitter_life.fill(0.0)
			for emitter in battle.visuals.emitters:
				emitter.emitting = false
			battle._fire()
			battle.visuals.shot_tween.pause()
			var bullet: Dictionary = battle.bullets[0]
			var target: Dictionary = battle._enemy_by_id(bullet.target)
			bullet.pos = bullet.pos.move_toward(target.pos, flight)
		battle._refresh_ui()
		battle.visuals.sync(0.0)
		require(battle.phase == phase, "캡처 상태 일치: " + stage)
		require(battle.result_panel.visible == (phase == battle.Phase.WON or phase == battle.Phase.LOST), "결과 창 표시 일치")
		var viewport := Rect2(Vector2.ZERO, battle.size)
		for control in [battle.title_label, battle.status_label, battle.wallet_label, battle.hint_label,
			battle.skill_button, battle.stats_label, battle.footer_label,
			battle.workshop_button, battle.upgrades.attack, battle.upgrades.speed, battle.upgrades.yield]:
			require(viewport.encloses(control.get_rect()), "화면 내 UI 배치: " + stage)
		require(battle.visuals.witch_sprite.texture != null and battle.visuals.background.texture != null, "실제 그림 연결")
		require(battle.visuals.witch_sprite.material is ShaderMaterial and battle.visuals.spirit_sprite.material is ShaderMaterial, "실제 마법 재질 연결")
		if battle.workshop.visible:
			require(viewport.encloses(battle.workshop.get_rect()), "장비 메뉴 화면 내 배치")
			var menu_rect := Rect2(Vector2.ZERO, battle.workshop.size)
			for control in battle.workshop.get_children():
				require(menu_rect.encloses(control.get_rect()), "장비 메뉴 내부 컨트롤 배치")
		if battle.result_panel.visible:
			require(viewport.encloses(battle.result_panel.get_rect()), "화면 내 결과 창 배치")
			var panel_rect := Rect2(Vector2.ZERO, battle.result_panel.size)
			for control in [battle.result_title, battle.result_text, battle.result_button, battle.rebirth_button]:
				if not control.visible:
					continue
				require(panel_rect.encloses(control.get_rect()), "결과 창 내부 텍스트·버튼 배치")
		var filename := "%s-%dx%d.png" % [stage, dimensions.x, dimensions.y]
		var item := {"path": filename, "stage": stage, "size": [dimensions.x, dimensions.y],
			"motion_clock": battle.visuals.motion.clock,
			"salvos": battle.visuals.salvos.size(), "reward_bursts": battle.visuals.reward_bursts.size(),
			"equipped": battle.equipped, "spirit": battle.spirit, "rebirths": battle.rebirths,
			"phase": phase, "attack_level": battle.levels.attack, "power_tier": battle.power_tier(),
			"shots": battle.total_shots, "hits": battle.total_hits, "rewards": battle.total_rewards,
			"boss_hp": battle.boss_hp, "boss_time": battle.boss_time,
			"status": battle.status_label.text, "skill": battle.skill_button.text,
			"witch_texture": battle.visuals.witch_sprite.texture.resource_path,
			"enemy_sprites": battle.visuals.enemy_sprites.size(),
			"emitters": battle.visuals.emitters.size(), "shaders": ["hit_flash", "magic_pulse"],
			"font": battle.font.get_font_name(), "logical_size": [battle.size.x, battle.size.y]}
		if launch or flight > 0.0:
			var sprite: Sprite2D = battle.visuals.witch_sprite
			var pixel := Vector2(1061, 504.5) if battle.power_tier() == 0 else Vector2(1250, 504.5)
			var muzzle: Vector2 = preload("res://tests/pose_probe.gd").new().tip(battle.visuals)
			var projectile: Vector2 = battle.visuals.projectile_position(battle.bullets[0])
			var tail: Vector2 = battle.visuals.projectile_tail(battle.bullets[0])
			var emitter: Vector2 = battle.visuals.emitters[0].position
			require(muzzle.distance_to(emitter) < 0.01, "실제 그림·입자 포구 일치")
			if launch:
				require(muzzle.distance_to(projectile) < 0.01 and muzzle.distance_to(tail) < 0.01, "발사 직후 탄·꼬리는 포구에 일치")
			var back_pixel := Vector2(920, 664.5) if battle.power_tier() == 0 else Vector2(800, 699.5)
			var back: Vector2 = preload("res://tests/pose_probe.gd").new().back(battle.visuals)
			var bullet: Dictionary = battle.bullets[0]
			var saved: Vector2 = bullet.pos
			var origin: Vector2 = battle.visuals.shot_origins[0].start
			bullet.pos = origin + Vector2(0, -8)
			var initial: Vector2 = battle.visuals.projectile_position(bullet)
			bullet.pos = saved
			var axis := (muzzle - back).normalized()
			require((initial - muzzle).normalized().dot(axis) > 0.9999, "원본 포신 축과 초기 비행 방향 일치")
			require(battle.visuals.kick == 1.0, "최대 반동 프레임 고정")
			item["shot_alignment"] = {"sprite_muzzle": [muzzle.x, muzzle.y],
				"projectile": [projectile.x, projectile.y], "tail": [tail.x, tail.y], "emitter": [emitter.x, emitter.y],
				"kick": battle.visuals.kick, "breath": battle.visuals.breath_amount,
				"sprite_breech": [back.x, back.y], "initial_projectile": [initial.x, initial.y], "travel": flight}
		item["terrain"] = []
		for enemy in battle.enemies:
			var shadow: Sprite2D = battle.visuals.enemy_shadows[enemy.id]
			var foot: Vector2 = battle.visuals.background.to_local(shadow.global_position) + battle.visuals.MEADOW.get_size() * 0.5
			var half_width: float = 32 * shadow.scale.x / battle.visuals.background.scale.x
			require(foot.y > 650.0 - (foot.x - half_width) * 0.5 and foot.y < 1480.0 - (foot.x + half_width) * 0.5, "실제 발밑 그림자가 원본 풀밭 영역에 놓임")
			item["terrain"].append({"foot": [foot.x, foot.y], "shadow_half_width": half_width})
		if not verify_only:
			battle.queue_redraw()
			await process_frame
			# 창 가림/크기 전환 때 자동 draw 신호를 무기한 기다리지 않는다.
			# 실제 GPU 프레임을 동기 생성하며 PNG 치수·상태 검증은 그대로 유지한다.
			RenderingServer.force_draw(false)
			var rendered := root.get_texture().get_image()
			require(rendered != null and rendered.get_size() == dimensions, "실제 캡처 치수: " + filename)
			require(rendered.get_pixel(0, 0) != rendered.get_pixel(dimensions.x / 2, dimensions.y / 2), "단색 빈 화면 거부")
			require(rendered.save_png(directory.path_join(filename)) == OK, "PNG 저장: " + filename)
			print("캡처: ", filename)
		records.append(item)
	if launch or flight > 0.0:
		battle.visuals.breath.play()
		battle.visuals.shot_tween.play()

func capture_party() -> void:
	# 기존 45장을 보존한다. 제품 드래그·이동으로 준비한 별도 지형 행렬이다.
	var probe := preload("res://tests/party_probe.gd").new()
	var cases := ["default", "top-left", "top-right", "bottom-left", "bottom-right",
		"edge-top", "edge-right", "edge-bottom", "edge-left", "counterexample", "enter", "exit", "moving", "return"]
	var targets := [Vector2(270, 625), Vector2(65, 490), Vector2(475, 490), Vector2(65, 660), Vector2(475, 660),
		Vector2(270, 490), Vector2(475, 575), Vector2(270, 660), Vector2(65, 575), Vector2(440, 660),
		Vector2(270, 490.1), Vector2(270, 489.9), Vector2(475, 660), Vector2(440, 660)]
	for dimensions in SIZES:
		root.size = dimensions
		await process_frame
		await process_frame
		for equipped in [-1, 2]:
			for index in range(cases.size()):
				fresh()
				battle._layout_ui()
				battle.equipped = equipped
				battle.spirit = true
				battle.shot_clock = 1000.0
				battle.visuals.breath.pause()
				battle.visuals.breath_amount = 1.0 if index % 2 == 0 else -1.0
				battle.elapsed = PI / 6 if index % 2 == 0 else PI / 2
				if cases[index] != "default":
					battle.dragging = true
					battle._drag_position(battle._world(targets[index]))
					advance_motion(0.8)
				if cases[index] == "return":
					battle.dragging = false
					advance_motion(4.0)
					require(battle.manual_grace == 0.0 and battle.witch.distance_to(targets[index]) > 20, "해제 후 실제 자동 이동")
				if cases[index] == "moving":
					battle._drag_position(battle._world(Vector2(65, 490)))
					advance_motion(0.1)
				battle.total_shots = 2
				battle.bullets.clear()
				battle.visuals.emitter_life.fill(0.0)
				battle._fire()
				battle.visuals.shot_tween.pause()
				battle.visuals.sync(0.0)
				if cases[index] in ["moving", "return"]:
					require(battle.visuals.motion.moving and battle.visuals.motion.legs.visible and battle.visuals.motion.pose_key.ends_with("-moving"), "실제 보행·분리 하체의 이동 발사 자세 활성화")
				var sprite: Sprite2D = battle.visuals.witch_sprite
				var tip := Vector2(1061, 504.5) if equipped == -1 else Vector2(1250, 504.5)
				var muzzle: Vector2 = preload("res://tests/pose_probe.gd").new().tip(battle.visuals)
				var spirit_pixel: Vector2 = Vector2(420, 340) - battle.visuals.spirit_sprite.texture.get_size() * 0.5
				var spirit_tip: Vector2 = preload("res://tests/pose_probe.gd").new().spirit_tip(battle.visuals)
				var main: Dictionary = battle.bullets[0]
				var linked: Dictionary = battle.bullets[1]
				var launch: Vector2 = battle.visuals.projectile_position(main)
				var linked_launch: Vector2 = battle.visuals.projectile_position(linked)
				var emitter: Vector2 = battle.visuals.emitters[0].position
				require(launch.distance_to(muzzle) < 0.01 and emitter.distance_to(muzzle) < 0.01, "드래그 행렬의 실제 그림·발사 입자·주탄 포구")
				require(linked_launch.distance_to(spirit_tip) < 0.01, "진동 중 정령 실제 그림·연계탄 출발점")
				var back_pixel := Vector2(920, 664.5) if equipped == -1 else Vector2(800, 699.5)
				var breech: Vector2 = preload("res://tests/pose_probe.gd").new().back(battle.visuals)
				var rule_start: Vector2 = main.pos
				main.pos += Vector2(0, -8)
				var initial: Vector2 = battle.visuals.projectile_position(main)
				main.pos = rule_start
				require((initial - muzzle).normalized().dot((muzzle - breech).normalized()) > 0.9999, "드래그 위치에서도 실제 포신 축으로 초기 비행")
				if cases[index] == "moving":
					battle._drag_position(battle._world(Vector2(65, 490)))
					# 발사 뒤 실제 본체만 이동한 순간. 충돌 이전의 8단위 비행을 판독한다.
					advance_motion(1.0 / 60.0)
					main.pos = rule_start
					require(battle.visuals.projectile_position(main).distance_to(muzzle) < 0.01, "본체 이동 후 발사 기준 고정")
					main.pos = rule_start + Vector2(0, -8)
				var measured: Dictionary = probe.measure(battle)
				require(measured.samples > 100 and measured.min_diagonal > 650 and measured.max_diagonal < 1480, "드래그 실제 발·그림자·정령 범위가 풀밭 내부")
				var filename := "party-%s-%s-%dx%d.png" % ["starter" if equipped == -1 else "cannon", cases[index], dimensions.x, dimensions.y]
				var item := {"path": filename, "stage": "party-%s-%s" % ["starter" if equipped == -1 else "cannon", cases[index]],
					"size": [dimensions.x, dimensions.y], "party": measured, "terrain": [],
					"motion": {"moving": battle.visuals.motion.moving, "state": battle.visuals.motion.state,
						"upper_frame": battle.visuals.motion.witch.frame, "lower_frame": battle.visuals.motion.legs.frame,
						"legs_visible": battle.visuals.motion.legs.visible},
					"party_shot": {"muzzle": [muzzle.x, muzzle.y], "launch": [launch.x, launch.y],
						"emitter": [emitter.x, emitter.y], "spirit_tip": [spirit_tip.x, spirit_tip.y],
						"spirit_launch": [linked_launch.x, linked_launch.y], "initial": [initial.x, initial.y],
						"breech": [breech.x, breech.y], "kick": battle.visuals.kick}}
				if not verify_only:
					battle._refresh_ui()
					battle.queue_redraw()
					await process_frame
					# 캡처 fixture만 명시 draw를 사용한다. 제품의 입력·lifecycle은 변경하지 않는다.
					RenderingServer.force_draw(false)
					var rendered := root.get_texture().get_image()
					require(rendered != null and rendered.get_size() == dimensions, "드래그 PNG 실제 치수")
					require(rendered.save_png(directory.path_join(filename)) == OK, "드래그 PNG 저장")
				records.append(item)
