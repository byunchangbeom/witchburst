extends SceneTree
## 실제 렌더러의 통제된 8초 동작 자료. OS 입력·실시간 자연 성장 영상은 아니다.
var battle: Control
var directory: String

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	directory = OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	battle = load("res://main.tscn").instantiate()
	battle.set_script(load("res://tests/capture_battle.gd"))
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("living-preview.json")
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	var observations: Array[Dictionary] = []
	for index in range(192):
		if index == 60:
			battle.coins = 1000
			battle.materials = 16
			for i in range(4):
				assert(battle.craft_tool())
			assert(battle.merge_tool(0) and battle.merge_tool(0) and battle.merge_tool(1) and battle.unlock_spirit())
		if index == 132:
			battle._start_boss()
		battle.advance(1.0/24.0)
		battle._refresh_ui()
		battle.visuals.sync(1.0/24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		assert(picture.save_png(directory.path_join("motion-%03d.png" % index)) == OK)
		observations.append({"index":index,"state":battle.visuals.motion.state,"frame":battle.visuals.motion.witch.frame,
			"tier":battle.power_tier(),"phase":battle.phase,"shots":battle.total_shots})
	var file := FileAccess.open(directory.path_join("motion-observations.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t"))
	file.close()
	battle.free()
	print("실제 동작 프레임 192장, 24fps 시간 제어, 음향 없음")
	quit(0)
