// RigidBatch, the see-through parts of a jointed model (a brain jar, a cockpit dome): the same joints and material table as rigid_batch.gdshader, blended. mat_pbr.w is the JS material's opacity.
shader_type spatial;
render_mode blend_mix, diffuse_lambert, specular_schlick_ggx, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2DArray maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 mat_albedo[24];
uniform vec4 mat_pbr[24];
uniform vec3 flash_tint = vec3(0.85, 0.85, 0.9);
uniform vec3 base_emit = vec3(0.0);
uniform vec4 mat_emit[24];
uniform vec4 mat_rim[24];       // a: what scales the emissive, as in rigid_batch.gdshader

const int PARAMS = 11;

varying vec3 v_albedo;
varying vec2 v_rm;
varying float v_layer;
varying float v_alpha;
varying float v_flash;
varying vec3 v_glow;
varying float v_glow_layer;

void vertex() {
	int row = INSTANCE_ID;
	int slot = int(UV2.x + 0.5);
	int m = int(UV2.y + 0.5);
	vec4 alb = mat_albedo[m];
	vec4 pbr = mat_pbr[m];
	int base = PARAMS + slot * 3;
	vec4 r0 = texelFetch(data, ivec2(base, row), 0);
	vec4 r1 = texelFetch(data, ivec2(base + 1, row), 0);
	vec4 r2 = texelFetch(data, ivec2(base + 2, row), 0);
	vec4 h = vec4(VERTEX, 1.0);
	VERTEX = vec3(dot(r0, h), dot(r1, h), dot(r2, h));
	vec3 n = NORMAL;
	NORMAL = vec3(dot(r0.xyz, n), dot(r1.xyz, n), dot(r2.xyz, n));
	v_albedo = alb.rgb * COLOR.rgb;
	v_rm = pbr.xy;
	v_layer = alb.a;
	v_alpha = pbr.w * COLOR.a;
	v_flash = texelFetch(data, ivec2(0, row), 0).x;
	vec4 em = mat_emit[m];
	int src = int(mat_rim[m].a + 0.5);
	v_glow = em.rgb * (src == 0 ? 1.0 : texelFetch(data, ivec2(2, row), 0)[src - 1]);
	v_glow_layer = em.a;
}

void fragment() {
	vec3 tex = v_layer < -0.5 ? vec3(1.0) : texture(maps, vec3(UV, v_layer)).rgb;
	ALBEDO = v_albedo * tex;
	ROUGHNESS = v_rm.x;
	METALLIC = v_rm.y;
	EMISSION = base_emit + flash_tint * v_flash;
	if (dot(v_glow, v_glow) > 0.0) {
		EMISSION += v_glow * (v_glow_layer < -0.5 ? vec3(1.0) : texture(maps, vec3(UV, v_glow_layer)).rgb);
	}
	ALPHA = v_alpha;
}
