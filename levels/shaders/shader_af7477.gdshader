// freefall air (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying float vA;
varying float vSeed;
varying float vLit;
uniform vec3 uLow;
uniform vec3 uHigh;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1., 0.)), f.x), mix(h(i + vec2(0., 1.)), h(i + vec2(1., 1.)), f.x), f.y); }

void vertex() {
	vUv = VERTEX.xy; vSeed = CUSTOM0.z; vLit = CUSTOM0.w;
	vec4 c = VIEW_MATRIX * vec4(CUSTOM1.xyz, 1.); float d = -c.z, r = CUSTOM0.y, s = sin(CUSTOM0.x), co = cos(CUSTOM0.x);
	vec2 corner = vec2(co * VERTEX.x - s * VERTEX.y, s * VERTEX.x + co * VERTEX.y) * CUSTOM0.y;
	vec4 mvPosition = c + vec4(corner, 0., 0.);
	vA = smoothstep(r * .15, r * .9, d) * (1. - smoothstep(2600., 3400., d));
	POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 p = vUv * 2.; float r = length(p);
	float f = .55 * n(p * 2.1 + vSeed * 13.) + .3 * n(p * 4.7 - vSeed * 7. + TIME * .02) + .15 * n(p * 9.3 + vSeed);
	float a = smoothstep(1., .25, r + (f - .5) * .9) * vA;
	if (a < .004) discard;
	float lit = clamp(.5 - vUv.y * .9 + (f - .5) * .6, 0., 1.);
	vec3 col = mix(uHigh, uLow, lit * vLit) * (.75 + .5 * f);
	fc_ = vec4(col, a * .62);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
