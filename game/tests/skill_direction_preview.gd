extends SceneTree
## 방향별 시전/취소 진단 fixture. 원래 전투는 적이 위쪽에 있으며 아래 표적은 판독용 주입이다.
var b: Control
var directory: String
var observations: Array[Dictionary]=[]
var max_speed := false
var actual_speed := 0.0
var case_direction := "N"
var case_tier := 0
func _initialize() -> void:run.call_deferred()
func capture(label: String) -> void:
	b._refresh_ui()
	b.title_label.text=label
	b.visuals.sync(1.0/24.0)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join("skill-%03d.png"%observations.size()))==OK)
	var m: Node2D=b.visuals.motion
	var whole_body: bool = m.pose_key == m.SOUTH_SKILLS
	var emitted_axes: Array = []
	for shot: Dictionary in b.visuals.shot_origins:
		emitted_axes.append([shot.axis.x, shot.axis.y])
	observations.append({"index":observations.size(),"label":label,"case_direction":case_direction,"case_tier":case_tier,"state":m.state,"facing":m.facing,"move":m.move_direction,"pose_key":m.pose_key,"whole_body":whole_body,"upper_frame":m.witch.frame,"lower_frame":m.legs.frame,"lower_visible":m.legs.visible,"stride":m.stride,"muzzle":[m.muzzle.x,m.muzzle.y],"breech":[m.breech.x,m.breech.y],"emitted_axes":emitted_axes,"skill_uses":b.skill_uses,"max_speed_fixture":max_speed,"actual_rule_speed":actual_speed})
func run() -> void:
	directory=OS.get_environment("WITCHBURST_ARTIFACTS")
	max_speed = "--max-speed" in OS.get_cmdline_user_args()
	root.size=Vector2i(540,960)
	root.content_scale_size=Vector2i(540,960)
	var names := ["N","NE","E","SE","S","SW","W","NW"]
	for tier in [0,3]:
		for sector in range(8):
			case_direction = names[sector]
			case_tier = tier
			b=load("res://main.tscn").instantiate()
			b.set_script(load("res://tests/capture_battle.gd"))
			b.save_path=OS.get_environment("WITCHBURST_TEST_ROOT").path_join("skill-dir-%d-%d.json"%[tier,sector])
			root.add_child(b)
			b.set_process(false)
			b.sound.enabled=false
			b.inventory=[1,1,1]
			b.equipped=tier-1
			b.witch=Vector2(270,575)
			b._start_boss()
			b.enemies[0].hp=1000000.0
			b.enemies[0].max_hp=1000000.0
			b.shot_clock=10
			b.visuals.sync(0.0)
			var aim:=Vector2.UP.rotated(sector*PI/4)
			var travel:=aim.rotated(PI*.5)
			for step in range(30):
				b.dragging=true
				# 3프레임마다 되돌려 경계에 붙지 않고 기존520속도의 전환을 캡처한다.
				var offset := travel * (60.0 if (step / 3) % 2 == 0 else -60.0) if max_speed else travel * 3.0
				b.drag_target=(b.witch+offset).clamp(Vector2(110,500),Vector2(430,650))
				var before: Vector2 = b.witch
				b.advance(1.0/24.0)
				actual_speed = b.witch.distance_to(before) * 24.0
				# 8방향을 모두 볼 수 있게 표적 위치만 통제한다. 새로운 적 이동 규칙이 아니다.
				b.enemies[0].pos=b._from_screen(b.visuals.witch_shadow.position+aim*150)
				if step==0:b.skill_button.button_down.emit()
				if step==6:b.skill_button.mouse_exited.emit()
				if step==9:b.skill_button.button_down.emit()
				if step==12:assert(b.cast_skill())
				if step==13:b._fire()
				if step==15:b.toggle_workshop()
				if step==18:b.toggle_workshop()
				await capture("%s / %s 조준 · 이동 시전/취소"%["지팡이" if tier==0 else "마법포",names[sector]])
			b.free()
	var file:=FileAccess.open(directory.path_join("skill-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	assert(observations.size()==480)
	print("8방향×2무기 별비/취소/이동480프레임·24fps 통제 fixture, OS입력/음향 미검증")
	quit(0)
