// A flying car's hull (see sky_traffic.gdshaderinc). Dark, vertex coloured, unlit: it is a silhouette against the smog with its lights.
shader_type spatial;
render_mode unshaded, shadows_disabled, skip_vertex_transform;

#include "res://levels/shaders/common.gdshaderinc"
#include "res://levels/shaders/sky_traffic.gdshaderinc"

varying vec3 vCol;

mat3 rX(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 rY(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rZ(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	float yaw, turn, bob;
	vec3 at = lane_at(MODEL_MATRIX, t, yaw, turn, bob);
	mat3 R = rY(yaw) * rX(sin(t * 0.9 + bob) * 0.04) * rZ(-turn * 0.5 + sin(t * 0.5 + bob) * 0.05);      // (JS Euler YXZ)
	vCol = srgb_decode(COLOR.rgb);      // (the exporter's vertex colours are stored encoded)
	VERTEX = (VIEW_MATRIX * vec4(at + R * VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vCol;
}
