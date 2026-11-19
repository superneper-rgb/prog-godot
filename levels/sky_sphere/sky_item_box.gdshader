// An Overcurrent item box (sky_items.gd): a turning holographic cube, lit edges cycling colour, a soft glow inside. Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float power = 1.0;

varying vec3 local_pos;

mat3 turn(float a, vec3 axis) {
	float c = cos(a);
	float s = sin(a);
	vec3 k = normalize(axis);
	return mat3(vec3(c + k.x * k.x * (1.0 - c), k.y * k.x * (1.0 - c) + k.z * s, k.z * k.x * (1.0 - c) - k.y * s),
		vec3(k.x * k.y * (1.0 - c) - k.z * s, c + k.y * k.y * (1.0 - c), k.z * k.y * (1.0 - c) + k.x * s),
		vec3(k.x * k.z * (1.0 - c) + k.y * s, k.y * k.z * (1.0 - c) - k.x * s, c + k.z * k.z * (1.0 - c)));
}

void vertex() {
	local_pos = VERTEX;
	float phase = float(INSTANCE_ID) * 1.7;
	VERTEX = turn(TIME * 1.6 + phase, vec3(0.3, 1.0, 0.2)) * VERTEX;
	VERTEX.y += sin(TIME * 2.3 + phase) * 0.12;
	NORMAL = turn(TIME * 1.6 + phase, vec3(0.3, 1.0, 0.2)) * NORMAL;
}

void fragment() {
	vec3 a = abs(local_pos) / 0.625;
	float big = max(a.x, max(a.y, a.z));
	float small = min(a.x, min(a.y, a.z));
	float mid = a.x + a.y + a.z - big - small;
	float edge = smoothstep(0.8, 0.95, mid);
	float hue = fract(TIME * 0.25 + local_pos.y * 0.3);
	vec3 col = 0.55 + 0.45 * cos(6.2832 * (hue + vec3(0.0, 0.33, 0.67)));
	float shimmer = 0.5 + 0.5 * sin(TIME * 7.0 + (local_pos.x + local_pos.z) * 9.0);
	ALBEDO = (col * edge * 2.2 + col * 0.12 * (0.6 + 0.4 * shimmer)) * tint * power;
}
