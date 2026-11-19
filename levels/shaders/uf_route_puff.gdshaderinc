// UNDERFOINT's last line (levels/underfoint/uf_route.gd): puffs of smoke, fire and dust that ride with the moving route, so what burns beside the line is left behind at the train's speed.
// OMNISPHERE's puff (levels/omnisphere/om_puff.gdshaderinc) with one change: the pool is a child of the moving route node, so MODEL_MATRIX is (that node * the instance). Column 3, the birth point,
// and column 0, the velocity, are carried round with the route; drag, fade and rise are the pool's own uniforms (they cannot ride in a column that the route's turn would mix up).
// INSTANCE_CUSTOM: size, grow, life, birth. COLOR: colour and alpha.
#include "res://levels/shaders/common.gdshaderinc"

uniform float now = 0.0;
uniform float drag = 1.2;
uniform float fade = 0.1;
uniform float rise = 0.0;      // m/s/s upward: hot smoke climbs
varying float vA;
varying vec3 vC;
varying float vSeed;
varying float vAge;      // seconds since it was made (the smoke's texture rolls with it)
varying float vSize;     // its size now, m (how far its soft edge reaches into what it meets)

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1., 0.)), f.x), mix(h(i + vec2(0., 1.)), h(i + vec2(1., 1.)), f.x), f.y); }

// the scene behind a puff (Godot 4.3+: reversed z, depth 0..1), so a puff fades out where it meets a wall or the floor instead of cutting into it with a hard straight line
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

float soft_edge(vec2 suv, vec3 vpos, mat4 inv_proj, float reach) {
	float depth = texture(depth_tex, suv).r;
	vec4 v = inv_proj * vec4(suv * 2.0 - 1.0, depth, 1.0);
	float scene = -v.z / v.w;
	return clamp((scene + vpos.z) / reach, 0.0, 1.0);
}

float fbm(vec2 p) { return .5 * n(p) + .25 * n(p * 2.03 + 7.1) + .125 * n(p * 4.01 - 3.3) + .0625 * n(p * 8.05 + 1.7); }

void vertex() {
	float life = INSTANCE_CUSTOM.z;
	float age = now - INSTANCE_CUSTOM.w;
	float u = age / life;
	if (u < 0.0 || u >= 1.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
		vA = 0.0;
	} else {
		vec3 p = MODEL_MATRIX[3].xyz + MODEL_MATRIX[0].xyz * (drag > 0.001 ? (1.0 - exp(-drag * age)) / drag : age);
		p.y += 0.5 * rise * age * age;
		float size = INSTANCE_CUSTOM.x * (1.0 + INSTANCE_CUSTOM.y * u);
		vec4 view = VIEW_MATRIX * vec4(p, 1.0);
		float d = -view.z;
		float spin = (fract(INSTANCE_CUSTOM.w * 7.31) - 0.5) * 6.0 + age * (fract(INSTANCE_CUSTOM.w * 3.7) - 0.5) * 1.6;
		vec2 q = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * VERTEX.xy;
		view.xy += q * size;
		POSITION = PROJECTION_MATRIX * view;
		vA = COLOR.a * min(1.0, u / max(0.01, fade)) * (1.0 - u * u) * smoothstep(0.6, 3.0, d);
		vC = COLOR.rgb;
		vSeed = fract(INSTANCE_CUSTOM.w * 13.37);
		vAge = age;
		vSize = size;
	}
}
