extends Control
## 첫 지역 전투. 고정 시간 간격 시뮬레이션과 화면 표현을 분리한다.

enum Phase { FOREST, BOSS, LOST, WON }
const STEP := 1.0 / 120.0
const FOREST_GOAL := 12
const BOSS_HP := 720.0
const BOSS_LIMIT := 24.0
const SKILL_COOLDOWN := 8.0
const INK := Color("eef4e6")
const MUTED := Color("9bb9b3")
const GOLD := Color("ffdb89")
const MINT := Color("8af2cc")
const LAVENDER := Color("c1a9ff")

var phase := Phase.FOREST
var coins := 0
var materials := 0
var levels := {"attack": 0, "speed": 0, "yield": 0}
var kills := 0
var round_number := 1
var total_shots := 0
var total_hits := 0
var total_rewards := 0
var skill_uses := 0
var boss_hp := BOSS_HP
var boss_time := BOSS_LIMIT
var cooldown := 0.0
var elapsed := 0.0
var accumulator := 0.0
var shot_clock := 0.0
var spawn_clock := 0.0
var next_enemy_id := 0
var witch := Vector2(270, 625)
var drag_target := Vector2(270, 625)
var dragging := false
var active_touch := -1
var manual_grace := 0.0
var recoil := 0.0
var skill_flash := 0.0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var font: SystemFont
var sound: Node
var status_label: Label
var wallet_label: Label
var stats_label: Label
var hint_label: Label
var bar: ProgressBar
var upgrades: Dictionary = {}
var skill_button: Button
var sound_button: Button
var result_panel: Panel
var result_title: Label
var result_text: Label
var result_button: Button
var notice := "작은 빛 하나로, 숲을 깨워요."
var notice_time := 5.0
var content_left := 0.0
var content_width := 540.0
var field_bottom := 710.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	random.seed = 725194
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic", "NanumGothic", "sans-serif"])
	font.allow_system_fallback = true
	var game_theme := Theme.new()
	game_theme.default_font = font
	game_theme.default_font_size = 18
	game_theme.set_color("font_color", "Label", INK)
	theme = game_theme
	sound = load("res://sound.gd").new()
	add_child(sound)
	_build_ui()
	resized.connect(_layout_ui)
	_layout_ui()
	_spawn_enemy()
	_refresh_ui()

func attack_damage() -> float:
	return 6.0 * pow(1.5, levels.attack)

func shot_interval() -> float:
	return maxf(0.18, 1.05 / pow(1.22, levels.speed))

func reward_amount() -> int:
	return 8 + levels.yield * 3

func upgrade_cost(kind: String) -> int:
	var base: int = {"attack": 12, "speed": 18, "yield": 14}.get(kind, 0)
	if base == 0:
		return 0
	return int(ceil(base * pow(1.65, levels[kind])))

func power_tier() -> int:
	if levels.attack >= 4:
		return 2
	return 1 if levels.attack >= 2 else 0

func buy_upgrade(kind: String) -> bool:
	if not levels.has(kind):
		return false
	var cost := upgrade_cost(kind)
	if coins < cost:
		return false
	coins -= cost
	levels[kind] += 1
	if kind == "attack":
		shot_clock = minf(shot_clock, 0.1)
	_set_notice({"attack": "마법이 자랐어요! 마도구도 함께 커져요.", "speed": "정령과 박자를 맞춰, 더 빠르게!", "yield": "숲이 더 많은 별빛을 나눠줘요."}[kind])
	_burst(witch, GOLD, 14)
	sound.play("upgrade")
	_refresh_ui()
	return true

func _process(delta: float) -> void:
	advance(delta)
	_refresh_ui()
	queue_redraw()

func advance(delta: float) -> void:
	# 프레임 수가 아닌 경과 초를 누적한다. 검사는 같은 함수를 사용한다.
	accumulator += delta
	while accumulator + 0.0000001 >= STEP:
		accumulator -= STEP
		_tick(STEP)

