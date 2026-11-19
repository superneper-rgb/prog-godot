// CityRoads, CitySidewalks, CityYard, CityPlaza (JS levels/hub/city-streets.js groundMaterial): a tiling map in world metres, puddles, the baked light map, view-dependent wet sheen and rain sparkle.
// The city's street lighting lives in lightMap: there are no scene lights for it.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D puddle : repeat_enable, filter_linear_mipmap;     // JS: srgb false
uniform sampler2D lightMap : repeat_enable, filter_linear;     // JS: srgb false, aniso 1
uniform vec4 uLM;
uniform float uScale = 1.0;
uniform float uWet = 1.0;
uniform vec3 uTint = vec3(1.0);

varying vec3 vW;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n21(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vW.xz;
	vec3 a = texture(map, p / uScale).rgb * uTint;
	float filth = n21(p / 7.0) * 0.6 + n21(p / 1.7) * 0.4;      // the city's filth: oily blotches and trodden-in dirt over every surface
	a *= 0.68 + 0.32 * smoothstep(0.25, 0.75, filth);
	a = mix(a, a * vec3(0.9, 0.86, 0.78), smoothstep(0.55, 0.8, n21(p / 3.1 + 7.0)));
	float wet = uWet * smoothstep(0.32, 0.78, texture(puddle, p / 23.0 + 0.37).r);
	vec3 L = texture(lightMap, (p - uLM.xy) / uLM.zw).rgb;
	vec3 v = normalize(CAMERA_POSITION_WORLD - vW);
	float fres = pow(1.0 - clamp(v.y, 0.0, 1.0), 3.0);
	vec3 col = a * (1.0 - 0.45 * wet) * 0.95 + a * L * 2.7 + L * (0.02 + 0.2 * wet * (0.3 + fres));
	col += (0.25 + 0.75 * wet) * fres * vec3(0.04, 0.022, 0.045);      // the wet ground mirrors the smog's neon glow
	vec2 cell = floor(p * 3.0);
	float sp = h21(cell + floor(TIME * 7.0));
	col += wet * step(0.992, sp) * (0.05 + L * 0.6);
	ALBEDO = col + flash_light(vW, vec3(0.0, 1.0, 0.0), vec3(0.18));      // (2026-11-11: a muzzle flash or a blast lights the street)
}
