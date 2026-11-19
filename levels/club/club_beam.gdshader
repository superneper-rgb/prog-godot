// CLUB 9's moving-head beams and lasers: light seen in haze. Bright at the lens and down the core, soft at the edges, thinning with distance, broken up by slow
// drifting smoke, fading where the beam meets the floor or a body (depth), and gone when the camera is right in it (a flat-alpha cone filled the screen
// with a purple slab). Additive and unlit; colour is radiance (ClubLevel passes View.display_to_radiance).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 col : source_color = vec3(1.0);
uniform float power = 1.0;
uniform float len = 6.4;          // the mesh's length along local +z
uniform float core = 3.0;         // how hard the edge falls off (higher: thinner core)
uniform float smoke = 0.55;       // how much the haze breaks the beam up
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying float vz;
varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vz = clamp(VERTEX.z / len, 0.0, 1.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, core);
	float along = pow(1.0 - vz, 1.2) * 0.55 + exp(-vz * 18.0) * 1.4;      // falls away down the throw, a hot spot at the lens
	float view_d = -VERTEX.z;
	float near = smoothstep(0.4, 2.8, view_d);
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_d = -sv.z / sv.w;
	float soft = clamp((scene_d - view_d) / 0.5, 0.0, 1.0);
	vec3 drift = vec3(TIME * 0.11, TIME * 0.05, -TIME * 0.08);
	float haze = vnoise(wpos * 1.6 + drift) * 0.65 + vnoise(wpos * 4.3 - drift * 2.0) * 0.35;
	haze = mix(1.0, smoothstep(0.15, 0.85, haze) * 1.5, smoke);
	ALBEDO = col * power;
	ALPHA = clamp(edge * along * near * soft * haze, 0.0, 1.0);
}
