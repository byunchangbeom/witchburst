extends RefCounted
## 제품의 지형 헬퍼를 쓰지 않고, 불투명 발 픽셀과 실제 Sprite 변환을 읽는다.
var contours: Dictionary = {}
var terrain_image: Image

func _rock(color: Color) -> bool:
	return color.r > color.g + 0.12 and color.g < 0.70 and color.r > 0.28


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
	var rock_samples := 0
	var shadow_rock_fraction := 0.0
	if terrain_image == null:
		terrain_image = visual.MEADOW.get_image()
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
			var tx := clampi(int(raw.x), 0, terrain_image.get_width() - 1)
			var ty := clampi(int(raw.y), 0, terrain_image.get_height() - 1)
			if _rock(terrain_image.get_pixel(tx, ty)):
				rock_samples += 1
			if sprite == visual.witch_shadow:
				var brown := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						if _rock(terrain_image.get_pixel(clampi(tx + dx, 0, terrain_image.get_width()-1), clampi(ty + dy, 0, terrain_image.get_height()-1))):
							brown += 1
				shadow_rock_fraction = maxf(shadow_rock_fraction, float(brown)/25.0)
	return {"min_diagonal": minimum, "max_diagonal": maximum, "samples": count, "rock_fraction": float(rock_samples)/count, "shadow_rock_fraction": shadow_rock_fraction,
		"shift": [visual.party_shift.x, visual.party_shift.y],
		"rule": [battle.witch.x, battle.witch.y],
		"display": [battle._world(battle.witch).x + visual.party_shift.x, battle._world(battle.witch).y + visual.party_shift.y]}