func _tick(dt: float) -> void:
	elapsed += dt
	recoil = maxf(0.0, recoil - dt * 5.0)
	skill_flash = maxf(0.0, skill_flash - dt * 2.0)
	notice_time = maxf(0.0, notice_time - dt)
	for p in particles:
		p.pos += p.velocity * dt
		p.velocity *= exp(-dt * 3.0)
		p.life -= dt
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	for f in floats:
		f.pos.y -= 30.0 * dt
		f.life -= dt
	floats = floats.filter(func(f: Dictionary) -> bool: return f.life > 0.0)
	if phase == Phase.LOST or phase == Phase.WON:
		return
	cooldown = maxf(0.0, cooldown - dt)
	manual_grace = maxf(0.0, manual_grace - dt)
	if dragging or manual_grace > 0:
		witch = witch.move_toward(drag_target, 520.0 * dt)
	else:
		witch = witch.move_toward(Vector2(270 + sin(elapsed * 0.75) * 93, 625 + sin(elapsed * 1.2) * 13), 65.0 * dt)
	if phase == Phase.BOSS:
		boss_time = maxf(0.0, boss_time - dt)
		if boss_time <= 0.0:
			_finish(false)
			return
	else:
		spawn_clock -= dt
		if spawn_clock <= 0.0 and enemies.size() < 4:
			_spawn_enemy()
			spawn_clock = 1.8
	for enemy in enemies:
		if enemy.boss:
			enemy.pos = Vector2(270 + sin(elapsed * 0.8) * 65, 312 + sin(elapsed) * 12)
		else:
			enemy.pos.y = minf(465.0, enemy.pos.y + 24.0 * dt)
			enemy.pos.x = enemy.origin_x + sin(elapsed * 1.5 + enemy.id) * 16.0
		enemy.flash = maxf(0.0, enemy.flash - dt * 5.0)
	shot_clock -= dt
	if shot_clock <= 0.0 and not enemies.is_empty():
		_fire()
		shot_clock += shot_interval()
	for bullet in bullets:
		bullet.life -= dt
		var target := _enemy_by_id(bullet.target)
		if target.is_empty():
			bullet.life = 0.0
			continue
		var distance: float = bullet.pos.distance_to(target.pos)
		var travel := 620.0 * dt
		if distance <= travel + target.radius:
			bullet.life = 0.0
			_hit(target, bullet.damage)
			if phase == Phase.WON:
				break
		else:
			bullet.pos = bullet.pos.move_toward(target.pos, travel)
	bullets = bullets.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	if phase == Phase.FOREST and kills >= FOREST_GOAL:
		_start_boss()

func _spawn_enemy() -> void:
	var x := random.randf_range(115, 425)
	var hp := 18.0 + floorf(kills / 4.0) * 4.0
	next_enemy_id += 1
	enemies.append({"id": next_enemy_id, "pos": Vector2(x, 245), "origin_x": x, "hp": hp, "max_hp": hp, "radius": 25.0, "boss": false, "flash": 0.0})

func _enemy_by_id(id: int) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return {}

func _fire() -> void:
	var target: Dictionary = enemies[0]
	for enemy in enemies:
		if enemy.pos.distance_squared_to(witch) < target.pos.distance_squared_to(witch):
			target = enemy
	bullets.append({"pos": witch + Vector2(25, -26), "target": target.id, "damage": attack_damage(), "life": 2.0, "tier": power_tier()})
	total_shots += 1
	recoil = 1.0
	_burst(witch + Vector2(25, -26), MINT, 3 + power_tier() * 2)
	sound.play("shot")

func _hit(enemy: Dictionary, damage: float) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp = maxf(0.0, enemy.hp - damage)
	enemy.flash = 1.0
	total_hits += 1
	_burst(enemy.pos, LAVENDER, 6 + power_tier() * 3)
	_float_text(enemy.pos + Vector2(0, -30), str(int(ceil(damage))), INK)
	sound.play("hit")
	if enemy.boss:
		boss_hp = enemy.hp
	if enemy.hp <= 0:
		var reward := reward_amount() * (8 if enemy.boss else 1)
		coins += reward
		materials += 5 if enemy.boss else 1
		total_rewards += reward
		_float_text(enemy.pos + Vector2(0, 10), "+%d 별빛  +%d 잎" % [reward, 5 if enemy.boss else 1], GOLD)
		_burst(enemy.pos, MINT, 25)
		sound.play("reward")
		if enemy.boss:
			_finish(true)
		else:
			kills += 1
			enemies.erase(enemy)

