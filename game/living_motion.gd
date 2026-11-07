extends Node2D
## 실제 방향·행동 자세만 구동한다. 이동/피해/입력/난수/저장에는 쓰지 않는다.
const TEXTURES := {
	"witch-wand-motion": preload("res://assets/art/witch-wand-motion.png"),
	"witch-cannon-motion": preload("res://assets/art/witch-cannon-motion.png"),
	"witch-wand-directions": preload("res://assets/art/witch-wand-directions.png"),
	"witch-cannon-directions": preload("res://assets/art/witch-cannon-directions.png"),
	"witch-wand-actions": preload("res://assets/art/witch-wand-actions.png"),
	"witch-cannon-actions": preload("res://assets/art/witch-cannon-actions.png"),
	"witch-wand-moving": preload("res://assets/art/witch-wand-moving.png"),
	"witch-cannon-moving": preload("res://assets/art/witch-cannon-moving.png"),
	"spirit-directions": preload("res://assets/art/spirit-directions.png"),
	"forest-motion": preload("res://assets/art/forest-motion.png")}
var visual: Node2D
var battle: Control
var metadata: Dictionary
var frames: Dictionary = {}
var witch: AnimatedSprite2D
var spirit: AnimatedSprite2D
var legs: AnimatedSprite2D
var enemies: Dictionary = {}
var clock := 0.0
var shot_at := -100.0
var spirit_at := -100.0
var skill_at := -100.0
var skill_targets: Array[Vector2] = []
var transition_at := -100.0
var cancel_at := -100.0
var state := "ready"
var pose_key := ""
var ghosts: Array[Dictionary] = []
var last_enemies: Dictionary = {}
var move_direction := "N"
var aim_direction := "N"
var skill_direction := "N"
var spirit_direction := "N"
var facing := "N"
var previous_rule := Vector2.INF
var stride := 0.0
var moving := false
var was_moving := false
var turning := false
var skill_preparing := false
var last_round := -1
var last_tier := -1
var shot_target := Vector2.ZERO
var aim_axis := Vector2.UP
var muzzle := Vector2.ZERO
var breech := Vector2.ZERO
var spirit_mouth := Vector2.ZERO

func setup(owner_visual: Node2D) -> void:
	visual = owner_visual
	battle = visual.battle
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/motion-atlas.json"))
	for key in metadata:
		var library := SpriteFrames.new()
		library.remove_animation("default")
		library.add_animation("poses")
		for cell in metadata[key].cells:
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/art/"+cell.file_override) if cell.has("file_override") else TEXTURES[key]
			atlas.region = Rect2(cell.region[0], cell.region[1], cell.region[2], cell.region[3])
			atlas.filter_clip = true
			library.add_frame("poses", atlas)
		frames[key] = library
	witch = _actor()
	spirit = _actor()
	legs = _actor()
	legs.visible = false
	legs.material = visual.witch_sprite.material.duplicate()
	witch.material = visual.witch_sprite.material
	spirit.material = visual.spirit_sprite.material
	sync(0.0)

func bind_controls() -> void:
	# 버튼 down/up은 기존 pressed 발동 시점을 바꾸지 않는 표현 준비/취소다.
	battle.skill_button.button_down.connect(prepare_skill)
	battle.skill_button.button_up.connect(cancel_skill_preview)
	battle.skill_button.mouse_exited.connect(cancel_skill_preview)

func _actor() -> AnimatedSprite2D:
	var actor := AnimatedSprite2D.new()
	actor.z_index = -1
	add_child(actor)
	return actor

func _pose(actor: AnimatedSprite2D, key: String, index: int, ground: Vector2, height: float) -> void:
	actor.sprite_frames = frames[key]
	actor.animation = "poses"
	actor.frame = index
	var cell: Dictionary = metadata[key].cells[index]
	actor.scale = Vector2.ONE * height / float(cell.get("canvas_size", [cell.region[2],cell.region[3]])[1])
	actor.offset = Vector2(cell.region[2], cell.region[3]) * .5 - Vector2(cell.foot[0], cell.foot[1])
	actor.position = ground

