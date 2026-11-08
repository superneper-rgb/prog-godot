// shader_6c1b3c (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vW;
uniform vec3 uCar;
uniform vec2 uFwd;
uniform float uOn;
uniform float uFlash;

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vW = w.xyz; POSITION = PROJECTION_MATRIX * VIEW_MATRIX * w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 d = vW.xz - uCar.xz; float L = length(d), k = uOn * smoothstep(.8, .97, dot(d / max(L, .01), uFwd)) * smoothstep(110., 10., L);
	fc_ = vec4(vec3(.04, .045, .05) + vec3(1., .78, .4) * k * 6. + vec3(.25) * uFlash, 1.);
	ALBEDO = display_to_radiance(fc_.rgb);
}
