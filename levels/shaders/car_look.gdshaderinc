// FOINT CITY's cars (levels/hub/city_cars.gd): what their paint, parts and glass share. The city draws with its reflections off (core/material_look.gd), so a glossy car would mirror nothing:
// here the surface carries the city itself: the level's own sky, the skyline's dark mass with its amber windows, the cold lamp row along the street, the wet road below. Plus the street's
// baked night fill, as the old cars had (levels/shader_ports.gd _fill_block), so a dark car still reads at night.
#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 sky_hor = vec3(0.066, 0.0085, 0.0055);      // the level's sky as radiance (hub_level.gd VIOLET / EMBER), kept in step by CityCars.set_sky
uniform vec3 sky_band = vec3(0.037, 0.004, 0.0036);
uniform vec3 sky_zen = vec3(0.011, 0.0019, 0.0029);
uniform float sky_gain = 2.2;

float car_h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float car_h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 car_h3(vec3 p) { return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453); }

// what a surface sees in world direction d, as radiance. soft: 0 a mirror, 1 a blur
vec3 car_city(vec3 d, float soft) {
	float y = d.y;
	float az = atan(d.x, d.z);
	vec3 sky = mix(sky_hor, sky_band, smoothstep(0.0, 0.22, y));
	sky = mix(sky, sky_zen, smoothstep(0.15, 0.75, y)) * sky_gain;
	// the skyline: towers of different heights with gaps between them (the horizon's glow comes through: the streaks down a flank), windows lit amber here and there
	float col = floor(az * 9.0);
	float top = (0.03 + 0.36 * car_h1(col) * car_h1(col + 31.0)) * step(0.35, car_h1(col + 7.0));
	float tower = 1.0 - smoothstep(top - 0.01 - soft * 0.2, top + 0.01 + soft * 0.2, y);
	float win = step(0.80, car_h2(floor(vec2(az * 54.0, y * 70.0)))) * step(0.2, fract(az * 54.0)) * step(0.3, fract(y * 70.0));
	vec3 mass = display_to_radiance(vec3(0.030, 0.016, 0.050) + vec3(1.0, 0.60, 0.22) * win * (1.0 - soft) * 0.9 + vec3(0.25, 0.12, 0.08) * soft * 0.25);
	vec3 up = mix(sky, mass, tower);
	// the street's lamp row: cold, low on the horizon
	float lf = fract(az * 5.0 + 0.3);
	float lamp = step(0.55, lf) * (1.0 - smoothstep(0.0, 0.05, abs(lf - 0.78)));
	up += display_to_radiance(vec3(0.62, 0.60, 0.70)) * lamp * (1.0 - smoothstep(0.02, 0.05 + soft * 0.2, abs(y - 0.07))) * (1.0 - soft * 0.6);
	vec3 road = display_to_radiance(vec3(0.05, 0.03, 0.06)) + sky_hor * sky_gain * 0.35 * smoothstep(-0.5, 0.0, y);
	return mix(road, up, smoothstep(-0.015 - soft * 0.3, 0.015 + soft * 0.3, y));
}

// ---- grime (2026-11-10): these are the cars of the people at the bottom, so they wear it. Road film thrown up from the wet street, drips run down the flanks, dust and water spots on
// the flat tops, chips, a faded coat and now and then a door in primer. All in the dark mass's values (FOINT CITY's 60/30/10): a dull grey-violet haze, never brown rust or a bright patch.
// Every car its own amount and pattern, keyed to its street slot so a car you take keeps the grime it had in the street.
uniform float own_seed = -1.0;      // a car you drive: the slot it had in the street (CityCars.model); < 0: a street MultiMesh, whose instance is its slot
uniform float grime = 0.0;          // the fleet's overall dirt (0: showroom). Off since 2026-11-11 (user): on screen the dirt read as a splotchy, badly made texture, not as grime

float car_vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec3(1.0, 57.0, 113.0));
	float a = mix(car_h1(n), car_h1(n + 1.0), f.x);
	float b = mix(car_h1(n + 57.0), car_h1(n + 58.0), f.x);
	float c = mix(car_h1(n + 113.0), car_h1(n + 114.0), f.x);
	float d = mix(car_h1(n + 170.0), car_h1(n + 171.0), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}
float car_fbm(vec3 p) { return 0.55 * car_vn(p) + 0.3 * car_vn(p * 2.07 + 13.1) + 0.15 * car_vn(p * 4.31 + 7.7); }

