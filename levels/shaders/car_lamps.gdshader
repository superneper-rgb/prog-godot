// The lamps on the moving cars (JS levels/hub/city-traffic.js lampMat, the CarLamps Points cloud): head, tail, indicators, roof signs. One draw per car type. The JS rewrites every lamp's place and colour in script each frame; here each lamp is a quad at its place on the car, in the car's own transform.
// VERTEX = the lamp's place on the car, UV = the quad's corner (+-1), COLOR = its colour, CUSTOM0.x = what it answers to (0 always on, 1 the brake, 2 and 3 the indicators of either side). INSTANCE_CUSTOM: x brake level, y left indicators, z right indicators.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float SIZE = 1.25;    // JS: PointsMaterial size, sizeAttenuation

varying vec3 vCol;
varying vec2 vUv;

void vertex() {
	float ch = CUSTOM0.x;
	float k = ch < 0.5 ? 1.0 : (ch < 1.5 ? INSTANCE_CUSTOM.x : (ch < 2.5 ? INSTANCE_CUSTOM.y : INSTANCE_CUSTOM.z));
	vCol = COLOR.rgb * k;
	vUv = UV * vec2(0.5, -0.5) + 0.5;
	vec3 c = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = k > 0.0 ? SIZE * 0.5 / PROJECTION_MATRIX[1][1] : 0.0;      // (three.js: a point SIZE * height / 2 / distance pixels across)
	VERTEX = c + vec3(UV * h, 0.0);
}

void fragment() {
	vec4 t = texture(map, vUv);
	ALBEDO = add_display(vCol * t.rgb, t.a);
}
