// Bullet tracers (JS FX.tracer): a thin additive box from muzzle to hit, fading over its life. INSTANCE_CUSTOM = (t0, life). The CPU never touches a live tracer.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://levels/shaders/common.gdshaderinc"
uniform float now = 0.0;
varying float v_a;

void vertex() {
	float t = now - INSTANCE_CUSTOM.x;
	if (t < 0.0 || t >= INSTANCE_CUSTOM.y) {
		VERTEX = vec3(0.0);
		v_a = 0.0;
	} else {
		v_a = (1.0 - t / INSTANCE_CUSTOM.y) * 0.9;
	}
}

void fragment() {
	ALBEDO = add_display(COLOR.rgb, v_a);
	ALPHA = 1.0;
}
