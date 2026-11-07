extends Button
## 실제 그림과 상태별 가격/완료 표시. 누름은 제자리에서 면만 내려간다.
const UiSkin = preload("res://story_skin.gd")
const BROWN := Color("543725")
var symbol := ""
var card := false
var slot := false
var heading := ""
var value := ""
var price := ""
var detail := ""
var state := "ready"
var cooldown_ratio := 0.0
var press_tween: Tween
var press_amount := 0.0

func _ready() -> void:
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	mouse_exited.connect(_press.bind(false))

func _press(down: bool) -> void:
	if is_instance_valid(press_tween):
		press_tween.kill()
	press_tween = create_tween()
	press_tween.tween_method(_press_frame, press_amount, 1.0 if down else 0.0, 0.08)

func _press_frame(amount: float) -> void:
	press_amount = amount
	queue_redraw()

func _draw() -> void:
	var dy := press_amount * 2.0
	if card:
		draw_texture_rect(UiSkin.icon(symbol),Rect2(9,6+dy,25,25),false)
		_text(heading,Vector2(40,23+dy),13,BROWN)
		var font:=get_theme_font("font")
		var x: float=(size.x-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x)*.5
		draw_string_outline(font,Vector2(x,52+dy),value,HORIZONTAL_ALIGNMENT_LEFT,-1,28,4,BROWN)
		draw_string(font,Vector2(x,52+dy),value,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color.WHITE)
		_center(detail,69+dy,11,BROWN)
		var rect:=Rect2(8,size.y-30+dy,size.x-16,24)
		var price_style:=StyleBoxFlat.new()
		price_style.bg_color=BROWN
		price_style.set_corner_radius_all(8)
		draw_style_box(price_style,rect)
		draw_texture_rect(UiSkin.icon("coin"),Rect2(rect.position+Vector2(7,5),Vector2(14,14)),false)
		_center(("부족 · " if state=="need" else "")+price,size.y-13+dy,17,Color("f29284") if state=="need" else Color.WHITE)
	elif slot:
		var diameter := minf(86.0,size.x-28)
		var art_origin := Vector2((size.x-diameter)*.5,15+dy)
		draw_texture_rect(UiSkin.icon(symbol),Rect2(art_origin,Vector2.ONE*diameter),false,Color(1,1,1,.45 if state=="missing" else 1))
		_text(value,Vector2(size.x-43,23+dy),12,BROWN)
		_center(heading,size.y-34+dy,15,BROWN)
		var color := Color("3b7854") if state=="equipped" else Color("88775e") if disabled else BROWN
		_center(detail,size.y-12+dy,12,color)
	elif not symbol.is_empty():
		var diameter := 24.0 if size.y < 52 else 36.0
		var y := (size.y - diameter) * .5 if size.y < 52 else 7.0
		draw_texture_rect(UiSkin.icon(symbol),Rect2(size.x*.5-diameter*.5,y + dy,diameter,diameter),false)
		if symbol == "star" and cooldown_ratio > 0:
			draw_arc(Vector2(size.x*.5,25),23,-PI*.5,-PI*.5+TAU*cooldown_ratio,32,Color("79558f"),4,true)

func _text(content: String, origin: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_font("font"),origin,content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _center(content: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,Vector2((size.x-width)*.5,y),content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
