// volcano plumes (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying float vA;
varying float vSeed;
varying float vH;
varying float vSteam;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1., 0.)), f.x), mix(h(i + vec2(0., 1.)), h(i + vec2(1., 1.)), f.x), f.y); }

void vertex() {
	float tt = fract(TIME / CUSTOM1.y + CUSTOM1.x), rise = CUSTOM1.z;
	vec3 c = CUSTOM0.xyz + vec3(CUSTOM2.x * tt * tt * rise * .7 + sin(CUSTOM1.x * 40.) * CUSTOM2.z * tt, tt * rise, CUSTOM2.y * tt * tt * rise * .7 + cos(CUSTOM1.x * 31.) * CUSTOM2.z * tt);
	vec4 mv = VIEW_MATRIX * vec4(c, 1.); float sz = CUSTOM1.w * (.3 + tt * 1.3), d = -mv.z, s = sin(CUSTOM1.x * 9. + TIME * .03), co = cos(CUSTOM1.x * 9. + TIME * .03);
	vec4 mvPosition = mv + vec4(vec2(co * VERTEX.x - s * VERTEX.y, s * VERTEX.x + co * VERTEX.y) * sz, 0., 0.);
	vUv = VERTEX.xy; vSeed = CUSTOM1.x; vH = tt; vSteam = CUSTOM2.w;
	vA = smoothstep(0., .12, tt) * (1. - smoothstep(.55, 1., tt)) * smoothstep(sz * .3, sz * 1.2, d);
	POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 p = vUv * 2.; float r = length(p);
	float f = .5 * n(p * 2.2 + vSeed * 17.) + .3 * n(p * 5.1 - vSeed * 5. + TIME * .03) + .2 * n(p * 10.7 + vSeed);
	float a = smoothstep(1., .2, r + (f - .5) * 1.) * vA;
	if (a < .004) discard;
	float under = clamp(.55 - vUv.y * 1.1 + (f - .5) * .5, 0., 1.) * (1. - vH * .8);
	vec3 ash = mix(vec3(.15, .12, .11), vec3(.95, .36, .1), under) * (.7 + .6 * f);
	vec3 steam = mix(vec3(.32, .28, .27), vec3(.95, .5, .25), under * .7) * (.8 + .4 * f);
	fc_ = vec4(mix(ash, steam, vSteam), a * mix(.8, .45, vSteam));
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
