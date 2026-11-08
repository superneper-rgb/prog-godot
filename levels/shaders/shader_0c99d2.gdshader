// admin-f1 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying vec3 vCell;
uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float uT;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233)) + uT * 37.) * 43758.5453); }

void vertex() {
	vUv = UV; vCell = CUSTOM0.xyz;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 q = vUv; float n = h(floor(q * vec2(160., 120.)) + vCell.xy * 7.); vec3 c = vCell.z > .5 ? texture(map, (vCell.xy + q) * vec2(.25, .5)).rgb : vec3(n * .6);
	float l = dot(c, vec3(.3, .59, .11)) * 1.9 + .03; l *= .82 + .18 * sin(q.y * 380.); l *= 1. - .55 * pow(length(q - .5) * 1.25, 2.); l += (n - .5) * .07;
	fc_ = vec4(vec3(.42, 1., .62) * l, 1.);
	ALBEDO = display_to_radiance(fc_.rgb);
}