func _start_boss() -> void:
	phase = Phase.BOSS
	enemies.clear()
	bullets.clear()
	boss_hp = BOSS_HP
	boss_time = BOSS_LIMIT
	cooldown = 0.0
	shot_clock = 0.2
	next_enemy_id += 1
	enemies.append({"id": next_enemy_id, "pos": Vector2(270, 312), "hp": BOSS_HP, "max_hp": BOSS_HP, "radius": 64.0, "boss": true, "flash": 0.0})
	_set_notice("가시왕 등장! 별비 스킬로 정화를 도와줘요.")
	_refresh_ui()

func cast_skill() -> bool:
	if phase != Phase.BOSS or cooldown > 0.0:
		return false
	cooldown = SKILL_COOLDOWN
	skill_uses += 1
	skill_flash = 1.0
	sound.play("skill")
	for enemy in enemies.duplicate():
		_hit(enemy, 210.0 + attack_damage() * 5.0)
	_refresh_ui()
	return true

func _finish(won: bool) -> void:
	phase = Phase.WON if won else Phase.LOST
	bullets.clear()
	dragging = false
	active_touch = -1
	sound.play("win" if won else "lose")
	if won:
		enemies.clear()
		_set_notice("숲이 다시 숨 쉬어요. 고마워요, 작은 마녀!")
	_refresh_ui()

func restart_battle() -> void:
	if phase != Phase.LOST and phase != Phase.WON:
		return
	round_number += 1
	phase = Phase.FOREST
	kills = 0
	enemies.clear()
	bullets.clear()
	boss_hp = BOSS_HP
	boss_time = BOSS_LIMIT
	cooldown = 0.0
	shot_clock = 0.2
	spawn_clock = 1.8
	witch = Vector2(270, 625)
	drag_target = witch
	manual_grace = 0.0
	_spawn_enemy()
	_set_notice("강화와 별빛은 그대로! 다시 숲으로 출발해요.")
	_refresh_ui()

func _set_notice(message: String) -> void:
	notice = message
	notice_time = 4.0

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var direction := Vector2.from_angle(random.randf_range(0, TAU))
		particles.append({"pos": pos, "velocity": direction * random.randf_range(35, 150), "life": random.randf_range(0.25, 0.6), "color": color})

func _float_text(pos: Vector2, value: String, color: Color) -> void:
	floats.append({"pos": pos, "text": value, "color": color, "life": 1.0})

func _world(pos: Vector2) -> Vector2:
	return Vector2(content_left + pos.x * content_width / 540.0, 190.0 + (pos.y - 190.0) * (field_bottom - 190.0) / 520.0)

func _from_screen(pos: Vector2) -> Vector2:
	return Vector2((pos.x - content_left) * 540.0 / content_width, 190.0 + (pos.y - 190.0) * 520.0 / (field_bottom - 190.0))

func _drag_position(pos: Vector2) -> void:
	var local_pos := _from_screen(pos)
	drag_target = Vector2(clampf(local_pos.x, 65, 475), clampf(local_pos.y, 490, 660))
	manual_grace = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.LOST or phase == Phase.WON:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1 and _in_field(event.position):
			active_touch = event.index
			dragging = true
			_drag_position(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			dragging = false
	elif event is InputEventScreenDrag and event.index == active_touch:
		_drag_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		if event.pressed and _in_field(event.position):
			dragging = true
			_drag_position(event.position)
		elif not event.pressed:
			dragging = false
	elif event is InputEventMouseMotion and dragging and active_touch == -1:
		_drag_position(event.position)

func _input(event: InputEvent) -> void:
	# UI 위에서 손을 떼도 드래그가 남지 않게 해제만 전역에서 처리한다.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		dragging = false
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch:
		dragging = false
		active_touch = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		active_touch = -1

func _in_field(pos: Vector2) -> bool:
	return Rect2(content_left, 195, content_width, field_bottom - 195).has_point(pos)

func _panel_style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _label(text_value: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("819b9a"))
	button.add_theme_stylebox_override("normal", _panel_style(color, color.lightened(0.2)))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), MINT))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.15), GOLD))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("172f39"), Color("2a4650")))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), GOLD))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	add_child(button)
	return button

