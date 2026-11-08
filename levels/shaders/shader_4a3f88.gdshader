// NightSky (JS levels/hub/city-style.js createNightSky): the gradient, moon, halo and painterly cloud streaks of the dome. In the JS the dome follows the camera and draws at the far plane.
// uCenter is where the dome sat when it was exported, so a vertex's offset from it is the view direction.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 uCenter;
uniform float uMoonR = 0.9986;
uniform float uCloud = 0.5;
uniform vec3 uMoon;
uniform vec3 uHor;
uniform vec3 uBand;
uniform vec3 uZen;
uniform vec3 uMoonCol;
uniform vec3 uHalo;

varying vec3 vDir;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * n2(p);
		p = p * 2.07 + 9.3;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	vDir = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - uCenter;
	vec4 p = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + vDir, 1.0);
	POSITION = vec4(p.xy, 0.0, p.w);       // JS p.xyww: on the far plane (0 with Godot's reversed depth)
}

void fragment() {
	vec3 d = normalize(vDir);
	float el = max(d.y, 0.0);
	vec3 col = mix(uHor, uBand, smoothstep(0.0, 0.22, el));
	col = mix(col, uZen, smoothstep(0.16, 0.72, el));
	col *= 0.94 + 0.06 * sin(atan(d.x, d.z) * 1.7);
	float md = dot(d, uMoon);
	col += uMoonCol * smoothstep(uMoonR, uMoonR + 0.0013, md);
	col += uHalo * pow(max(0.0, md), 90.0) + uHalo * 0.13 * pow(max(0.0, md), 30.0);      // the second term is the bloom around the disc: wide and strong here is exactly what makes a sun
	vec2 cp = vec2(atan(d.x, d.z) * 1.5 + TIME * 0.004, el * 7.0 - TIME * 0.0012);
	float c = smoothstep(0.46, 0.86, fbm(vec2(cp.x * 1.1, cp.y * 4.2)));
	col = mix(col, mix(uZen * 1.6, uHor * 1.12, 1.0 - smoothstep(0.0, 0.42, el)), c * uCloud * (1.0 - smoothstep(0.3, 0.8, el)));
	ALBEDO = col;
}
