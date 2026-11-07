extends SceneTree
## 방향/조준의 실제 렌더러 fixture. OS 드래그와 자연 성장 영상으로 표시하지 않는다.
var battle: Control
var directory: String
var observations: Array[Dictionary] = []
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func fresh() -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = load("res://main.tscn").instantiate()
	battle.set_script(load("res://tests/capture_battle.gd"))
	serial += 1
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("direction-%d.json" % serial)
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false

func capture(label: String) -> void:
	battle._refresh_ui()
	battle.title_label.text = label
	battle.visuals.sync(1.0/24.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.save_png(directory.path_join("motion-%03d.png" % observations.size())) == OK)
	var motion: Node2D = battle.visuals.motion
	observations.append({"index":observations.size(),"label":label,"move":motion.move_direction,"aim":motion.aim_direction,
		"facing":motion.facing,"state":motion.state,"frame":motion.witch.frame,"scale_x":motion.witch.scale.x,"tier":battle.power_tier()})

func run() -> void:
	directory = OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size = Vector2i(540,960)
	root.content_scale_size = Vector2i(540,960)
	var names := ["위","오른쪽 위","오른쪽","오른쪽 아래","아래","왼쪽 아래","왼쪽","왼쪽 위"]
	for tier in [0,3]:
		for sector in range(8):
			fresh()
			battle.equipped = tier - 1
			battle.witch = Vector2(270,600)
			battle.shot_clock = 10.0
			battle.visuals.motion.previous_rule = battle.witch
			battle.visuals.sync(0.0)
			var vector := Vector2.UP.rotated(sector * PI / 4.0)
			for step in range(12):
				if step < 6:
					battle.witch += vector * 3.0
				else:
					if step == 6:
						battle.enemies[0].pos = battle._from_screen(battle.visuals.witch_shadow.position + vector * 170.0)
						battle.bullets.clear()
						battle._fire()
				await capture("%s · %s%s" % ["지팡이" if tier == 0 else "마법포",names[sector]," 이동" if step < 6 else " 공격"])
	fresh()
	battle.witch = Vector2(270,625)
	battle._start_boss()
	battle.visuals.sync(0.0)
	battle.enemies[0].pos = battle._from_screen(battle.visuals.witch_shadow.position + Vector2(0,-200))
	assert(battle.cast_skill())
	for step in range(8):
		await capture("위쪽 보스 · 별비 시전 방향")
	var file := FileAccess.open(directory.path_join("direction-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	assert(observations.size() == 200)
	battle.free()
	print("방향·시전 실제 프레임 200장,8방향×2무기+별비,24fps")
	quit(0)
