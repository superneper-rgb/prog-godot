// FOINT CITY's buildings (levels/shaders/city_facade.gdshader, city_shop.gdshader): what their glass and wet faces share. The city draws with its reflections off, so a face
// carries the city itself: the level's live sky, the skyline across the street with its lit windows, the wet street below. Plus the hashes and noise both use.
#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 sky_hor = vec3(0.044, 0.012, 0.0375);      // the level's sky as radiance (hub_level.gd VIOLET / EMBER), kept in step by CityFacades.set_sky
uniform vec3 sky_band = vec3(0.024, 0.008, 0.032);
uniform vec3 sky_zen = vec3(0.0057, 0.0032, 0.0134);
uniform float sky_gain = 2.2;

const vec3 COOL = vec3(0.3, 0.72, 1.0);       // Neo-Gotham's windows (the Batman Beyond references): mostly cyan,
const vec3 PALE = vec3(0.72, 0.84, 1.0);      // some blue-white,
const vec3 WARM = vec3(1.0, 0.56, 0.24);      // amber the odd one out

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float vnoise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// A wall's frame from screen derivatives (the exported normals all point up): its outward normal, level (every wall is plumb), and the way `u` (metres) runs along it.
// Call at the top of fragment(), outside any branch.
void city_face(vec3 w, vec3 V, float u, out vec3 n, out vec3 T) {
	vec3 dpx = dFdx(w);
	vec3 dpy = dFdy(w);
	vec2 du = vec2(dFdx(u), dFdy(u));
	n = cross(dpx, dpy);
	n.y = 0.0;
	n = length(n) > 1e-9 ? normalize(n) : -normalize(vec3(V.x, 0.0, V.z) + vec3(1e-4));
	if (dot(n, V) > 0.0) {
		n = -n;
	}
	vec3 tc = vec3(-n.z, 0.0, n.x);
	T = dot(dpx, tc) * du.x + dot(dpy, tc) * du.y < 0.0 ? -tc : tc;
}

// What a face sees in world direction d, as radiance: the sky, the skyline across the street with its windows, the wet street below. soft: 0 a mirror, 1 a blur.
// above: how high the face is (the higher up, the more of the city sits below the horizon). mass_r, street_r: the skyline's and the street's dark, as radiance. wk: a lit window's light.
vec3 city_env(vec3 d, float soft, float above, vec3 mass_r, vec3 street_r, float wk) {
	float y = d.y;
	float az = atan(d.x, d.z);
	vec3 sky = mix(sky_hor, sky_band, smoothstep(0.0, 0.22, y));
	sky = mix(sky, sky_zen, smoothstep(0.15, 0.75, y)) * sky_gain;
	float c = floor(az * 6.0);
	float near = clamp(1.0 - above / 170.0, 0.12, 1.0);
	float top = (0.1 + 0.6 * hash11(c * 7.7 + 1.3) * hash11(c * 3.1 + 9.2)) * near * step(0.22, hash11(c + 41.0));
	float tower = 1.0 - smoothstep(top - 0.01 - soft * 0.25, top + 0.01 + soft * 0.25, y);
	vec2 g = vec2(az * 18.0, y * 15.0);
	vec2 gi = floor(g);
	float w = step(0.8, hash12(gi)) * step(0.55, fract(g.x)) * step(0.6, fract(g.y)) * (1.0 - smoothstep(0.0, 0.3, soft));
	vec3 wc = mix(WARM, COOL, step(0.12, hash12(gi + 5.0)));
	vec3 m = mass_r + wc * wk * (w * 0.5 + 0.03 * soft);
	vec3 up = mix(sky, m, tower);
	vec3 below = street_r + sky_hor * sky_gain * 0.25;
	return mix(below, up, smoothstep(-0.03 - soft * 0.3, 0.03 + soft * 0.3, y));
}
