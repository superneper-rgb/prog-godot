// shader_89ebf4 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vL;
varying vec3 vN;
varying vec3 vV;
uniform float uA;

void vertex() {
	vL = UV.y; vec4 w = MODELVIEW_MATRIX * vec4(VERTEX, 1.); vV = normalize(-w.xyz); vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); POSITION = PROJECTION_MATRIX * w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float a = uA * pow(abs(dot(vN, vV)), 2.) * vL * vL; fc_ = vec4(vec3(1., .93, .78) * a, 1.);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
