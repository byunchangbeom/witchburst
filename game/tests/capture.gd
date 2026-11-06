extends SceneTree
## 실제 렌더러의 장면을 캡처한다. OS 터치·사람 플레이 검증과 구분한다.

var battle: Control
var directory: String

func _initialize() -> void:
	_run.call_deferred()

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
	if DisplayServer.get_name() == "headless":
		push_error("FAIL: 캡처에는 실제 디스플레이가 필요")
		quit(1)
		return
	directory = OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	battle.advance(1.5)
	await capture("01-작은마녀")
	# 성장 전후 비교용 수치 fixture. 자연 보상만의 승리는 smoke.gd가 별도 검사한다.
	battle.coins = 1000
	for i in range(4):
		battle.buy_upgrade("attack")
	for i in range(3):
		battle.buy_upgrade("speed")
	battle.buy_upgrade("yield")
	battle.advance(0.2)
	await capture("02-거대마도구")
	for i in range(6000):
		if battle.phase == battle.Phase.BOSS:
			break
		battle.advance(1.0 / 60.0)
	battle.advance(2.0)
	await capture("03-가시왕")
	battle.cast_skill()
	battle.advance(0.1)
	await capture("04-별비")
	for i in range(1800):
		if battle.phase == battle.Phase.WON:
			break
		battle.advance(1.0 / 60.0)
	await capture("05-승리")
	battle.result_button.pressed.emit()
	root.size = Vector2i(540, 1200)
	await process_frame
	await capture("06-긴화면")
	root.size = Vector2i(720, 960)
	await process_frame
	await capture("07-넓은화면")
	root.size = Vector2i(540, 960)
	battle.free()
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	for i in range(9000):
		if battle.phase == battle.Phase.LOST:
			break
		battle.advance(1.0 / 60.0)
	await capture("08-시간초과")
	print("실제 렌더러 캡처 완료. OS 입력·음향·사람 재미는 NOT_MEASURED.")
	battle.free()
	quit(0)

func capture(filename: String) -> void:
	battle._layout_ui()
	battle._refresh_ui()
	battle.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var result := rendered.save_png(directory.path_join(filename + ".png"))
	if result != OK:
		push_error("FAIL: 캡처 저장 실패 " + filename)
		quit(1)
	print("캡처: ", filename, " ", rendered.get_size())
