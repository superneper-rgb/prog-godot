// The eyes (JS EYE_FX): lids close over the eyeballs when u_blink rises. Works from the bind-pose position, so it holds whatever the head does.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform bool has_map = false;
uniform bool use_vcol = false;
uniform float u_blink = 0.0;
uniform vec3 u_eye[2];
uniform float u_eye_ry = 0.02;
uniform vec3 u_lid = vec3(0.49944, 0.30936, 0.18102);     // the lid tone: from the build on the textured model, else the face (vertex colours average ~0.6)
uniform float sclera = 1.0;                               // untextured eye white: brighter
uniform bool hide_lid = false;                            // untextured iris / pupil: gone under a closed lid
uniform vec3 emissive = vec3(0.0);                        // untextured eye white: self-lit so the open eye reads white at night

varying vec3 v_bp;

void vertex() {
	v_bp = CUSTOM0.xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (has_map) {
		col *= texture(map, UV).rgb;
	}
	if (use_vcol) {
		col *= COLOR.rgb;
	}
	col *= sclera;
	if (u_blink > 0.002) {
		vec3 c = v_bp.x < 0.0 ? u_eye[0] : u_eye[1];
		float yn = (v_bp.y - c.y) / u_eye_ry;
		float eTop = 1.0 - 1.18 * u_blink;                 // upper lid comes down, lower lid comes up a little
		float eBot = -1.0 + 0.88 * u_blink;
		float lid = max(smoothstep(eTop - 0.1, eTop + 0.1, yn), 1.0 - smoothstep(eBot - 0.1, eBot + 0.1, yn)) * step(0.001, u_blink);
		lid = mix(lid, 1.0, smoothstep(0.93, 1.0, u_blink));
		lid *= 1.0 - smoothstep(2.0, 2.8, length(v_bp.xy - c.xy) / u_eye_ry);     // only ever act on the eye itself (not the mouth / other dark parts)
		float lash = (1.0 - smoothstep(0.0, 0.2, abs(yn - eTop))) * smoothstep(0.1, 0.6, u_blink);
		vec3 lid_col = u_lid;
		lid_col *= 1.0 - 0.35 * lash - 0.18 * smoothstep(0.9, 1.0, u_blink);      // lash line / crease when shut
		col = mix(col, lid_col, lid);
		if (hide_lid && lid > 0.3) {
			discard;
		}
	}
	ALBEDO = col;
	EMISSION = emissive;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
