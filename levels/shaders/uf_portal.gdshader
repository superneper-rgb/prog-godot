// A hole SERN's machinery tears in the air (levels/underfoint/uf_chase.gd): the Sigil was built from it, and it leaks. A flat card: a black throat with somewhere else's light far down it, a rim that
// burns violet to white and arms of light dragged round it. `open` 0..1 grows it from a spark.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;

uniform float open = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p) / max(open, 0.001);
	float a = atan(p.y, p.x);
	float t = TIME + seed * 10.0;
	float edge = 0.78 + 0.07 * noise(vec2(a * 2.5 + seed * 5.0, t * 1.7)) + 0.03 * sin(a * 9.0 - t * 6.0);
	float rim = exp(-pow((r - edge) * 9.0, 2.0));
	float arms = noise(vec2(a * 3.0 + r * 7.0 - t * 2.4, r * 3.0 - t * 0.6));
	float inside = 1.0 - smoothstep(edge - 0.05, edge, r);
	float deep = pow(max(0.0, 1.0 - r / edge), 2.5);
	vec3 col = vec3(0.01, 0.0, 0.03) * inside;
	col += vec3(0.25, 0.75, 1.0) * deep * (0.5 + 0.8 * noise(p * 6.0 + t)) * 1.6;      // the light of wherever it goes
	col += vec3(0.62, 0.3, 1.0) * arms * inside * smoothstep(0.25, 0.95, r / edge) * 1.3;
	col += mix(vec3(0.6, 0.25, 1.0), vec3(1.0, 0.95, 1.0), rim) * rim * 3.2;
	float halo = exp(-max(0.0, r - edge) * 7.0) * 0.5 * (1.0 - inside);
	col += vec3(0.5, 0.25, 0.9) * halo;
	ALBEDO = col;
	ALPHA = clamp(inside + rim + halo, 0.0, 1.0) * step(0.001, open);
}
