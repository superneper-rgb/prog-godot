// The derelict SkySphere's inner skin (sky_venue.gd), 760 m across: blackened, rust-streaked plate, panels torn out to the dark behind,
// a few service lights still burning (sodium, the odd cold lamp), red beacons blinking, and the glow of fires deep in the lower hull.
// The level's haze swallows most of it. (2026-11-18: was a clean, lit neon sphere.)
shader_type spatial;
render_mode unshaded, cull_front;

varying vec3 radial;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(123.2, 71.9))) * 41633.19);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	radial = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(radial);
	vec2 sector_uv = UV * vec2(64.0, 36.0);
	vec2 panel_uv = fract(sector_uv);
	vec2 panel_id = floor(sector_uv);
	float frame = min(min(panel_uv.x, 1.0 - panel_uv.x), min(panel_uv.y, 1.0 - panel_uv.y));
	float seam = 1.0 - smoothstep(0.02, 0.05, frame);
	float h = hash12(panel_id);
	// blackened plate with rust bleeding down from the seams
	float streak = noise(vec2(UV.x * 900.0, UV.y * 40.0)) * smoothstep(0.0, 0.6, panel_uv.y);
	vec3 plate = mix(vec3(0.016, 0.014, 0.013), vec3(0.045, 0.024, 0.014), streak * 0.8) * (0.6 + 0.6 * h);
	plate *= 1.0 - seam * 0.6;
	// torn-out panels: nothing behind but the dark
	float torn = step(0.86, hash12(panel_id + 17.0));
	plate = mix(plate, vec3(0.002), torn * smoothstep(0.08, 0.14, frame));
	// the lights that still work
	vec2 lamp_cell = fract(panel_uv * vec2(3.0, 2.0));
	float lamp = (1.0 - smoothstep(0.03, 0.08, length(lamp_cell - 0.5))) * step(0.965, hash12(floor(panel_uv * vec2(3.0, 2.0)) + panel_id * 7.0));
	float cold = step(0.8, hash12(panel_id + 3.0));
	vec3 bulb = mix(vec3(1.0, 0.55, 0.18), vec3(0.75, 0.82, 0.9), cold);
	float beacon = (1.0 - smoothstep(0.02, 0.05, length(panel_uv - 0.5))) * step(0.97, hash12(panel_id + 41.0)) * step(0.5, fract(TIME * 0.8 + h));
	// fires deep in the lower hull
	float low = smoothstep(-0.2, -0.75, n.y);
	float fire = low * smoothstep(0.62, 0.8, noise(UV * vec2(40.0, 20.0) + TIME * 0.05)) * torn;
	vec3 col = plate + bulb * lamp * 3.0 + vec3(1.0, 0.1, 0.05) * beacon * 3.0 + vec3(0.9, 0.3, 0.06) * fire * 1.2;
	col += vec3(0.03, 0.018, 0.012) * low;
	ALBEDO = col;
}
