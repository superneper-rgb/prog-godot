// shader_ea8496 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying vec3 vW;
uniform vec3 uCol;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + 1.), f.x), f.y); }

void vertex() {
	vUv = UV; vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vW = w.xyz; POSITION = PROJECTION_MATRIX * VIEW_MATRIX * w;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 p = vW.xz * .035 + vec2(TIME * .012, TIME * .004); float m = n(p) * .6 + n(p * 2.3 + 5.) * .4;
	float edge = smoothstep(.5, .15, length(vUv - .5)); float d = distance(vW, CAMERA_POSITION_WORLD), near = smoothstep(4., 22., d) * smoothstep(520., 180., d);
	float a = smoothstep(.35, .85, m) * edge * near * .3; fc_ = vec4(uCol, a);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
