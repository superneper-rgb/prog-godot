// JUNGLE TEST forest floor: dark wet soil under leaf litter and moss, with standing water in the low spots. Vertex colour carries what the level worked out where:
// r = how wet (the low ground), g = moss (under the trees), b = shade (the deep forest, which the sun never reaches).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 soil : source_color = vec3(0.13, 0.09, 0.07);
uniform vec3 litter : source_color = vec3(0.3, 0.2, 0.11);
uniform vec3 litter2 : source_color = vec3(0.24, 0.24, 0.12);
uniform vec3 moss_color : source_color = vec3(0.14, 0.24, 0.08);
uniform vec3 water : source_color = vec3(0.05, 0.07, 0.06);
uniform float puddles = 0.55;

uniform float bump = 1.1;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wp.xz;
	float n1 = texture(noise_tex, uv * 0.045).r;
	float n2 = texture(noise_tex, uv * 0.21 + vec2(0.31, 0.17)).r;
	float n3 = texture(noise_tex, uv * 0.93 + vec2(0.7, 0.2)).r;
	float n4 = texture(noise_tex, uv * 3.7).r;
	float wet = COLOR.r;
	float mossk = COLOR.g;
	float shade = COLOR.b;
	// leaf litter in drifts, two kinds of it, over the soil
	float lit = smoothstep(0.42, 0.62, n2 * 0.6 + n3 * 0.4);
	vec3 a = mix(soil, mix(litter, litter2, smoothstep(0.4, 0.6, n1)), lit) * (0.75 + 0.5 * n4);
	float m = smoothstep(0.4, 0.75, mossk * (0.55 + 0.9 * n1) + (n3 - 0.5) * 0.3);
	a = mix(a, moss_color * (0.7 + 0.6 * n4), m);
	// standing water in the low spots: dark, smooth, flat
	float pud = smoothstep(0.62, 0.7, wet * puddles * 1.6 + (n2 - 0.5) * 0.35 + (n3 - 0.5) * 0.12);
	float damp = clamp(wet * 0.8 + 0.25, 0.0, 1.0);
	a *= mix(1.0, 0.55, damp * (1.0 - m * 0.5));
	a = mix(a, water, pud);
	ALBEDO = a * mix(1.0, 0.35, shade);
	ROUGHNESS = mix(mix(0.82, 0.55, damp), 0.04, pud);
	SPECULAR = mix(0.4, 0.6, pud);
	// the mesh has no tangents: the map lies in the ground's plane, x along x and y along z (water is flat)
	vec3 t = texture(noise_nrm, uv * 0.93 + vec2(0.7, 0.2)).xyz * 2.0 - 1.0;
	vec3 t2 = texture(noise_nrm, uv * 0.21 + vec2(0.31, 0.17)).xyz * 2.0 - 1.0;
	vec2 d = (t.xy + t2.xy * 0.6) * bump * (1.0 - pud);
	vec3 gn = normalize(wn + vec3(d.x, 0.0, d.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(gn, 0.0)).xyz);
}
