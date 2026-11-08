// OMNISPHERE puffs (JS skyfoes.js P_VERT / P_FRAG, a Points cloud): no CPU per frame. MODEL_MATRIX columns: 0 velocity, 1 (drag, fade), 3 birth point; INSTANCE_CUSTOM: size, grow, life, birth. A puff's life is worked out from the clock.
#include "res://levels/shaders/common.gdshaderinc"

uniform float now = 0.0;
varying float vA;
varying vec3 vC;
varying float vSeed;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1., 0.)), f.x), mix(h(i + vec2(0., 1.)), h(i + vec2(1., 1.)), f.x), f.y); }

void vertex() {
	float life = INSTANCE_CUSTOM.z;
	float age = now - INSTANCE_CUSTOM.w;
	float u = age / life;
	if (u < 0.0 || u >= 1.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
		vA = 0.0;
	} else {
		float drag = MODEL_MATRIX[1].x;
		float fade = MODEL_MATRIX[1].y;
		vec3 p = MODEL_MATRIX[3].xyz + MODEL_MATRIX[0].xyz * (drag > 0.001 ? (1.0 - exp(-drag * age)) / drag : age);
		float size = INSTANCE_CUSTOM.x * (1.0 + INSTANCE_CUSTOM.y * u);
		vec4 view = VIEW_MATRIX * vec4(p, 1.0);
		float d = -view.z;
		view.xy += VERTEX.xy * size;
		POSITION = PROJECTION_MATRIX * view;
		vA = COLOR.a * min(1.0, u / max(0.01, fade)) * (1.0 - u * u) * smoothstep(0.8, 5.0, d);
		vC = COLOR.rgb;
		vSeed = fract(INSTANCE_CUSTOM.w * 13.37);
	}
}
