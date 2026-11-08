// shader_ce694a (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
uniform vec3 uCol;

void vertex() {
	vUv = UV;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float d = length(vUv - .5) * 2.; fc_ = vec4(uCol * pow(max(0., 1. - d), 2.2) * .16, 1.);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
