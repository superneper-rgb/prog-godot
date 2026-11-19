// A boost pad on the Overcurrent's deck (sky_course.gd _build_pads): chevrons running forward. UV: x across, y 0..1 along the pad.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;

uniform vec3 glow : source_color = vec3(0.35, 0.95, 1.0);

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float v = UV.y * 4.0 - x * 0.7 - TIME * 3.2;
	float chev = 1.0 - smoothstep(0.18, 0.32, abs(fract(v) - 0.5));
	float frame = smoothstep(0.86, 0.92, x) + smoothstep(0.04, 0.0, UV.y) + smoothstep(0.96, 1.0, UV.y);
	ALBEDO = glow * (chev * 1.6 + clamp(frame, 0.0, 1.0) * 0.7 + 0.08);
}
