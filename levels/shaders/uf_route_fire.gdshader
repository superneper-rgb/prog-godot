// UNDERFOINT's last line: fire, flashes and sparks that ride with the moving route (levels/shaders/uf_route_puff.gdshaderinc), additive, with a broken edge so a fireball is not a disc.
// 2026-11-15: its fringe reached the quad's edge where the noise ran low (a square glow showed), and it cut straight into the wall it burned against: now a round window that is zero inside the
// quad, a warped flame noise that licks upward as it ages, and soft particles where it meets the scene.
shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_never, cull_disabled, fog_disabled;

#include "res://levels/shaders/uf_route_puff.gdshaderinc"

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float d = length(p);
	vec2 q = p * 1.5 + vec2(vSeed * 11.0, vSeed * 5.0);
	float f = fbm(q + vec2(0.0, vAge * 1.6) + 0.6 * vec2(fbm(q * 1.7 - vAge), 0.0));
	d += (f - .45) * .5;
	float a = (d < 0.22 ? mix(1.0, 0.55, d / 0.22) : mix(0.55, 0.0, clamp((d - 0.22) / 0.6, 0.0, 1.0))) * vA;
	a *= 1.0 - smoothstep(0.6, 0.97, length(p));
	if (vSize > 0.4) {      // (a spark is too small to need it)
		a *= soft_edge(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, max(0.4, vSize * 0.35));
	}
	ALBEDO = vC * a;
}