func _pixel(actor: AnimatedSprite2D, key: String, index: int, point: Vector2) -> Vector2:
	var cell: Dictionary = metadata[key].cells[index]
	var size := Vector2(cell.region[2], cell.region[3])
	return to_local(actor.to_global((point - Vector2(.5,.5)) * size + actor.offset))

func direction(vector: Vector2) -> String:
	if vector.length_squared() < .0001:
		return facing
	var sector := posmod(int(round(vector.angle() / (PI / 4.0))), 8)
	return ["E","SE","S","SW","W","NW","N","NE"][sector]

func direction_row(value: String) -> int:
	return {"N":0,"NE":1,"E":2,"SE":3,"S":4,"SW":3,"W":2,"NW":1}[value]

func nearest_target() -> Dictionary:
	var target: Dictionary = {}
	for enemy in battle.enemies:
		if target.is_empty() or enemy.pos.distance_squared_to(battle.witch) < target.pos.distance_squared_to(battle.witch):
			target = enemy
	return target

func target_facing() -> String:
	var target := nearest_target()
	return direction(visual._point(target.pos) - visual.witch_shadow.position) if not target.is_empty() else facing

func on_shot(bullet: Dictionary, linked: bool) -> void:
	sync_party()
	shot_at = clock
	var target: Dictionary = battle._enemy_by_id(bullet.target)
	shot_target = visual._point(target.pos) if not target.is_empty() else muzzle + Vector2(0,-150)
	aim_direction = direction(shot_target - visual.witch_shadow.position)
	if linked:
		spirit_at = clock
		spirit_direction = direction(shot_target - visual.spirit_sprite.position)

func prepare_skill() -> void:
	if not frozen() and battle.phase == battle.Phase.BOSS and battle.cooldown <= 0.0:
		skill_preparing = true
		skill_direction = target_facing()

func cancel_skill_preview() -> void:
	if skill_preparing:
		skill_preparing = false
		cancel_at = clock

func on_skill() -> void:
	sync_party()
	skill_targets.clear()
	for enemy in battle.enemies:
		skill_targets.append(visual._point(enemy.pos))
	skill_preparing = false
	skill_at = clock
	skill_direction = target_facing()

func frozen() -> bool:
	return battle.is_suspended() or (is_instance_valid(battle.workshop) and battle.workshop.visible)

func reset_actions() -> void:
	shot_at = -100.0
	skill_at = -100.0
	spirit_at = -100.0
	cancel_at = -100.0
	transition_at = -100.0
	skill_preparing = false

