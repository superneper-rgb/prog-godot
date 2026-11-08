// shader_a09ff2 (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float uAlive[8];
varying float vA;
uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 uCol;
varying vec2 vPc_;

void vertex() {
	float px_ = 1.0;
	float life = CUSTOM0.w, tt = fract(TIME / life + CUSTOM0.x) ;
	vec3 p = VERTEX + vec3(sin(CUSTOM0.y * 40. + tt * 3.) * 4. * tt, tt * CUSTOM0.z, cos(CUSTOM0.y * 33. + tt * 2.) * 4. * tt) + vec3(tt * tt * 18., 0., tt * tt * 6.);
	vec4 mv = VIEW_MATRIX * vec4(p, 1.); POSITION = PROJECTION_MATRIX * mv;
	px_ = min((6. + 26. * tt) * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * .5 / max(-mv.z, 1.), 400.);
	vA = smoothstep(0., .12, tt) * (1. - smoothstep(.55, 1., tt)) * uAlive[int(CUSTOM1.x + .5)];
	vPc_ = UV * vec2(0.5, -0.5) + 0.5;
	POSITION.xy += UV * px_ / VIEWPORT_SIZE * POSITION.w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 t = texture(map, vPc_); fc_ = vec4(uCol, t.a * vA * .55);
	ALBEDO = display_to_radiance(srgb_encode(fc_.rgb));
	ALPHA = fc_.a;
}
