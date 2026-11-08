// DistrictWater (JS levels/hub/city-water.js): swell, two ripple layers, a traced reflection of the island's lit facades and the smog sky, glitter paths under the lamps, the DYOSPHERE's glint, foam at the quays.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

#define NBOX 8
#define NL 40

uniform float uWater = -12.6;
uniform float uGY = -10.0;
uniform sampler2D uRip : repeat_enable, filter_linear_mipmap;
uniform vec3 uSmog;
uniform vec3 uPlanet;
uniform vec3 uOrb;
uniform vec4 uIsle;
uniform vec4 uBox[NBOX];
uniform vec4 uL[NL];
uniform float uLN = 0.0;

varying vec3 vW;

const vec4 SW0 = vec4(0.82, 0.57, 23.0, 0.11);
const vec4 SW1 = vec4(-0.45, 0.89, 14.0, 0.075);
const vec4 SW2 = vec4(0.98, -0.2, 8.5, 0.045);
const vec4 SW3 = vec4(-0.7, -0.71, 5.2, 0.025);
vec3 swell(vec4 s, vec2 p, float t) {
	float k = 6.2832 / s.z, w = sqrt(9.8 * k) * 0.55, ph = dot(s.xy, p) * k + t * w;
	return vec3(s.w * sin(ph), s.w * k * cos(ph) * s.xy);
}
vec3 swells(vec2 p, float t) { return swell(SW0, p, t) + swell(SW1, p, t) + swell(SW2, p, t) + swell(SW3, p, t); }      // x: height, yz: slope