func sync_party() -> void:
	var tier: int = battle.power_tier()
	if last_round != battle.round_number:
		skill_targets.clear()
		reset_actions()
		moving = false
		previous_rule = battle.witch
		move_direction = "N"
		stride = 0.0
		last_round = battle.round_number
	if last_tier >= 0 and last_tier != tier:
		# 장비 변경은 표시만 중단. 기존 탄·피해·쿨다운은 보존한다.
		reset_actions()
	last_tier = tier
	visual.witch_sprite.visible = false
	visual.spirit_sprite.visible = false
	if frozen() and witch.sprite_frames != null:
		cancel_skill_preview()
		return
	var unit: float = battle.content_width / 540.0
	var family := "witch-wand" if tier == 0 else "witch-cannon"
	var age := clock - shot_at
	var skill_age := clock - skill_at
	var column := 0 if fmod(clock, 2.8) < 2.56 else 1
	var key := family + "-actions"
	var columns := 8
	state = "ready"
	facing = move_direction
	if skill_preparing:
		column = 5
		state = "skill_prepare"
		facing = skill_direction
	elif skill_age < .14:
		column = 6
		state = "skill_release"
		facing = skill_direction
	elif skill_age < .30:
		column = 7
		state = "skill_recover"
		facing = skill_direction
	elif skill_age < .44 or clock - cancel_at < .12:
		column = 4
		state = "skill_settle"
		facing = skill_direction
	elif age < .29:
		facing = aim_direction
		state = "release" if age < .055 else "recoil" if age < .16 else "recover"
		if moving:
			key = family + "-moving"
			columns = 4
			column = int(stride) % 4
		elif age < .055:
			key = family + "-directions"
			columns = 6
			column = 5
		else:
			column = 3 if age < .16 else 4
	elif battle.phase == battle.Phase.WON or battle.phase == battle.Phase.LOST:
		facing = "S"
		var result_age: float=maxf(0.0,battle.elapsed-battle.result_at+.45)
		state = "victory_react" if battle.phase==battle.Phase.WON else "result_recover"
		if battle.phase==battle.Phase.WON:
			column=5 if result_age<.25 else 6 if result_age<.65 else 7 if result_age<1.05 else column
		elif result_age<.35:
			column=4
	elif battle.shot_clock < .12 and not battle.enemies.is_empty():
		key = family + "-directions"
		columns = 6
		column = 4
		state = "anticipate"
		facing = target_facing()
	elif clock - transition_at < .08:
		column = 2
		state = "turn" if turning else "start" if moving else "settle"
	elif moving:
		key = family + "-directions"
		columns = 6
		column = int(stride) % 4
		state = "walk"
	pose_key = key
	var index := direction_row(facing) * columns + column
	_pose(witch, key, index, visual.witch_shadow.position, visual.actor_height("wand" if tier==0 else "cannon")*unit)
	if facing in ["NW","W","SW"]:
		witch.scale.x *= -1.0
	legs.visible = moving and (state in ["release","recoil","recover","skill_prepare","skill_release","skill_recover","skill_settle"])
	if legs.visible:
		split_legs(witch,legs,family,move_direction,stride,visual.witch_shadow.position,visual.actor_height("wand" if tier==0 else "cannon")*unit,unit)
	else:
		witch.material.set_shader_parameter("split_part",0)
	var mark: Array = metadata[key].cells[index].muzzle_uv
	muzzle = _pixel(witch, key, index, Vector2(mark[0],mark[1]))
	aim_axis = (shot_target - muzzle).normalized() if age < .29 else Vector2.UP
	breech = muzzle - aim_axis * 20.0 * unit
	visual.witch_muzzle.position = visual.witch_sprite.to_local(to_global(muzzle))
	var fox_column := int(clock * 4.0) % 2
	if clock - spirit_at < .12:
		fox_column = 3
	elif battle.shot_clock < .10 and (battle.total_shots + 1) % 3 == 0:
		fox_column = 2
		spirit_direction = target_facing()
	elif clock - spirit_at > .30:
		spirit_direction = move_direction
	var fox_index := direction_row(spirit_direction) * 4 + fox_column
	_pose(spirit, "spirit-directions", fox_index, visual.spirit_sprite.position + Vector2(0,22*unit),visual.actor_height("spirit")*unit)
	if spirit_direction in ["NW","W","SW"]:
		spirit.scale.x *= -1.0
	spirit.visible = battle.spirit
	var mouth: Array = metadata["spirit-directions"].cells[fox_index].muzzle_uv
	spirit_mouth = _pixel(spirit,"spirit-directions",fox_index,Vector2(mouth[0],mouth[1]))

func split_legs(upper: AnimatedSprite2D, lower: AnimatedSprite2D, family: String, move_facing: String, gait: float, ground: Vector2, height: float, unit: float) -> void:
	_pose(lower,family+"-moving",direction_row(move_facing)*4+int(gait)%4,ground,height)
	if move_facing in ["NW","W","SW"]:lower.scale.x *= -1.0
	if upper.material == null:
		upper.material = ShaderMaterial.new()
		upper.material.shader = visual.PULSE
	if lower.material == null:
		lower.material = ShaderMaterial.new()
		lower.material.shader = visual.PULSE
	var upper_key := family+"-actions" if upper.sprite_frames.get_frame_count("poses")==40 else family+"-moving"
	# 발끝 피벗은 접지에 유지하고 의상 아래 연결점의 가로축을 맞춘다.
	# 보행 프레임마다 다른 지지발을 상체 중심으로 쓰면 다리가 옆으로 분리된다.
	lower.position.x += _leg_joint_x(upper,upper_key) - _leg_joint_x(lower,family+"-moving")
	upper.material.set_shader_parameter("split_part",-1)
	upper.material.set_shader_parameter("upper_regions",_region_array(upper,upper_key))
	upper.material.set_shader_parameter("upper_region_count",metadata[upper_key].cells[upper.frame].leg_regions.size())
	lower.material.set_shader_parameter("split_part",1)
	lower.material.set_shader_parameter("leg_regions",_region_array(lower,family+"-moving"))
	lower.material.set_shader_parameter("leg_region_count",metadata[family+"-moving"].cells[lower.frame].leg_regions.size())
	lower.material.set_shader_parameter("pulse",battle.recoil*.6)