var title_label: Label
var chapter_label: Label
var footer_label: Label

func _build_ui() -> void:
	title_label = _label("마녀포격단", 28)
	chapter_label = _label("첫 번째 숲  /  잠든 이끼길", 16, MUTED)
	sound_button = _button("소리 켬", Color("294552"))
	sound_button.add_theme_font_size_override("font_size", 15)
	sound_button.pressed.connect(func() -> void:
		sound.enabled = not sound.enabled
		sound_button.text = "소리 켬" if sound.enabled else "소리 끔")
	wallet_label = _label("", 19, GOLD)
	status_label = _label("", 17)
	bar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _panel_style(Color("233d49")))
	bar.add_theme_stylebox_override("fill", _panel_style(MINT))
	add_child(bar)
	hint_label = _label("", 16, MINT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_button = _button("별비 · 보스에서 사용", Color("4a3c72"))
	skill_button.pressed.connect(cast_skill)
	stats_label = _label("", 16, MUTED)
	for kind in ["attack", "speed", "yield"]:
		var button := _button("", Color("254b50"))
		button.pressed.connect(buy_upgrade.bind(kind))
		upgrades[kind] = button
	footer_label = _label("저장 · 합성 · 환생은 후속 제작  |  현재 실행 중 진행만 유지", 13, MUTED)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel = Panel.new()
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color("152d3b"), Color("739b94"), 24))
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_panel)
	result_title = Label.new()
	result_title.add_theme_font_size_override("font_size", 29)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(result_title)
	result_text = Label.new()
	result_text.add_theme_font_size_override("font_size", 17)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(result_text)
	result_button = _button("", Color("416951"))
	remove_child(result_button)
	result_panel.add_child(result_button)
	result_button.pressed.connect(restart_battle)

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout_ui() -> void:
	content_width = minf(size.x, 600.0)
	content_left = (size.x - content_width) * 0.5
	field_bottom = size.y - 258.0
	var left := content_left + 24.0
	var width := content_width - 48.0
	_place(title_label, Rect2(left, 22, width - 110, 40))
	_place(chapter_label, Rect2(left, 64, width, 27))
	_place(sound_button, Rect2(left + width - 90, 28, 90, 48))
	_place(wallet_label, Rect2(left, 106, width, 30))
	_place(status_label, Rect2(left, 144, width, 29))
	_place(bar, Rect2(left, 180, width, 7))
	_place(hint_label, Rect2(left, field_bottom - 44, width, 30))
	_place(skill_button, Rect2(left + width - 208, field_bottom + 6, 208, 54))
	_place(stats_label, Rect2(left, field_bottom + 76, width, 26))
	var index := 0
	for kind in upgrades:
		_place(upgrades[kind], Rect2(left + index * (width + 10) / 3.0, size.y - 140, (width - 20) / 3.0, 86))
		index += 1
	_place(footer_label, Rect2(left - 8, size.y - 40, width + 16, 24))
	_place(result_panel, Rect2(left + 12, 265, width - 24, 235))
	_place(result_title, Rect2(16, 24, width - 56, 45))
	_place(result_text, Rect2(12, 79, width - 48, 63))
	_place(result_button, Rect2(28, 158, width - 80, 54))
	queue_redraw()

