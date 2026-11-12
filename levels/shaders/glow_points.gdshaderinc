// three.js Points with a glowSprite map, sizeAttenuation on and additive blending (the FOINT DOME's flames and spire tips, the alley's door bulb): each point is a camera-facing quad.
// The exporter drew them as fixed-size pixel squares (Godot points have no attenuation and no texture); levels/glow_points.gd builds these quads from the exported points.
// VERTEX: the point, UV: the quad's corner, UV2.x: the point's index (JS k, for the flames' flicker).
// (the including shader sets the render mode)

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(1.0);
uniform float opacity = 1.0;
uniform float size = 1.0;        // JS PointsMaterial.size
uniform float t = 0.0;           // the district's clock
uniform float flicker = 0.0;     // 1: the lanterns' flames (JS foint-arena.js update: each one dances on its own phase)

varying vec2 v_uv;

void vertex() {
	vec3 p = VERTEX;
	float k = UV2.x;
	p += flicker * vec3(sin(t * 9.0 + k * 3.1) * 0.04, abs(sin(t * 7.0 + k * 1.7)) * 0.12, cos(t * 8.0 + k * 2.3) * 0.04);
	vec4 view = MODELVIEW_MATRIX * vec4(p, 1.0);
	float dist = max(0.1, -view.z);
	float px = size * VIEWPORT_SIZE.y * 0.5 / dist;      // three.js: gl_PointSize = size * (height / 2) / distance
	view.xy += (UV - vec2(0.5)) * 2.0 * point_half(px, dist, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]);
	VERTEX = view.xyz;
	v_uv = UV;
}

void fragment() {
	vec4 tx = texture(map, v_uv);
	ALBEDO = add_display(color * tx.rgb, tx.a * opacity);
	ALPHA = 1.0;
}