func _leg_joint_x(actor: AnimatedSprite2D, key: String) -> float:
	var cell: Dictionary = metadata[key].cells[actor.frame]
	var regions: Array = cell.leg_regions
	var count := mini(3,regions.size())
	var joint := Vector2.ZERO
	for i in range(count):
		var region: Array = regions[i]
		joint += Vector2((float(region[0])+float(region[2]))*.5,float(region[1]))
	joint /= maxf(1.0,count)
	var half := Vector2(cell.region[2],cell.region[3])*.5
	return to_local(actor.to_global(joint-half+actor.offset)).x

func _region_array(actor: AnimatedSprite2D, key: String) -> PackedVector4Array:
	var regions := PackedVector4Array()
	var cell: Dictionary = metadata[key].cells[actor.frame]
	var half := Vector2(cell.region[2],cell.region[3])*.5
	for r in cell.leg_regions:
		var first := actor.to_global(Vector2(r[0],r[1])-half+actor.offset)
		var last := actor.to_global(Vector2(r[2],r[3])-half+actor.offset)
		regions.append(Vector4(minf(first.x,last.x),minf(first.y,last.y),maxf(first.x,last.x),maxf(first.y,last.y)))
	regions.resize(64)
	return regions

func sync(delta: float) -> void:
	if not frozen() and delta > 0.0:
		was_moving = moving
		var old_direction := move_direction
		if previous_rule.is_finite():
			var distance: Vector2 = battle.witch - previous_rule
			moving = distance.length() > .025
			if moving:
				move_direction = direction(distance)
				stride += minf(distance.length() / 8.0, 16.0 * delta)
		var direction_changed := moving and old_direction != move_direction
		if was_moving != moving or direction_changed:
			turning = direction_changed and was_moving
			transition_at = clock
		previous_rule = battle.witch
		clock += minf(delta,.1)
	sync_party()
	var active := {}
	var unit: float = battle.content_width / 540.0
	for enemy in battle.enemies:
		active[enemy.id] = true
		if not enemies.has(enemy.id):
			enemies[enemy.id] = _actor()
		var actor: AnimatedSprite2D = enemies[enemy.id]
		var source: Sprite2D = visual.enemy_sprites[enemy.id]
		source.visible = false
		actor.material = source.material
		var index := (4 if enemy.boss else 0) + int(clock * (3.0 if enemy.boss else 7.0) + enemy.id) % 2
		if enemy.flash > .02:
			index = 6 if enemy.boss else 2
		elif enemy.boss and fmod(clock,2.0) > 1.65:
			index = 6
		var ground: Vector2 = visual.enemy_shadows[enemy.id].position
		_pose(actor,"forest-motion",index,ground,visual.actor_height("boss" if enemy.boss else "seed")*unit)
		last_enemies[enemy.id] = {"position":ground,"boss":enemy.boss,"rule":enemy}
	for id in enemies.keys():
		if not active.has(id):
			var old: AnimatedSprite2D = enemies[id]
			var previous: Dictionary = last_enemies[id]
			if ghosts.size() < 8 and previous.rule.hp <= 0.0:
				old.material = null
				_pose(old,"forest-motion",7 if previous.boss else 3,previous.position,visual.actor_height("boss" if previous.boss else "seed")*unit)
				ghosts.append({"actor":old,"born":clock,"ground":previous.position})
			else:
				old.free()
			enemies.erase(id)
			last_enemies.erase(id)
	for i in range(ghosts.size()-1,-1,-1):
		var ghost: Dictionary = ghosts[i]
		var age: float = clock - ghost.born
		if age > .42:
			ghost.actor.free()
			ghosts.remove_at(i)
		else:
			ghost.actor.position = ghost.ground + Vector2(0,-sin(minf(age/.42,1.0)*PI)*16*unit)
			ghost.actor.modulate.a = 1.0-age/.42
