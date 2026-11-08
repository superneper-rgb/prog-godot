// Opening logo sting (intro/logo-intro.js FRAG): the SHIT HOUSE logo on an old green-phosphor CRT. One fragment shader, driven by ui/intro/logo_intro.gd, so the picture is a pure function of time.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D logo_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D osd_tex : filter_linear, repeat_disable;
uniform vec2 res = vec2(1920.0, 1080.0);
uniform vec2 shake = vec2(0.0);
uniform float time_s = 0.0;
uniform float logo_aspect = 2.0;
uniform float sx_u = 0.0;
uniform float sy_u = 0.0;
uniform float dot_u = 0.0;
uniform float pop_x = 0.0;
uniform float pop_y = 0.0;
uniform float glitch = 0.0;
uniform float static_u = 0.0;
uniform float flash = 0.0;
uniform float fade = 0.0;
uniform float osd_a = 0.0;
uniform float logo_on = 0.0;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec4 logo(vec2 p, float bias) {
	vec2 inb = step(vec2(0.0), p) * step(p, vec2(1.0));
	return textureLod(logo_tex, vec2(p.x, 1.0 - p.y), bias) * inb.x * inb.y;
}
// phosphor brightness of a logo sample (premultiplied): luminance, lifted so the blue hair still reads
float ph(vec4 s) {
	float l = mix(dot(s.rgb, vec3(0.30, 0.59, 0.11)), max(s.r, max(s.g, s.b)) * 0.8, 0.45);
	return l * s.a;
}

void fragment() {
	vec2 vuv = vec2(UV.x, 1.0 - UV.y);
	float t = time_s;
	float aspect = res.x / res.y;
	// tube curvature: the picture bulges, the corners fall off into the bezel
	vec2 c = vuv * 2.0 - 1.0 + shake;
	c += c * (c.yx * c.yx) * vec2(0.07, 0.09);
	vec2 q = abs(c) - vec2(1.0 - 0.07);
	float bez = 1.0 - smoothstep(-0.006, 0.006, length(max(q, vec2(0.0))) - 0.07);

	// power on / off: the picture is squashed into the lit part of the tube
	float px = 2.0 / res.y;
	float sx = max(sx_u, 0.0015), sy = max(sy_u, 0.0015);
	float vis = (1.0 - smoothstep(sy, sy + px * 1.5, abs(c.y))) * (1.0 - smoothstep(sx, sx + px * 1.5, abs(c.x))) * step(1e-4, sx_u);
	vec2 u = vec2(c.x / sx, c.y / sy) * 0.5 + 0.5;

	// tracking: torn rows slide sideways, the whole frame wobbles, sometimes jumps
	float gt = floor(t * 24.0);
	float row = floor(u.y * 46.0);
	float slice = step(1.0 - glitch * 0.55, hash(vec2(row, gt))) * (hash(vec2(gt, row * 1.7)) - 0.5) * 0.28 * glitch;
	float wob = sin(u.y * 180.0 + t * 9.0) * 0.0009 + sin(u.y * 13.0 - t * 2.3) * 0.0016;
	u.x += slice + wob;
	u.y += step(0.8, hash(vec2(gt, 9.0))) * glitch * 0.035;

	vec3 green = vec3(0.32, 1.0, 0.45);
	vec3 col = vec3(0.010, 0.032, 0.016) + vec3(0.0, 0.035, 0.012) * (1.0 - length(c) * 0.6);

	// snow
	float snow = hash(floor(FRAGCOORD.xy / 2.0) + gt * vec2(13.1, 7.7));
	float band = hash(vec2(floor(u.y * 90.0), gt)) * 0.5;
	col += green * (snow * 0.55 + band * 0.25) * static_u;

	// the logo
	if (logo_on > 0.5) {
		vec2 p = (u - 0.5) * vec2(aspect, 1.0);
		float lh = min(0.6, 0.8 * aspect / logo_aspect);
		vec2 ls = vec2(lh * logo_aspect, lh) * vec2(pop_x, pop_y);
		vec2 lp = p / max(ls, vec2(1e-4)) + 0.5;
		float ca = 0.0028 + glitch * 0.02;
		float r = ph(logo(lp + vec2(ca, 0.0), 0.0)), g = ph(logo(lp, 0.0)), b = ph(logo(lp - vec2(ca, 0.0), 0.0));
		vec3 l = vec3(r * 0.42, g, b * 0.5);
		l += pow(g, 3.0) * vec3(0.45, 0.22, 0.4);                                      // hot spots burn towards white
		float ghost = ph(logo(lp - vec2(0.014, 0.0), 1.0));                             // ghost image trailing to the right
		float glow = ph(logo(lp, 3.5)) * 0.55 + ph(logo(lp, 5.5)) * 0.45;              // phosphor bloom
		col = col * (1.0 - logo(lp, 0.0).a * 0.85) + l * 1.08 + green * (ghost * 0.13 + glow * 0.42);
	}

	// VCR on-screen display
	col += vec3(0.6, 1.0, 0.65) * texture(osd_tex, vec2(u.x, 1.0 - u.y)).a * osd_a;

	// scanlines, aperture grille, rolling bar, flicker
	float sl = sin(vuv.y * res.y * 3.14159 / 3.0);
	col *= 0.58 + 0.42 * sl * sl;
	float m = mod(FRAGCOORD.x, 3.0);
	col *= vec3(m < 1.0 ? 1.0 : 0.78, (m >= 1.0 && m < 2.0) ? 1.0 : 0.78, m >= 2.0 ? 1.0 : 0.78);
	float roll = exp(-pow((fract(vuv.y * 0.9 - t * 0.17) - 0.5) * 7.0, 2.0));
	col = col * (1.0 + roll * 0.2) + green * roll * 0.012;
	col *= 0.965 + 0.035 * sin(t * 113.0) + (hash(vec2(gt, 3.0)) - 0.5) * 0.04;
	col += green * flash * 0.4;

	// the lit part of the tube; a thin picture is a hot white-green line
	float thin = clamp((1.0 - sy) * 1.15, 0.0, 1.0);
	col = mix(col, vec3(0.78, 1.0, 0.82), thin * 0.85);
	col *= vis * (1.0 + (1.0 - sy) * 2.0 + (1.0 - sx) * 3.0);
	// the dot left behind when the set switches off
	vec2 dc = c * vec2(aspect, 1.0);
	float d2 = dot(dc, dc);
	col += vec3(0.7, 1.0, 0.75) * dot_u * (exp(-d2 * 2500.0) + 0.35 * exp(-d2 * 90.0));

	col += (hash(FRAGCOORD.xy + fract(t) * 517.0) - 0.5) * 0.035 * vis;       // grain
	col *= clamp(1.0 - 0.32 * dot(c, c), 0.0, 1.0);                           // vignette
	col = col * bez + vec3(0.012, 0.014, 0.013) * (1.0 - bez);                // bezel
	COLOR = vec4(col * (1.0 - fade), 1.0);
}
