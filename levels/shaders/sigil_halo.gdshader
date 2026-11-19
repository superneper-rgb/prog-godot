// The glow round an armed weak point of the Sigil (enemies/sigil_beast_view.gd): a soft additive sprite that always faces the camera, sized by the view so it still reads 130 m down a tunnel.
// It ignores fog on purpose: it is the one thing the player must find. `glow` is per sprite (an instance uniform), so all of them share this material.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float glow = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.55, 0.12);

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.4) + 0.6 * pow(max(0.0, 1.0 - d * 2.2), 3.0);
	ALBEDO = color * a * glow;
}
