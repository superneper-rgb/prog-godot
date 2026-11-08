// A suit painted onto a skinned mesh from a per-vertex flag (JS phantom-suit.js paintShader): Prog's skin under the suit and his gloves, Tommy's whole white body. CUSTOM1.x = body cloth, .y = boot / glove.
// His face lives in the body texture: wherever that texture is dark (eyes, brows, mouth) the original colour wins over the paint, so the face is never covered.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform bool has_map = false;
uniform bool use_vcol = false;
uniform vec3 u_suit_navy : source_color = vec3(0.1);
uniform vec3 u_suit_boot : source_color = vec3(0.1);
uniform bool ink = false;

varying vec3 v_bp;
varying vec2 v_suit;

void vertex() {
	v_bp = CUSTOM0.xyz;
	v_suit = CUSTOM1.xy;
}

void fragment() {
	vec3 orig_col = albedo.rgb;
	if (has_map) {
		orig_col *= texture(map, UV).rgb;
	}
	if (use_vcol) {
		orig_col *= COLOR.rgb;
	}
	// shadeGLSL(9.0, true): the facet tone and the quilted bands of the suit's cloth
	vec3 face_n = abs(normalize(cross(dFdx(v_bp), dFdy(v_bp)) + vec3(1e-9)));
	float fh = fract(sin(dot(floor(face_n * 9.0 + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float shade_k = 0.9 + 0.2 * fh;
	shade_k *= 1.0 - 0.11 * step(fract(v_bp.y * 5.5), 0.07);
	shade_k *= 0.96 + 0.08 * smoothstep(0.0, 1.9, v_bp.y);
	float ink_k = ink ? 1.0 - smoothstep(0.3, 0.65, dot(orig_col, vec3(0.299, 0.587, 0.114))) : 0.0;
	float is_navy = step(0.5, v_suit.x);
	float is_boot = step(0.5, v_suit.y);
	vec3 painted = mix(orig_col, u_suit_navy * shade_k, is_navy);
	painted = mix(painted, u_suit_boot * (0.9 + 0.2 * fh), is_boot);
	ALBEDO = mix(painted, orig_col, ink_k * max(is_navy, is_boot));
}
