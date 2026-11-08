// lava bursts (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, blend_add, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vHeat;
varying vec2 vPc_;

void vertex() {
	float px_ = 1.0;
	float tt = fract(TIME / CUSTOM0.xy.x + CUSTOM0.xy.y) * CUSTOM0.xy.x, life = 2.4;
	vec3 p = VERTEX + CUSTOM1.xyz * tt + vec3(0., -4.9 * tt * tt, 0.);
	vec4 mv = VIEW_MATRIX * vec4(p, 1.); POSITION = PROJECTION_MATRIX * mv;
	float on = step(tt, life) * step(VERTEX.y - .2, p.y);
	px_ = on * min(CUSTOM1.w * (1. - .45 * tt / life) * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * .5 / max(-mv.z, .5), 120.);
	vHeat = tt / life;
	vPc_ = UV * vec2(0.5, -0.5) + 0.5;
	POSITION.xy += UV * px_ / VIEWPORT_SIZE * POSITION.w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float r = length(vPc_ - .5); if (r > .5) discard;
	vec3 c = mix(vec3(2.6, 1.5, .4), vec3(1.2, .18, .02), smoothstep(.1, .8, vHeat));
	fc_ = vec4(c * (1. - smoothstep(.25, .5, r)) * (1. - smoothstep(.75, 1., vHeat)), 1.);
	ALBEDO = display_to_radiance(srgb_encode(fc_.rgb) * fc_.a);
}
