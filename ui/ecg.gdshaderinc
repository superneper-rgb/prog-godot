// The patient-monitor trace (JS class Ecg, its draw): one sample per css px across the canvas, in a one-row float texture. A bright head writes left to right over a short blank gap.
// Drawn here rather than as a polyline: one quad, and a real glow around the line.
uniform sampler2D ecg_buf : filter_nearest, repeat_disable;
uniform int ecg_w = 190;
uniform int ecg_head = 0;
uniform int ecg_gap = 17;
uniform vec3 ecg_color = vec3(0.22, 1.0, 0.48);
uniform float ecg_line = 2.0;
uniform float ecg_glow = 7.0;
uniform float ecg_grid = 1.0;
uniform int ecg_reach = 8;

float ecg_sample(int i) { return texelFetch(ecg_buf, ivec2(i, 0), 0).r; }

float ecg_seg(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a, ap = p - a;
	float h = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-5), 0.0, 1.0);
	return length(ap - ab * h);
}

// p: css px in the canvas, cs: the canvas size. Returns a premultiplied layer.
vec4 ecg_trace(vec2 p, vec2 cs) {
	float mid = cs.y * 0.5, amp = cs.y * 0.42;
	int W = ecg_w;
	int len = W - ecg_gap;
	float best = 1e6;
	int k = int(floor(p.x));
	for (int j = -ecg_reach; j <= ecg_reach; j++) {
		int i = k + j;
		if (i < 0 || i >= W - 1) { continue; }
		// the samples, oldest first, start just past the blank gap; the buffer's wrap point is a jump, not a segment
		int rel = (i - ecg_head - ecg_gap + 2 * W) % W;
		if (rel + 1 >= len) { continue; }
		vec2 a = vec2(float(i), mid - ecg_sample(i) * amp);
		vec2 b = vec2(float(i + 1), mid - ecg_sample(i + 1) * amp);
		best = min(best, ecg_seg(p, a, b));
	}
	float line = clamp(ecg_line * 0.5 + 0.5 - best, 0.0, 1.0);
	float sg = ecg_glow * 0.5;
	float glow = exp(-best * best / (2.0 * sg * sg)) * 0.8;
	float a = line + (1.0 - line) * glow;
	vec3 col = ecg_color * a;
	if (ecg_grid > 0.0) {
		float gx = mod(p.x, 16.0) < 1.0 ? 1.0 : 0.0;
		float gy = mod(p.y - mod(mid, 16.0), 16.0) < 1.0 ? 1.0 : 0.0;
		float g = max(gx, gy) * 0.12;
		col = col + ecg_color * g * (1.0 - a);
		a = a + g * (1.0 - a);
	}
	// the bright head
	int hx = (ecg_head + W - 1) % W;
	vec2 h = vec2(float(hx), mid - ecg_sample(hx) * amp);
	float dh = length(p - h);
	float core = clamp(ecg_line * 1.25 + 0.5 - dh, 0.0, 1.0);
	float sh = ecg_glow * 0.9;
	float hg = exp(-dh * dh / (2.0 * sh * sh)) * 0.8;
	col = col + ecg_color * hg * (1.0 - a);
	a = a + hg * (1.0 - a);
	col = vec3(1.0) * core + col * (1.0 - core);
	a = core + a * (1.0 - core);
	return vec4(col, a);
}
