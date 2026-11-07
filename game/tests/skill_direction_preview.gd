extends SceneTree
## 방향별 시전/취소 진단 fixture. 원래 전투는 적이 위쪽에 있으며 아래 표적은 판독용 주입이다.
var b: Control
var directory: String
var observations: Array[Dictionary]=[]
var max_speed := false
var stationary := false
var verify_states := false
var actual_speed := 0.0
var case_direction := "N"
var case_tier := 0
func _initialize() -> void:run.call_deferred()
func capture(label: String) -> void:
	b._refresh_ui()
	b.title_label.text=label
	b.visuals.sync(1.0/24.0)
	if not verify_states:
		await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(directory.path_join("skill-%03d.png"%observations.size()))==OK)
	var m: Node2D=b.visuals.motion
	var whole_body: bool = m.pose_key == m.SOUTH_SKILLS
	if stationary:
		assert(actual_speed==0.0 and b.witch==Vector2(270,575) and m.stride==0.0 and not m.moving and not m.legs.visible, "정지 fixture의 좌표·속도·보행 보존")
		assert(b.skill_uses==(0 if observations.size()%30<12 else 1), "준비·취소 무발동과 실제 한 번 발동")
		if case_tier==3 and case_direction=="S" and m.state.begins_with("skill_") and not m.direct_firing:
			assert(whole_body and m.witch.frame==(4 if m.state in ["skill_release","skill_recover"] else 0) and m.muzzle.y>m.breech.y, "정지 S 전신 중립과 실제 아래 관구")
	var emitted_axes: Array = []
	for shot: Dictionary in b.visuals.shot_origins:
		emitted_axes.append([shot.axis.x, shot.axis.y])
	observations.append({"index":observations.size(),"label":label,"case_direction":case_direction,"case_tier":case_tier,"state":m.state,"direct_firing":m.direct_firing,"facing":m.facing,"move":m.move_direction,"pose_key":m.pose_key,"whole_body":whole_body,"upper_frame":m.witch.frame,"lower_frame":m.legs.frame,"lower_visible":m.legs.visible,"stride":m.stride,"muzzle":[m.muzzle.x,m.muzzle.y],"breech":[m.breech.x,m.breech.y],"emitted_axes":emitted_axes,"skill_uses":b.skill_uses,"cooldown":b.cooldown,"skill_age":m.clock-m.skill_at,"skill_targets":m.skill_targets,"max_speed_fixture":max_speed,"stationary_fixture":stationary,"actual_rule_speed":actual_speed,"rule_position":[b.witch.x,b.witch.y]})
func run() -> void:
	directory=OS.get_environment("WITCHBURST_ARTIFACTS")
	max_speed = "--max-speed" in OS.get_cmdline_user_args()
	stationary = "--stationary" in OS.get_cmdline_user_args()
	verify_states = "--verify-states" in OS.get_cmdline_user_args()
	assert(verify_states or DisplayServer.get_name()!="headless", "실제 화면 생성에는 디스플레이 필요")
	assert(not (max_speed and stationary), "최고속과 정지 fixture는 별도 실행")
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
			# fixture의 시작 좌표 주입을 실제 보행으로 세지 않는다.
			b.visuals.motion.previous_rule=b.witch
			var aim:=Vector2.UP.rotated(sector*PI/4)
			var travel:=aim.rotated(PI*.5)
			var seen_states := {}
			for step in range(30):
				b.dragging=true
				# 3프레임마다 되돌려 경계에 붙지 않고 기존520속도의 전환을 캡처한다.
				var offset := travel * (60.0 if (step / 3) % 2 == 0 else -60.0) if max_speed else travel * 3.0
				if stationary:offset=Vector2.ZERO
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
				await capture("%s / %s 조준 · %s 시전/취소"%["지팡이" if tier==0 else "마법포",names[sector],"정지" if stationary else "이동"])
				seen_states[b.visuals.motion.state]=true
			for state: String in ["skill_prepare","skill_settle","skill_release","skill_recover"]:
				assert(seen_states.has(state), "각 무기/방향의 준비·취소·발동·회복 누락 거부")
			b.free()
	var file:=FileAccess.open(directory.path_join("skill-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	var method:=FileAccess.open(directory.path_join("method.json"),FileAccess.WRITE)
	method.store_string(JSON.stringify({"rendered":not verify_states,"method":"HEADLESS_STATE_ONLY" if verify_states else "GPU_PNG_FIXTURE","visual_acceptance":"PENDING_INDEPENDENT_REVIEW"}))
	method.close()
	assert(observations.size()==480)
	print("8방향×2무기 별비/취소480상태·24fps 통제 fixture, 정지=",stationary,", 실제PNG=",not verify_states,", OS입력/음향 미검증")
	quit(0)
