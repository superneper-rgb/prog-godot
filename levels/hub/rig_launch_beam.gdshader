// Pauly's rig taking off (levels/hub/rig_launch.gd): the streak of light it leaves from the street to the sky, on a tube along +Z (UV.y 0 at the street, 1 at the far end).
// The head runs up it in a few frames; the line it leaves hangs, spreads, breaks up and goes out from the street end first. Added to the frame, never fogged.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.5, 0.86, 1.0);
uniform float power = 0.0;       // 0: not drawn
uniform float head = 0.0;        // how far along the head has got, 0..1
uniform float tail = 0.0;        // the line is gone up to here, 0..1
uniform float fray = 0.0;        // 0 a clean line .. 1 broken into shreds
uniform float age = 0.0;         // seconds since it left

varying vec3 axis_v;      // the tube's own axis, view space

void vertex() {
	axis_v = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
}

void fragment() {
	float z = UV.y;
	float a = smoothstep(tail - 0.02, tail + 0.1, z) * (1.0 - smoothstep(head - 0.004, head, z));
	a *= mix(0.45, 1.0, smoothstep(head - 0.3, head, z));      // brighter behind the head
	// a soft-edged tube: full along its middle, nothing at its edge. Judged across the tube only (the view with its part along the axis taken out): the camera stands at
	// its foot and looks almost straight up it, where a plain facing term would call the whole of it an edge.
	vec3 v = normalize(VIEW);
	vec3 across = v - axis_v * dot(v, axis_v);
	float side = abs(dot(normalize(NORMAL), across / max(length(across), 0.0001)));
	float n = sin(z * 260.0 + age * 5.0) * sin(UV.x * 18.85 + z * 70.0 - age * 3.0) + 0.6 * sin(z * 71.0 - age * 2.0);
	a *= mix(1.0, smoothstep(-0.2, 0.9, n), fray);
	float core = pow(side, 7.0) * (1.0 - 0.8 * fray);          // a white-hot thread down its middle, which goes first
	vec3 c = tint * side * side * 0.7 + vec3(1.0) * core * 1.3;
	ALBEDO = c * power * a;
	ALPHA = 1.0;
	if (power * a < 0.0005) {
		discard;
	}
}
