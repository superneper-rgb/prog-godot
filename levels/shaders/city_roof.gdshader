// FOINT CITY's roofs (levels/hub/city_facades.gd), in place of the JS roof material (city-buildings.js CityRoofs: the membrane texture under the cap's baked colour, flat and dry).
// Wet now, as everything in this city is: rain ponds on the membrane, the puddles mirror the sky and the towers round them and ring with the rain falling in them; the rest carries
// a wet film that picks the sky up at a low angle (from the Deck, a roof is mostly sky). Unshaded like the rest of the city.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/city_env.gdshaderinc"

uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float ground_y = -10.0;
uniform float lamp_k = 0.3;           // the skyline's lit windows in the puddles (as city_facade.gdshader)
uniform float pond = 0.42;            // how much of a flat roof stands in water

varying vec3 v_col;
varying vec3 w_pos;
varying flat vec3 v_far_mass;
varying flat vec3 v_far_street;

void vertex() {
	v_col = srgb_decode(COLOR.rgb);
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_far_mass = display_to_radiance(vec3(0.022, 0.016, 0.036));
	v_far_street = display_to_radiance(vec3(0.032, 0.02, 0.042));
}

void fragment() {
	vec3 V = normalize(w_pos - CAMERA_POSITION_WORLD);
	vec3 n = normalize(cross(dFdx(w_pos), dFdy(w_pos)));
	if (dot(n, V) > 0.0) {
		n = -n;
	}
	float fp = max(length(dFdx(w_pos)), length(dFdy(w_pos)));      // metres per pixel
	vec2 p = w_pos.xz;
	float above = w_pos.y - ground_y;
	vec3 base = texture(map, UV).rgb * v_col;

	// where the water stands: low spots in big soft shapes, only on the flat
	float lie = vnoise(p * 0.21) * 0.65 + vnoise(p * 0.73 + 11.0) * 0.35;
	float wet_pool = smoothstep(1.0 - pond, 1.0 - pond + 0.08 + fp * 0.05, lie) * smoothstep(0.96, 0.995, n.y);
	// rain falling in it: rings spreading out of random points, one per half-metre cell, each on its own beat
	vec3 nr = vec3(0.0, 1.0, 0.0);
	float near = 1.0 - smoothstep(0.01, 0.05, fp);
	if (near > 0.0 && wet_pool > 0.0) {
		for (int k = 0; k < 2; k++) {
			vec2 q = p * 2.0 + float(k) * vec2(0.37, 0.71);
			vec2 ci = floor(q);
			vec2 o = vec2(hash12(ci + float(k) * 17.0), hash12(ci + 5.3 + float(k) * 17.0)) * 0.6 + 0.2;
			float ph = fract(TIME * 0.9 + hash12(ci + 9.1 + float(k)));
			vec2 d = q - ci - o;
			float r = length(d);
			float ring = sin((r - ph * 0.45) * 60.0) * exp(-pow((r - ph * 0.45) * 14.0, 2.0)) * (1.0 - ph);
			nr.xz += d / max(r, 1e-3) * ring * 0.18 * near;
		}
	}
	vec3 nw = normalize(mix(n, normalize(nr), wet_pool * step(0.96, n.y)));
	vec3 R = reflect(V, nw);
	float fres = pow(1.0 - max(dot(-V, nw), 0.0), 5.0);
	vec3 city = city_env(normalize(R), mix(0.5, 0.03, wet_pool), above, v_far_mass, v_far_street, lamp_k);
	float F = mix(0.02 + 0.35 * fres, 0.02 + 0.98 * fres, wet_pool);
	float grime = 0.8 + 0.4 * vnoise(p * 0.5 + 3.0);
	ALBEDO = base * grime * (1.0 - 0.6 * wet_pool) + city * F;
}
