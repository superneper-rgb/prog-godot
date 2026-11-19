// OMNISPHERE: the charge inside a capacitor bank's tube (levels/omnisphere/om_lab.gd): a column of plasma that crawls upward, hot white down its middle and at its
// knots, the siphon's green at its edge, flickering and dimming with the plant's power (omni_power).
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 tint : source_color = vec3(0.25, 1.0, 0.62);
global uniform float omni_power;
varying vec3 v_lp;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }

void vertex() {
	v_lp = VERTEX;
	float w = sin(VERTEX.y * 1.9 + TIME * 5.0) * 0.07 + sin(VERTEX.y * 4.3 - TIME * 8.0) * 0.035;      // the column writhes
	VERTEX.xz *= 1.0 + w;
}

void fragment() {
	float a = atan(v_lp.z, v_lp.x);
	float flow = n(vec2(a * 2.0, v_lp.y * 1.3 - TIME * 3.2)) * 0.6 + n(vec2(a * 5.0 + 3.0, v_lp.y * 3.1 - TIME * 6.0)) * 0.4;
	float f = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float pw = 0.12 + 0.88 * omni_power;
	float flick = 0.85 + 0.15 * sin(TIME * 31.0 + v_lp.y);
	vec3 c = mix(tint * 0.9, vec3(1.0, 1.0, 0.92), smoothstep(0.45, 0.95, flow * f + f * 0.35));
	ALBEDO = c * (0.55 + 1.5 * flow) * pw * flick;
}
