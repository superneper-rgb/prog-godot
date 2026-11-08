// shader_7cdfd9 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vL;
varying vec3 vN;
varying vec3 vV;
uniform float uA;
uniform vec3 uCol;

void vertex() {
	vL = UV.y; vec4 w = MODELVIEW_MATRIX * vec4(VERTEX, 1.); vV = normalize(-w.xyz); vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); POSITION = PROJECTION_MATRIX * w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float rim = pow(abs(dot(vN, vV)), 1.6); float a = uA * rim * pow(vL, 1.4); fc_ = vec4(uCol * a, 1.);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
