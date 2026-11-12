// JUNGLE TEST canopy: a ceiling of leaves far overhead, cut from noise (clumps of rounded leaves, holes between them) with a gap where the sun comes through.
// Lit through from above, so from below the leaves the sun reaches glow green and the rest stay dark. Its holes cast the dappled light; its gap casts the shaft.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D clump_tex : filter_linear_mipmap, repeat_enable;     // soft noise: where the leaves bunch
uniform sampler2D leaf_tex : filter_linear_mipmap, repeat_enable;      // cellular distance: single leaves (0 at a leaf's middle)
uniform float clump_scale = 0.025;
uniform float leaf_scale = 0.35;
uniform float cover = 0.62;
uniform vec2 gap = vec2(0.0);
uniform float gap_r = 8.0;
uniform vec3 leaf_dark : source_color = vec3(0.03, 0.1, 0.07);
uniform vec3 leaf_lit : source_color = vec3(0.16, 0.36, 0.16);
uniform float backlight = 0.9;
uniform float droop = 0.35;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.35 + wp.x * 0.05 + wp.z * 0.04) * droop;
}

void fragment() {
	float c = texture(clump_tex, wp.xz * clump_scale).r;
	float l = texture(leaf_tex, wp.xz * leaf_scale).r;
	float d = length(wp.xz - gap);
	float open = 1.0 - smoothstep(gap_r * 0.75, gap_r * 1.35, d + (c - 0.5) * gap_r * 0.6);
	float dens = c + cover - 0.5 - open * 1.5;
	float a = dens * 2.2 + 0.5 - l * 1.1;
	ALPHA = clamp(a * 3.0, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 col = mix(leaf_dark, leaf_lit, clamp(0.9 - l * 1.3 + (c - 0.5) * 0.6, 0.0, 1.0));
	ALBEDO = col;
	BACKLIGHT = col * backlight;
	ROUGHNESS = 0.5;
	SPECULAR = 0.4;
}
