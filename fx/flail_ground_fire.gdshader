// JS flail-impact-fx.js groundFire: a broken, turbulent pressure front: heat crawls through a broad low annulus instead of a clean neon circle. INSTANCE_CUSTOM = (age, opacity, seed).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;
varying vec3 v_c;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_c = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	float age = v_c.x;
	float opacity = v_c.y;
	float seed = v_c.z;
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = noise(p * 19.0 + vec2(seed, age * -8.0));
	float fine = noise(p * 43.0 + age * 11.0);
	float edge = 0.78 + 0.035 * sin(a * 11.0 + seed) + 0.024 * sin(a * 23.0 - seed) + 0.025 * (n - 0.5);
	float band = smoothstep(edge - 0.23, edge - 0.075, r) * (1.0 - smoothstep(edge - 0.035, edge + 0.055, r));
	float torn = smoothstep(0.20, 0.66, n * 0.68 + fine * 0.32);
	float heat = pow(torn, 1.8);
	vec3 color = mix(vec3(0.75, 0.075, 0.006), vec3(1.0, 0.39, 0.035), torn);
	color = mix(color, vec3(1.0, 0.68, 0.18), heat * 0.65);
	ALBEDO = color;
	ALPHA = band * (0.12 + 0.88 * torn) * opacity;
}
