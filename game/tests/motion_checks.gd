extends SceneTree
var checks := 0
var failures := 0
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func fresh(fixture: bool = false) -> Control:
	var battle = load("res://main.tscn").instantiate()
	if fixture:
		battle.set_script(load("res://tests/capture_battle.gd"))
	serial += 1
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("motion-%d.json" % serial)
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	return battle

func run() -> void:
	directional_checks()
	var product := fresh()
	var fixture := fresh(true)
	for battle in [product, fixture]:
		battle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		battle.bullets.clear()
		battle._fire()
	require(product.is_suspended() and product.bullets.is_empty(), "제품 focus 정지 보호 유지")
	require(not fixture.is_suspended() and fixture.bullets.size() == 1 and fixture.ignored_host_notifications.size() > 0, "캡처 fixture만 실제 알림 dispatcher와 분리")
	product.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	require(not product.is_suspended(), "제품 focus 복귀 유지")
	product.free()
	fixture.free()
	var battle := fresh()
	var motion: Node2D = battle.visuals.motion
	battle.shot_clock = 10.0
	var seen := {}
	motion.previous_rule = battle.witch
	for frame in range(32):
		motion.clock = frame / 60.0
		battle.witch.x += 1.0
		battle.visuals.sync(1.0/60.0)
		if motion.state == "walk":
			seen[motion.witch.frame] = true
		require(motion.state == ("start" if frame < 4 else "walk"), "턴→걷기 실제 자세 재생")
	require(seen.size() == 4, "경로 이동과 별개인 네 걷기 프레임")
	battle.shot_clock = .06
	motion.clock = 10.0
	battle.visuals.sync(0.0)
	require(motion.state == "anticipate" and motion.witch.frame % 6 == 4, "다음 발사 전 준비 자세")
	for tier in [0, 3]:
		battle.equipped = tier - 1
		battle.spirit = true
		battle.total_shots = 2
		battle.bullets.clear()
		battle._fire()
		var shot_time: float = motion.clock
		require(motion.state == "release" and (motion.pose_key.ends_with("-moving") or motion.witch.frame % 6 == 5) and motion.spirit.frame % 4 == 3, "마녀 실제 방출과 정령 연계 자세")
		var probe := preload("res://tests/pose_probe.gd").new()
		require(probe.tip(battle.visuals).distance_to(battle.visuals.projectile_position(battle.bullets[0])) < .01, "새 실제 그림의 포구와 주탄 출발 일치")
		for age in [.08, .20, .40]:
			motion.clock = shot_time + age
			battle.visuals.sync(0.0)
			var expected := "recoil" if age < .16 else "recover" if age < .29 else "anticipate"
			require(motion.state == expected, "방출→반동→회복→다음 준비 연결")
	var snapshot: Dictionary = battle.progress_data().duplicate(true)
	var rules: Array = battle.enemies.duplicate(true)
	for i in range(120):
		battle.visuals.sync(1.0/60.0)
	require(snapshot == battle.progress_data() and rules == battle.enemies, "자세 갱신이 전투·저장·난수를 변경하지 않음")
	battle.toggle_workshop()
	var paused: float = motion.clock
	battle.visuals.sync(.1)
	require(motion.clock == paused, "메뉴 정지에서 자세·정화 효과 시간 정지")
	battle.toggle_workshop()
	var enemy: Dictionary = battle.enemies[0]
	battle._hit(enemy, 1.0)
	battle.visuals.sync(0.0)
	require(motion.enemies[enemy.id].frame == 2, "피격은 별도 표정/몸 자세")
	battle._hit(enemy, enemy.hp)
	battle.visuals.sync(0.0)
	require(motion.ghosts.size() == 1 and motion.ghosts[0].actor.frame == 3, "정화 직후 즉시 삭제 대신 정화 자세")
	for i in range(8):
		battle.visuals.sync(.1)
	require(motion.ghosts.is_empty(), "정화 자세 회수")
	battle.free()
	print("생동감·fixture 회귀: ", checks, "개, 실패 ", failures)
	quit(1 if failures else 0)

func directional_checks() -> void:
	var battle := fresh()
	var visual: Node2D = battle.visuals
	var motion: Node2D = visual.motion
	var names := ["E","SE","S","SW","W","NW","N","NE"]
	var rows := [2,3,4,3,2,1,0,1]
	for tier in [0,3]:
		battle.equipped = tier - 1
		for sector in range(8):
			var vector := Vector2.RIGHT.rotated(sector * PI / 4.0)
			battle.witch = Vector2(270,600)
			motion.previous_rule = battle.witch
			motion.shot_at = motion.clock - 1.0
			battle.shot_clock = 10.0
			battle.witch += vector * 2.0
			visual.sync(1.0/60.0)
			require(motion.move_direction == names[sector] and motion.facing == names[sector], "이동 벡터의8방향 몸/발 선택")
			require(motion.witch.frame / int(motion.witch.sprite_frames.get_frame_count("poses") / 5) == rows[sector] and (motion.witch.scale.x < 0) == (sector in [3,4,5]), "실제 뒤/옆/앞 행과 좌측 변환")
			var enemy: Dictionary = battle.enemies[0]
			enemy.pos = battle._from_screen(visual.witch_shadow.position + vector * 170.0)
			battle.bullets.clear()
			battle._fire()
			require(motion.facing == names[sector] and motion.witch.frame / int(motion.witch.sprite_frames.get_frame_count("poses") / 5) == rows[sector] and (motion.pose_key.ends_with("-moving") or motion.witch.frame % 6 == 5), "각 방향 release 자세와 조준 선택")
			var bullet: Dictionary = battle.bullets[0]
			var start: Vector2 = visual.projectile_position(bullet)
			var origin: Vector2 = bullet.pos
			bullet.pos += Vector2(0,-8)
			var axis: Vector2 = (visual.projectile_position(bullet) - start).normalized()
			var target_axis: Vector2 = (visual._point(enemy.pos) - start).normalized()
			require(axis.dot(target_axis) > .9999 and start.distance_to(preload("res://tests/pose_probe.gd").new().tip(visual)) < .01, "그림 포구에서 실제 표적으로 발사, 전체 이미지 회전 없음")
			bullet.pos = origin
			var before: float = motion.stride
			motion.shot_at = motion.clock - 1.0
			visual.sync(1.0/60.0)
			require(motion.state == "settle" and motion.stride == before and motion.facing == names[sector], "정지 시 마지막 방향 유지·제자리 발 미끄러짐 없음")
	# 스킬이 보스를 끝내더라도 위를 향한 시전 프레임을 먼저 보여야 한다.
	battle.witch = Vector2(270,625)
	battle._start_boss()
	visual.sync(0.0)
	battle.enemies[0].pos = battle._from_screen(visual.witch_shadow.position + Vector2(0,-200))
	battle.enemies[0].hp = 1.0
	require(battle.cast_skill(), "실제 별비 스킬 시전")
	visual.sync(1.0/60.0)
	require(motion.facing == "N" and motion.witch.frame / 8 == 0 and motion.state == "skill_release", "승리 전환에도 위쪽 시전은 실제 뒷모습")
	battle.free()
