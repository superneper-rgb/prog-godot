// UNDERFOINT's last line: smoke and dust that ride with the moving route (levels/shaders/uf_route_puff.gdshaderinc).
// 2026-11-15 (audit: "flat cards with hard square edges", worst in the twin bores and the gate hall). Two causes: the cards were premultiplied but still took the scene's fog, which Godot adds to the
// whole quad whatever its alpha, so every card showed its square in the haze; and the old alpha was still ~0.6 at the quad's edge where the noise ran low, and cut straight into the wall it touched.
// Now each puff is an ordinary alpha-blended, LIT card (fog then blends right): a round window that is zero well inside the quad, a domain-warped fbm that rolls as the puff ages, a normal bent
// over it like a ball so the line's lamps and fires light its near side and leave its far side dark, and faded out where it meets the scene behind it (soft particles).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://levels/shaders/uf_route_puff.gdshaderinc"

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	vec2 q = p * 1.35 + vec2(vSeed * 17.0, vSeed * 9.0);
	vec2 w = vec2(fbm(q + vec2(0.0, vAge * 0.35)), fbm(q + vec2(5.2, 1.3) - vec2(vAge * 0.28, 0.0)));
	float f = fbm(q * 1.6 + w * 1.8 - vec2(0.0, vAge * 0.2));
	float edge = 1.0 - smoothstep(0.1, 0.97, r);
	float dens = smoothstep(0.0, 0.8, edge * (0.3 + 1.1 * f) - 0.08);
	ALPHA = dens * vA * soft_edge(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, max(0.6, vSize * 0.45));
	ALBEDO = vC * (0.75 + 0.5 * f);
	NORMAL = normalize(vec3(p.x, -p.y, 1.2 * sqrt(max(0.0, 1.0 - min(r, 1.0)))) + vec3(0.0, 0.0, 0.25));
}
