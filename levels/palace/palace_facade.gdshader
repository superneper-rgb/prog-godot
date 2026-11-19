// FOINT CITY's towers seen from the Pervert Palace site (levels/palace/palace_city.gd): boxes, one per tower of the hub's own footprint, drawn as the city reads at night (CLAUDE.md, 60 / 30 / 10):
// the near-black violet mass, dense runs of cyan and blue-white strip windows floor by floor, the odd amber one, dark floors, a lighter band at the top edge never lighter than the mass.
// The pattern is in world space (floors every 3.4 m, bays every 1.6 m), so any box gets it; each tower's own seed (INSTANCE_CUSTOM.x) changes its rhythm.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 mass : source_color = vec3(0.05, 0.042, 0.075);
uniform vec3 lit_a : source_color = vec3(0.45, 0.85, 1.0);
uniform vec3 lit_b : source_color = vec3(0.78, 0.88, 1.0);
uniform vec3 lit_amber : source_color = vec3(1.0, 0.62, 0.22);
uniform float glow = 2.4;

varying vec3 wpos;
varying vec3 wnrm;
varying float seed;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 n = wnrm;
	float side = abs(n.x) > abs(n.z) ? wpos.z : wpos.x;
	float flat_up = step(0.7, n.y);
	float fl = floor(wpos.y / 3.4);
	float fy = fract(wpos.y / 3.4);
	float bay = floor(side / 1.6);
	float bx = fract(side / 1.6);
	float s = seed * 37.0;
	// windows: a strip across most of each floor, broken into panes by thin mullions
	float pane = step(0.32, fy) * step(fy, 0.78) * step(0.08, bx) * step(bx, 0.94);
	float floor_on = step(0.28, h2(vec2(fl, s)));                         // some floors are dark
	float run = step(0.35, h2(vec2(floor(bay / 5.0), fl * 3.1 + s)));      // runs of bays lit together
	float one = step(0.12, h2(vec2(bay, fl + s * 1.7)));
	float on = pane * floor_on * run * one * (1.0 - flat_up);
	float pick = h2(vec2(bay * 0.37 + s, fl * 1.3));
	vec3 lit = pick < 0.06 ? lit_amber : (pick < 0.55 ? lit_a : lit_b);
	float flick = 0.85 + 0.15 * h2(vec2(bay, fl * 2.0 + s));
	vec3 base = mass * (0.85 + 0.3 * h2(vec2(fl, bay * 0.1 + s)));
	ALBEDO = mix(base, vec3(0.02, 0.025, 0.04), pane * 0.6);
	ROUGHNESS = mix(0.75, 0.18, pane);
	METALLIC = 0.0;
	SPECULAR = mix(0.35, 0.6, pane);
	EMISSION = lit * on * glow * flick;
}
