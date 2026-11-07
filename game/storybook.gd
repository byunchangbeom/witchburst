extends Node2D
## 전투 자료를 읽는 표현 계층. 규칙·저장·전투 난수에는 쓰지 않는다.

const STARTER = preload("res://assets/art/witch-starter.png")
const CANNON = preload("res://assets/art/witch-cannon.png")
const LEGACY_MEADOW = preload("res://assets/art/sunlit-meadow.png")
const REFERENCE_MEADOW = preload("res://assets/art/reference-meadow.png")
var MEADOW: Texture2D = LEGACY_MEADOW
const UiSkin = preload("res://story_skin.gd")
const CREATURES = preload("res://assets/art/forest-creatures.png")
const FLASH = preload("res://shaders/hit_flash.gdshader")
const PULSE = preload("res://shaders/magic_pulse.gdshader")
const BROWN := Color("543725")
const MAX_EMITTERS := 12
const PARTICLES_PER_EMITTER := 18

var battle: Control
var background: Sprite2D
var witch_sprite: Sprite2D
var witch_muzzle: Marker2D
var shot_origins: Array[Dictionary] = []
const MAX_SALVOS := 16
var salvos: Array[Dictionary] = []
var reward_bursts: Array[Dictionary] = []
var impact_pulses: Array[Dictionary] = []
var salvo_round := -1
var salvo_layer: Node2D
var spirit_sprite: Sprite2D
var enemy_sprites: Dictionary = {}
var emitters: Array[CPUParticles2D] = []
var emitter_life: Array[float] = []
var seed_texture: AtlasTexture
var boss_texture: AtlasTexture
var spirit_texture: AtlasTexture
var star_texture: ImageTexture
var leaf_texture: ImageTexture
var breath: Tween
var breath_amount := 0.0
var kick := 0.0
var shot_tween: Tween
var hit_tweens: Dictionary = {}
var last_flashes: Dictionary = {}
var emitter_positions: Array[Vector2] = []
var shadow_texture: ImageTexture
var witch_shadow: Sprite2D
var enemy_shadows: Dictionary = {}
var party_shift := Vector2.ZERO
var motion: Node2D

func actor_height(kind: String) -> float:
	return {"wand":50.0,"cannon":76.0,"spirit":34.0,"seed":40.0,"boss":120.0}[kind]

func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = CREATURES
	texture.region = region
	texture.filter_clip = true
	return texture

func _material(shader: Shader) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	return result

func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = -1
	add_child(sprite)
	return sprite

