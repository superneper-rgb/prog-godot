// rain outside (three.js ShaderMaterial, level apartment). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 uWind;
varying float vA;
uniform vec3 uColor;

void vertex() {
	float s = mod(VERTEX.y + TIME * CUSTOM1.x, 80.0);
	vec3 p = vec3(VERTEX.x, 25.0, VERTEX.z) + uWind * s;
	p -= uWind * CUSTOM0.x * CUSTOM1.x * 0.09;
	vec4 mv = MODELVIEW_MATRIX * vec4(p, 1.0);
	vA = (1.0 - CUSTOM0.x * 0.9) * clamp(1.5 - (-mv.z) / 25.0, 0.12, 1.0);
	POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	fc_ = vec4(uColor, 0.55 * vA);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
