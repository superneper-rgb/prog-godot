// JS FlailSwingTrail: a short, fading blue-white ribbon follows the moving head; it never replaces the physical chain.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

void fragment() {
	float w = pow(max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0)), 0.7);
	ALBEDO = vec3(0.43, 0.73, 1.0);
	ALPHA = COLOR.a * w * 0.42;
}
