// The lenses of the city's traffic signals (JS levels/hub/city-streets.js lensPts + its per-frame recolouring, city-plan.js signalAt): each lens works out its own aspect from the street clock, so the whole grid costs one uniform a frame and always agrees with what the drivers obey.
// Instance origin = the lens, INSTANCE_CUSTOM: x junction offset, y axis (0 x, 1 z), z kind (0 red, 1 yellow, 2 green, 3 the pedestrian head).
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float sim_t = 0.0;      // the street clock (HubLife.sim_t)
const float SIZE = 1.5;
const float GREEN = 13.0;
const float YELLOW = 3.0;
const float CYCLE = 35.2;

varying vec3 vCol;
varying vec2 vUv;

void vertex() {
	float u = mod(sim_t + INSTANCE_CUSTOM.x, CYCLE);
	float mine = INSTANCE_CUSTOM.y < 0.5 ? u : mod(u + CYCLE * 0.5, CYCLE);
	int sgl = mine < GREEN ? 0 : (mine < GREEN + YELLOW ? 1 : 2);      // G Y R
	int kind = int(INSTANCE_CUSTOM.z + 0.5);
	vec3 c = vec3(0.0);
	bool lit = false;
	if (kind == 3) {       // walk white on green, a flashing amber on yellow, don't-walk amber on red
		if (sgl == 0) { c = vec3(0.85, 0.95, 1.0); lit = true; }
		else if (sgl == 1 && fract(sim_t * 2.0) < 0.5) { c = vec3(1.0, 0.45, 0.1); lit = true; }
		else if (sgl == 2) { c = vec3(1.0, 0.36, 0.08); lit = true; }
		else { c = vec3(1.0, 0.12, 0.08); }
	} else {
		c = kind == 0 ? vec3(1.0, 0.12, 0.08) : (kind == 1 ? vec3(1.0, 0.62, 0.08) : vec3(0.2, 1.0, 0.55));
		lit = (kind == 0 && sgl == 2) || (kind == 1 && sgl == 1) || (kind == 2 && sgl == 0);
	}
	vCol = c * (lit ? 1.0 : 0.06);
	vUv = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	vec3 v = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = v + vec3(VERTEX.xy * SIZE * 0.5 / PROJECTION_MATRIX[1][1], 0.0);
}

void fragment() {
	vec4 t = texture(map, vUv);
	ALBEDO = add_display(vCol * t.rgb, t.a);
}
