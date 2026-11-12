// JUNGLE TEST leaves, fronds, stalks and vines: vertex colour over a fine mottle, waxy, lit through from behind (the sun in the canopy), moving in the shared breeze.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://levels/jungle_test/jungle_wind.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float backlight = 0.55;
uniform float rough = 0.42;
uniform float mottle = 0.35;

varying vec3 wp;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float w = jungle_weight(VERTEX, COLOR.a);
	vec3 at = sway_by == 0 ? VERTEX : root;
	VERTEX += jungle_wind(at, w);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, wp.xz * 0.9 + vec2(wp.y * 0.37)).r;
	float f = texture(noise_tex, wp.xz * 4.1 + vec2(wp.y * 1.3)).r;
	vec3 a = COLOR.rgb * (1.0 - mottle * 0.5 + mottle * (0.65 * n + 0.35 * f));
	ALBEDO = a;
	ROUGHNESS = rough + (f - 0.5) * 0.15;
	SPECULAR = 0.5;
	BACKLIGHT = a * backlight;
}
