// UNDERFOINT's built surfaces (levels/underfoint/uf_build.gd `tex`): a tiling photographed material laid flat on each face (the builder writes UVs in metres), with what fifty years under a slab does to it on top:
// big damp stains, moss and slime creeping up from the ground and along every ledge (the builder's vertex alpha says where it can take hold), and standing water on level ground.
// Vertex colour rgb is the builder's painted shade: darker at a wall's foot and under what overhangs.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile = 2.0;            // metres one repeat of the maps covers
uniform float arm_packed = 1.0;      // 1: the map is occlusion / roughness / metal in r / g / b; 0: roughness alone
uniform float rough_mul = 1.0;
uniform float metal_mul = 1.0;
uniform float normal_depth = 1.0;
uniform vec3 moss : source_color = vec3(0.07, 0.11, 0.04);
uniform float growth = 1.0;          // how readily moss takes on this material
uniform float puddles = 0.0;         // 1: water stands on it where it lies level
uniform float stick = 0.0;           // 1: the stains, moss and puddles are laid in the mesh's own space, so they ride with it (the last line's route moves past the train: levels/underfoint/uf_route.gd)

varying vec3 w_pos;
varying vec3 w_nor;

void vertex() {
	w_pos = mix((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, VERTEX, stick);
	w_nor = normalize(mix((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, NORMAL, stick));
}

void fragment() {
	vec2 uv = UV / tile;
	vec3 a = texture(albedo_tex, uv).rgb * tint * COLOR.rgb;
	vec3 arm = texture(arm_tex, uv).rgb;
	float ao = mix(1.0, arm.r, arm_packed);
	float rough = mix(arm.r, arm.g, arm_packed) * rough_mul;
	float metal = arm.b * arm_packed * metal_mul;
	// stains: one noise read at two sizes, slid by height so a wall's stain does not line up with the ground's
	float n1 = texture(noise_tex, w_pos.xz * 0.031 + w_pos.y * 0.043).r;
	float n2 = texture(noise_tex, w_pos.xz * 0.23 + w_pos.yy * vec2(0.17, 0.21)).r;
	a *= mix(0.6, 1.1, n1);
	rough *= mix(0.75, 1.05, n1);
	float g = smoothstep(0.62, 0.84, n2 * 0.55 + n1 * 0.25 + COLOR.a * 0.75 * growth);
	a = mix(a, moss * (0.5 + 1.0 * n2), g * 0.88);
	rough = mix(rough, 0.92, g);
	float nd = normal_depth * (1.0 - 0.6 * g);
	float p = puddles * smoothstep(0.56, 0.62, texture(noise_tex, w_pos.xz * 0.075 + 0.37).r * 0.65 + n2 * 0.35) * step(0.9, w_nor.y);
	a = mix(a, a * 0.5, p);
	rough = mix(rough, 0.03, p);
	metal *= 1.0 - p;
	nd *= 1.0 - p * 0.96;
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	METALLIC = metal;
	AO = ao;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = nd;
}
