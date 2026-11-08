// The gray family's world-space extras (enemies/fx_beam.gd): additive tubes and bubbles (mode 0), and a camera-facing glow dot (mode 1, the JS's sprite with its soft radial falloff).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform int mode = 0;      // 2: fissures on the floor, drawn here (the JS paints them on a canvas)
instance uniform vec4 tint = vec4(1.0);
instance uniform float opacity = 1.0;

void vertex() {
	if (mode == 1) {
		float s = length(MODEL_MATRIX[0].xyz);
		vec4 view = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
		view.xy += VERTEX.xy * s;
		POSITION = PROJECTION_MATRIX * view;
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);      // (a shader that writes POSITION must write it on every path: Godot does not fall back)
	}
}

void fragment() {
	float a = 1.0;
	if (mode == 1) {
		float d = length(UV * 2.0 - vec2(1.0));
		a = d < 0.35 ? mix(1.0, 0.45, d / 0.35) : mix(0.45, 0.0, clamp((d - 0.35) / 0.65, 0.0, 1.0));
	}
	if (mode == 2) {
		vec2 p = UV * 2.0 - vec2(1.0);
		float ang = atan(p.y, p.x);
		float r = length(p);
		float spokes = abs(sin(ang * 3.5 + sin(r * 9.0) * 0.6));
		a = smoothstep(0.1, 0.0, spokes * (0.25 + r)) * smoothstep(1.0, 0.45, r);
	}
	if (mode == 3) {      // the JS RingGeometry(0.75, 1)
		float r = length(UV * 2.0 - vec2(1.0));
		a = step(0.75, r) * step(r, 1.0);
	}
	if (mode == 4) {      // a plain flat rectangle
		a = 1.0;
	}
	ALBEDO = add_display(tint.rgb, a * opacity);
	ALPHA = 1.0;
}
