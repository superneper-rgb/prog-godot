// WetReflections (JS levels/hub/city-streets.js): a lamp's streak on the wet road, always pointing at the camera and fading with the view angle. Instance origin = aC, COLOR = aCol, INSTANCE_CUSTOM.xy = aSize.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float uK = 1.0;

varying vec2 vQ;
varying vec3 vCol;
varying float vF;

void vertex() {
	vec3 aC = MODEL_MATRIX[3].xyz;
	vec2 aSize = INSTANCE_CUSTOM.xy;
	vec2 d = CAMERA_POSITION_WORLD.xz - aC.xz;
	float dl = length(d);
	d = dl > 0.01 ? d / dl : vec2(0.0, 1.0);
	vec2 n = vec2(-d.y, d.x);
	float L = aSize.x * (0.6 + 0.8 * clamp(dl / 40.0, 0.0, 1.0));
	vec3 wp = vec3(aC.x + d.x * VERTEX.y * L + n.x * VERTEX.x * aSize.y, aC.y, aC.z + d.y * VERTEX.y * L + n.y * VERTEX.x * aSize.y);
	vQ = VERTEX.xy;
	vCol = COLOR.rgb;
	vec3 vd = normalize(CAMERA_POSITION_WORLD - wp);
	vF = pow(1.0 - clamp(vd.y, 0.0, 1.0), 2.0);
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float a = exp(-vQ.x * vQ.x * 4.0) * (1.0 - vQ.y) * smoothstep(0.0, 0.08, vQ.y);
	ALBEDO = add_display(vCol * a * vF * uK, 1.0);
}
