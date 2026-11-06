extends SceneTree
## 실제 렌더러 캡처와 headless 상태 준비 검사를 명시적으로 구분한다.

const SIZES := [Vector2i(540, 960), Vector2i(540, 1200), Vector2i(720, 960)]
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
	var actual_user := OS.get_user_data_dir()
	if not actual_user.is_absolute_path():
		actual_user = ProjectSettings.globalize_path("res://").path_join(actual_user)
	actual_user = actual_user.simplify_path()
	if isolation.is_empty() or not actual_user.begins_with(isolation + "/"):
		push_error("FAIL: 격리 환경에서만 캡처 가능")
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
	# 외형 비교 fixture다. 자연 보상만의 승리는 smoke.gd에서 별도로 확인한다.
	battle.coins = 1000
	for i in range(4):
		require(battle.buy_upgrade("attack"), "공격 강화 준비")
	for i in range(3):
		require(battle.buy_upgrade("speed"), "속도 강화 준비")
	require(battle.buy_upgrade("yield"), "획득 강화 준비")
	battle.advance(0.2)
	require(battle.power_tier() == 2 and battle.bullets.any(func(b: Dictionary) -> bool: return b.tier == 2), "성장한 마도구와 큰 탄 표시 준비")
	await capture_matrix("02-grown", battle.Phase.FOREST)
	until_phase(battle.Phase.BOSS, 100)
	battle.advance(2.0)
	require(battle.boss_hp > 0 and battle.boss_time < battle.BOSS_LIMIT, "보스 HP·시간 표시 준비")
	await capture_matrix("03-boss", battle.Phase.BOSS)
	battle.skill_button.pressed.emit()
	battle.advance(0.1)
	require(battle.skill_uses == 1 and battle.cooldown > 0 and battle.skill_flash > 0, "스킬 효과·쿨다운 표시 준비")
	await capture_matrix("04-skill", battle.Phase.BOSS)
	until_phase(battle.Phase.WON, 30)
	await capture_matrix("05-won", battle.Phase.WON)
	battle.result_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.round_number == 2, "승리 후 다시 전투")
	fresh()
	until_phase(battle.Phase.LOST, 150)
	await capture_matrix("06-lost", battle.Phase.LOST)
	battle.result_button.pressed.emit()
	require(battle.phase == battle.Phase.FOREST and battle.round_number == 2, "패배 후 재도전")
	var manifest := {"display_server": DisplayServer.get_name(), "captures": records,
		"visual_review": "NOT_MEASURED", "human_play": "NOT_MEASURED",
		"fixture": "성장 비교는 별빛 1000 주입, 나머지는 전투 시뮬레이션"}
	var filename := "capture-stages.json" if verify_only else "capture-manifest.json"
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	require(file != null, "상태 기록 저장")
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("캡처 상태 준비 검사 완료 (PNG 없음)." if verify_only else "실제 렌더러 PNG 18개 저장. 독립 시각 판독은 별도 필요.")
	battle.free()
	quit(0)

func capture_matrix(stage: String, phase: int) -> void:
	for dimensions in SIZES:
		root.size = dimensions
		# 창 크기와 stretch가 적용된 뒤 레이아웃을 읽는다.
		await process_frame
		await process_frame
		battle._layout_ui()
		battle._refresh_ui()
		require(battle.phase == phase, "캡처 상태 일치: " + stage)
		require(battle.result_panel.visible == (phase == battle.Phase.WON or phase == battle.Phase.LOST), "결과 창 표시 일치")
		var viewport := Rect2(Vector2.ZERO, battle.size)
		for control in [battle.title_label, battle.status_label, battle.wallet_label, battle.hint_label,
			battle.skill_button, battle.stats_label, battle.footer_label,
			battle.upgrades.attack, battle.upgrades.speed, battle.upgrades.yield]:
			require(viewport.encloses(control.get_rect()), "화면 내 UI 배치: " + stage)
		if battle.result_panel.visible:
			require(viewport.encloses(battle.result_panel.get_rect()), "화면 내 결과 창 배치")
			var panel_rect := Rect2(Vector2.ZERO, battle.result_panel.size)
			for control in [battle.result_title, battle.result_text, battle.result_button]:
				require(panel_rect.encloses(control.get_rect()), "결과 창 내부 텍스트·버튼 배치")
		var filename := "%s-%dx%d.png" % [stage, dimensions.x, dimensions.y]
		var item := {"path": filename, "stage": stage, "size": [dimensions.x, dimensions.y],
			"phase": phase, "attack_level": battle.levels.attack, "power_tier": battle.power_tier(),
			"shots": battle.total_shots, "hits": battle.total_hits, "rewards": battle.total_rewards,
			"boss_hp": battle.boss_hp, "boss_time": battle.boss_time,
			"status": battle.status_label.text, "skill": battle.skill_button.text,
			"font": battle.font.get_font_name(), "logical_size": [battle.size.x, battle.size.y]}
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
