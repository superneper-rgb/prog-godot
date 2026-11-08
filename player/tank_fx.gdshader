// Prog's tank top (JS TANK_FX): lambert plus blotchy stains, drips, sweat under the arms, dirt at the hem, a sweat line at the neck. All from the bind-pose position.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

#include "res://player/prog_fx.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform bool has_map = false;
uniform bool use_vcol = false;
uniform vec3 u_arm[6];
uniform float u_hem = 0.8;

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
	vec3 p = v_bp;
	float f = fbm(p * vec3(6.0, 5.0, 6.0));
	float g = fbm(p * 14.0 + 3.3);
	vec3 c = vec3(1.0);
	float blot = smoothstep(0.52, 0.62, f) * (0.6 + 0.4 * g);                       // blotchy tea / grease stains
	c *= mix(vec3(1.0), vec3(0.74, 0.60, 0.40), blot * 0.85);
	float dr = smoothstep(0.62, 0.85, vn(vec3(p.x * 34.0, p.y * 1.7, p.z * 34.0))) * smoothstep(0.0, 0.5, f);   // vertical drip streaks
	c *= 1.0 - 0.2 * dr;
	for (int i = 0; i < 2; i++) {                                                   // sweat under the arms
		vec3 a = u_arm[i * 3] - vec3(0.0, 0.09, 0.0);
		float m = 1.0 - smoothstep(0.05, 0.17, distance(p, a) + (f - 0.5) * 0.09);
		c *= mix(vec3(1.0), vec3(0.78, 0.70, 0.52), m * 0.95);
	}
	float hem = (1.0 - smoothstep(u_hem, u_hem + 0.14, p.y)) * (0.5 + 0.5 * g);     // dirt gathering at the hem
	c *= 1.0 - 0.24 * hem;
	float neck = smoothstep(1.52, 1.62, p.y) * (0.4 + 0.6 * g);                     // faint sweat line around the neckline
	c *= 1.0 - 0.14 * neck;
	ALBEDO = col * c;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
