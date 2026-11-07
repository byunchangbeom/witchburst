extends SceneTree
## 실제 획득/구매 함수만 쓰는 봇 비교. 재화·장비·적 HP 주입과 OS 입력은 없다.
var b: Control
var directory: String
var simulated := 0.0
var frames: Array[Dictionary]=[]
var actions: Array[Dictionary]=[]
var drawn := false

func _initialize() -> void:run.call_deferred()

func policy() -> void:
	if b.phase in [b.Phase.WON,b.Phase.LOST]:
		actions.append({"time":simulated,"action":"restart","phase":b.phase})
		b.restart_battle()
	if not b.spirit and b.materials>=4 and b.unlock_spirit():
		actions.append({"time":simulated,"action":"unlock_spirit"})
	if b.equipped<2 and b.materials>=3 and b.craft_tool():
		actions.append({"time":simulated,"action":"craft"})
	for tier in range(2):
		if b.inventory[tier]>=2 and b.merge_tool(tier):
			actions.append({"time":simulated,"action":"merge","tier":tier})
	if not drawn and b.coins>=b.DRAW_COST:
		drawn=b.draw_tool()>=0
		if drawn:actions.append({"time":simulated,"action":"draw"})
	var kind: String="attack" if b.levels.attack<4 else "speed" if b.levels.speed<7 else "yield" if b.levels.yield<5 else "attack" if b.levels.attack<8 else "speed" if b.levels.speed<9 else "yield"
	if b.buy_upgrade(kind):actions.append({"time":simulated,"action":"upgrade","kind":kind,"level":b.levels[kind]})

func snapshot() -> Dictionary:
	return {"time":simulated,"phase":b.phase,"round":b.round_number,"coins":b.coins,"materials":b.materials,"levels":b.levels.duplicate(),"inventory":b.inventory.duplicate(),"equipped":b.equipped,"spirit":b.spirit,"shots":b.total_shots,"spirit_shots":b.spirit_shots}

func capture(label: String) -> void:
	b._refresh_ui()
	b.visuals.sync(1.0/24.0)
	b.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join("natural-%03d.png"%frames.size()))==OK)
	var observation:=snapshot()
	observation["label"]=label
	frames.append(observation)

func run() -> void:
	directory=OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size=Vector2i(540,960)
	root.content_scale_size=Vector2i(540,960)
	b=load("res://main.tscn").instantiate()
	b.set_script(load("res://tests/capture_battle.gd"))
	b.save_path=OS.get_environment("WITCHBURST_TEST_ROOT").path_join("natural-growth.json")
	root.add_child(b)
	b.set_process(false)
	b.sound.enabled=false
	assert(b.coins==0 and b.materials==0 and b.equipped==-1 and not b.spirit)
	for i in range(48):
		b.advance(1.0/24.0)
		simulated+=1.0/24.0
		await capture("initial")
	# 10분의 규칙 시간을 가속한다. 이 구간은 실시간 관람/성장 속도 평가가 아니다.
	for i in range(18000):
		if i%8==0:policy()
		b.advance(1.0/30.0)
		simulated+=1.0/30.0
		if i%8==0:b.visuals.sync(0.0)
	var reached:=snapshot()
	assert(b.spirit and b.equipped==2 and b.levels.speed>=7)
	for i in range(192):
		if i%6==0:policy()
		b.advance(1.0/24.0)
		simulated+=1.0/24.0
		await capture("naturally-grown")
	var record:={"method":"controlled bot using real earned rewards/actions; no currency/inventory/HP injection; no OS input/audio","fast_forward_seconds":600,"reached":reached,"actions":actions,"frames":frames,"human_tempo_or_fun":"NOT_MEASURED"}
	var file:=FileAccess.open(directory.path_join("natural-growth-observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	file.close()
	print("자연 획득 봇: ",JSON.stringify(reached)," / captured ",frames.size())
	b.free()
	quit(0)
