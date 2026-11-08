// ash (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vEmber;
varying float vA;
varying vec2 vPc_;

void vertex() {
	float px_ = 1.0;
	vec3 box = vec3(90., 46., 90.);
	float ember = step(.93, CUSTOM0.w);
	vec3 drift = ember > .5 ? vec3(.011, .034, .006) : vec3(.016, -.011, .009);
	vec3 q = fract(CUSTOM0.xyz + drift * TIME * (.6 + CUSTOM0.w * .8) + vec3(sin(TIME * .7 + CUSTOM0.w * 40.) * .004, 0., cos(TIME * .5 + CUSTOM0.x * 30.) * .004));
	vec3 w = CAMERA_POSITION_WORLD + (fract(q - CAMERA_POSITION_WORLD / box + .5) - .5) * box;
	vec4 mv = VIEW_MATRIX * vec4(w, 1.); POSITION = PROJECTION_MATRIX * mv;
	float d = -mv.z;
	px_ = clamp((ember > .5 ? .09 : .05 + CUSTOM0.w * .05) * PROJECTION_MATRIX[1][1] * 400. / max(d, .1), 1., 5.);
	vEmber = ember; vA = smoothstep(46., 20., d) * smoothstep(2.5, 5., d) * (ember > .5 ? .5 + .5 * sin(TIME * 6. + CUSTOM0.y * 60.) : 1.);
	vPc_ = UV * vec2(0.5, -0.5) + 0.5;
	POSITION.xy += UV * px_ / VIEWPORT_SIZE * POSITION.w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float r = length(vPc_ - .5); if (r > .5) discard;
	vec3 c = vEmber > .5 ? vec3(2.2, .8, .2) : vec3(.16, .15, .15);
	fc_ = vec4(c, (1. - smoothstep(.2, .5, r)) * vA * (vEmber > .5 ? 1. : .55));
	ALBEDO = display_to_radiance(srgb_encode(fc_.rgb));
	ALPHA = fc_.a;
}
