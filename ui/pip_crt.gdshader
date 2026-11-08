// Live CRT effects on the terminal's glass (Wheel._crtStart): a slow rolling bright band and a faint brightness flicker, clipped to the screen shape.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D glass_tex : filter_linear, repeat_disable;
uniform vec4 glass_box = vec4(0.0, 0.0, 1.0, 1.0);   // y0 and height of the band's travel, fractions of the frame: x = y0, y = hh, z = K / frame height
uniform float flicker = 0.04;

void fragment() {
	float m = texture(glass_tex, UV).r;
	float y0 = glass_box.x, hh = glass_box.y, K = glass_box.z;
	float t = TIME * 1000.0;
	float by = y0 - 60.0 * K + fract(t * 0.00006) * (hh + 120.0 * K);
	float bh = 70.0 * K;
	float u = (UV.y - by) / bh;
	float band = 0.0;
	if (u > 0.0 && u < 1.0) { band = (u < 0.5 ? u * 2.0 : (1.0 - u) * 2.0) * 0.13; }
	vec3 col = vec3(0.47, 1.0, 0.667) * band;
	float a = band;
	// the black flicker sheet, a new level every frame
	float f = flicker;
	col *= 1.0 - f;
	a = f + a * (1.0 - f);
	COLOR = vec4(col, a) * m;
}
