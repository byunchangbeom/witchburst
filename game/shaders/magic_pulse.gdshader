shader_type canvas_item;
// Compatibility에서 기존 국소 맥동과 실제 부위 프레임 선택만 수행한다.
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.7, 1.0, 0.72, 1.0);
uniform int split_part = 0;
uniform int upper_region_count = 0;
uniform int leg_region_count = 0;
uniform vec4 upper_regions[64];
uniform vec4 leg_regions[64];
varying vec2 actor_world;
void vertex() { actor_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 tex = COLOR;
	if (split_part != 0) {
		bool inside = false;
		int count = split_part < 0 ? upper_region_count : leg_region_count;
		for (int i = 0; i < 64; i++) {
			if (i >= count) { break; }
			if (i < count) {
				vec4 r = split_part < 0 ? upper_regions[i] : leg_regions[i];
				if (actor_world.x >= r.x && actor_world.x < r.z && actor_world.y >= r.y && actor_world.y < r.w) { inside = true; }
			}
		}
		if ((split_part < 0 && inside) || (split_part > 0 && !inside)) { tex.a = 0.0; }
	}
	COLOR = vec4(mix(tex.rgb, min(vec3(1.0), tex.rgb + tint.rgb * 0.32), pulse), tex.a);
}
