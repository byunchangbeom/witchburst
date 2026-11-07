extends SceneTree
## 같은 제품 소스의 전환/취소 연속 실행. 표적·성장/시계는 fixture, OS 조작 아님.
var b: Control
var m: Node2D
var directory: String
var observations: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func fresh(tier: int) -> void:
	if is_instance_valid(b):b.free()
	b=load("res://main.tscn").instantiate()
	b.set_script(load("res://tests/capture_battle.gd"))
	b.save_path=OS.get_environment("WITCHBURST_TEST_ROOT").path_join("sequence-%d.json"%observations.size())
	root.add_child(b)
	b.set_process(false)
	b.sound.enabled=false
	b.inventory=[1,1,1]
	b.equipped=tier-1
	b.spirit=tier>0
	b.witch=Vector2(270,575)
	b.shot_clock=10
	b.visuals.sync(0.0)
	m=b.visuals.motion
func capture(title: String) -> void:
	b._refresh_ui()
	b.title_label.text=title
	b.visuals.sync(1.0/24.0)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join("action-%03d.png"%observations.size()))==OK)
	if observations.size()%16==0:print("연속 실행 frame ",observations.size())
	observations.append({"index":observations.size(),"label":title,"time":m.clock,"state":m.state,"key":m.pose_key,"frame":m.witch.frame,"facing":m.facing,"move":m.move_direction,"stride":m.stride,"skill_uses":b.skill_uses,"cooldown":b.cooldown})
func run() -> void:
	directory=OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size=Vector2i(540,960)
	root.content_scale_size=Vector2i(540,960)
	var names := ["N","NE","E","SE","S","SW","W","NW"]
	for tier in [0,3]:
		fresh(tier)
		for sector in range(8):
			if b.enemies.is_empty():b._spawn_enemy()
			b.enemies[0].hp=10000.0
			b.enemies[0].max_hp=10000.0
			var vector:=Vector2.UP.rotated(sector*PI/4)
			var text: String=("지팡이" if tier==0 else "마법포")+" / "+names[sector]
			b.witch=Vector2(270,575)
			m.previous_rule=b.witch
			m.reset_actions()
			b.shot_clock=10
			for step in range(16):
				# 이동 상태는 fixture로 주입하며 원래520속도의 _tick 물리를 사용한다. 입력 경로는 별도 smoke다.
				if step<9:
					b.dragging=true
					b.drag_target=(b.witch+vector*6).clamp(Vector2(100,505),Vector2(440,645))
					b._tick(1.0/24.0)
				if step==4:
					b.enemies[0].pos=b._from_screen(b.visuals.witch_shadow.position+vector*160)
					b.total_shots=2
					b._fire()
				if step>=9:b.dragging=false
				await capture(text+(" 이동 사격" if step<9 else " 정지/회복"))
		# 버튼 준비/취소/발동/자동사격 중첩/정지/회복/결과/재도전.
		b._start_boss()
		b.enemies[0].hp=1000000.0
		b.enemies[0].max_hp=1000000.0
		b.shot_clock=10
		for step in range(72):
			if step==0:b.skill_button.button_down.emit()
			if step==6:b.skill_button.mouse_exited.emit()
			if step==10:b.skill_button.button_down.emit()
			if step==15:assert(b.cast_skill())
			if step==16:b._fire()
			if step==18:b.toggle_workshop()
			if step==24:b.toggle_workshop()
			if step==34:b._finish(false)
			if step==62:b.restart_battle()
			b.advance(1.0/24.0)
			await capture("별비 준비/취소/발동/공방 정지/복귀" if step<34 else "결과 → 재도전 상태 초기화")
	var file:=FileAccess.open(directory.path_join("action-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	assert(observations.size()==400)
	b.free()
	print("행동/취소 연속 실행400프레임,24fps,무음·통제 fixture")
	quit(0)
