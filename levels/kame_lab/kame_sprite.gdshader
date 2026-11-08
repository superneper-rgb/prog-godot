// A camera-facing sprite of the Kamehameha (JS T.SpriteMaterial, additive): a map, an opacity, a rotation.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;
uniform sampler2D map : source_color, filter_linear, repeat_disable;
uniform float opacity = 1.0;
uniform float rot = 0.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	float c = cos(rot);
	float n = sin(rot);
	vec2 v = vec2(VERTEX.x * c - VERTEX.y * n, VERTEX.x * n + VERTEX.y * c);
	VERTEX = vec3(v, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 t = texture(map, UV);
	ALBEDO = t.rgb;
	ALPHA = pow(t.a * opacity, 2.2);      // (the JS adds in display space: over the dark this is the same falloff in linear)
}
