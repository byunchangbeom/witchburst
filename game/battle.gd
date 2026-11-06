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

const Store = preload("res://progress_store.gd")
const DRAW_COST := 12
const CRAFT_COST := 3
const SPIRIT_COST := 4
var inventory: Array = [0, 0, 0]
var equipped := -1
var spirit := false
var spirit_shots := 0
var rebirths := 0
var boss_cleared := false
var local_owner_id := ""
var reward_cursor := 0
var saved_at := 0
var pending_coins := 0
var save_path := "user://progress.json"
var store = Store.new()
var save_status := "기기 내 자동 저장"
var save_clock := 0.0
var growth_random := RandomNumberGenerator.new()
var workshop: Panel
var workshop_button: Button
var workshop_text: Label
var draw_button: Button
var craft_button: Button
var merge_button: Button
var spirit_button: Button
var claim_button: Button
var rebirth_button: Button
var equip_buttons: Array[Button] = []
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
	growth_random.randomize()
	# 검사 사본은 기본 사용자 저장에 접근하지 않는다.
	var test_root := OS.get_environment("WITCHBURST_TEST_ROOT")
	if not test_root.is_empty() and save_path == "user://progress.json":
		save_path = test_root.path_join("test-progress.json")
	store.path = save_path
	_load_progress()
	get_tree().auto_accept_quit = false
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
	return 6.0 * pow(1.5, levels.attack) * equipment_multiplier() * (1.0 + rebirths * 0.25)

func equipment_multiplier() -> float:
	return [1.3, 2.1, 3.4][equipped] if equipped >= 0 else 1.0

func projectile_radius(tier: int) -> float:
	return 4.0 + tier * 3.0

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
	return maxi(2 if levels.attack >= 4 else (1 if levels.attack >= 2 else 0), equipped + 1)

func buy_upgrade(kind: String) -> bool:
	if not levels.has(kind) or levels[kind] >= 20:
		return false
	var cost := upgrade_cost(kind)
	if coins < cost:
		return false
	var before := progress_data()
	coins -= cost
	levels[kind] += 1
	if not _commit_growth(before):
		return false
	if kind == "attack":
		shot_clock = minf(shot_clock, 0.1)
	_set_notice({"attack": "마법이 자랐어요! 마도구도 함께 커져요.", "speed": "정령과 박자를 맞춰, 더 빠르게!", "yield": "숲이 더 많은 별빛을 나눠줘요."}[kind])
	_burst(witch, GOLD, 14)
	sound.play("upgrade")
	_refresh_ui()
	return true

