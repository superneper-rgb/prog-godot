// Main menu backdrop: dark storm clouds (fbm), lit from inside around the bolt during a flash (JS SKY_VS, SKY_FS).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
uniform float u_time = 0.0;
uniform float u_flash = 0.0;
uniform vec3 u_bolt = vec3(0.2, 0.45, -1.0);
varying vec3 v_dir;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * n(p);
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	v_dir = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD;
}

void fragment() {
	vec3 d = normalize(v_dir);
	float y = max(d.y, 0.0);
	vec2 uv = d.xz / (y + 0.25) * 1.4 + vec2(u_time * 0.012, u_time * 0.004);
	float c = fbm(uv);
	float c2 = fbm(uv * 2.4 - u_time * 0.02);
	float dens = smoothstep(0.35, 0.85, c * 0.7 + c2 * 0.4);
	vec3 col = mix(vec3(0.016, 0.022, 0.04), vec3(0.004, 0.006, 0.012), smoothstep(0.0, 0.5, y));
	col += vec3(0.02, 0.028, 0.05) * dens;      // clouds catch a little city glow
	col += vec3(0.03, 0.038, 0.055) * exp(-y * 9.0);      // haze over the walls
	float near = pow(max(dot(d, normalize(u_bolt)), 0.0), 18.0);
	col += u_flash * (vec3(0.55, 0.62, 0.9) * (0.25 + dens) * (0.35 + 2.2 * near) + vec3(0.08, 0.1, 0.16));
	ALBEDO = col;
}
