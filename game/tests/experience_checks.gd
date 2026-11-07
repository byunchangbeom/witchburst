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