// the car's own frame (x left, y up, z forward) from what the vertex stage got: a street MultiMesh is turned (x forward), a car you drive is not
vec3 car_frame(vec3 q) { return own_seed < 0.0 ? vec3(-q.z, q.y, q.x) : q; }
float car_seed(int inst) { return own_seed < 0.0 ? float(inst) : own_seed; }

// x: dirt (road film, drips, dust), y: chip, z: primer panel, w: the car's own amount
vec4 car_grime(vec3 p, vec3 n, float seed) {
	if (grime <= 0.0) {
		return vec4(0.0);      // (clean: skip the noise altogether)
	}
	float amt = grime * (0.3 + 0.7 * car_h1(seed * 1.37 + 0.11));
	vec3 o = vec3(car_h1(seed * 2.1), car_h1(seed * 3.7), car_h1(seed * 5.3)) * 40.0;
	float h = p.y;
	float wob = car_fbm(p * vec3(2.6, 5.0, 2.6) + o);
	// road film: thrown up by the wheels, thick on the sills and thinning in blotches up the flank (a low line: the clean coat above it is what makes the dirt read)
	float road = 1.0 - smoothstep(0.1, 0.3 + 0.28 * amt, h + (wob - 0.5) * 0.4);
	road *= 0.45 + 0.55 * smoothstep(0.3, 0.7, car_fbm(p * vec3(7.0, 3.0, 7.0) + o * 1.7));
	float side = 1.0 - abs(n.y);
	// drips: dirty water run down from the window line and the shoulders, thin and long
	float drip = smoothstep(0.62, 0.92, car_vn(vec3((p.x + p.z) * 16.0, h * 0.9, seed) + o)) * smoothstep(0.35, 0.75, car_vn(vec3((p.x + p.z) * 3.0, h * 2.5, seed + 3.0))) * side * smoothstep(1.4, 0.35, h);
	float top = smoothstep(0.45, 0.9, n.y);
	float spots = smoothstep(0.55, 0.75, car_vn(p * 22.0 + o));
	float dust = top * (0.25 + 0.75 * spots) * smoothstep(0.35, 0.75, car_fbm(p * 1.3 + o));
	float dirt = clamp(amt * (road * 1.1 + drip * 0.8 + dust * 0.6), 0.0, 1.0);
	float chip = step(0.955 - 0.03 * amt, car_vn(p * 41.0 + o)) * (0.35 + 0.65 * road) * amt;
	// one front door in primer on some cars (the door every kind has, about the driver's place)
	float pick = car_h1(seed * 7.9 + 0.3);
	float sd = pick > 0.86 ? 1.0 : -1.0;
	float primer = step(0.78, pick) * step(0.0, p.x * sd) * step(0.5, abs(p.x)) * step(-0.45, p.z) * step(p.z, 0.55) * step(0.28, h) * step(h, 0.92) * side;
	return vec4(dirt, chip, primer, amt);
}
const vec3 CAR_FILM = vec3(0.0145, 0.0122, 0.0142);   // the road film: sRGB ~0.12 grey-violet. Wet (it always rains down here): darker than dust would be, and it still shines
const vec3 CAR_PRIMER = vec3(0.012, 0.011, 0.014);    // sRGB ~0.11
const vec3 CAR_BARE = vec3(0.05, 0.048, 0.055);

// EMISSION for a car surface: the night fill, the city blurred in the base coat (tinted by it), the city sharp in the clear coat. n: the surface normal, nf: the same tipped by the flake (view space)
vec3 car_emission(vec3 albedo, float metal, float coat, float fill, vec3 n, vec3 nf, vec3 view, mat4 inv_view) {
	float fres = 0.10 + 0.90 * pow(1.0 - clamp(dot(n, view), 0.0, 1.0), 4.0);
	vec3 rw = (inv_view * vec4(reflect(-view, n), 0.0)).xyz;
	vec3 rf = (inv_view * vec4(reflect(-view, nf), 0.0)).xyz;
	vec3 e = albedo * fill * (0.55 + 0.45 * clamp((inv_view * vec4(n, 0.0)).y * 0.5 + 0.5, 0.0, 1.0));
	e += car_city(rf, 0.75) * (albedo * 5.0 + 0.02) * metal;
	e += car_city(rw, 0.0) * fres * coat;
	return e;
}
