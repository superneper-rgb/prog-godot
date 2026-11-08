// RigidBatch, the solid parts: every copy of a jointed hard-surface model in one instanced draw. Each vertex is rigidly attached to one joint (UV2.x); the joints' world matrices are read
// from the batch's data texture, one row per copy. UV2.y picks the material row, so a model with several JS materials is still one draw (and one shadow draw per cascade).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back, depth_draw_opaque, shadows_disabled;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2DArray maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 mat_albedo[24];    // rgb: linear colour; a: map layer, < 0 for none
uniform vec4 mat_pbr[24];       // x: roughness; y: metalness; z: kind (0 lit, 1 unlit in the copy's colour A, 2 unlit in its colour B, 3 unlit, the map itself, 4 unlit, the row's colour x vertex colour x map); w: 1 takes the copy's paint tint (a lit row)
uniform vec4 mat_emit[24];      // rgb: emissive colour; a: emissive map layer, < 0 for none. All zero on models that have none
uniform vec4 mat_rim[24];       // rgb: JS wetSkin's rim colour x strength; a: what scales the emissive: 0 nothing, 1 the copy's glow A, 2 its glow B (texel 2 r, g)
uniform vec3 flash_tint = vec3(0.85, 0.85, 0.9);
uniform float digit_adv = 0.0;  // the unit number plate: one character's width in metres

const int PARAMS = 11;

varying vec3 v_albedo;
varying vec3 v_emit;
varying vec2 v_rm;
varying float v_layer;
varying vec3 v_map_emit;
varying float v_spec;
varying vec3 v_glow;
varying float v_glow_layer;
varying vec3 v_rim;

void vertex() {
	int row = INSTANCE_ID;
	int slot = int(UV2.x + 0.5);
	int m = int(UV2.y + 0.5);
	vec4 p0 = texelFetch(data, ivec2(0, row), 0);    // flash, tint, unit number, bar scale
	vec4 alb = mat_albedo[m];
	vec4 pbr = mat_pbr[m];
	int kind = int(pbr.z + 0.5);
	vec3 local = VERTEX;
	vec2 uv = UV;
	if (kind == 3 && COLOR.a < 0.95) {               // one digit of the plate: its quad picks the glyph, the text stays centred
		int pos = int(COLOR.a * 10.0 + 0.5) - 1;
		int num = int(p0.z + 0.5);
		int n = 1;
		for (int i = num; i >= 10; i /= 10) {
			n++;
		}
		n = max(2, n);
		int d = num;
		for (int i = 0; i < pos; i++) {
			d /= 10;
		}
		uv.x += float(d % 10) * (12.1 / 256.0);
		local.x -= float(4 - min(n, 4)) * digit_adv * 0.5;
		if (pos >= n) {
			local = vec3(0.0);
		}
	}
	UV = uv;
	int base = PARAMS + slot * 3;
	vec4 r0 = texelFetch(data, ivec2(base, row), 0);
	vec4 r1 = texelFetch(data, ivec2(base + 1, row), 0);
	vec4 r2 = texelFetch(data, ivec2(base + 2, row), 0);
	vec4 h = vec4(local, 1.0);
	VERTEX = vec3(dot(r0, h), dot(r1, h), dot(r2, h));
	vec3 n = NORMAL;
	NORMAL = vec3(dot(r0.xyz, n), dot(r1.xyz, n), dot(r2.xyz, n));

	v_layer = alb.a;
	v_rm = pbr.xy;
	v_map_emit = vec3(0.0);
	v_spec = kind == 0 ? 0.5 : 0.0;
	vec4 em = mat_emit[m];
	vec4 rm = mat_rim[m];
	int src = int(rm.a + 0.5);
	v_glow = em.rgb * (src == 0 ? 1.0 : texelFetch(data, ivec2(2, row), 0)[src - 1]);
	v_glow_layer = em.a;
	v_rim = rm.rgb;
	if (kind == 0) {
		float tint = pbr.w > 0.5 ? p0.y : 1.0;
		v_albedo = alb.rgb * COLOR.rgb * (pbr.w > 0.5 ? vec3(tint, tint * 0.97, tint * 0.9) : vec3(1.0));
		v_emit = flash_tint * p0.x;        // hit flash
	} else if (kind == 1) {
		vec4 a = texelFetch(data, ivec2(1, row), 0);
		v_albedo = vec3(0.0);
		v_emit = a.rgb * min(1.4, a.a);
	} else if (kind == 2) {
		v_albedo = vec3(0.0);
		v_emit = texelFetch(data, ivec2(2, row), 0).rgb;
	} else {
		v_albedo = vec3(0.0);
		v_emit = vec3(0.0);
		v_map_emit = kind == 4 ? alb.rgb * COLOR.rgb : vec3(1.0);
	}
}

void fragment() {
	vec3 tex = v_layer < -0.5 ? vec3(1.0) : texture(maps, vec3(UV, v_layer)).rgb;
	ALBEDO = v_albedo * tex;
	ROUGHNESS = v_rm.x;
	METALLIC = v_rm.y;
	SPECULAR = v_spec;
	vec3 e = v_emit + tex * v_map_emit;
	if (dot(v_glow, v_glow) > 0.0) {
		e += v_glow * (v_glow_layer < -0.5 ? vec3(1.0) : texture(maps, vec3(UV, v_glow_layer)).rgb);
	}
	if (dot(v_rim, v_rim) > 0.0) {      // JS wetSkin: light bleeding through thin flesh at the silhouette
		e += v_rim * pow(1.0 - abs(dot(VIEW, NORMAL)), 2.6) * (0.6 + 0.6 * ALBEDO.r);
	}
	EMISSION = e;
}
