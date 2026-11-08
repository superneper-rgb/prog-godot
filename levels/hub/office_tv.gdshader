// One of the B-9 office's vintage television tubes (JS office-tv-wall.js): a grainy tinted CCTV feed in a rounded tube, or colour bars, snow, or a dead set.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform float time = 0.0;
uniform int mode = 0;
uniform vec3 tint = vec3(0.7);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 vuv = vec2(UV.x, 1.0 - UV.y);
	vec2 edge = abs(vuv - 0.5) * 2.0;
	if (pow(edge.x, 7.0) + pow(edge.y, 7.0) > 1.0) {
		discard;
	}
	vec2 uv = 0.5 + (vuv - 0.5) * (1.0 + 0.085 * dot(vuv - 0.5, vuv - 0.5));
	float grain = hash(floor(uv * vec2(320.0, 240.0)) + floor(time * 13.0));
	float tear = step(0.982, sin(uv.y * 7.0 + time * 0.8));
	uv.x += tear * 0.012 * sin(time * 31.0);
	float luma = dot(texture(feed, vec2(uv.x, 1.0 - uv.y)).rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = tint * (luma * 0.78 + 0.012) + (grain - 0.5) * 0.055;
	if (mode == 3) {
		float bar = floor(uv.x * 7.0);
		col = vec3(0.33);
		if (bar < 1.0) {
			col = vec3(0.65);
		} else if (bar < 2.0) {
			col = vec3(0.55, 0.47, 0.12);
		} else if (bar < 3.0) {
			col = vec3(0.08, 0.42, 0.42);
		} else if (bar < 4.0) {
			col = vec3(0.1, 0.39, 0.14);
		} else if (bar < 5.0) {
			col = vec3(0.40, 0.12, 0.40);
		} else if (bar < 6.0) {
			col = vec3(0.47, 0.10, 0.08);
		} else {
			col = vec3(0.08, 0.12, 0.42);
		}
		if (uv.y < 0.24) {
			col = vec3(floor(uv.x * 7.0) / 9.0);
		}
		col += (grain - 0.5) * 0.06;
	}
	if (mode == 4) {
		col = tint * (grain * 0.37 + step(0.67, grain) * 0.1);
	}
	if (mode == 5) {
		col = vec3(0.008, 0.012, 0.012) + tint * 0.01 * pow(1.0 - uv.y, 4.0);
	}
	col *= 0.83 + 0.17 * sin(vuv.y * 820.0);
	col *= 1.0 - 0.55 * pow(length(edge) * 0.707, 2.0);
	col += tint * 0.018 * exp(-pow((fract(uv.y + time * 0.07) - 0.5) * 40.0, 2.0));
	// Broad soft reflection on the curved face, never an opaque white rectangle.
	col += vec3(0.018, 0.022, 0.024) * exp(-pow((uv.x + uv.y * 0.4 - 0.45) * 8.0, 2.0));
	ALBEDO = max(col, vec3(0.0));
}
