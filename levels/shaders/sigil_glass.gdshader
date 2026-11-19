// The Sigil's six weak-point screens (enemies/sigil_beast_view.gd): one material for all of them; which screen a face belongs to is in UV2.x ((index + 1.5) / 8, written by tools/sigil/build_sigil.py).
// Dark: black curved glass with only a faint green scanline in it. Armed: amber, blinking, hot enough to read down a tunnel (its halo is a separate sprite). Broken: cracked and dead, now and then a
// spark of light crawling along a crack. UV is the screen's own 0..1 (v down).
shader_type spatial;
render_mode cull_back;

uniform float state[6];          // 0 dark, 1 armed, 2 broken
uniform float blink = 1.0;       // the armed blink: 1 lit, 0 its dark half
uniform float rage = 0.0;
uniform float flash = 0.0;

varying flat int id;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// distance to the nearest cell edge of a voronoi pattern: the cracks
float crack(vec2 uv, float seed) {
	vec2 p = uv * vec2(4.0, 3.0) + seed * 7.13;
	vec2 g = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + vec2(hash(g + o), hash(g + o + 19.1)) - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	float e = sqrt(d2) - sqrt(d1);
	// and a star of cracks out from where it was hit
	vec2 c = uv - vec2(0.42 + 0.16 * hash(vec2(seed)), 0.45 + 0.1 * hash(vec2(seed, 3.0)));
	float a = atan(c.y, c.x);
	float star = abs(fract(a * 7.0 / 6.2832 + seed) - 0.5) * length(c) * 6.0;
	return max(1.0 - smoothstep(0.0, 0.05, e), 1.0 - smoothstep(0.0, 0.06, star)) * smoothstep(0.02, 0.08, length(c) + 0.06);
}

void vertex() {
	id = clamp(int(UV2.x * 8.0) - 1, 0, 5);
}

void fragment() {
	float st = state[id];
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 150.0 - TIME * 5.0);
	float vig = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x) * smoothstep(0.0, 0.22, uv.y) * smoothstep(1.0, 0.78, uv.y);
	ALBEDO = vec3(0.004);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.75;
	vec3 e = vec3(0.12, 0.55, 0.2) * (0.05 + 0.05 * rage) * (0.55 + 0.45 * scan) * vig;      // unlit: a dead tube, barely there
	if (st > 1.5) {
		float c = crack(uv, float(id) * 1.37);
		ROUGHNESS = mix(0.05, 0.75, c);
		ALBEDO = mix(vec3(0.004), vec3(0.06, 0.06, 0.065), c);
		float run = step(0.93, hash(vec2(floor(TIME * 9.0), float(id))));
		float along = smoothstep(0.3, 0.0, abs(fract(uv.x * 2.0 + TIME * 3.0) - 0.5));
		e = vec3(0.55, 0.75, 1.0) * c * run * along * 6.0;
	} else if (st > 0.5) {
		// lit: a hot amber field, the tube's lines across it, a target ring pulsing in it
		vec2 c = uv - 0.5;
		float ring = smoothstep(0.035, 0.0, abs(length(c * vec2(1.3, 1.0)) - fract(TIME * 1.6) * 0.45));
		float on = mix(0.18, 1.0, blink);
		e = vec3(1.0, 0.5, 0.08) * (3.0 + 5.0 * blink) * (0.7 + 0.3 * scan) * (0.55 + 0.45 * vig) * on + vec3(1.0, 0.8, 0.4) * ring * 3.0 * on;
	}
	EMISSION = e + vec3(1.0, 0.55, 0.15) * flash * 0.5;
}
