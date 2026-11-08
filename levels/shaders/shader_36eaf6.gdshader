// admin-f1, admin-f2, admin-f3 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vW;
uniform float uT;
uniform float uF;
uniform sampler2D uRain : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vW = w.xyz; POSITION = PROJECTION_MATRIX * VIEW_MATRIX * w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 q = vec2(vW.x + vW.z, vW.y) * .45; float r = texture(uRain, q + vec2(0., uT * .12)).r, r2 = texture(uRain, q * 1.7 + vec2(.31, uT * .27)).r;
	vec3 c = mix(vec3(.03, .05, .08), vec3(.6, .66, .8), min(1., uF)); float a = .22 + uF * .4 + (r * .5 + r2 * .35) * .3;
	fc_ = vec4(c + vec3(.16, .2, .26) * (r + r2) * .55, a);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
