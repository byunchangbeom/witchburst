extends RefCounted
## 실제 표시 AtlasTexture와 Sprite 변환을 읽는 검사측 그림 랜드마크다.
var landmarks: Dictionary = {}
var south_landmarks: Dictionary = {}

func record(visual: Node2D) -> Dictionary:
	if visual.motion.pose_key == "witch-cannon-south-skills":
		# 공급된 독립 raw 관측을 trim 전 좌표로 변환했다. 게임 통합 수용과는 별도다.
		if south_landmarks.is_empty():
			south_landmarks = JSON.parse_string(FileAccess.get_file_as_string("res://tests/south-moving-observations.json"))
		return south_landmarks.frames[visual.motion.pose_key][str(visual.motion.witch.frame)]
	if landmarks.is_empty():
		landmarks = JSON.parse_string(FileAccess.get_file_as_string("res://tests/weapon-axis-landmarks.json"))
	return landmarks.frames.get(visual.motion.pose_key, {}).get(str(visual.motion.witch.frame), {})

func _landmark(visual: Node2D, actor: AnimatedSprite2D, uv: Vector2) -> Vector2:
	var picture := actor.sprite_frames.get_frame_texture(actor.animation, actor.frame)
	var key: String = visual.motion.pose_key if actor == visual.motion.witch else "spirit-directions"
	var cell: Dictionary = visual.motion.metadata[key].cells[actor.frame]
	var canvas: Array = cell.get("canvas_size",[picture.get_width(),picture.get_height()])
	var trim: Array = cell.get("trim_offset",[0,0])
	var point := uv * Vector2(canvas[0],canvas[1])-Vector2(trim[0],trim[1])
	return visual.to_local(actor.to_global(point - picture.get_size()*.5 + actor.offset))

func tip(visual: Node2D) -> Vector2:
	var observed := record(visual)
	if not observed.is_empty():
		var point: Array = observed.muzzle_canvas_uv
		return _landmark(visual, visual.motion.witch, Vector2(point[0], point[1]))
	# 실제 각 방향 release 그림의 밝은 별/포구를 독립 판독한 위치.
	var row: int = visual.motion.direction_row(visual.motion.facing)
	if visual.motion.pose_key.ends_with("-moving"):
		var points := [[0.8688, 0.1892], [0.8106, 0.1899], [0.7595, 0.1844], [0.7241, 0.1913], [0.9137, 0.2345], [0.8917, 0.2612], [0.8333, 0.2513], [0.8337, 0.2426], [0.9489, 0.4463], [0.878, 0.4516], [0.8574, 0.4495], [0.8606, 0.4505], [0.8708, 0.5054], [0.8533, 0.5273], [0.7861, 0.5256], [0.7933, 0.5224], [0.5658, 0.688], [0.5944, 0.6693], [0.5487, 0.6615], [0.5257, 0.6728]] if visual.battle.power_tier() == 0 else [[0.7215, 0.0877], [0.6965, 0.0896], [0.6826, 0.0888], [0.6574, 0.0854], [0.7975, 0.1901], [0.7656, 0.1792], [0.7489, 0.1894], [0.7498, 0.1905], [0.9283, 0.462], [0.9036, 0.4745], [0.9115, 0.4726], [0.8844, 0.4685], [0.8682, 0.6031], [0.8411, 0.6232], [0.8268, 0.62], [0.8171, 0.6309], [0.5732, 0.6011], [0.5796, 0.613], [0.5551, 0.604], [0.5631, 0.6085]]
		var uv: Array = points[visual.motion.witch.frame]
		return _landmark(visual, visual.motion.witch, Vector2(uv[0],uv[1]))
	var wand := [Vector2(.8779,.2361),Vector2(.9041,.2458),Vector2(.8863,.4221),Vector2(.8657,.5512),Vector2(.5921,.7775)]
	var cannon := [Vector2(.6408,.0646),Vector2(.8213,.2217),Vector2(.9294,.5321),Vector2(.8510,.7215),Vector2(.5105,.8303)]
	return _landmark(visual, visual.motion.witch, (wand if visual.battle.power_tier() == 0 else cannon)[row])

func back(visual: Node2D) -> Vector2:
	# 제품 metadata/포신 헬퍼나 적 좌표를 사용하지 않는 독립 Art 판독 원문이다.
	var observed := record(visual)
	var uv: Array = observed.rear_canvas_uv
	return _landmark(visual, visual.motion.witch, Vector2(uv[0],uv[1]))

func spirit_tip(visual: Node2D) -> Vector2:
	var mouths := [Vector2(.5,.26),Vector2(.72,.38),Vector2(.83,.46),Vector2(.71,.49),Vector2(.5,.48)]
	return _landmark(visual, visual.motion.spirit, mouths[visual.motion.spirit.frame / 4])