func _process(delta: float) -> void:
	advance(delta)
	save_clock += delta
	if save_clock >= 5.0:
		save_clock = 0.0
		save_progress()
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
	if (is_instance_valid(workshop) and workshop.visible) or phase == Phase.LOST or phase == Phase.WON:
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
	# 해금한 정령은 매 세 번째 사격에 연계탄을 보탠다.
	if spirit and total_shots % 3 == 0:
		bullets.append({"pos": witch + Vector2(-58, -18), "target": target.id, "damage": attack_damage() * 0.65, "life": 2.0, "tier": power_tier(), "spirit": true})
		spirit_shots += 1
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
		save_progress()

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
		boss_cleared = true
		enemies.clear()
		_set_notice("숲이 다시 숨 쉬어요. 환생으로 영구 마법 +25%!")
	save_progress()
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
	if workshop.visible or phase == Phase.LOST or phase == Phase.WON:
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_progress():
			get_tree().quit()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not local_owner_id.is_empty():
			save_progress()
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
	workshop_button = _button("장비 · 정령", Color("395569"))
	workshop_button.pressed.connect(toggle_workshop)
	footer_label = _label("", 13, MUTED)
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
	rebirth_button = _button("환생 · 영구 마법 +25%", Color("564276"))
	remove_child(rebirth_button)
	result_panel.add_child(rebirth_button)
	rebirth_button.pressed.connect(rebirth)
	_build_workshop()

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
	_place(workshop_button, Rect2(left, field_bottom + 6, 170, 54))
	_place(skill_button, Rect2(left + width - 208, field_bottom + 6, 208, 54))
	_place(stats_label, Rect2(left, field_bottom + 76, width, 26))
	var index := 0
	for kind in upgrades:
		_place(upgrades[kind], Rect2(left + index * (width + 10) / 3.0, size.y - 140, (width - 20) / 3.0, 86))
		index += 1
	_place(footer_label, Rect2(left - 8, size.y - 40, width + 16, 24))
	_place(result_panel, Rect2(left + 12, 240, width - 24, 330))
	_place(result_title, Rect2(16, 24, width - 56, 45))
	_place(result_text, Rect2(12, 79, width - 48, 108))
	_place(result_button, Rect2(28, 196, width - 80, 54))
	_place(rebirth_button, Rect2(28, 262, width - 80, 54))
	_place(workshop, Rect2(left, 210, width, 460))
	_place(workshop_text, Rect2(16, 14, width - 32, 178))
	_place(draw_button, Rect2(16, 198, (width - 42) / 2, 52))
	_place(craft_button, Rect2(width / 2 + 5, 198, (width - 42) / 2, 52))
	for i in range(3):
		_place(equip_buttons[i], Rect2(16 + i * (width - 22) / 3, 262, (width - 42) / 3, 48))
	_place(merge_button, Rect2(16, 322, (width - 42) / 2, 52))
	_place(spirit_button, Rect2(width / 2 + 5, 322, (width - 42) / 2, 52))
	_place(claim_button, Rect2(16, 386, width - 120, 52))
	_place(workshop.get_node("닫기"), Rect2(width - 94, 386, 78, 52))
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
		upgrades[kind].disabled = coins < upgrade_cost(kind) or levels[kind] >= 20
		if levels[kind] >= 20:
			upgrades[kind].text = names[kind] + " 최대"
	hint_label.text = notice if notice_time > 0.0 else "자동 사격 → 강화 · 장비 합성 → 거대 마법포!"
	footer_label.text = "%s · 가격/확률/배율은 가설" % save_status
	_refresh_workshop()
	skill_button.disabled = phase != Phase.BOSS or cooldown > 0.0
	skill_button.text = "별비 · 보스에서 사용"
	if phase == Phase.BOSS:
		skill_button.text = "별비 · %.1f초" % cooldown if cooldown > 0.0 else "별비 내리기 · 준비!"
	result_panel.visible = phase == Phase.LOST or phase == Phase.WON
	if result_panel.visible:
		result_title.text = "숲이 깨어났어요!" if phase == Phase.WON else "시간이 다 됐어요"
		result_title.add_theme_color_override("font_color", MINT if phase == Phase.WON else GOLD)
		rebirth_button.visible = boss_cleared
		result_text.text = "가시왕 정화! 다시 전투하거나 환생해요.\n환생 초기화: 별빛·잎·강화·장비·보상\n보존: 정령·소유자·환생 수 / 영구 마법 +25%" if phase == Phase.WON else "재화·장비·강화는 그대로 남아요.\n아래 강화 / 장비·정령을 누른 뒤 재도전!"
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
		var radius := projectile_radius(bullet.tier)
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
		if tier >= 2:
			for side in [-1, 1]:
				_star(Vector2(26 + side * 27, -13), 8, GOLD)
	draw_set_transform(Vector2.ZERO)
	for i in range(2 if spirit else 0):
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

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func progress_data() -> Dictionary:
	return {"schema_version": Store.VERSION, "local_owner_id": local_owner_id,
		"saved_at": saved_at, "reward_cursor": reward_cursor, "pending_coins": pending_coins,
		"coins": coins, "materials": materials, "levels": levels.duplicate(),
		"inventory": inventory.duplicate(), "equipped": equipped, "spirit": spirit,
		"rebirths": rebirths, "boss_cleared": boss_cleared}

func _apply_progress(data: Dictionary) -> void:
	local_owner_id = data.local_owner_id
	saved_at = int(data.saved_at)
	reward_cursor = int(data.reward_cursor)
	pending_coins = int(data.pending_coins)
	coins = int(data.coins)
	materials = int(data.materials)
	for kind in levels:
		levels[kind] = int(data.levels[kind])
	inventory = data.inventory.map(func(count: Variant) -> int: return int(count))
	equipped = int(data.equipped)
	spirit = data.spirit
	rebirths = int(data.rebirths)
	boss_cleared = data.boss_cleared

