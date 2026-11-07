extends SceneTree
## Godot가 실제 제품 SpriteFrames를 원래 표시 배율로 그린다. 확대 합성 이미지가 아니다.
var b: Control
var layer: Node2D
var directory: String
const DIRECTIONS := ["N","NE","E","SE","S","SW","W","NW"]
func _initialize() -> void:run.call_deferred()
func label_at(value: String, point: Vector2, size: int = 16) -> void:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("49382d"))
	layer.add_child(label)
func pose(key: String,index: int,point: Vector2,height: float,flip: bool=false) -> AnimatedSprite2D:
	var actor := AnimatedSprite2D.new()
	layer.add_child(actor)
	b.visuals.motion._pose(actor,key,index,point,height)
	if flip:actor.scale.x *= -1
	return actor
func save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK)
func panel() -> void:
	if is_instance_valid(layer):layer.free()
	layer=Node2D.new()
	root.add_child(layer)
func run() -> void:
	directory=OS.get_environment("WITCHBURST_ARTIFACTS")
	root.size=Vector2i(1200,660)
	root.content_scale_size=Vector2i(1200,660)
	RenderingServer.set_default_clear_color(Color("e5edcd"))
	b=load("res://main.tscn").instantiate()
	b.set_script(load("res://tests/capture_battle.gd"))
	b.save_path=OS.get_environment("WITCHBURST_TEST_ROOT").path_join("board.json")
	root.add_child(b)
	b.set_process(false)
	b.visible=false
	b.sound.enabled=false
	for family: String in ["witch-wand","witch-cannon"]:
		var height: float=b.visuals.actor_height("wand" if family.ends_with("wand") else "cannon")
		for dir: String in DIRECTIONS:
			panel()
			var row: int=b.visuals.motion.direction_row(dir)
			var flip: bool=dir in ["NW","W","SW"]
			label_at("%s / %s · 540×960 원작대조 후보의 실제1x · 발 기준"%[family,dir],Vector2(16,8),21)
			var actions := ["대기A","대기B","턴/접지","반동","회복","별비 준비","별비 발동","별비 회복"]
			for i in range(8):
				var x:=110.0+i*140
				pose(family+"-actions",row*8+i,Vector2(x,190),height,flip)
				label_at(actions[i],Vector2(x-42,204),15)
			for i in range(8):
				var moving:=i>=4
				var key:=family+("-moving" if moving else "-directions")
				var index:=row*(4 if moving else 6)+i%4
				var x:=110.0+i*140
				var upper:=pose(key,index,Vector2(x,376),height,flip)
				if moving:
					var lower:=AnimatedSprite2D.new()
					layer.add_child(lower)
					b.visuals.motion.split_legs(upper,lower,family,dir,float(i%4),Vector2(x,376),height,1.0)
				label_at(("이동 사격" if moving else "기존 걷기")+str(i%4+1),Vector2(x-48,394),15)
			for i in range(8):
				var x:=110.0+i*140
				var action := "skill_prepare" if i<4 else "skill_release"
				var whole: Dictionary = b.visuals.motion.moving_skill_pose(family,dir,action,float(i%4))
				if not whole.is_empty():
					pose(whole.key,whole.index,Vector2(x,560),height)
				else:
					var upper:=pose(family+"-actions",row*8+(5 if i<4 else 6),Vector2(x,560),height,flip)
					var lower:=AnimatedSprite2D.new()
					layer.add_child(lower)
					var move_dir: String=DIRECTIONS[(DIRECTIONS.find(dir)+2)%8]
					b.visuals.motion.split_legs(upper,lower,family,move_dir,float(i%4),Vector2(x,560),height,1.0)
				label_at(("이동 준비" if i<4 else "이동 시전")+str(i%4+1),Vector2(x-48,582),15)
			label_at("3행: 조준과 직각 이동 · 마법포S는 신규 전신8자세, 나머지는 실제 파츠 · 판정 지연 없음",Vector2(18,632),16)
			await save("board-%s-%s"%[family,dir])
	root.size=Vector2i(1000,640)
	root.content_scale_size=Vector2i(1000,640)
	panel()
	label_at("정령 방향·연계 / 기존 적 이동·피격·정화 · 실제 1x",Vector2(18,8),21)
	for row in range(5):
		label_at(["N","NE","E","SE","S"][row],Vector2(8,100+row*67))
		for col in range(4):pose("spirit-directions",row*4+col,Vector2(90+col*100,110+row*67),b.visuals.actor_height("spirit"))
	for i in range(8):
		var boss:=i>=4
		pose("forest-motion",i,Vector2(600+(i%2)*250,230+(i%4/2)*240) if boss else Vector2(90+i*100,570),b.visuals.actor_height("boss" if boss else "seed"))
	await save("board-spirit-enemies")
	b.free()
	print("실제1x 프레임 보드17장:2무기×8방향+정령/적")
	quit(0)
