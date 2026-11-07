extends SceneTree
## 실제 제품 이동·그림 경로의 회귀. 이미지 판독·OS 입력·재미 검증은 아니다.
var checks := 0
var failures := 0
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func fresh() -> Control:
	var b = load("res://main.tscn").instantiate()
	serial += 1
	b.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("experience-%d.json" % serial)
	root.add_child(b)
	b.set_process(false)
	b.sound.enabled = false
	return b

func run() -> void:
	south_skill_checks()
	if "--south-only" in OS.get_cmdline_user_args():
		print("S 이동 시전 작은 재현: ", checks, "개, 실패 ", failures)
		quit(1 if failures else 0)
		return
	salvo_checks()
	reward_checks()
	for dimensions in [Vector2(540,960), Vector2(540,1200), Vector2(720,960)]:
		var b := fresh()
		b.size = dimensions
		b._layout_ui()
		var v: Node2D = b.visuals
		for tier in [0,3]:
			b.equipped = tier - 1
			b.spirit = true
			b.total_shots = 2
			b.bullets.clear()
			b._fire()
			for bullet: Dictionary in b.bullets:
				var start: Vector2 = bullet.pos
				var target: Dictionary = b._enemy_by_id(bullet.target)
				var origin: Vector2 = v.projectile_position(bullet)
				require(v.projectile_ribbon(bullet).is_empty(), "발사 직후 성장 궤적은 길이0")
				var before: Dictionary = b.progress_data().duplicate(true)
				for distance in [8.0, 28.0, 80.0, 180.0]:
					bullet.pos = start.move_toward(target.pos, distance)
					var ribbon: PackedVector2Array = v.projectile_ribbon(bullet)
					if tier == 0:
						require(ribbon.is_empty(), "초기 약한 단발에 성장 리본을 붙이지 않음")
					else:
						require(ribbon.size() == 13 and ribbon[-1].distance_to(v.projectile_position(bullet)) < .01, "성장 궤적 끝은 실제 탄 머리와 일치")
						for point in ribbon:
							require(point.is_finite(), "세 비율·두 발원점의 유한 경로")
						if distance <= 28.0:
							var axis: Vector2 = (ribbon[-1] - origin).normalized()
							for point in ribbon:
								require((point - origin).dot(axis) >= -.01 and absf((point - origin).cross(axis)) < .01, "초기 리본이 실제 포구 뒤나 포신 축 밖으로 침범하지 않음")
					require(before == b.progress_data(), "리본 조회는 재화·장비·저장 계약을 변경하지 않음")
				bullet.pos = target.pos
				if tier > 0:
					require(v.projectile_ribbon(bullet)[-1].distance_to(v._point(target.pos)) < .01, "성장 궤적도 실제 표적에 도착")
			b.bullets.clear()
			v.sync(0.0)
			require(v.shot_origins.is_empty(), "탄 제거 후 리본용 별도 잔류 자료가 없음")
		b.free()

	for tier in [0,3]:
		for sector in range(8):
			var b := fresh()
			b.equipped = tier - 1
			b.witch = Vector2(270,575)
			b._start_boss()
			b.shot_clock = 10.0
			b.visuals.sync(0.0)
			var m: Node2D = b.visuals.motion
			m.previous_rule = b.witch
			var travel := Vector2.UP.rotated(sector * PI / 4)
			b.dragging = true
			b.drag_target = b.witch + travel * 60.0
			b.skill_button.button_down.emit()
			var hp: float = b.boss_hp
			var frames := {}
			for frame in range(12):
				var before: Vector2 = b.witch
				b.advance(b.STEP)
				b.visuals.sync(b.STEP)
				frames[m.legs.frame] = true
				require(absf(b.witch.distance_to(before) / b.STEP - 520.0) < .01, "8방향 최고속 이동을 준비 자세가 지연하지 않음")
				require(m.state == "skill_prepare" and m.legs.visible and m.move_direction == m.direction(travel), "최고속에서도 조준 준비와 실제 방향 하체를 함께 선택")
			require(frames.size() >= 2, "최고속 준비 동안 실제 보행 프레임 진행")
			b.skill_button.mouse_exited.emit()
			b.visuals.sync(0.0)
			require(m.state == "skill_settle" and b.skill_uses == 0 and b.cooldown == 0 and b.boss_hp == hp, "8방향 준비 취소는 피해·발동·쿨다운을 발생시키지 않음")
			b.drag_target = b.witch - travel * 60.0
			b.advance(b.STEP)
			b.visuals.sync(b.STEP)
			require(m.move_direction == m.direction(-travel) and m.legs.visible, "취소 회복 중 반대 방향 하체 즉시 전환")
			b.free()
	print("원작 대조 표현·최고속 회귀: ", checks, "개, 실패 ", failures)
	quit(1 if failures else 0)

