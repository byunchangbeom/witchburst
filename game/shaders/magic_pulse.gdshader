shader_type canvas_item;
// Compatibility에서 HDR/bloom 없이 색을 살짝 밝히는 국소 맥동.
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.7, 1.0, 0.72, 1.0);
void fragment() {
	// 원색과 가장자리 알파를 두 번 곱하지 않는다.
	vec4 tex = COLOR;
	COLOR = vec4(mix(tex.rgb, min(vec3(1.0), tex.rgb + tint.rgb * 0.32), pulse), tex.a);
}
