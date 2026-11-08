// shader_7b858d (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vA;
uniform vec3 uC;
varying vec2 vPc_;

void vertex() {
	float px_ = 1.0;
	vA = CUSTOM0.x; vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.); px_ = CUSTOM1.x * 700. / max(.5, -mv.z); POSITION = PROJECTION_MATRIX * mv;
	vPc_ = UV * vec2(0.5, -0.5) + 0.5;
	POSITION.xy += UV * px_ / VIEWPORT_SIZE * POSITION.w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float d = length(vPc_ - .5) * 2.; float a = vA * smoothstep(1., .2, d); if (a < .01) discard; fc_ = vec4(uC, a);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
