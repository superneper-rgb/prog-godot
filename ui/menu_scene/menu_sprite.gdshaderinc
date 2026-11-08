// The main menu backdrop's flat things: three.js Sprite (faces the camera, keeps its scale) or a plain mesh. Values are linear, as in the JS's composer; fog is FogExp2 by hand because Godot's depth fog has no such curve.
uniform sampler2D map : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec3 col = vec3(1.0);
uniform float opacity = 1.0;
uniform bool billboard = false;
uniform float fog_k = 0.0;
uniform vec3 fog_col = vec3(0.0);
varying float v_depth;

void vertex() {
	vec4 mv;
	if (billboard) {
		vec3 wp = MODEL_MATRIX[3].xyz;
		mv = VIEW_MATRIX * vec4(wp, 1.0);
		mv.xy += VERTEX.xy * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	} else {
		mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
	v_depth = -mv.z;
	POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	vec4 t = texture(map, UV);
	float d = v_depth * fog_k;
	ALBEDO = mix(col * t.rgb, fog_col, 1.0 - exp(-d * d));
	ALPHA = t.a * opacity;
}
