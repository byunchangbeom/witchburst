shader_type canvas_item;
// 알파를 보존한 피격 흰색 섬광. 적 Sprite2D마다 개별 재질을 사용한다.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	// fragment의 COLOR에는 이미 텍스처와 CanvasItem 색이 적용돼 있다.
	vec4 tex = COLOR;
	COLOR = vec4(mix(tex.rgb, vec3(1.0, 0.98, 0.85), flash), tex.a);
}