func _refresh_ui() -> void:
	if not is_instance_valid(wallet_label):
		return
	wallet_label.text = "✦ 별빛 %d     ·     정화잎 %d" % [coins, materials]
	if phase == Phase.BOSS:
		status_label.text = "가시왕  ·  HP %d / %d     남은 시간 %.1f초" % [ceil(boss_hp), BOSS_HP, boss_time]
		bar.max_value = BOSS_HP
		bar.value = boss_hp
	else:
		status_label.text = "숲 정화 %d / %d     ·     %d번째 탐험" % [kills, FOREST_GOAL, round_number]
		bar.max_value = FOREST_GOAL
		bar.value = kills
	stats_label.text = "마법 %d  ·  초당 %.1f발  ·  정화당 별빛 %d" % [round(attack_damage()), 1.0 / shot_interval(), reward_amount()]
	for kind in upgrades:
		var names := {"attack": "공격력", "speed": "사격 속도", "yield": "획득량"}
		upgrades[kind].text = "%s +%d\n✦ %d  강화" % [names[kind], levels[kind], upgrade_cost(kind)]
		upgrades[kind].disabled = coins < upgrade_cost(kind)
	hint_label.text = notice if notice_time > 0.0 else "자동 전투 중 · 마녀를 끌어 위치를 바꿀 수 있어요"
	skill_button.disabled = phase != Phase.BOSS or cooldown > 0.0
	skill_button.text = "별비 · 보스에서 사용"
	if phase == Phase.BOSS:
		skill_button.text = "별비 · %.1f초" % cooldown if cooldown > 0.0 else "별비 내리기 · 준비!"
	result_panel.visible = phase == Phase.LOST or phase == Phase.WON
	if result_panel.visible:
		result_title.text = "숲이 깨어났어요!" if phase == Phase.WON else "시간이 다 됐어요"
		result_title.add_theme_color_override("font_color", MINT if phase == Phase.WON else GOLD)
		result_text.text = "가시왕 정화! 별빛과 정화잎을 받았어요.\n강화를 이어서 더 큰 마법을 만나보세요." if phase == Phase.WON else "재화와 강화는 그대로 남아요.\n아래에서 강화한 뒤 다시 도전해요."
		result_button.text = "다시 숲으로" if phase == Phase.WON else "강화 유지 · 재도전"