func south_skill_checks() -> void:
	# 기존 접합 반례의 작은 재현: S 조준 중 양방향 최고속 이동·취소·재시전.
	var b := fresh()
	b.equipped = 2
	b.witch = Vector2(270,575)
	b._start_boss()
	b.shot_clock = 10.0
	var v: Node2D = b.visuals
	v.sync(0.0)
	var m: Node2D = v.motion
	b.enemies[0].pos = b._from_screen(v.witch_shadow.position+Vector2(0,150))
	b.skill_button.button_down.emit()
	var before := [b.boss_hp,b.skill_uses,b.cooldown]
	var gait := {}
	b.dragging = true
	for i in range(18):
		b.drag_target = b.witch+Vector2(60 if (i/3)%2==0 else -60,0)
		var start: Vector2 = b.witch
		b.advance(b.STEP)
		v.sync(b.STEP)
		gait[m.witch.frame] = true
		require(m.state == "skill_prepare" and m.pose_key == m.SOUTH_SKILLS and m.witch.frame < 4, "S 이동 준비는 신규 전신4자세 선택")
		require(not m.legs.visible and m.witch.material.get_shader_parameter("split_part") == 0, "S 전신에 기존 하체나 절단 마스크를 겹치지 않음")
		require(absf(b.witch.distance_to(start)/b.STEP-520.0)<.01, "전신 교체가 실제 최고속 이동을 지연하지 않음")
	require(gait.size()==4 and before==[b.boss_hp,b.skill_uses,b.cooldown], "준비4자세와 피해/쿨다운 무발동 보존")
	b.skill_button.mouse_exited.emit()
	v.sync(0.0)
	require(m.state=="skill_settle" and m.pose_key==m.SOUTH_SKILLS and before==[b.boss_hp,b.skill_uses,b.cooldown], "S 취소도 접합 없는 전신으로 복귀하며 발동 없음")
	b.enemies[0].pos = b._from_screen(v.witch_shadow.position+Vector2(0,150))
	b.skill_button.button_down.emit()
	require(b.cast_skill(), "S 이동 중 기존 스킬 즉시 발동")
	v.sync(0.0)
	require(m.state=="skill_release" and m.pose_key==m.SOUTH_SKILLS and m.witch.frame>=4 and b.skill_uses==before[1]+1, "S 전신 방출과 실제 한 번 발동")
	var observation := preload("res://tests/pose_probe.gd").new()
	require(observation.tip(v).distance_to(m.muzzle)<.01 and observation.back(v).distance_to(m.breech)<.01, "Worker 원본 관측점과 새 Sprite의 포구/뒤점 변환 일치; 독립 Art 수용 별도")
	for i in range(10):
		b.drag_target = b.witch+Vector2(60 if (i/3)%2==0 else -60,0)
		b.advance(b.STEP)
		v.sync(b.STEP)
	require(m.state=="skill_recover" and m.pose_key==m.SOUTH_SKILLS and not m.legs.visible, "S 이동 회복도 전신 자세 유지")
	b.drag_target = b.witch
	b.advance(b.STEP)
	v.sync(b.STEP)
	require(not m.moving and m.pose_key=="witch-cannon-actions" and not m.legs.visible, "이동 중단은 기존 정지 회복으로 복귀")
	b.free()

