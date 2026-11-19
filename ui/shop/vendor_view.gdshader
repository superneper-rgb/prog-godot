// A vendor terminal's screen (JS .vd.pz .pz-view + .vd-frame's filter): the menu turned monochrome in the theme's colour (grayscale, sepia, saturate, hue-rotate, brightness, contrast) with its phosphor drop shadow, over the screen's radial background; the staged open clip; the CRT's glitch moves.
shader_type canvas_item;

uniform sampler2D menu : filter_linear, repeat_disable;
uniform float sat = 5.5;
uniform float hue = -0.698;
uniform float bright = 1.05;
uniform float contrast = 1.12;
uniform vec3 pzr = vec3(1.0, 0.22, 0.19);
uniform vec3 bg1 = vec3(0.17, 0.02, 0.035);
uniform vec3 bg2 = vec3(0.04, 0.01, 0.01);
uniform vec2 px = vec2(0.001, 0.002);      // 3 css px of drop shadow, in uv
// The 3D item preview (weapon, suit, vial, glass) keeps its own colours: the JS's monochrome CSS filter hid what the items actually look like (user, 2026-11-16). `keep_rect` is the preview box in uv (x0, y0, x1, y1), `keep` how much of the real colour shows there (0 = the old all-one-colour look); the page sets both each frame it draws a preview.
uniform vec4 keep_rect = vec4(0.0);
uniform float keep : hint_range(0.0, 1.0) = 0.9;
// staged open: the main band opens from its middle
uniform vec2 band = vec2(0.0, 1.0);
uniform float band_open = 1.0;
// the glitch (the view jumps, skews, flashes, loses a band)
uniform vec2 gl_off = vec2(0.0);
uniform float gl_skew = 0.0;
uniform float gl_bright = 1.0;
uniform float gl_contrast = 1.0;
uniform float gl_hue = 0.0;
uniform float gl_sat = 1.0;
uniform vec2 gl_clip = vec2(0.0, 1.0);

vec3 hue_rot(vec3 c, float h) {
	float s = sin(h), k = cos(h);
	mat3 m = mat3(
		vec3(0.213 + k * 0.787 - s * 0.213, 0.213 - k * 0.213 + s * 0.143, 0.213 - k * 0.213 - s * 0.787),
		vec3(0.715 - k * 0.715 - s * 0.715, 0.715 + k * 0.285 + s * 0.140, 0.715 - k * 0.715 + s * 0.715),
		vec3(0.072 - k * 0.072 + s * 0.928, 0.072 - k * 0.072 - s * 0.283, 0.072 + k * 0.928 + s * 0.072));
	return clamp(m * c, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec2 uv = UV - gl_off;
	uv.x += gl_skew * (uv.y - 0.5);
	vec4 t = texture(menu, uv);
	// inside band? the main panels are only there once the band has opened
	float mid = (band.x + band.y) * 0.5;
	float half_h = (band.y - band.x) * 0.5 * band_open;
	if (uv.y > band.x && uv.y < band.y && abs(uv.y - mid) > half_h) {
		t = vec4(0.0);
	}
	float L = dot(t.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = clamp(vec3(L * 1.351, L * 1.203, L * 0.937), vec3(0.0), vec3(1.0));
	float l2 = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = clamp(mix(vec3(l2), c, sat), vec3(0.0), vec3(1.0));
	c = hue_rot(c, hue);
	c = clamp(c * bright, vec3(0.0), vec3(1.0));
	c = clamp((c - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	// inside the preview box, bring the item's real colours back (soft edge so the box does not show)
	vec2 kd = min(uv - keep_rect.xy, keep_rect.zw - uv);
	float inside = clamp(min(kd.x, kd.y) / 0.006, 0.0, 1.0) * step(0.0001, keep_rect.z);
	c = mix(c, clamp(t.rgb * 1.08, vec3(0.0), vec3(1.0)), keep * inside);
	// drop-shadow(0 0 3px pzr .55)
	float sh = 0.0;
	sh += texture(menu, uv + px * vec2(1.0, 0.0)).a + texture(menu, uv - px * vec2(1.0, 0.0)).a;
	sh += texture(menu, uv + px * vec2(0.0, 1.0)).a + texture(menu, uv - px * vec2(0.0, 1.0)).a;
	sh += texture(menu, uv + px * vec2(0.7, 0.7)).a + texture(menu, uv - px * vec2(0.7, 0.7)).a;
	sh += texture(menu, uv + px * vec2(0.7, -0.7)).a + texture(menu, uv - px * vec2(0.7, -0.7)).a;
	sh = sh / 8.0 * 0.55;
	// the screen's own background
	float d = length((UV - 0.5) / vec2(0.8, 0.8)) * 2.0 * 0.5;
	vec3 base = mix(bg1, bg2, clamp(d * 2.0, 0.0, 1.0));
	vec3 o = mix(base, pzr, sh * (1.0 - t.a));
	o = mix(o, c, t.a);
	if (gl_hue != 0.0) {
		o = hue_rot(o, gl_hue);
	}
	o = clamp(mix(vec3(dot(o, vec3(0.2126, 0.7152, 0.0722))), o, gl_sat), vec3(0.0), vec3(1.0));
	o = clamp(o * gl_bright, vec3(0.0), vec3(1.0));
	o = clamp((o - 0.5) * gl_contrast + 0.5, vec3(0.0), vec3(1.0));
	if (UV.y < gl_clip.x || UV.y > gl_clip.y) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(o, 1.0);
	}
}