func _draw() -> void:
	if not is_instance_valid(font):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1923"))
	draw_rect(Rect2(content_left, 195, content_width, field_bottom - 195), Color("102d32"))
	# 멀리 있는 나무와 이끼 길. 원본 도형을 조합해 새로 그린다.
	for i in range(10):
		var x := float(i) * 63.0 - 14.0
		var y := 243.0 + sin(i * 2.0) * 15.0
		_tree(Vector2(x, y), 0.8, Color("173d43"))
	draw_colored_polygon(PackedVector2Array([_world(Vector2(210, 230)), _world(Vector2(330, 230)), _world(Vector2(455, 710)), _world(Vector2(85, 710))]), Color("193d3c"))
	for i in range(24):
		var p := Vector2(fmod(i * 91.0 + 17, 510) + 15, 280 + fmod(i * 73.0 + elapsed * 15.0, 390))
		draw_circle(_world(p), 1.5 + sin(elapsed + i) * 0.5, Color(0.56, 0.85, 0.66, 0.25))
	for side in [-1, 1]:
		for i in range(4):
			_tree(Vector2(20 if side == -1 else 520, 310 + i * 108), 0.95 + i * 0.06, Color("205052"))
	for i in range(9):
		var x := 50.0 + fmod(i * 137.0, 440.0)
		var y := 385.0 + fmod(i * 71.0, 270.0)
		var p := _world(Vector2(x, y))
		draw_line(p, p + Vector2(0, -9), Color("709b80"), 2, true)
		draw_circle(p + Vector2(0, -12), 4, Color("b79ccb"))
	if phase == Phase.BOSS:
		draw_arc(_world(Vector2(270, 340)), 98, 0, TAU, 48, Color(0.8, 0.5, 0.8, 0.18), 3, true)
	for enemy in enemies:
		_draw_enemy(enemy)
	for bullet in bullets:
		var p := _world(bullet.pos)
		var radius: float = 4.0 + bullet.tier * 3.0
		draw_circle(p, radius * 2.4, Color(0.5, 1.0, 0.8, 0.12))
		draw_line(p + Vector2(0, 20 + bullet.tier * 7), p, MINT, radius, true)
		draw_circle(p, radius, INK)
	_draw_witch()
	for p in particles:
		var color: Color = p.color
		color.a = minf(p.life * 3.0, 1.0)
		draw_circle(_world(p.pos), 2.8, color)
	for f in floats:
		var color: Color = f.color
		color.a = minf(f.life * 2.0, 1.0)
		var p := _world(f.pos)
		var text_width := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, p - Vector2(text_width * 0.5, 0) + Vector2(1, 2), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("11212c"))
		draw_string(font, p - Vector2(text_width * 0.5, 0), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	if skill_flash > 0:
		for i in range(8):
			var start := _world(Vector2(80 + i * 54, 210))
			var end := _world(Vector2(60 + i * 54, 455))
			draw_line(start, end, Color(0.85, 0.8, 1.0, skill_flash * 0.8), 5, true)
	draw_rect(Rect2(content_left, field_bottom, content_width, size.y - field_bottom), Color("10232e"))
	draw_line(Vector2(content_left + 24, field_bottom), Vector2(content_left + content_width - 24, field_bottom), Color("3c625d"), 1, true)
	draw_string(font, Vector2(content_left + 24, field_bottom + 31), "마녀의 작업대", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(font, Vector2(content_left + 24, field_bottom + 52), "별빛으로 더 강하게", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)

func _tree(pos: Vector2, tree_scale: float, color: Color) -> void:
	var p := _world(pos)
	draw_line(p, p + Vector2(0, 72 * tree_scale), color.darkened(0.15), 12 * tree_scale, true)
	for j in range(3):
		draw_circle(p + Vector2((j - 1) * 19, -j * 13) * tree_scale, (33 - j * 3) * tree_scale, color)

func _draw_enemy(enemy: Dictionary) -> void:
	var p := _world(enemy.pos)
	var r: float = enemy.radius
	var color := Color("9675b3") if enemy.boss else Color("8a83ba")
	if enemy.flash > 0:
		color = color.lerp(INK, enemy.flash)
	draw_set_transform(p + Vector2(0, r * 0.8), 0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.22))
	draw_set_transform(p)
	if enemy.boss:
		for i in range(9):
			var a := -PI + i * PI / 8.0
			var v := Vector2.from_angle(a)
			draw_colored_polygon(PackedVector2Array([v * r * 0.72 + v.orthogonal() * 12, v * (r + 23), v * r * 0.72 - v.orthogonal() * 12]), Color("d4b791"))
		draw_line(Vector2(-r + 4, 15), Vector2(-r - 18, -6 + sin(elapsed * 3) * 8), color, 13, true)
		draw_line(Vector2(r - 4, 15), Vector2(r + 18, -6 + sin(elapsed * 3) * 8), color, 13, true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -15), Vector2(-17, -37), Vector2(0, -22)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(10, -15), Vector2(23, -32), Vector2(24, -5)]), color)
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(0, r * 0.35), r * 0.6, color.lightened(0.1))
	for side in [-1, 1]:
		draw_circle(Vector2(side * r * 0.32, -r * 0.08), 4 if not enemy.boss else 7, Color("292940"))
		draw_circle(Vector2(side * r * 0.32 - 1, -r * 0.08 - 2), 1.5, INK)
		draw_circle(Vector2(side * r * 0.62, r * 0.14), r * 0.13, Color("d79dc4"))
	draw_arc(Vector2(0, r * 0.12), 5 if not enemy.boss else 10, 0.2, PI - 0.2, 12, Color("423752"), 2, true)
	var width := r * 1.7
	draw_rect(Rect2(-width / 2, -r - 16, width, 4), Color("34414c"))
	draw_rect(Rect2(-width / 2, -r - 16, width * enemy.hp / enemy.max_hp, 4), LAVENDER)
	draw_set_transform(Vector2.ZERO)

