// Main menu backdrop: water on Prog (JS DROP_VS, DROP_FS): beads, running drops, splash rings and spray, as camera-facing quads of a MultiMesh. COLOR.a is the drop's alpha; the instance's scale is its size in metres.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D map : filter_linear, repeat_disable;
uniform vec3 u_color = vec3(1.0);
varying float v_a;

void vertex() {
	v_a = COLOR.a;
	vec4 mv = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	mv.xy += VERTEX.xy * length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	vec4 t = texture(map, UV);
	float a = t.a * v_a;
	if (a < 0.003) {
		discard;
	}
	ALBEDO = u_color * t.rgb * a;
	ALPHA = a;
}