func _load_progress(now: int = -1) -> void:
	var timestamp := _now() if now == -1 else now
	var data: Dictionary = store.load_progress(timestamp)
	if data.is_empty():
		var had_invalid := FileAccess.file_exists(save_path)
		local_owner_id = Crypto.new().generate_random_bytes(16).hex_encode()
		reward_cursor = maxi(0, timestamp)
		saved_at = reward_cursor
		save_progress(timestamp)
		if had_invalid:
			_set_notice("저장을 읽지 못해 새 진행을 시작해요. 원본 보존.")
	else:
		_apply_progress(data)
		if store.recovered:
			_set_notice("백업 복구: 중복 방지를 위해 접속 보상은 생략해요.")
		elif pending_coins > 0:
			_set_notice("돌아왔군요! 장비·정령에서 오프라인 별빛 수령")
	if not store.error_message.is_empty():
		save_status = "저장 실패 · 경로 확인"

func save_progress(now: int = -1) -> bool:
	if local_owner_id.is_empty():
		return false
	var data := progress_data()
	var timestamp := clampi(_now() if now == -1 else now, 0, 4102444800)
	data.saved_at = maxi(saved_at, timestamp)
	data.reward_cursor = maxi(reward_cursor, timestamp)
	if not store.write(data):
		save_status = "저장 실패 · 경로 확인"
		_set_notice(store.error_message)
		return false
	saved_at = data.saved_at
	reward_cursor = data.reward_cursor
	save_status = "기기 내 자동 저장"
	return true

func _commit_growth(before: Dictionary) -> bool:
	if save_progress():
		return true
	_apply_progress(before)
	return false

func _acquire(tier: int) -> void:
	inventory[tier] += 1
	if equipped < tier:
		equipped = tier

func draw_tool() -> int:
	if coins < DRAW_COST or inventory.any(func(count: Variant) -> bool: return count >= 9998):
		return -1
	var before := progress_data()
	var roll := growth_random.randi_range(1, 100)
	var tier := 0 if roll <= 80 else (1 if roll <= 98 else 2)
	coins -= DRAW_COST
	_acquire(tier)
	if not _commit_growth(before):
		return -1
	_set_notice("%s 획득! 더 높은 등급은 자동 장착해요." % tool_name(tier))
	sound.play("upgrade")
	_refresh_ui()
	return tier

func craft_tool() -> bool:
	if materials < CRAFT_COST or inventory[0] >= 9998:
		return false
	var before := progress_data()
	materials -= CRAFT_COST
	_acquire(0)
	if not _commit_growth(before):
		return false
	_set_notice("정화잎으로 새싹 마도구 제작! 2개로 합성해요.")
	sound.play("upgrade")
	_refresh_ui()
	return true

func merge_tool(tier: int) -> bool:
	if tier < 0 or tier >= 2 or inventory[tier] < 2 or inventory[tier + 1] >= 9998:
		return false
	var before := progress_data()
	inventory[tier] -= 2
	_acquire(tier + 1)
	if not _commit_growth(before):
		return false
	_set_notice("합성 성공! %s · 커진 마법탄을 보세요." % tool_name(tier + 1))
	sound.play("upgrade")
	_burst(witch, GOLD, 24)
	_refresh_ui()
	return true

func equip_tool(tier: int) -> bool:
	if tier < -1 or tier > 2 or (tier >= 0 and inventory[tier] < 1):
		return false
	var before := progress_data()
	equipped = tier
	if not _commit_growth(before):
		return false
	_refresh_ui()
	return true

func unlock_spirit() -> bool:
	if spirit or materials < SPIRIT_COST:
		return false
	var before := progress_data()
	materials -= SPIRIT_COST
	spirit = true
	if not _commit_growth(before):
		return false
	_set_notice("정령 해금! 매 3번째 사격에 65% 위력의 연계탄!")
	sound.play("upgrade")
	_refresh_ui()
	return true

