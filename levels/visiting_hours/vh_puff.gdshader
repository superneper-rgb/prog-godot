// VISITING HOURS: the drain's steam: a soft round card facing the camera (JS a Sprite with the glow map and normal blending; the export's copy of that map has lost its alpha). Same falloff as the glow's alpha, in premultiplied form.
// (fog_disabled: on a premultiplied card Godot's fog is not scaled by the card's alpha, so its whole square lays the fog colour over the frame. The card thins out in the last metres before the lens: walking into the pipe through the steam otherwise washes the whole picture grey.)
shader_type spatial;
render_mode blend_premul_alpha, unshaded, shadows_disabled, depth_draw_never, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

instance uniform vec3 col = vec3(1.0);
instance uniform float opacity = 0.0;
varying float v_near;

void vertex() {
	vec4 view = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	view.xy += VERTEX.xy * length(MODEL_MATRIX[0].xyz);
	v_near = smoothstep(0.8, 6.0, -view.z);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float d = length(UV * 2.0 - vec2(1.0));
	float a = (d < 0.22 ? mix(1.0, 0.5, d / 0.22) : mix(0.5, 0.0, clamp((d - 0.22) / 0.78, 0.0, 1.0))) * opacity * v_near;
	ALBEDO = display_to_radiance(radiance_to_display(col) * a);
	ALPHA = a;
}