func salvo_checks() -> void:
	for tier in [0,3]:
		var b := fresh()
		b.equipped = tier-1
		b.spirit = true
		b.total_shots = 2
		b.shot_clock = 10.0
		var v: Node2D = b.visuals
		b._fire()
		require(v.salvos.size() == (0 if tier==0 else 2), "성장 주탄/실제 정령탄만 발사당 한 광류를 남김")
		if tier==0:
			b.free()
			continue
		var bullet: Dictionary = b.bullets[0]
		var target: Dictionary = b._enemy_by_id(bullet.target)
		var origin: Vector2 = bullet.pos
		for distance in [8.0,40.0,80.0]:
			bullet.pos = origin.move_toward(target.pos,distance)
			v.sync(1.0/60.0)
		var saved: Dictionary = b.progress_data().duplicate(true)
		var salvo: Dictionary = v.salvos[0]
		var observed: Vector2 = v.projectile_position(bullet)
		for lane in range(-2,3):
			var strand: PackedVector2Array = v.salvo_strand(salvo,lane)
			require(strand[0].distance_to(b._world(salvo.points[0])) < .01 and strand[-1].distance_to(observed) < .01, "분지 양끝은 실제 발원점·관측된 머리에 합류; 표적 앞까지 미리 그리지 않음")
		require(saved == b.progress_data(), "광류 조회가 피해·재화·저장 계약을 변경하지 않음")
		# 실제 제품 _tick의 적중 통지를 통과시키고 정확히 한 피해만 확인한다.
		b.bullets.resize(1)
		target.hp = 1000000.0
		var hp: float = target.hp
		bullet.pos = target.pos
		b.advance(b.STEP)
		v.sync(b.STEP)
		require(b.total_hits == 1 and is_equal_approx(hp-target.hp,b.attack_damage()), "다섯 광류는 한 발의 적중/피해를 늘리지 않음")
		var strand: PackedVector2Array = v.salvo_strand(salvo,2)
		require(strand[-1].distance_to(v._point(target.pos)) < .01, "실제 적중 통지 뒤에만 도착점 기록")
		require(v.shot_origins.is_empty() and not v.salvos.is_empty(), "살아있는 탄과 짧은 적중 잔광의 수명을 분리")
		b.toggle_workshop()
		var paused: float = v.motion.clock
		v.sync(.1)
		require(v.motion.clock == paused, "공방은 광류 잔광 시간도 정지")
		b.toggle_workshop()
		for i in range(4):v.sync(.1)
		require(v.salvos.is_empty() and v.impact_pulses.is_empty(), "완료 광류 .32초·적중 섬광 .18초 뒤 회수")
		for i in range(30):b._fire()
		require(v.salvos.size() <= v.MAX_SALVOS, "최고 연사·정령 중첩에도 광류16개 상한")
		b.round_number += 1
		v.sync(0.0)
		require(v.salvos.is_empty(), "재시작/환생의 새 전투에 이전 광류가 남지 않음")
		b.free()

func reward_checks() -> void:
	var b := fresh()
	b.equipped = 2
	var v: Node2D = b.visuals
	var expected: int = b.coins+b.reward_amount()
	b._hit(b.enemies[0],b.enemies[0].hp)
	v.sync(0.0)
	var floats: Array = b.floats.duplicate(true)
	require(b.coins == expected and v.reward_bursts.size() == 1, "실제 정화 지급 한 건만 보상 아이콘에 연결")
	for i in range(12):v.sync(.1)
	require(b.floats == floats and v.reward_bursts.size() == 1, "보상 그림 수명은 규칙 float/실제 지급을 연장하거나 소비하지 않음")
	for i in range(12):v.sync(.1)
	require(v.reward_bursts.is_empty() and b.coins == expected, "성장 수확 그림은2.05초 뒤 회수되고 중복 지급하지 않음")
	for i in range(8):v.play_reward(Vector2(270,350))
	require(v.reward_bursts.size() == 4 and b.coins == expected, "표현용4묶음 상한과 지급의 독립성")
	b.round_number += 1
	v.sync(0.0)
	require(v.reward_bursts.is_empty(), "재시작에 수확 그림 잔류 없음")
	b.free()