func claim_offline() -> bool:
	if pending_coins <= 0 or coins + pending_coins > 1000000000:
		return false
	var before := progress_data()
	var reward := pending_coins
	coins += reward
	pending_coins = 0
	if not _commit_growth(before):
		return false
	_set_notice("오프라인 별빛 +%d (최대 24시간 · 가설)" % reward)
	_refresh_ui()
	return true

func rebirth() -> bool:
	if not boss_cleared or rebirths >= 1000:
		return false
	var before := progress_data()
	coins = 0
	materials = 0
	levels = {"attack": 0, "speed": 0, "yield": 0}
	inventory = [0, 0, 0]
	equipped = -1
	pending_coins = 0
	boss_cleared = false
	rebirths += 1
	if not _commit_growth(before):
		return false
	phase = Phase.WON
	restart_battle()
	workshop.visible = false
	_set_notice("환생 %d회 · 영구 마법 +%d%% / 정령은 함께해요!" % [rebirths, rebirths * 25])
	return true

func tool_name(tier: int) -> String:
	return ["새싹", "달빛포", "거대 성운포"][tier] if tier >= 0 else "별 지팡이"

func toggle_workshop() -> void:
	workshop.visible = not workshop.visible
	dragging = false
	active_touch = -1
	_refresh_ui()

func _merge_available() -> void:
	for tier in range(2):
		if inventory[tier] >= 2:
			merge_tool(tier)
			return

func _build_workshop() -> void:
	workshop = Panel.new()
	workshop.add_theme_stylebox_override("panel", _panel_style(Color("152d3b"), MINT))
	workshop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(workshop)
	workshop_text = _label("", 16)
	remove_child(workshop_text)
	workshop.add_child(workshop_text)
	draw_button = _button("뽑기 ✦12", Color("395569"))
	craft_button = _button("제작 잎3", Color("395569"))
	merge_button = _button("동급 2개 합성", Color("395569"))
	spirit_button = _button("정령 해금 잎4", Color("395569"))
	claim_button = _button("", Color("395569"))
	var close := _button("닫기", Color("584966"))
	close.name = "닫기"
	for button in [draw_button, craft_button, merge_button, spirit_button, claim_button, close]:
		remove_child(button)
		workshop.add_child(button)
	for tier in range(3):
		var button := _button("", Color("395569"))
		remove_child(button)
		workshop.add_child(button)
		equip_buttons.append(button)
		button.pressed.connect(equip_tool.bind(tier))
	draw_button.pressed.connect(draw_tool)
	craft_button.pressed.connect(craft_tool)
	merge_button.pressed.connect(_merge_available)
	spirit_button.pressed.connect(unlock_spirit)
	claim_button.pressed.connect(claim_offline)
	close.pressed.connect(toggle_workshop)
	workshop.visible = false

func _refresh_workshop() -> void:
	workshop_text.text = "장비 · 정령  /  메뉴 중 전투 잠시 멈춤\n✦ %d · 잎 %d / 장착: %s\n새싹 %d · 달빛포 %d · 성운포 %d\n가설: 뽑기 새싹80%% / 달빛18%% / 성운2%%\n제작: 새싹 1개 / 합성: 동급 2 → 상위 1\n환생 %d회 · 영구 마법 +%d%%\n정령: %s" % [coins, materials, tool_name(equipped), inventory[0], inventory[1], inventory[2], rebirths, rebirths * 25, "매 3발 연계탄 65%" if spirit else "잎 4개로 해금"]
	draw_button.disabled = coins < DRAW_COST
	craft_button.disabled = materials < CRAFT_COST
	merge_button.disabled = inventory[0] < 2 and inventory[1] < 2
	spirit_button.disabled = spirit or materials < SPIRIT_COST
	spirit_button.text = "정령 연계 중" if spirit else "정령 해금 잎4"
	for tier in range(3):
		equip_buttons[tier].text = ("장착 중" if equipped == tier else "장착") + " · " + ["새싹", "달빛", "성운"][tier]
		equip_buttons[tier].disabled = inventory[tier] < 1 or equipped == tier
	claim_button.text = "접속 보상 ✦%d 수령" % pending_coins
	claim_button.disabled = pending_coins <= 0
