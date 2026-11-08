// Soft sprites that turn (OMNISPHERE). Instance origin = position, COLOR = aCol, INSTANCE_CUSTOM = aSize, aAlpha, aRot. JS: no tone map.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D uMap : source_color, filter_linear_mipmap;
uniform float uScale = 449.0;

varying float vA;
varying float vR;
varying vec3 vC;
varying vec2 vPc;

void vertex() {
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float d = -c.z;
	float px = clamp(INSTANCE_CUSTOM.x * uScale / max(d, 0.1), 0.0, 900.0);
	vA = INSTANCE_CUSTOM.y * smoothstep(0.8, 5.0, d) * step(1.0, px);
	vR = INSTANCE_CUSTOM.z;
	vC = COLOR.rgb;
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	vec2 u = vPc - 0.5;
	float co = cos(vR), si = sin(vR);
	u = vec2(co * u.x - si * u.y, si * u.x + co * u.y) + 0.5;
	vec4 t = texture(uMap, u);
	float al = t.a * vA;
	if (al < 0.003) {
		discard;
	}
	ALBEDO = display_to_radiance(vC * t.rgb);
	ALPHA = al;
}
