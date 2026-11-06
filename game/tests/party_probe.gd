extends RefCounted
## 제품의 지형 헬퍼를 쓰지 않고, 불투명 발 픽셀과 실제 Sprite 변환을 읽는다.
var contours: Dictionary = {}

func _feet(sprite: Sprite2D, first_row: int) -> Array[Vector2]:
	var key := sprite.texture.resource_path + str(sprite.texture.get_size()) + str(first_row)
	if not contours.has(key):
		var pixels: Array[Vector2] = []
		var picture := sprite.texture.get_image()
		for y in range(first_row, picture.get_height()):
			var left := -1
			var right := -1
			for x in range(picture.get_width()):
				if picture.get_pixel(x, y).a > 0.1:
					if left < 0:
						left = x
					right = x
			if left >= 0:
				pixels.append(Vector2(left, y))
				pixels.append(Vector2(right, y))
		contours[key] = pixels
	return contours[key]

func measure(battle: Control) -> Dictionary:
	var visual: Node2D = battle.visuals
	var sprites := [visual.witch_sprite, visual.witch_shadow]
	if battle.spirit:
		sprites.append(visual.spirit_sprite)
	var minimum := INF
	var maximum := -INF
	var count := 0
	for sprite: Sprite2D in sprites:
		var pixels: Array[Vector2]
		if sprite == visual.witch_shadow:
			pixels = [Vector2(0, 0), Vector2(64, 0), Vector2(0, 24), Vector2(64, 24)]
		else:
			pixels = _feet(sprite, 500 if sprite == visual.spirit_sprite else 950)
		for pixel in pixels:
			var world: Vector2 = sprite.to_global(pixel - sprite.texture.get_size() * 0.5)
			var raw: Vector2 = visual.background.to_local(world) + visual.MEADOW.get_size() * 0.5
			var diagonal := raw.y + raw.x * 0.5
			minimum = minf(minimum, diagonal)
			maximum = maxf(maximum, diagonal)
			count += 1
	return {"min_diagonal": minimum, "max_diagonal": maximum, "samples": count,
		"shift": [visual.party_shift.x, visual.party_shift.y],
		"rule": [battle.witch.x, battle.witch.y],
		"display": [battle._world(battle.witch).x + visual.party_shift.x, battle._world(battle.witch).y + visual.party_shift.y]}
