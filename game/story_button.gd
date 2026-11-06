extends Button
## 종이·민트 카드와 작은 기능 아이콘. 모든 버튼의 눌림 반응을 공유한다.

const BROWN := Color("543725")
var symbol := ""
var card := false
var heading := ""
var value := ""
var price := ""
var press_tween: Tween

func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	mouse_exited.connect(_press.bind(false))

func _press(down: bool) -> void:
	if is_instance_valid(press_tween):
		press_tween.kill()
	press_tween = create_tween()
	press_tween.tween_property(self, "scale", Vector2.ONE * (0.96 if down else 1.0), 0.09).set_trans(Tween.TRANS_QUAD)

func _draw() -> void:
	var font := get_theme_font("font")
	if card:
		_icon(Vector2(22, 23), 12.0)
		draw_string(font, Vector2(42, 29), heading, HORIZONTAL_ALIGNMENT_LEFT, size.x - 46, 17, BROWN)
		_center(value, 63, 30, BROWN)
		var plate := StyleBoxFlat.new()
		plate.bg_color = BROWN
		plate.set_corner_radius_all(12)
		draw_style_box(plate, Rect2(10, size.y - 35, size.x - 20, 27))
		_center(price, size.y - 14, 20, Color("ffe9ab") if not disabled else Color("ddcdb3"))
	elif not symbol.is_empty():
		_icon(Vector2(size.x * 0.5, 22), 13.0)

func _center(content: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, y), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _icon(center: Vector2, radius: float) -> void:
	var fill := Color("ffe295")
	match symbol:
		"leaf":
			var points := PackedVector2Array([center + Vector2(-radius, 5), center + Vector2(-3, -radius), center + Vector2(radius, -6), center + Vector2(5, radius)])
			draw_colored_polygon(points, Color("8fcc85"))
			points.append(points[0])
			draw_polyline(points, BROWN, 3, true)
			draw_line(center + Vector2(-9, 9), center + Vector2(8, -7), BROWN, 2, true)
		"cannon":
			draw_line(center + Vector2(-10, 9), center + Vector2(10, -8), BROWN, 15, true)
			draw_line(center + Vector2(-10, 9), center + Vector2(10, -8), Color("9de3ca"), 10, true)
			draw_circle(center + Vector2(10, -8), 8, BROWN)
			draw_circle(center + Vector2(10, -8), 5, fill)
		"speed":
			var points := PackedVector2Array([center + Vector2(3, -14), center + Vector2(-11, 2), center + Vector2(-1, 2), center + Vector2(-4, 14), center + Vector2(12, -4), center + Vector2(2, -4)])
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, BROWN, 2.5, true)
		"sound":
			draw_line(center + Vector2(-7, 5), center + Vector2(-7, -10), BROWN, 4, true)
			draw_line(center + Vector2(-7, -10), center + Vector2(9, -13), BROWN, 4, true)
			draw_line(center + Vector2(9, -13), center + Vector2(9, 2), BROWN, 4, true)
			draw_circle(center + Vector2(-10, 6), 5, fill)
			draw_circle(center + Vector2(6, 3), 5, fill)
		_:
			var points := PackedVector2Array()
			for i in range(10):
				points.append(center + Vector2.from_angle(-PI / 2 + i * TAU / 10) * (radius if i % 2 == 0 else radius * 0.47))
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, BROWN, 2.5, true)
