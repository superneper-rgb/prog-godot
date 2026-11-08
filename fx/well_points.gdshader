// The 70 points swirling into a gravity well (JS Gadgets: PointsMaterial size 0.16, additive, 0xcaa0ff, positions rewritten every frame). The same swirl from each point's seed; INSTANCE_CUSTOM = (seed k, seed angle, seed height).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
uniform float t = 0.0;
uniform float r = 1.0;

void vertex() {
	float k = fract(INSTANCE_CUSTOM.x + t * 0.45);
	float rad = r * 0.9 * (1.0 - k) + 0.3;
	float a = INSTANCE_CUSTOM.y + t * (1.5 + (1.0 - k) * 4.0);
	vec3 local = vec3(cos(a) * rad, INSTANCE_CUSTOM.z * rad * 0.35, sin(a) * rad);
	vec3 c = (VIEW_MATRIX * MODEL_MATRIX * vec4(local, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * 0.102, 0.0);    // three.js size 0.16 with size attenuation at the game's field of view
}

void fragment() {
	ALBEDO = vec3(0.591, 0.352, 1.0);             // 0xcaa0ff, linear
	ALPHA = 0.9;
}
