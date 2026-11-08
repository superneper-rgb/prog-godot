// A soft glow that faces the camera (JS arc sprite canvas: white centre, pale blue at a quarter, blue fading out). The instance's scale is the size; drawn on a unit quad.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
varying vec2 v_uv;

void vertex() {
	v_uv = VERTEX.xy * 2.0;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * length(MODEL_MATRIX[0].xyz), 0.0);
}

void fragment() {
	float d = length(v_uv);
	vec4 a = vec4(1.0, 1.0, 1.0, 1.0);
	vec4 b = vec4(130.0 / 255.0, 205.0 / 255.0, 1.0, 0.7);
	vec4 e = vec4(40.0 / 255.0, 100.0 / 255.0, 1.0, 0.0);
	vec4 g = d < 0.25 ? mix(a, b, d / 0.25) : mix(b, e, clamp((d - 0.25) / 0.75, 0.0, 1.0));
	ALBEDO = COLOR.rgb * pow(g.rgb, vec3(2.2));
	ALPHA = g.a;
}
