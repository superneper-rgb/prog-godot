// The body of cine_glow: billboard at the node's scale, radial alpha.
uniform vec4 col : source_color = vec4(1.0);

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = r < 0.35 ? mix(1.0, 0.45, r / 0.35) : mix(0.45, 0.0, clamp((r - 0.35) / 0.65, 0.0, 1.0));
	ALBEDO = col.rgb * COLOR.rgb;
#ifdef ADDITIVE
	ALPHA = pow(a * col.a * COLOR.a, 2.2);      // (the JS adds in display space: over the dark this is the same falloff in linear)
#else
	ALPHA = a * col.a * COLOR.a;
#endif
}
