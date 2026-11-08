// The developer note's tube (intro/dev-notice.js FRAG). The text page comes from a viewport, so its blur is taken with taps rather than mip levels (a viewport's texture has no mips).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D text_tex : filter_linear, repeat_disable;
uniform vec2 res = vec2(1920.0, 1080.0);
uniform float time_s = 0.0;
uniform float sx_u = 0.0;
uniform float sy_u = 0.0;
uniform float dot_u = 0.0;
uniform float static_u = 0.0;
uniform float glitch = 0.0;
uniform float fade = 0.0;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float txt(vec2 p) { vec2 inb = step(vec2(0.0), p) * step(p, vec2(1.0)); return texture(text_tex, vec2(p.x, 1.0 - p.y)).a * inb.x * inb.y; }
float blur(vec2 p, float r_px) {
	vec2 r = vec2(r_px) / res;
	float s = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		vec2 d = vec2(cos(a), sin(a));
		s += txt(p + d * r) * 0.6 + txt(p + d.yx * r * 0.5) * 0.4;
	}
	return s / 12.0;
}

void fragment() {
	vec2 vuv = vec2(UV.x, 1.0 - UV.y);
	float t = time_s;
	float aspect = res.x / res.y;
	// tube curvature (gentler than the logo's, so the text stays easy to read); the corners fall off into the bezel
	vec2 c = vuv * 2.0 - 1.0;
	c += c * (c.yx * c.yx) * vec2(0.045, 0.06);
	vec2 q = abs(c) - vec2(1.0 - 0.06);
	float bez = 1.0 - smoothstep(-0.006, 0.006, length(max(q, vec2(0.0))) - 0.06);

	// power on / off: the picture is squashed into the lit part of the tube
	float px = 2.0 / res.y;
	float sx = max(sx_u, 0.0015), sy = max(sy_u, 0.0015);
	float vis = (1.0 - smoothstep(sy, sy + px * 1.5, abs(c.y))) * (1.0 - smoothstep(sx, sx + px * 1.5, abs(c.x))) * step(1e-4, sx_u);
	vec2 u = vec2(c.x / sx, c.y / sy) * 0.5 + 0.5;

	// a little tracking wobble, and torn rows while it powers up
	float gt = floor(t * 24.0);
	float row = floor(u.y * 46.0);
	u.x += step(1.0 - glitch * 0.55, hash(vec2(row, gt))) * (hash(vec2(gt, row * 1.7)) - 0.5) * 0.2 * glitch;
	u.x += sin(u.y * 180.0 + t * 9.0) * 0.0006 + sin(u.y * 13.0 - t * 2.3) * 0.0011;

	vec3 green = vec3(0.32, 1.0, 0.45);
	vec3 col = vec3(0.010, 0.032, 0.016) + vec3(0.0, 0.035, 0.012) * (1.0 - length(c) * 0.6);
	float snow = hash(floor(FRAGCOORD.xy / 2.0) + gt * vec2(13.1, 7.7));
	col += green * (snow * 0.55 + hash(vec2(floor(u.y * 90.0), gt)) * 0.12) * static_u;

	// the text: sharp phosphor, a faint ghost to the right, and a bloom
	float s = txt(u);
	float ca = 0.0012;
	float r = txt(u + vec2(ca, 0.0)), b = txt(u - vec2(ca, 0.0));
	float ghost = txt(u - vec2(0.006, 0.0));
	float glow = blur(u, 5.0) * 0.6 + blur(u, 16.0) * 0.4;
	col += vec3(r * 0.5, s, b * 0.6) * vec3(0.62, 1.0, 0.7) + green * (ghost * 0.1 + glow * 0.5);

	// scanlines, aperture grille, rolling bar, flicker
	float sl = sin(vuv.y * res.y * 3.14159 / 3.0);
	col *= 0.62 + 0.38 * sl * sl;
	float m = mod(FRAGCOORD.x, 3.0);
	col *= vec3(m < 1.0 ? 1.0 : 0.8, (m >= 1.0 && m < 2.0) ? 1.0 : 0.8, m >= 2.0 ? 1.0 : 0.8);
	float roll = exp(-pow((fract(vuv.y * 0.9 - t * 0.17) - 0.5) * 7.0, 2.0));
	col = col * (1.0 + roll * 0.15) + green * roll * 0.01;
	col *= 0.97 + 0.03 * sin(t * 113.0) + (hash(vec2(gt, 3.0)) - 0.5) * 0.03;

	// the lit part of the tube; a thin picture is a hot white-green line, and the dot left when it switches off
	float thin = clamp((1.0 - sy) * 1.15, 0.0, 1.0);
	col = mix(col, vec3(0.78, 1.0, 0.82), thin * 0.85);
	col *= vis * (1.0 + (1.0 - sy) * 2.0 + (1.0 - sx) * 3.0);
	vec2 dc = c * vec2(aspect, 1.0);
	float d2 = dot(dc, dc);
	col += vec3(0.7, 1.0, 0.75) * dot_u * (exp(-d2 * 2500.0) + 0.35 * exp(-d2 * 90.0));

	col += (hash(FRAGCOORD.xy + fract(t) * 517.0) - 0.5) * 0.03 * vis;       // grain
	col *= clamp(1.0 - 0.3 * dot(c, c), 0.0, 1.0);                           // vignette
	col = col * bez + vec3(0.012, 0.014, 0.013) * (1.0 - bez);               // bezel
	COLOR = vec4(col * (1.0 - fade), 1.0);
}
