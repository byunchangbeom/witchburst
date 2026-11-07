extends SceneTree
## 실제 Godot UI의 상태·스타일 fixture 캡처. OS 입력 검증으로 표시하지 않는다.
var battle: Control
var directory: String
var serial := 0
var records: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func fresh() -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = load("res://main.tscn").instantiate()
	battle.set_script(load("res://tests/capture_battle.gd"))
	serial += 1
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("ui-preview-%d.json" % serial)
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false

func picture(state: String, dimensions: Vector2i) -> void:
	battle._refresh_ui()
	battle.visuals.sync(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := "ui-%s-%dx%d.png" % [state,dimensions.x,dimensions.y]
	assert(root.get_texture().get_image().save_png(directory.path_join(filename)) == OK)
	records.append({"state":state,"size":[dimensions.x,dimensions.y],"file":filename,
		"wallet":battle.wallet_label.text,"status":battle.status_label.text,"timer":battle.timer_label.text,
		"result":battle.result_text.text,"skill_disabled":battle.skill_button.disabled,"press":battle.upgrades.attack.press_amount})

func run() -> void:
	directory = OS.get_environment("WITCHBURST_ARTIFACTS")
	for dimensions in [Vector2i(540,960),Vector2i(540,1200),Vector2i(720,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		fresh()
		await process_frame
		await process_frame
		battle._layout_ui()
		await picture("poor",dimensions)
		battle.coins = 1000
		battle.materials = 16
		await picture("ready",dimensions)
		var before: Dictionary = battle.progress_data().duplicate(true)
		# 정지 시각 비교용 pressed 상태. 실제 엔진 입력 경로는 smoke에서 별도 검사한다.
		var button: Button = battle.upgrades.attack
		var normal: StyleBox = button.get_theme_stylebox("normal")
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		await process_frame
		button.add_theme_stylebox_override("normal",button.get_theme_stylebox("pressed"))
		button.button_down.emit()
		if is_instance_valid(button.press_tween):
			button.press_tween.custom_step(.12)
		if button.press_amount <= .99:
			push_error("FAIL: pressed 스타일 fixture 준비 실패")
			quit(1)
			return
		await picture("pressed",dimensions)
		button.add_theme_stylebox_override("normal",normal)
		button.button_up.emit()
		if is_instance_valid(button.press_tween):
			button.press_tween.custom_step(.12)
		if battle.progress_data() != before or button.press_amount >= .01:
			push_error("FAIL: 시각 누름/해제 fixture가 진행을 변경함")
			quit(1)
			return
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		await picture("cancel",dimensions)
		battle.coins = 1000000000
		battle.materials = 1000000000
		battle.levels = {"attack":20,"speed":20,"yield":20}
		battle._start_boss()
		battle.boss_time = .8
		await picture("max",dimensions)
		battle.inventory = [0,2,1]
		battle.equipped = 1
		battle.pending_coins = 100
		battle.toggle_workshop()
		await picture("inventory",dimensions)
		battle.toggle_workshop()
		battle.cooldown = 6.8
		await picture("cooldown",dimensions)
		battle.boss_cleared = true
		battle._finish(false)
		battle.advance(.5)
		await picture("after-win-loss",dimensions)
	assert(records.size() == 24)
	var file := FileAccess.open(directory.path_join("ui-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	file.close()
	battle.free()
	print("실제 UI 상태24장·신호/스타일·Tween custom_step press/cancel fixture, 입력 경로는별도 smoke, OS입력 미검증")
	quit(0)