func _draw_witch() -> void:
	var p := _world(witch)
	var bob := sin(elapsed * 4.0) * 3.0
	draw_set_transform(p + Vector2(0, 31), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 36, Color(0, 0, 0, 0.28))
	draw_set_transform(p + Vector2(-recoil * 3, bob))
	# 장화, 망토, 머리, 큰 모자: 작은 실루엣에서도 마녀임을 읽게 한다.
	draw_line(Vector2(-10, 19), Vector2(-13, 30), Color("503d66"), 9, true)
	draw_line(Vector2(9, 19), Vector2(13, 30), Color("503d66"), 9, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -9), Vector2(16, -9), Vector2(29, 22), Vector2(-29, 22)]), Color("9b82da"))
	draw_line(Vector2(-19, 20), Vector2(18, 20), LAVENDER, 3, true)
	draw_circle(Vector2(0, -20), 24, Color("eab993"))
	draw_circle(Vector2(0, -20), 20, Color("ffe0bd"))
	draw_arc(Vector2(0, -23), 23, PI, TAU, 24, Color("dba082"), 8, true)
	for side in [-1, 1]:
		draw_circle(Vector2(side * 8, -19), 2.8, Color("43354c"))
		draw_circle(Vector2(side * 15, -12), 4, Color("f4adad"))
	draw_arc(Vector2(0, -13), 4, 0, PI, 12, Color("996878"), 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -38), Vector2(-7, -83), Vector2(19, -67), Vector2(24, -38)]), Color("7964ac"))
	draw_line(Vector2(-37, -37), Vector2(34, -37), Color("a48bd7"), 11, true)
	draw_line(Vector2(-20, -47), Vector2(19, -47), GOLD, 5, true)
	_star(Vector2(2, -62), 7, GOLD)
	var tier := power_tier()
	if tier == 0:
		draw_line(Vector2(21, 6), Vector2(29, -30), Color("b5c1a0"), 5, true)
		_star(Vector2(30, -33), 7 + recoil * 3, MINT)
	else:
		var cannon_width := 18.0 if tier == 1 else 30.0
		draw_line(Vector2(26, 13), Vector2(26, -33 - tier * 10), Color("435875"), cannon_width + 7, true)
		draw_line(Vector2(26, 10), Vector2(26, -33 - tier * 10), LAVENDER, cannon_width, true)
		draw_line(Vector2(26, -4), Vector2(26, -20), GOLD, cannon_width + 6, true)
		draw_circle(Vector2(26, -33 - tier * 10), cannon_width * 0.52, Color("275661"))
		draw_circle(Vector2(26, -33 - tier * 10), cannon_width * 0.3 + recoil * 3, MINT)
		if tier == 2:
			for side in [-1, 1]:
				_star(Vector2(26 + side * 27, -13), 8, GOLD)
	draw_set_transform(Vector2.ZERO)
	for i in range(1 + tier):
		var spirit := p + Vector2(-58 - i * 24, -18 + sin(elapsed * 3.0 + i) * 10)
		draw_circle(spirit, 19, Color(0.52, 0.94, 0.8, 0.12))
		draw_circle(spirit, 11, MINT)
		draw_colored_polygon(PackedVector2Array([spirit + Vector2(-7, 4), spirit + Vector2(-14, 17), spirit + Vector2(7, 8)]), MINT)
		draw_circle(spirit + Vector2(-4, -1), 1.8, Color("285461"))
		draw_circle(spirit + Vector2(4, -1), 1.8, Color("285461"))
	if dragging:
		draw_arc(p, 44, 0, TAU, 32, Color(0.65, 1, 0.8, 0.6), 2, true)

func _star(pos: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(pos + Vector2.from_angle(-PI / 2 + i * TAU / 8) * (radius if i % 2 == 0 else radius * 0.4))
	draw_colored_polygon(points, color)
