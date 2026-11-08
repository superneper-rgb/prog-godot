// FOINT goon: the health bar (the robots' look): dark background + fill in one camera-facing quad, never depth tested.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec4 fill = vec4(0.5, 0.5, 0.5, 1.0);      // rgb, a = the fraction left

void vertex() {
	vec4 view = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	view.xy += VERTEX.xy;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	// the quad is 0.9 x 0.1; the fill 0.86 x 0.06, shrinking to its left end
	vec2 p = (UV - vec2(0.5)) * vec2(0.9, 0.1);
	bool inside = abs(p.y) < 0.03 && p.x > -0.43 && p.x < -0.43 + 0.86 * fill.a;
	ALBEDO = inside ? fill.rgb : vec3(0.0030, 0.0048, 0.0091);
	ALPHA = inside ? 1.0 : 0.8;
}
