// Space round the Pervert Palace finale's Earth shot (levels/palace/palace_space.gd): black, a dense field of stars of a few sizes and tints, the faint band of the galaxy. Drawn on the inside
// of a big sphere round the shot. `mode` 1 is the atmosphere's halo instead: an additive blue shell just outside the Earth, brightest at its limb on the sunlit side.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled, blend_add, depth_draw_never;

uniform vec3 centre;
uniform int mode = 0;
uniform vec3 sun_dir = vec3(-0.6, 0.35, 0.7);

varying vec3 wpos;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(wpos - centre);
	if (mode == 1) {
		vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
		float edge = 1.0 - abs(dot(d, V));
		float lit = smoothstep(-0.3, 0.5, dot(d, normalize(sun_dir)));
		ALBEDO = vec3(0.25, 0.55, 1.0) * pow(edge, 6.0) * (0.2 + 1.6 * lit);
	} else {
		vec3 col = vec3(0.0);
		for (int s = 0; s < 3; s++) {
			float sc = 140.0 + float(s) * 170.0;
			vec3 cell = floor(d * sc);
			float h = h3(cell + float(s) * 17.0);
			if (h > 0.985 - float(s) * 0.004) {
				vec3 c0 = (cell + 0.5 + (vec3(h3(cell + 1.0), h3(cell + 2.0), h3(cell + 3.0)) - 0.5) * 0.6) / sc;
				float dd = length(d - normalize(c0)) * sc;
				float b = smoothstep(0.5, 0.0, dd) * (0.4 + 1.6 * h3(cell + 9.0));
				vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.88, 0.7), h3(cell + 5.0));
				col += tint * b * (1.2 - float(s) * 0.3);
			}
		}
		float band = exp(-pow(dot(d, normalize(vec3(0.2, 0.9, -0.4))) * 3.2, 2.0));
		col += vec3(0.05, 0.04, 0.08) * band * (0.6 + 0.4 * h3(floor(d * 40.0)));
		ALBEDO = col;
	}
}
