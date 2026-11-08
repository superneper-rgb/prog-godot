// Muscle striations on the arms (JS SKIN_FX), untextured skin only: the original costume. The textured model has its own. Works from the bind-pose position.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

#include "res://player/prog_fx.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform bool has_map = false;
uniform bool use_vcol = false;
uniform vec3 u_arm[6];
uniform vec2 u_arm_r = vec2(0.09, 0.075);

varying vec3 v_bp;

// nearest arm segment: best = distance / radius, bt = position along it, ba/bb = its ends, bu = 1 for an upper arm
void arm_seg(vec3 p, vec3 a, vec3 b, float R, float up, inout float best, inout float bt, inout vec3 ba, inout vec3 bb, inout float bu) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	float d = length(p - a - ab * t) / R;
	if (d < best) {
		best = d;
		bt = t;
		ba = a;
		bb = b;
		bu = up;
	}
}

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
	float best = 1e9;
	float bt = 0.0;
	float bu = 0.0;
	vec3 ba = vec3(0.0);
	vec3 bb = vec3(0.0, 1.0, 0.0);
	arm_seg(p, u_arm[0], u_arm[1], u_arm_r.x, 1.0, best, bt, ba, bb, bu);
	arm_seg(p, u_arm[1], u_arm[2], u_arm_r.y, 0.0, best, bt, ba, bb, bu);
	arm_seg(p, u_arm[3], u_arm[4], u_arm_r.x, 1.0, best, bt, ba, bb, bu);
	arm_seg(p, u_arm[4], u_arm[5], u_arm_r.y, 0.0, best, bt, ba, bb, bu);
	float mask = 1.0 - smoothstep(1.05, 1.3, best);
	mask *= bu > 0.5 ? smoothstep(0.08, 0.3, bt) : 1.0 - smoothstep(0.72, 0.93, bt);
	if (mask > 0.001) {
		vec3 ax = normalize(bb - ba);
		vec3 h = abs(ax.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 u1 = normalize(cross(ax, h));
		vec3 u2 = cross(ax, u1);
		vec3 r = p - ba - ax * dot(p - ba, ax);
		float th = atan(dot(r, u2), dot(r, u1));
		vec3 cs = vec3(cos(th), sin(th), 0.0);
		float wob = vn(cs * 1.6 + vec3(0.0, 0.0, bt * 4.0 + bu * 7.0)) * 2.0 - 1.0;
		float fine = sin(th * 11.0 + wob * 1.8 + bt * 2.5);                            // fibres running along the limb
		float brk = smoothstep(0.12, 0.45, vn(cs * 2.2 + vec3(0.0, 0.0, bt * 11.0)));  // breaks the lines up into short strands
		float line = (1.0 - smoothstep(0.0, 0.36, abs(fine))) * brk;
		float seam = 1.0 - smoothstep(0.0, 0.14, abs(sin(th * 2.0 + bt * 1.4 + 0.7 + wob * 0.4)));   // deeper cuts between muscle groups
		float aa = 1.0 - smoothstep(0.7, 1.6, fwidth(th * 11.0));                      // fade the fine detail out when it gets sub-pixel
		float aa2 = 1.0 - smoothstep(0.9, 2.2, fwidth(th * 2.0) * 3.0);
		col *= 1.0 + mask * 0.13 * aa * fine * (0.6 + 0.4 * brk);
		col *= 1.0 - mask * (0.42 * line * aa + 0.34 * seam * aa2);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
