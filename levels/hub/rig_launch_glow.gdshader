// Pauly's rig taking off (levels/hub/rig_launch.gd): one soft light on a quad. A round glow (an emitter's flare, the charge at the tail, the flash), a four-point star (the
// twinkle it leaves in the sky), or a thin ring (the shock where it went). Added to the frame, never fogged: the far ones are 250 m up the sky.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.55, 0.9, 1.0);
uniform float power = 0.0;       // 0: not drawn
uniform float face = 1.0;        // 1: turned to the camera; 0: lies as its node is placed (the pools on the road, the ring across the path)
uniform float star = 0.0;        // 0 a round glow .. 1 a four-point star
uniform float ring = 0.0;        // above 0: a ring of this radius (0..1 of the quad) in place of the glow
uniform float ring_w = 0.06;
uniform float hot = 0.25;        // how much of the middle burns to white

void vertex() {
	if (face > 0.5) {
		vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a;
	if (ring > 0.0) {
		float d = abs(r - ring);
		a = exp(-d * d / (ring_w * ring_w)) + 0.25 * exp(-d * d / (ring_w * ring_w * 9.0)) * step(r, ring);
	} else {
		float g = exp(-r * r * 9.0) + 0.3 * exp(-r * r * 2.4);
		float sx = exp(-abs(p.y) * 46.0) * exp(-abs(p.x) * 2.6);
		float sy = exp(-abs(p.x) * 46.0) * exp(-abs(p.y) * 2.6);
		a = mix(g, g * 0.5 + sx + sy, star);
	}
	a *= smoothstep(1.0, 0.82, r);
	vec3 c = mix(tint, vec3(1.0), clamp(a * hot, 0.0, 1.0));
	ALBEDO = c * power * a;
	ALPHA = 1.0;
	if (power * a < 0.0005) {
		discard;
	}
}
