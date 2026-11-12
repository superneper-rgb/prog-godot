// FOINT CITY car paint: metal flake under a wet clear coat that carries the city (car_look.gdshaderinc), worn by the street (car_grime). The colour is the car's own: the street MultiMesh's instance colour, or own_paint on a car you drive.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://levels/shaders/car_look.gdshaderinc"

uniform vec4 own_paint : source_color = vec4(0.0);      // a > 0: this colour, not the instance's
uniform float metal = 0.75;
uniform float rough = 0.26;
uniform float coat = 1.0;
uniform float fill = 0.42;
uniform float flake = 0.5;
uniform float dent = 0.10;        // bodywork that is no longer true: how far the panels' normals wander (0: showroom)
uniform float scratch = 0.5;      // fine scratches along the flanks, in the clear coat
varying vec3 v_lp;
varying vec3 v_cp;
varying vec3 v_cn;
varying flat float v_seed;

void vertex() {
	v_lp = VERTEX;
	v_cp = car_frame(VERTEX);
	v_cn = car_frame(NORMAL);
	v_seed = car_seed(INSTANCE_ID);
}

void fragment() {
	vec3 paint = mix(srgb_decode(COLOR.rgb), own_paint.rgb, own_paint.a);      // (the city's car colours are sRGB bytes, as the old paint read them)
	vec4 g = car_grime(v_cp, normalize(v_cn), v_seed);
	// years of sun-less smog: the coat has gone flat and a little grey
	paint = mix(paint, vec3(dot(paint, vec3(0.3, 0.5, 0.2))), 0.18 * g.w) * (1.0 - 0.1 * g.w);
	paint = mix(paint, CAR_PRIMER, g.z);
	// flake: tiny mirrors under the coat, each tipped its own way
	// years of knocks (2026-11-11: mirror-true panels read as toys): the panels wave a little, more on a car that has had a hard life, so the city's reflection wobbles across them
	vec3 wq = v_cp * vec3(2.3, 3.1, 1.7) + v_seed * 3.7;
	vec3 wob = vec3(car_vn(wq), car_vn(wq + 17.3), car_vn(wq + 41.9)) - 0.5 + 0.35 * (vec3(car_vn(wq * 4.3), car_vn(wq * 4.3 + 9.1), car_vn(wq * 4.3 + 23.5)) - 0.5);
	vec3 nb = normalize(NORMAL + (VIEW_MATRIX * (MODEL_MATRIX * vec4(wob, 0.0))).xyz * dent * (0.4 + 1.2 * g.w));
	NORMAL = nb;
	float scr = smoothstep(0.72, 0.9, car_vn(vec3(v_cp.z * 2.5, v_cp.y * 150.0, v_cp.x * 150.0) + v_seed)) * smoothstep(0.3, 0.7, car_vn(v_cp * 2.1 + v_seed * 1.3)) * scratch * g.w;
	vec3 fl = car_h3(floor(v_lp * 900.0)) - 0.5;
	vec3 nf = normalize(nb + (VIEW_MATRIX * vec4(fl, 0.0)).xyz * 0.35 * flake * (1.0 - g.z));
	float wear = clamp(g.x + g.z, 0.0, 1.0);
	float m = metal * (1.0 - 0.8 * wear);
	vec3 alb = mix(paint * 0.6, CAR_FILM, g.x * 0.7);      // (the street lamps on a full-strength metallic coat washed every car out to the lamp's lilac: the lights get less of the paint than the city's reflection does)
	alb = mix(alb, CAR_BARE, g.y);
	ALBEDO = alb;
	METALLIC = mix(m, 0.55, g.y);
	ROUGHNESS = mix(mix(rough, 0.6, wear), 0.4, g.y);
	CLEARCOAT = 1.0 - 0.45 * g.z;      // (the rain keeps even the dirt wet: the coat dulls, it does not go dry and matte; only primer has none)
	CLEARCOAT_ROUGHNESS = mix(0.05, 0.45, max(g.x, scr));      // (on a dark coat the dirt reads by what it does to the reflection: it breaks it up)
	EMISSION = car_emission(mix(paint, CAR_FILM, g.x * 0.7), m, coat * (1.0 - 0.6 * wear - 0.3 * g.z) * (1.0 - g.y) * (1.0 - 0.6 * scr), fill, nb, normalize(mix(nf, nb, g.x)), VIEW, INV_VIEW_MATRIX);
}
