// OMNISPHERE: the ash cloud deck the drop falls through (JS freefall.js C_VERT / C_FRAG): camera-facing puffs, the bottom of each one catching the magma glow. Premultiplied (three.js blends on the display value: see vh_puff.gdshader). INSTANCE_CUSTOM: rotation, size, seed, how much it catches the glow. (The JS sorts these far to near every few frames; here their soft edges add up either way, so no CPU sort.)
shader_type spatial;
render_mode blend_premul_alpha, unshaded, shadows_disabled, depth_draw_never, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying float vA;
varying float vSeed;
varying float vLit;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1., 0.)), f.x), mix(h(i + vec2(0., 1.)), h(i + vec2(1., 1.)), f.x), f.y); }

void vertex() {
	vUv = VERTEX.xy;
	vSeed = INSTANCE_CUSTOM.z;
	vLit = INSTANCE_CUSTOM.w;
	vec4 c = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	float d = -c.z;
	float r = INSTANCE_CUSTOM.y;
	float s = sin(INSTANCE_CUSTOM.x);
	float co = cos(INSTANCE_CUSTOM.x);
	c.xy += vec2(co * VERTEX.x - s * VERTEX.y, s * VERTEX.x + co * VERTEX.y) * r;
	vA = smoothstep(r * .15, r * .9, d) * (1. - smoothstep(2600., 3400., d));
	POSITION = PROJECTION_MATRIX * c;
}

void fragment() {
	vec2 p = vUv * 2.;
	float r = length(p);
	float f = .55 * n(p * 2.1 + vSeed * 13.) + .3 * n(p * 4.7 - vSeed * 7. + TIME * .02) + .15 * n(p * 9.3 + vSeed);
	float a = smoothstep(1., .25, r + (f - .5) * .9) * vA * .62;
	float lit = clamp(.5 - vUv.y * .9 + (f - .5) * .6, 0., 1.);      // the bottom of each puff catches the magma glow
	vec3 col = mix(vec3(0.0467, 0.0343, 0.0369), vec3(0.6308, 0.1170, 0.0296), lit * vLit) * (.75 + .5 * f);
	ALBEDO = display_to_radiance(radiance_to_display(col) * a);
	ALPHA = a;
}