func setup(owner_battle: Control) -> void:
	battle = owner_battle
	# 지형 canvas 기준은 보존하고 실제 표시/픽셀 검사는 새 자산을 함께 읽는다.
	var picture := REFERENCE_MEADOW.get_image()
	picture.resize(LEGACY_MEADOW.get_width(),LEGACY_MEADOW.get_height(),Image.INTERPOLATE_LANCZOS)
	MEADOW = ImageTexture.create_from_image(picture)
	# 전투 그림·숫자·입자는 HUD와 공방/결과 창보다 뒤에서 그린다.
	z_index = -1
	seed_texture = _atlas(Rect2(140, 144, 415, 530))
	boss_texture = _atlas(Rect2(724, 0, 724, 710))
	spirit_texture = _atlas(Rect2(1558, 10, 500, 700))
	background = _sprite(MEADOW)
	background.z_index = -10
	background.modulate = Color(1.0,1.0,1.0,.83)
	salvo_layer = Node2D.new()
	salvo_layer.name = "SalvoAfterglow"
	salvo_layer.z_index = -3
	add_child(salvo_layer)
	salvo_layer.draw.connect(_draw_salvos)
	var shadow := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	shadow.fill(Color.TRANSPARENT)
	for y in range(24):
		for x in range(64):
			var distance := Vector2((x - 31.5) / 32.0, (y - 11.5) / 12.0).length()
			if distance < 1.0:
				shadow.set_pixel(x, y, Color(BROWN, (1.0 - distance) * 0.28))
	shadow_texture = ImageTexture.create_from_image(shadow)
	witch_shadow = _sprite(shadow_texture)
	witch_shadow.z_index = -2
	witch_sprite = _sprite(STARTER)
	witch_sprite.material = _material(PULSE)
	witch_muzzle = Marker2D.new()
	witch_sprite.add_child(witch_muzzle)
	spirit_sprite = _sprite(spirit_texture)
	spirit_sprite.material = _material(PULSE)
	# 표현 전용 호흡 Tween. 시뮬레이션 시각과 난수는 변경하지 않는다.
	breath = create_tween().set_loops()
	breath.tween_property(self, "breath_amount", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	breath.tween_property(self, "breath_amount", -1.0, 0.8).set_trans(Tween.TRANS_SINE)
	star_texture = _particle_texture(false)
	leaf_texture = _particle_texture(true)
	for i in range(MAX_EMITTERS):
		var emitter := CPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		emitter.amount = PARTICLES_PER_EMITTER
		emitter.lifetime = 0.65
		emitter.explosiveness = 1.0
		emitter.spread = 180.0
		emitter.direction = Vector2.UP
		emitter.initial_velocity_min = 35.0
		emitter.initial_velocity_max = 100.0
		emitter.gravity = Vector2(0, 65)
		emitter.scale_amount_min = 0.5
		emitter.scale_amount_max = 1.0
		emitter.z_index = 0
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		emitter.color_ramp = gradient
		add_child(emitter)
		emitters.append(emitter)
		emitter_life.append(0.0)
		emitter_positions.append(Vector2.ZERO)
	sync(0.0)
	motion = preload("res://living_motion.gd").new()
	add_child(motion)
	motion.setup(self)

func play_shot(bullet: Dictionary) -> void:
	_sync_salvos()
	if is_instance_valid(shot_tween):
		shot_tween.kill()
	kick = 1.0
	if is_instance_valid(motion):
		motion.on_shot(bullet, battle.bullets.any(func(item: Dictionary) -> bool: return item.get("spirit", false) and not shot_origins.any(func(shot: Dictionary) -> bool: return is_same(shot.bullet, item))))
	# 반동·호흡을 먼저 적용한 그림의 실제 포구를 탄과 입자가 공유한다.
	_sync_witch()
	var muzzle: Vector2 = battle._from_screen(to_local(witch_muzzle.global_position))
	# 원본 그림에서 판독한 지팡이/포신 축을 실제 Sprite 변환으로 읽는다.
	var breech := Vector2(264, 65) if battle.power_tier() == 0 else Vector2(144, 100)
	var axis: Vector2 = (witch_muzzle.global_position - witch_sprite.to_global(breech)).normalized()
	if is_instance_valid(motion):
		axis = (motion.muzzle - motion.breech).normalized()
	_prune_shots()
	shot_origins.append({"bullet": bullet, "start": bullet.pos, "muzzle": muzzle, "axis": axis})
	for linked in battle.bullets:
		if linked.get("spirit", false) and not shot_origins.any(func(shot: Dictionary) -> bool: return is_same(shot.bullet, linked)):
			# 원본 아틀라스의 입 앞쪽을 현재 진동·공통 변위가 적용된 그림에서 읽는다.
			var start: Vector2 = to_local(spirit_sprite.to_global(Vector2(420, 340) - spirit_texture.get_size() * 0.5))
			if is_instance_valid(motion):
				start = motion.spirit_mouth
			var target: Dictionary = battle._enemy_by_id(linked.target)
			shot_origins.append({"bullet": linked, "start": linked.pos, "muzzle": battle._from_screen(start),
				"axis": (_point(target.pos) - start).normalized()})
	for shot: Dictionary in shot_origins:
		if shot.bullet.tier >= 2 and not shot.has("salvo"):
			if salvos.size() >= MAX_SALVOS:
				salvos.pop_front()
			var salvo := {"shot": shot, "points": PackedVector2Array([battle._from_screen(projectile_position(shot.bullet))]),
				"tier": shot.bullet.tier, "linked": shot.bullet.get("spirit",false), "ended": -1.0}
			# 상호 참조 없이 발사당 한 번만 등록한다.
			shot.salvo = true
			salvos.append(salvo)
	_emit_at(battle._world(muzzle), battle.MINT, 3 + battle.power_tier() * 2)
	shot_tween = create_tween()
	shot_tween.tween_property(self, "kick", 0.0, 0.16 + battle.power_tier() * 0.025).set_trans(Tween.TRANS_QUAD)

func _prune_shots() -> void:
	shot_origins = shot_origins.filter(func(shot: Dictionary) -> bool:
		return battle.bullets.any(func(bullet: Dictionary) -> bool: return is_same(bullet, shot.bullet)))

func play_impact(bullet: Dictionary, target: Vector2) -> void:
	# 실제 적중에만 짧고 응집된 섬광을 더한다. 새 피해나 보상 호출은 없다.
	if bullet.tier >= 1:
		if impact_pulses.size() >= 16:
			impact_pulses.pop_front()
		impact_pulses.append({"pos":target,"born":motion.clock,"tier":bullet.tier,"linked":bullet.get("spirit",false)})
	# 판정 직전의 실제 적중 통지만 받는다. 표시 효과가 피해를 호출하지 않는다.
	for salvo: Dictionary in salvos:
		if is_same(salvo.shot.bullet,bullet):
			_append_salvo_point(salvo,_point(target))
			salvo.ended = motion.clock

func play_reward(target: Vector2) -> void:
	# 실제 지급 통지의 아이콘만 오래 흩뿌린 뒤 지갑으로 모은다.
	_sync_salvos()
	if reward_bursts.size() >= 4:
		reward_bursts.pop_front()
	reward_bursts.append({"pos":target,"born":motion.clock,"tier":battle.power_tier()})

func _append_salvo_point(salvo: Dictionary, point: Vector2) -> void:
	var points: PackedVector2Array = salvo.points
	var logical: Vector2 = battle._from_screen(point)
	if points[-1].distance_to(logical) >= .5:
		points.append(logical)
		if points.size() > 64:
			points.remove_at(1)
		salvo.points = points

func _sync_salvos() -> void:
	if salvo_round != battle.round_number:
		salvos.clear()
		reward_bursts.clear()
		impact_pulses.clear()
		salvo_round = battle.round_number
	for salvo: Dictionary in salvos:
		if salvo.ended >= 0.0:
			continue
		var bullet: Dictionary = salvo.shot.bullet
		if battle.bullets.any(func(item: Dictionary) -> bool: return is_same(item,bullet)):
			_append_salvo_point(salvo,projectile_position(bullet))
		else:
			# 표적 소멸/장면 전환으로 사라진 탄에는 가짜 적중점을 추가하지 않는다.
			salvo.ended = motion.clock
	impact_pulses = impact_pulses.filter(func(pulse: Dictionary) -> bool: return motion.clock-pulse.born < .18)
	var hold := .32
	salvos = salvos.filter(func(salvo: Dictionary) -> bool: return salvo.ended < 0.0 or motion.clock - salvo.ended < hold)
	reward_bursts = reward_bursts.filter(func(burst: Dictionary) -> bool: return motion.clock-burst.born < 1.0+burst.tier*.35)

func salvo_strand(salvo: Dictionary, lane: int) -> PackedVector2Array:
	var strand := PackedVector2Array()
	var points: PackedVector2Array = salvo.points
	if points.size() < 2:
		return strand
	var unit: float = battle.content_width / 540.0
	for i in range(points.size()):
		var tangent: Vector2 = battle._world(points[mini(i+1,points.size()-1)]) - battle._world(points[maxi(0,i-1)])
		var t := float(i) / (points.size()-1)
		# 같은 한 발의 마력 분지. 실제 지난 경로 양옆으로 펼쳐졌다 실제 적중점에 합류한다.
		strand.append(battle._world(points[i]) + tangent.normalized().orthogonal() * sin(t*PI) * lane * (2.0 + salvo.tier*.7) * unit)
	return strand

func projectile_position(bullet: Dictionary) -> Vector2:
	for shot in shot_origins:
		if is_same(shot.bullet, bullet):
			return _flight_point(shot, bullet.pos.distance_to(shot.start))
	return _point(bullet.pos)

func _flight_point(shot: Dictionary, traveled: float) -> Vector2:
	# 처음 28단위는 포신 축으로 전진하고 이후 표적으로 부드럽게 휘어진다.
	# 피해·충돌·수명은 기존 규칙 좌표만 사용한다. 표현을 규칙에 되먹이지 않는다.
	var unit: float = battle.content_width / 540.0
	var muzzle: Vector2 = battle._world(shot.muzzle)
	var lead: Vector2 = muzzle + shot.axis * minf(traveled, 28.0) * unit
	if traveled <= 28.0:
		return lead
	var target: Dictionary = battle._enemy_by_id(shot.bullet.target)
	if target.is_empty():
		return _point(shot.bullet.pos)
	var end := _point(target.pos)
	var start: Vector2 = muzzle + shot.axis * 28.0 * unit
	var distance: float = shot.bullet.pos.distance_to(shot.start)
	var remaining: float = shot.bullet.pos.distance_to(target.pos) + distance - traveled
	var t := clampf((traveled - 28.0) / maxf(traveled - 28.0 + remaining, 0.001), 0.0, 1.0)
	var handle := minf(90.0 * unit, start.distance_to(end) * 0.4)
	return start.bezier_interpolate(start + shot.axis * handle, end - (end - start).normalized() * handle, end, t)

func projectile_tail(bullet: Dictionary) -> Vector2:
	var point := projectile_position(bullet)
	for shot in shot_origins:
		if is_same(shot.bullet, bullet):
			var unit: float = battle.content_width / 540.0
			var traveled: float = bullet.pos.distance_to(shot.start)
			var length := minf(traveled, 12.0 + bullet.tier * 12.0)
			var previous := _flight_point(shot, traveled - length)
			return point.move_toward(previous, length * unit)
	# 출발점이 없는 탄은 머리만 표시하여 임의의 뒤쪽 궤적을 만들지 않는다.
	return point

func projectile_ribbon(bullet: Dictionary) -> PackedVector2Array:
	# 실제로 지난 유도 경로만 넓힌다. 사격 수·판정·기존 짧은 중심 꼬리는 그대로다.
	var points := PackedVector2Array()
	if bullet.tier == 0:
		return points
	for shot in shot_origins:
		if not is_same(shot.bullet, bullet):
			continue
		var traveled: float = bullet.pos.distance_to(shot.start)
		var length := minf(traveled, 40.0 + bullet.tier * 40.0)
		if length < .01:
			return points
		for i in range(13):
			points.append(_flight_point(shot, traveled - length + length * i / 12.0))
		break
	return points

func _particle_texture(leaf: bool) -> ImageTexture:
	# 신규 별·잎 입자 모양을 엔진에서 생성한다.
	var picture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var p := Vector2(x - 7.5, y - 7.5)
			var inside := absf(p.x) + absf(p.y) < 7.0
			if leaf:
				inside = pow((p.x + p.y * 0.4) / 5.0, 2) + pow(p.y / 7.0, 2) < 1.0
			else:
				inside = absf(p.x) * absf(p.y) < 6.0 and p.length() < 7.5
			if inside:
				picture.set_pixel(x, y, Color("a1df77") if leaf else Color("fff3a3"))
	return ImageTexture.create_from_image(picture)

func emit_burst(pos: Vector2, color: Color, count: int) -> void:
	_emit_at(_point(pos), color, count)

func _emit_at(point: Vector2, color: Color, count: int) -> void:
	for i in range(MAX_EMITTERS):
		if emitter_life[i] > battle.elapsed:
			continue
		var emitter := emitters[i]
		emitter_positions[i] = battle._from_screen(point)
		emitter.position = point
		emitter.texture = leaf_texture if color == battle.MINT and count >= 20 else star_texture
		emitter.amount = mini(count, PARTICLES_PER_EMITTER)
		emitter.color = color
		emitter.initial_velocity_max = 65.0 + battle.power_tier() * 25.0
		emitter.restart()
		emitter.emitting = true
		emitter_life[i] = battle.elapsed + emitter.lifetime + 0.1
		return
	# 모든 슬롯이 사용 중이면 생략하여 노드와 입자 수를 제한한다.

func sync(_delta: float) -> void:
	for i in range(MAX_EMITTERS):
		emitters[i].position = battle._world(emitter_positions[i])
	background.position = battle.size * 0.5
	# 세로 비율이 달라도 나무와 절벽을 찌그러뜨리지 않고 화면을 채운다.
	background.scale = Vector2.ONE * maxf(battle.size.x / MEADOW.get_width(), battle.size.y / MEADOW.get_height())
	_prune_shots()
	_sync_witch()
	var unit: float = battle.content_width / 540.0
	_sync_enemies(unit)
	if is_instance_valid(motion):
		motion.sync(_delta)
		_sync_salvos()
	if is_instance_valid(salvo_layer):
		salvo_layer.queue_redraw()
	queue_redraw()

func _point(pos: Vector2) -> Vector2:
	# 배경 원본의 안전한 풀밭 경계 y=650-0.5x를 화면으로 투영한다.
	# 적 생성 높이에서 가장 많이 보정하고 드래그 영역(490) 전에 0으로
	# 이어 준다. 배경의 cover/crop과 같은 변환을 써서 세 비율을 함께 다룬다.
	var point: Vector2 = battle._world(pos)
	var meadow_scale := maxf(battle.size.x / MEADOW.get_width(), battle.size.y / MEADOW.get_height())
	var origin: Vector2 = (battle.size - MEADOW.get_size() * meadow_scale) * 0.5
	var texture_x := (point.x - origin.x) / meadow_scale
	var grass_y := origin.y + (650.0 - texture_x * 0.5) * meadow_scale
	var spawn_y: float = battle._world(Vector2(pos.x, 245)).y
	var correction := maxf(0.0, grass_y + 16.0 * battle.content_width / 540.0 - spawn_y)
	point.y += correction * clampf((490.0 - pos.y) / 245.0, 0.0, 1.0)
	return point

func _sync_witch() -> void:
	var unit: float = battle.content_width / 540.0
	var tier: int = battle.power_tier()
	witch_sprite.texture = STARTER if tier == 0 else CANNON
	var width := (82.0 if tier == 0 else 96.0 + tier * 6.0) * unit
	var sprite_scale := width / witch_sprite.texture.get_width()
	witch_sprite.scale = Vector2(sprite_scale, sprite_scale * (1.0 + breath_amount * 0.018))
	# 규칙상 포구를 기준으로 그림을 배치하고 표현용 반동·호흡을 더한다.
	var tip := Vector2(405, -95) if tier == 0 else Vector2(594, -95)
	witch_muzzle.position = tip
	witch_sprite.position = battle._world(battle.muzzle_position()) - tip * witch_sprite.scale
	witch_sprite.position += Vector2(-kick * (2.0 + tier * 2.0), breath_amount * 1.5) * unit
	witch_sprite.rotation = -kick * 0.035 * tier
	witch_shadow.position = witch_sprite.position + Vector2(0, 1199 * sprite_scale * 0.47)
	witch_shadow.scale = Vector2.ONE * unit * (0.68 if tier==0 else 0.85)
	witch_sprite.material.set_shader_parameter("pulse", battle.recoil * 0.6)
	spirit_sprite.visible = battle.spirit
	spirit_sprite.position = battle._world(battle.witch + Vector2(-58, -18)) + Vector2(0, sin(battle.elapsed * 3.0) * 6.0)
	spirit_sprite.scale = Vector2.ONE * 48.0 * unit / spirit_texture.get_height()
	spirit_sprite.material.set_shader_parameter("pulse", 0.45 + sin(battle.elapsed * 3.0) * 0.35)
	# 발 하단의 불투명 범위와 그림자 전체를 실제 Sprite 변환으로 투영한다.
	# 배경 원본 판독 경계 650 < y + 0.5x < 1260 (아래 절벽에서 보수적으로 안쪽) 안의 최소 끝점 이동이다.
	var feet := Rect2(119, 950, 1131, 233) if tier == 0 else Rect2(223, 950, 1021, 238)
	var points := _sprite_corners(witch_sprite, feet)
	points.append_array(_sprite_corners(witch_shadow, Rect2(Vector2.ZERO, Vector2(64, 24))))
	if battle.spirit:
		points.append_array(_sprite_corners(spirit_sprite, Rect2(2, 500, 469, 196)))
	var base: Vector2 = battle._world(battle.witch)
	var lower := -INF
	var upper := INF
	for point in points:
		var raw: Vector2 = background.to_local(to_global(point)) + MEADOW.get_size() * 0.5
		lower = maxf(lower, base.y + (652.0 - raw.y - raw.x * 0.5) * background.scale.y)
		upper = minf(upper, base.y + (1258.0 - raw.y - raw.x * 0.5) * background.scale.y)
	var top: float = battle._world(Vector2(battle.witch.x, 490)).y
	var bottom: float = battle._world(Vector2(battle.witch.x, 660)).y
	# clamp로 y들이 뭉치지 않도록 전체 세로 구간을 양의 기울기로 대응한다.
	var safe_bottom := minf(bottom, upper)
	var safe_top := maxf(lower, minf(top, safe_bottom - (bottom - top) * 0.35))
	var mapped := lerpf(safe_top, safe_bottom, (base.y - top) / (bottom - top))
	if battle.phase in [battle.Phase.WON,battle.Phase.LOST]:
		# 결과 창이 큰 마도구의 발을 덮지 않도록 전환 시간에 맞춰 표현만 정돈한다.
		var result_age: float=maxf(0.0,battle.elapsed-battle.result_at+.45)
		var panel_height: float=196.0 if battle.boss_cleared else 140.0
		var result_floor: float=battle.field_bottom-panel_height-24*unit
		mapped=lerpf(mapped,minf(mapped,result_floor),smoothstep(0.0,.45,result_age))
	party_shift = Vector2(0, mapped - base.y)
	witch_sprite.position += party_shift
	witch_shadow.position += party_shift
	spirit_sprite.position += party_shift
	if is_instance_valid(motion):
		motion.sync_party()

func _sprite_corners(sprite: Sprite2D, pixels: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for pixel in [pixels.position, Vector2(pixels.end.x, pixels.position.y), pixels.end, Vector2(pixels.position.x, pixels.end.y)]:
		points.append(to_local(sprite.to_global(pixel - sprite.texture.get_size() * 0.5)))
	return points


func _sync_enemies(unit: float) -> void:
	var active: Array[int] = []
	for enemy in battle.enemies:
		active.append(enemy.id)
		if not enemy_sprites.has(enemy.id):
			var created := _sprite(boss_texture if enemy.boss else seed_texture)
			created.material = _material(FLASH)
			enemy_sprites[enemy.id] = created
			var enemy_shadow := _sprite(shadow_texture)
			enemy_shadow.z_index = -2
			enemy_shadows[enemy.id] = enemy_shadow
		var sprite: Sprite2D = enemy_sprites[enemy.id]
		if enemy.flash > float(last_flashes.get(enemy.id, 0.0)):
			if hit_tweens.has(enemy.id) and is_instance_valid(hit_tweens[enemy.id]):
				hit_tweens[enemy.id].kill()
			sprite.skew = 0.12
			var tween := create_tween()
			tween.tween_property(sprite, "skew", 0.0, 0.2).set_trans(Tween.TRANS_BACK)
			hit_tweens[enemy.id] = tween
		last_flashes[enemy.id] = enemy.flash
		var height: float = actor_height("boss" if enemy.boss else "seed") * unit
		sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
		sprite.scale.y *= 1.0 + sin(battle.elapsed * 3.5 + enemy.id) * 0.025
		sprite.position = _point(enemy.pos) + Vector2(enemy.flash * 5.0, -enemy.flash * 4.0)
		sprite.rotation = sin(battle.elapsed * 2.0 + enemy.id) * 0.035 + enemy.flash * 0.08
		sprite.material.set_shader_parameter("flash", enemy.flash)
		var ground: Sprite2D = enemy_shadows[enemy.id]
		ground.position = _point(enemy.pos) + Vector2(0, height * 0.44)
		ground.scale = Vector2.ONE * (1.8*0.8 if enemy.boss else 0.65*0.68) * unit
	for id in enemy_sprites.keys():
		if id not in active:
			# 즉시 회수하여 headless 고속 진행에도 대기 노드를 쌓지 않는다.
			if hit_tweens.has(id) and is_instance_valid(hit_tweens[id]):
				hit_tweens[id].kill()
			hit_tweens.erase(id)
			last_flashes.erase(id)
			enemy_shadows[id].free()
			enemy_shadows.erase(id)
			enemy_sprites[id].free()
			enemy_sprites.erase(id)

func _draw_salvos() -> void:
	# 실제 궤적만 남기되 캐릭터/표적보다 뒤에서 읽히는 짧고 응집된 광류다.
	if not is_instance_valid(battle) or not is_instance_valid(salvo_layer):
		return
	var unit: float = battle.content_width / 540.0
	for salvo: Dictionary in salvos:
		var fade: float = 1.0 if salvo.ended < 0.0 else clampf(1.0-(motion.clock-salvo.ended)/.32,0.0,1.0)
		var color := Color("ffce6f") if salvo.linked else Color("62dba9")
		var lanes: int = 1 if salvo.tier >= 3 else 0
		for lane in range(-lanes,lanes+1):
			var strand := salvo_strand(salvo,lane)
			if strand.size() < 2:
				continue
			if lane == 0:
				var width: float = (16.0 + salvo.tier * 16.0) * unit
				salvo_layer.draw_polyline(strand,Color(color,fade*.23),width*1.4,true)
				salvo_layer.draw_polyline(strand,Color(color,fade*.72),width,true)
				salvo_layer.draw_polyline(strand,Color("fffacb",fade*.96),width*.34,true)
			else:
				salvo_layer.draw_polyline(strand,Color(color.lightened(.35),fade*.32),1.6*unit,true)

func _draw() -> void:
	if not is_instance_valid(battle):
		return
	var unit: float = battle.content_width / 540.0
	for pulse: Dictionary in impact_pulses:
		var age: float = clampf((motion.clock-pulse.born)/.18,0.0,1.0)
		var at := _point(pulse.pos)
		var side: float = (12.0+pulse.tier*12.0)*unit*(.8+age*.35)
		var ink := Color("ffe0a0") if pulse.linked else Color("baf9e5")
		draw_texture_rect(star_texture,Rect2(at-Vector2.ONE*side*.5,Vector2.ONE*side),false,Color(ink,(1.0-age)*.82))
		draw_arc(at,side*.38,0.0,TAU,16,Color("fffacb",(1.0-age)*.65),1.8*unit,true)
	for enemy in battle.enemies:
		var p := _point(enemy.pos)
		var width: float = (104.0 if enemy.boss else 42.0) * unit
		var y: float = (88.0 if enemy.boss else 40.0) * unit
		draw_style_box(battle._panel_style(BROWN, BROWN, 4), Rect2(p - Vector2(width / 2, y), Vector2(width, 9)))
		draw_rect(Rect2(p - Vector2(width / 2 - 2, y - 2), Vector2((width - 4) * enemy.hp / enemy.max_hp, 5)), Color("b0ed75"))
	for bullet in battle.bullets:
		var p := projectile_position(bullet)
		var r: float = battle.projectile_radius(bullet.tier) * unit
		var tail := projectile_tail(bullet)
		var linked: bool = bullet.get("spirit", false)
		var ink := Color("ffdf87") if linked else Color("6fddac")
		var ribbon := projectile_ribbon(bullet)
		for i in range(1, ribbon.size()):
			var weight := float(i) / (ribbon.size() - 1)
			# 길이/폭이 성장하되 초기 단발과 HUD를 가리지 않는 반투명 마력이다.
			draw_line(ribbon[i-1], ribbon[i], Color(ink, .12 + weight * .18), r * (1.0 + weight * 1.8), true)
			draw_line(ribbon[i-1], ribbon[i], Color("fffacb", weight * .7), maxf(1.0, r * weight * .6), true)
		if tail.distance_squared_to(p) > 0.0001:
			draw_line(tail, p, BROWN, r * 1.8 + 3, true)
			draw_line(tail, p, ink, r * 1.8, true)
			draw_line(tail, p, Color("fffacb"), r * 0.65, true)
		if bullet.tier>=2 and tail.distance_to(p)>12*unit:
			var normal := (p-tail).normalized().orthogonal()
			for side in [-1.0,1.0]:
				var strand := PackedVector2Array()
				for sample in range(9):
					var t:=sample/8.0
					strand.append(tail.lerp(p,t)+normal*sin(t*PI)*(r+4*unit)*side)
				draw_polyline(strand,Color("bcf7d9"),2.5*unit,true)
		draw_circle(p, r * 0.6, Color.WHITE)
	var reward_visual_budget := 48
	for burst: Dictionary in reward_bursts:
		var amount := mini(3+int(burst.tier)*4,reward_visual_budget)
		reward_visual_budget -= amount
		var age: float = clampf((motion.clock-burst.born)/(1.0+burst.tier*.35),0.0,1.0)
		var target: Vector2 = battle.wallet_label.position+battle.wallet_label.size*.5
		for i in range(amount):
			var angle := i*2.39996
			var spread: Vector2 = Vector2(cos(angle),sin(angle))*(14.0+i*(3.0+burst.tier*1.7))*unit*sin(minf(age*2.0,1.0)*PI*.5)
			var point: Vector2 = (_point(burst.pos)+spread).lerp(target,smoothstep(.65,1.0,age))
			var diameter: float = (11.0+burst.tier)*unit
			var icon := UiSkin.icon("material" if i%4==3 else "coin")
			draw_texture_rect(icon,Rect2(point-Vector2.ONE*diameter*.5,Vector2.ONE*diameter),false,Color(1,1,1,minf((1.0-age)*8,1.0)))
	for floating in battle.floats:
		var p := _point(floating.pos)
		if not floating.text.begins_with("+") and battle.power_tier()>=2:
			var impact_age: float=clampf(1.0-floating.life,0.0,1.0)
			var impact_center: Vector2=_point(floating.pos+Vector2(0,30+impact_age*30))
			draw_arc(impact_center,(10+impact_age*44)*unit,0,TAU,28,Color(.65,1,.83,floating.life*.55),2*unit,true)
		var color: Color = floating.color
		color.a = minf(floating.life * 3.0, 1.0)
		var font_size := 22 if not floating.text.begins_with("+") else 18
		var offset := Vector2(battle.font.get_string_size(floating.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0)
		draw_string_outline(battle.font, p - offset, floating.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(BROWN, color.a))
		draw_string(battle.font, p - offset, floating.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if battle.dragging:
		draw_arc(battle._world(battle.witch) + party_shift, 44 * unit, 0, TAU, 32, Color("fff4be"), 3, true)
	if battle.skill_flash > 0 and is_instance_valid(motion):
		# 판정 순간의 실제 표적에 별비가 도착한다. 보스가 제거돼도 그 위치를 유지한다.
		for target: Vector2 in motion.skill_targets:
			for i in range(7):
				var end: Vector2 = target + Vector2((i-3)*16,8+absi(i-3)*3)*unit
				var start: Vector2 = end + Vector2(-36,-170)*unit
				draw_line(start,end,Color(.4,.85,.72,battle.skill_flash*.7),12*unit,true)
				draw_line(start,end,Color(1,1,.86,battle.skill_flash),4*unit,true)
