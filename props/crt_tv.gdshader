// The gunshop's CRT screen (JS props/crt-tv.js FS): curved glass, scanlines, an aperture-grille RGB mask, slight colour fringing, a rolling bright bar, flicker, vignette and a faint picture wobble, and every so often a glitch (tearing bands, colour split, static burst, a picture roll or a collapse to a line). toneMapped: false in the JS: a display value, turned to the linear light the post tone map brings back.
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D src : source_color, filter_linear, repeat_disable;
uniform float time = 0.0;
uniform float glitch = 0.0;
uniform float roll = 0.0;
uniform float squash = 1.0;
uniform float power = 1.25;
uniform float seed = 0.0;
uniform vec2 fit = vec2(1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
vec2 bend(vec2 uv) { uv = uv * 2.0 - 1.0; vec2 o = abs(uv.yx) / vec2(5.2, 4.2); uv += uv * o * o; return uv * 0.5 + 0.5; }

void fragment() {
	vec2 vuv = vec2(UV.x, 1.0 - UV.y);
	vec2 uv = bend(vuv);
	vec3 c = vec3(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec2 p = uv;
		p.y = (p.y - 0.5) / max(squash, 0.002) + 0.5;      // collapse to a bright line (power cut / glitch)
		float inside = step(0.0, p.y) * step(p.y, 1.0);
		p.y = fract(p.y + roll);      // vertical hold slipping
		p = (p - 0.5) / fit + 0.5;      // letterbox / pillarbox a picture of another shape
		float pic = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
		float row = floor(p.y * 28.0);
		float tick = floor(time * 24.0);
		float band = step(0.62, hash(vec2(row, tick)));      // which rows tear this instant
		float shift = (hash(vec2(floor(p.y * 90.0), tick)) - 0.5) * 0.16 * glitch * band;
		shift += sin(p.y * 38.0 + time * 6.0) * 0.0012 + sin(p.y * 3.0 + time * 1.3) * 0.0008;      // the picture never sits quite still
		float ca = 0.0016 + 0.014 * glitch;
		// (the picture's v runs down here: the JS's textures run up)
		c.r = texture(src, vec2(p.x + shift + ca, 1.0 - p.y)).r;
		c.g = texture(src, vec2(p.x + shift, 1.0 - p.y)).g;
		c.b = texture(src, vec2(p.x + shift - ca, 1.0 - p.y)).b;
		c = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));      // (the JS samples the sRGB texture linear; its un-tone-mapped output is linear-to-sRGB in the end)
		c *= pic;      // black bars
		float n = hash(p * vec2(330.0, 250.0) + fract(time * 7.13) * 91.0);
		c = mix(c, vec3(n), 0.045 + 0.55 * glitch * band);      // snow, heavy on the torn rows
		c *= 0.74 + 0.26 * sin(uv.y * 250.0 * 3.14159);      // scanlines
		float m = mod(floor(uv.x * 540.0), 3.0);      // aperture grille
		c *= vec3(m == 0.0 ? 1.12 : 0.78, m == 1.0 ? 1.12 : 0.78, m == 2.0 ? 1.12 : 0.78);
		c *= 1.0 + 0.07 * smoothstep(0.75, 1.0, sin((uv.y + time * 0.11) * 6.2832));      // slow rolling brighter bar
		c *= 0.95 + 0.05 * sin(time * 113.0) + 0.03 * (hash(vec2(tick, 3.0)) - 0.5);      // flicker
		vec2 d = uv - 0.5;
		c *= 1.0 - dot(d, d) * 1.5;      // vignette toward the curved edges
		c += vec3(0.03, 0.035, 0.04) * (1.0 - dot(d, d) * 2.0);      // glass glow
		c *= inside * power;
	}
	ALBEDO = pow(max(c, vec3(0.0)), vec3(2.2));
}
