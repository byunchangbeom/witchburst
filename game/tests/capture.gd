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
	fixture_id += 1
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("capture-%d.json" % fixture_id)
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false

func until_phase(target: int, limit: float) -> void:
	for i in range(int(limit * 60)):
		if battle.phase == target:
			return
		battle.advance(1.0 / 60.0)
	require(battle.phase == target, "캡처할 전투 상태 도달 실패: %d" % target)

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
	battle.advance(0.1)
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
	battle.advance(0.2)
	require(battle.power_tier() == 3 and battle.bullets.any(func(b: Dictionary) -> bool: return b.tier == 3), "성장한 마도구와 큰 탄 표시 준비")
	await capture_matrix("02-grown", battle.Phase.FOREST)
	await capture_matrix("11-grown-shot", battle.Phase.FOREST, true)
	await capture_matrix("13-grown-flight", battle.Phase.FOREST, false, 80.0)
	battle.toggle_workshop()
	await capture_matrix("07-workshop", battle.Phase.FOREST)
	battle.toggle_workshop()
	until_phase(battle.Phase.BOSS, 100)
	battle.advance(0.25)
	require(battle.boss_hp > 0 and battle.boss_time < battle.BOSS_LIMIT, "보스 HP·시간 표시 준비")
	await capture_matrix("03-boss", battle.Phase.BOSS)
	await capture_matrix("14-boss-shot", battle.Phase.BOSS, true)
	await capture_matrix("15-boss-flight", battle.Phase.BOSS, false, 80.0)
	battle.skill_button.pressed.emit()
	battle.advance(0.1)
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
	require(records.size() == 45, "15상태 × 3비율 캡처 행렬 완성")
	var manifest := {"display_server": DisplayServer.get_name(), "captures": records,
		"visual_review": "NOT_MEASURED", "human_play": "NOT_MEASURED",
		"fixture": "성장 비교는 별빛1000·잎16 주입 후 실제 제작·합성·정령 해금. 발사·비행 비교는 _fire 직접 호출 후 반동·호흡1 고정, 비행은 규칙 탄을 표적 쪽으로80단위 이동한 표현 fixture; 나머지는 전투 시뮬레이션"}
	var filename := "capture-stages.json" if verify_only else "capture-manifest.json"
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	require(file != null, "상태 기록 저장")
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("캡처 상태 준비 검사 완료 (PNG 없음)." if verify_only else "실제 렌더러 PNG 45개 저장. 독립 시각 판독은 별도 필요.")
	battle.free()
	quit(0)

func capture_matrix(stage: String, phase: int, launch: bool = false, flight: float = 0.0) -> void:
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
				require(panel_rect.encloses(control.get_rect()), "결과 창 내부 텍스트·버튼 배치")
		var filename := "%s-%dx%d.png" % [stage, dimensions.x, dimensions.y]
		var item := {"path": filename, "stage": stage, "size": [dimensions.x, dimensions.y],
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
			var muzzle: Vector2 = battle.visuals.to_local(sprite.to_global(pixel - sprite.texture.get_size() * 0.5))
			var projectile: Vector2 = battle.visuals.projectile_position(battle.bullets[0])
			var tail: Vector2 = battle.visuals.projectile_tail(battle.bullets[0])
			var emitter: Vector2 = battle.visuals.emitters[0].position
			require(muzzle.distance_to(emitter) < 0.01, "실제 그림·입자 포구 일치")
			if launch:
				require(muzzle.distance_to(projectile) < 0.01 and muzzle.distance_to(tail) < 0.01, "발사 직후 탄·꼬리는 포구에 일치")
			var back_pixel := Vector2(920, 664.5) if battle.power_tier() == 0 else Vector2(800, 699.5)
			var back: Vector2 = battle.visuals.to_local(sprite.to_global(back_pixel - sprite.texture.get_size() * 0.5))
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
			await RenderingServer.frame_post_draw
			var rendered := root.get_texture().get_image()
			require(rendered != null and rendered.get_size() == dimensions, "실제 캡처 치수: " + filename)
			require(rendered.get_pixel(0, 0) != rendered.get_pixel(dimensions.x / 2, dimensions.y / 2), "단색 빈 화면 거부")
			require(rendered.save_png(directory.path_join(filename)) == OK, "PNG 저장: " + filename)
			print("캡처: ", filename)
		records.append(item)
	if launch or flight > 0.0:
		battle.visuals.breath.play()
		battle.visuals.shot_tween.play()