float h1(float n) { return fract(sin(n * 91.345) * 47453.21); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// a cheap copy of the smog dome (city-atmos.js): smog on the horizon, sodium / neon glow, teal overcast, black above, and the DYOSPHERE as a grey smear under its blue orb
vec3 sky(vec3 d) {
	float el = d.y;
	vec3 glow = mix(vec3(0.15, 0.065, 0.04), vec3(0.13, 0.035, 0.09), 0.5 + 0.5 * sin(atan(d.x, d.z) * 2.0 + 0.6));
	vec3 col = mix(uSmog, glow, smoothstep(0.0, 0.05, el) * (1.0 - smoothstep(0.05, 0.2, el)));
	col = mix(col, vec3(0.022, 0.034, 0.034), smoothstep(0.1, 0.32, el));
	col = mix(col, vec3(0.006, 0.008, 0.01), smoothstep(0.3, 0.85, el));
	float pd = dot(d, uPlanet);
	col = mix(col, vec3(0.09, 0.08, 0.11), smoothstep(0.9992, 0.99975, pd));      // the station, about 2 degrees across now (blurred by the chop it reads as one smear)
	float od = dot(d, uOrb);
	col += vec3(0.4, 0.2, 0.85) * smoothstep(0.99975, 0.99995, od) + vec3(0.06, 0.03, 0.14) * smoothstep(0.985, 0.9995, od);      // the wound and its violet aura
	return col;
}

// the island seen in the water: trace the reflected ray across to the quay; if it passes under the skyline, return a facade of lit windows
vec4 island(vec2 p, vec3 r) {
	vec2 rd = r.xz;
	float rl = length(rd);
	if (rl < 1e-4) {
		return vec4(0.0);
	}
	rd /= rl;
	vec2 inv = 1.0 / (rd + sign(rd) * 1e-5 + vec2(1e-6));
	vec2 t0 = (uIsle.xz - p) * inv, t1 = (uIsle.yw - p) * inv;      // slabs: x0/x1 and z0/z1
	vec2 tn = min(t0, t1), tf = max(t0, t1);
	float tN = max(tn.x, tn.y), tF = min(tf.x, tf.y);
	if (tF < tN || tN < 0.0) {
		return vec4(0.0);
	}
	vec2 hp = p + rd * tN;
	float y = uWater + r.y / rl * tN;      // where it hits, and how high up
	bool xFace = tn.x > tn.y;
	float s = xFace ? hp.y : hp.x;         // the coordinate along that quay
	float seg = floor(s / 21.0) + (xFace ? 37.0 : 0.0), H = 16.0 + 105.0 * pow(h1(seg + (hp.x > 0.0 ? 3.1 : 0.0) + (hp.y > 300.0 ? 7.7 : 0.0)), 1.6), z = y - uGY;
	if (z > H) {
		return vec4(0.0);
	}
	if (z < 0.0) {
		return vec4(vec3(0.012, 0.013, 0.015), 1.0);      // the quay wall
	}
	vec2 cell = vec2(floor(s / 2.5), floor(z / 3.3));
	float lit = step(0.64, h2(cell + seg));
	vec3 win = mix(vec3(1.0, 0.62, 0.3), vec3(0.45, 0.7, 1.0), step(0.75, h2(cell * 1.7 + 3.0))) * lit * (0.12 + 0.12 * h2(cell + 9.0));
	vec3 col = vec3(0.014, 0.012, 0.012) + win * (1.0 - smoothstep(H - 4.0, H, z) * 0.6);
	vec3 neon = mix(mix(vec3(1.0, 0.2, 0.6), vec3(0.2, 0.9, 1.0), h1(seg * 3.3)), vec3(1.0, 0.55, 0.15), step(0.66, h1(seg * 5.1)));
	col += neon * 0.16 * smoothstep(5.5, 3.5, z) * step(0.35, h1(seg * 7.9));      // shop fronts and signs along the waterfront drive
	return vec4(col, 1.0);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = 1.0 - smoothstep(50.0, 200.0, distance(wp.xz, CAMERA_POSITION_WORLD.xz));
	float dy = swells(wp.xz, TIME).x * fade;
	wp.y += dy;
	VERTEX.y += dy;
	vW = wp;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 p = vW.xz;
	vec3 toC = cam - vW;
	float dist = length(toC);
	vec3 vd = toC / dist;
	float near_k = 1.0 - smoothstep(20.0, 170.0, dist);
	// the surface: swell slope + two ripple layers drifting across each other (mipmaps calm them down in the distance)
	vec3 sw = swells(p, TIME) * (1.0 - smoothstep(150.0, 450.0, dist));
	vec4 r1 = texture(uRip, p * 0.043 + vec2(TIME * 0.021, TIME * 0.012));
	vec4 r2 = texture(uRip, p * 0.117 + vec2(-TIME * 0.034, TIME * 0.027));
	vec2 rip = (r1.xy - 0.5) * 0.9 + (r2.xy - 0.5) * 0.6 * (1.0 - smoothstep(25.0, 110.0, dist));      // the fine layer only up close
	float chop = 0.12 + 0.55 * near_k * near_k;      // flatter in the distance: a calm mirror there, no sparkle noise
	vec3 N = normalize(vec3(-sw.y + rip.x * chop, 1.0, -sw.z + rip.y * chop));
	float ht = r1.a * 0.6 + r2.a * 0.4;
	// reflection: island facades if the ray comes back at the quay, else the sky
	vec3 r = reflect(-vd, N);
	r.y = abs(r.y) + 0.002;
	vec4 isl = island(p, r);
	vec3 refl = mix(sky(r), isl.rgb, isl.a);
	float fres = 0.03 + 0.97 * pow(1.0 - max(dot(N, vd), 0.0), 5.0);
	vec3 deep = vec3(0.004, 0.012, 0.015) + vec3(0.006, 0.016, 0.014) * ht;      // murky harbour green-black, a touch lighter on the crests
	vec3 col = mix(deep, refl, clamp(fres * 1.15, 0.0, 1.0));
	// glitter paths under the lamps: the light's mirror image sits where the camera-to-image ray meets the water; the chop smears it into a
	// broken streak along the line of sight, longer the flatter the view
	float hc = max(cam.y - uWater, 0.3);
	for (int i = 0; i < NL; i++) {
		if (float(i) >= uLN) {
			break;
		}
		vec4 L = uL[i];
		float hl = L.y - uWater;
		vec2 cl = L.xz - cam.xz;
		vec2 P0 = cam.xz + cl * (hc / (hc + hl));
		vec2 d = p - P0;
		float lc = length(cl);
		vec2 u = lc > 0.01 ? cl / lc : vec2(0.0, 1.0);
		float along = dot(d, u), across = dot(d, vec2(-u.y, u.x));
		float dP = length(P0 - cam.xz), len = 3.0 + dP * 0.5 + dP * dP / (hc * 6.0 + 8.0) * 0.12, wid = 0.25 + dP * 0.008;
		len = min(len, 40.0);
		across += rip.x * 2.2 * wid;      // the chop pushes the streak about sideways
		float g = exp(-across * across / (wid * wid)) * exp(-along * along / (len * len)) * step(0.0, dot(p - cam.xz, cl));      // lamps behind the camera leave no path in front of it
		float dash = smoothstep(0.42, 0.7, ht + rip.y * 0.6);      // broken into wobbling dashes by the ripples
		vec3 lcol = L.w > 0.5 ? vec3(1.0, 0.6, 0.28) : vec3(0.45, 0.68, 1.0);
		col += lcol * g * (0.15 + 0.85 * dash) * 0.7;
	}
	// glints: the DYOSPHERE orb's glitter path, and sparkles on the ripple crests catching the city glow
	float pg = pow(max(dot(r, uOrb), 0.0), 900.0);
	col += vec3(0.5, 0.28, 0.9) * pg * smoothstep(0.5, 0.75, r2.a) * 0.6;
	float spk = smoothstep(0.9, 0.99, r1.a * r2.a * 1.25) * (1.0 - smoothstep(15.0, 90.0, dist)) * fres;
	col += mix(vec3(1.0, 0.55, 0.3), vec3(0.6, 0.8, 1.0), r1.a) * spk * 0.5;
	// foam slapping at the quay walls, the hub platform and the piers
	float dB = 1e5;
	for (int i = 0; i < NBOX; i++) {
		vec4 b = uBox[i];
		vec2 q = max(vec2(b.x - p.x, b.z - p.y), vec2(p.x - b.y, p.y - b.w));
		dB = min(dB, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0));
	}
	float lap = 1.1 + 0.6 * sin(TIME * 1.3 + p.x * 0.21 + p.y * 0.17) + 0.6 * r2.a;
	float foam = (1.0 - smoothstep(0.0, lap, dB)) * smoothstep(0.38, 0.62, texture(uRip, p * 0.29 + vec2(TIME * 0.05, -TIME * 0.04)).a);
	col = mix(col, vec3(0.07, 0.075, 0.075), foam * 0.8 * step(0.0, dB));
	ALBEDO = col;
}
