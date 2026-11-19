// THE MOTHERSHIP: the Godmother's PIT floor (ms_arena.gd). Dark plum at rest; while she holds the floor up it wakes into slow veins of hot psychic plasma that drift round the room ("THE PIT BURNS").
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;      // (MsKit.ring winds for the glow shader, which draws both sides)

uniform float heat = 0.0;      // 0 = the floor is home (nobody sees the pit), 1 = every tile is up
uniform vec3 base : source_color = vec3(0.10, 0.015, 0.06);
uniform vec3 hot : source_color = vec3(1.0, 0.22, 0.62);
uniform vec3 core : source_color = vec3(0.78, 0.45, 1.0);
varying vec3 wp;

float hash(vec2 p) {      // (a sine-free hash: the usual fract(sin(...)) broke into hard blocks on the GPU)
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	// the plasma turns slowly round the room (the same way the sweep goes)
	float a = 0.05 * t;
	p = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p;
	float n = vnoise(p * 0.32 + vec2(t * 0.11, -t * 0.07)) * 0.62 + vnoise(p * 0.85 - vec2(t * 0.23, t * 0.05)) * 0.38;
	float vein = pow(1.0 - abs(n * 2.0 - 1.0), 7.0);
	float r = length(wp.xz);
	float swell = pow(0.5 + 0.5 * sin(r * 1.6 - t * 2.2), 6.0);      // rings of heat breathing out from the centre
	float h = clamp(heat, 0.0, 1.0);
	vec3 c = base * (1.0 + 1.5 * h);
	c += hot * (vein * 1.1 + swell * 0.12 + 0.05) * h;
	c += core * pow(vein, 4.0) * 1.1 * h;
	ALBEDO = c;
}
