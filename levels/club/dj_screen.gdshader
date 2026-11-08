// CLUB 9's LED wall behind the DJ (JS levels/club/level.js djScreen): five colour stops drifting across it, with thin white bars rising and falling, on the JS canvas's 256 x 64 grid and its ~8 redraws a second.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 pal0;
uniform vec3 pal1;
uniform vec3 pal2;

vec3 tint(float u) {
	u = mod(u, 3.0);
	float i = floor(u);
	float f = u - i;
	vec3 a = i < 0.5 ? pal0 : (i < 1.5 ? pal1 : pal2);
	vec3 b = i < 0.5 ? pal1 : (i < 1.5 ? pal2 : pal0);
	return mix(a, b, f);
}

void fragment() {
	float t = floor(TIME / 0.12) * 0.12;
	float w = 256.0;
	float h = 64.0;
	float x = UV.x * w;
	float y = (1.0 - UV.y) * h;
	// the gradient's stops are written as display colours, darkened to 0.55 first
	float u = UV.x * 4.0;
	float i0 = min(floor(u), 3.0);
	vec3 c0 = srgb_encode(tint(t * 0.07 + i0 * 0.7 - 3.0) * 0.55);
	vec3 c1 = srgb_encode(tint(t * 0.07 + (i0 + 1.0) * 0.7 - 3.0) * 0.55);
	vec3 col = mix(c0, c1, u - i0);
	float bx = floor(x / 8.0) * 8.0;
	float v = 0.5 + 0.5 * sin(t * 1.3 + bx * 0.09);
	float bh = h * (0.1 + 0.4 * v * (0.5 + 0.5 * sin(t * 0.7 + bx * 0.03)));
	float inside = step(bx + 1.0, x) * step(x, bx + 7.0) * step(y, bh);
	col = mix(col, vec3(1.0), inside * 0.12);
	ALBEDO = display_to_radiance(col * vec3(0.7843, 0.7843, 0.8471));      // JS: colour 0xc8c8d8 over the texture, toneMapped false
}
