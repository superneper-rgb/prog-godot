// shader_c6108c (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vN;
varying vec3 vP;
uniform float uFlare;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
    return mix(mix(mix(h(i), h(i + vec3(1.0,0.0,0.0)), f.x), mix(h(i + vec3(0.0,1.0,0.0)), h(i + vec3(1.0,1.0,0.0)), f.x), f.y), mix(mix(h(i + vec3(0.0,0.0,1.0)), h(i + vec3(1.0,0.0,1.0)), f.x), mix(h(i + vec3(0.0,1.0,1.0)), h(i + vec3(1.0,1.0,1.0)), f.x), f.y), f.z); }

void vertex() {
	vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); vP = VERTEX;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 p = normalize(vP) * 3.; float t = TIME;
	float a = n3(p + vec3(t * .3, -t * .2, t * .25)) * .6 + n3(p * 2.7 - t * .6) * .4;
	float veins = 1. - smoothstep(.0, .08, abs(a - .5));
	float rim = pow(1. - abs(vN.z), 2.);
	vec3 c = mix(vec3(.15, .9, .55), vec3(.85, 1., .9), veins) * (1.2 + 1.4 * veins + rim * 1.5) * (1. + uFlare * 1.4);
	fc_ = vec4(1. - exp(-c * 1.1), 1.);
	ALBEDO = display_to_radiance(fc_.rgb);
}
