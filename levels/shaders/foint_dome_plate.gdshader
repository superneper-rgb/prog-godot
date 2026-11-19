// The FOINT DOME's armour plate (levels/hub/foint_dome.gd, the model built by tools/dome/build_foint_dome.py). Unshaded like the rest of FOINT CITY, with its light painted in:
// a soft key from over the bridge and the sky's hemisphere on the plate's own value, the occlusion and red light baked into the vertex colours, grime and rain streaks, and a
// wet sheen that carries the city's sky. Gunmetal, not black: the bevels and the layered plates have to read, as in the concept.
// COLOR: r = the plate's tone / 1.6 (worn edges are lighter), g = occlusion, b = how much of the red light reaches it.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/city_env.gdshaderinc"
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

uniform vec3 plate = vec3(0.112, 0.108, 0.122);   // (user, 2026-11-12: darker, "like a black grey almost"; was 0.172, 0.168, 0.19)                      // gunmetal: the display value of a plate under full light (no source_color: display_to_radiance decodes it)
uniform vec3 key_dir = vec3(-0.35, 0.72, -0.6);                     // from over the bridge, high and a little to one side
uniform vec3 key_col : source_color = vec3(0.95, 0.9, 1.0);
uniform float key_k = 1.25;
uniform float sky_k = 0.55;                                         // the hemisphere: up faces
uniform float under_k = 0.16;                                       // and what is left underneath
uniform float ao_floor = 0.22;                                     // how dark a fully occluded corner goes
uniform vec3 red = vec3(0.72, 0.03, 0.09);                          // display value: the same deep crimson as the lights
uniform float red_k = 1.25;                                         // the red light on the plate round every window and seam
uniform float level = 1.0;                                          // the red light's breathing (FointDomeLife)
uniform float wet_k = 0.5;
uniform float hazard = 0.0;                                         // 1: the footings' hazard band (UV in metres)
uniform float ground_y = -10.0;

varying vec3 w_pos;
varying vec3 w_nrm;
varying flat vec3 v_far_mass;
varying flat vec3 v_far_street;
varying flat vec3 v_plate;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_far_mass = display_to_radiance(vec3(0.022, 0.016, 0.036));
	v_far_street = display_to_radiance(vec3(0.032, 0.02, 0.042));
	v_plate = display_to_radiance(plate);
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 V = normalize(w_pos - CAMERA_POSITION_WORLD);
	float tone = COLOR.r * 1.6;
	float ao = mix(ao_floor, 1.0, COLOR.g);
	float side = 1.0 - abs(n.y);
	// the surface: plate to plate grime, fine grain, the rain's streaks down every upright face
	vec2 q = abs(n.y) > 0.7 ? w_pos.xz : (abs(n.x) > abs(n.z) ? w_pos.zy : w_pos.xy);
	float grime = 0.8 + 0.34 * vnoise(q * 0.55) * vnoise(q.yx * 1.9 + 11.0);
	float grain = 0.93 + 0.14 * vnoise(q * 14.0);
	float streak = vnoise(vec2(q.x * 2.6, w_pos.y * 0.3 + 3.0));
	vec3 base = v_plate * tone * grime * grain * (1.0 - 0.16 * side * smoothstep(0.4, 0.9, streak));
	if (hazard > 0.5) {
		float st = smoothstep(0.46, 0.5, abs(fract((UV.x + UV.y) * 0.9) - 0.5) * 2.0 * 0.5 + 0.25);
		base = mix(v_plate * 0.25, display_to_radiance(vec3(0.62, 0.4, 0.05)), st) * grime * grain;
	}
	// the painted light
	vec3 L = normalize(key_dir);
	float key = max(dot(n, L), 0.0);
	float hemi = mix(under_k, sky_k, smoothstep(-0.6, 0.9, n.y));
	vec3 col = base * (hemi + key_col * key * key_k) * ao;
	// wet: the sky and the skyline in it at a low angle, most on the tops, and the key's broad highlight
	float fres = pow(1.0 - max(dot(-V, n), 0.0), 5.0);
	vec3 env = city_env(normalize(reflect(V, n)), 0.45, w_pos.y - ground_y, v_far_mass, v_far_street, 0.3);
	float wet = wet_k * (0.35 + 0.65 * smoothstep(0.2, 0.9, n.y)) * (hazard > 0.5 ? 0.4 : 1.0);
	col += env * (0.05 + 0.7 * fres) * wet * ao;
	col += display_to_radiance(vec3(0.3)) * key_col * pow(max(dot(n, normalize(L - V)), 0.0), 28.0) * wet * ao;
	// the red light out of the windows, the seams and the sign
	float rk = COLOR.b * level;
	col += display_to_radiance(red) * rk * red_k * (tone * grime * 0.3 + 0.25 * fres);
	ALBEDO = col + flash_light(w_pos, n, vec3(0.3));
}
