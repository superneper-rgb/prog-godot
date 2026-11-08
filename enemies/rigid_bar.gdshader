// RigidBatch, the health bars: dark background + fill, never depth tested, all copies of a model in one draw.
// The copy's row: texel 9 = the bar's world position + the robot's yaw, texel 10 = fill colour + fill fraction (< 0 hides the bar); texel 0.w = the bar's world scale.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, skip_vertex_transform;

uniform sampler2D data : filter_nearest, repeat_disable;

varying vec4 v_col;

void vertex() {
	int row = INSTANCE_ID;
	vec4 at = texelFetch(data, ivec2(9, row), 0);
	vec4 fill = texelFetch(data, ivec2(10, row), 0);
	float bar_scale = texelFetch(data, ivec2(0, row), 0).w;
	vec3 p = VERTEX;
	if (UV2.x > 0.5) {                               // the fill: shrinks toward its left end
		float f = max(0.001, fill.a);
		p.x = p.x * f - 0.43 * (1.0 - f);
		v_col = vec4(fill.rgb, 1.0);
	} else {
		v_col = COLOR;
	}
	// the JS bar copies the camera's rotation into a child of the robot's group, so the robot's yaw turns it on top of that; kept, it is what the game shows
	vec3 q = mat3(INV_VIEW_MATRIX) * (p * bar_scale);
	float s = sin(at.w);
	float c = cos(at.w);
	vec3 w = at.xyz + vec3(c * q.x + s * q.z, q.y, -s * q.x + c * q.z);
	VERTEX = fill.a < 0.0 ? vec3(0.0) : (VIEW_MATRIX * vec4(w, 1.0)).xyz;
}

void fragment() {
	ALBEDO = v_col.rgb;
	ALPHA = v_col.a;
}
