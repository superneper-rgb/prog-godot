// A barrel fire (levels/underfoint/underfoint_level.gd `_fire`): one upright card that turns to face you, a flame drawn on it from scrolling noise. Added to what is behind it, so it only ever lightens.
// `seed` keeps two fires from licking in step. The level scales the card's height with the fire's flicker.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float seed = 0.0;

void vertex() {
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	to_cam.y = 0.0;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(to_cam)));
	vec3 wp = MODEL_MATRIX[3].xyz + right * VERTEX.x * length(MODEL_MATRIX[0].xyz) + vec3(0.0, 1.0, 0.0) * VERTEX.y * length(MODEL_MATRIX[1].xyz);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float h = 1.0 - UV.y;      // 0 at the barrel's rim, 1 at the tip
	float n = texture(noise_tex, vec2(UV.x * 0.35 + seed, UV.y * 0.45 + TIME * 0.6)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 0.8 - seed, UV.y * 0.9 + TIME * 1.05)).r;
	float x = (UV.x - 0.5) * 2.0 + (n - 0.5) * 0.8 * h;
	float width = mix(0.7, 0.0, pow(h, 0.8)) * (0.7 + n2 * 0.7);
	float body = smoothstep(width, width * 0.3, abs(x)) * smoothstep(0.0, 0.07, h);
	body *= smoothstep(1.0, 0.55, h + (1.0 - n2) * 0.4);
	vec3 col = mix(vec3(1.0, 0.22, 0.03), vec3(1.0, 0.7, 0.2), body * (1.0 - h * 0.7));
	col = mix(col, vec3(1.0, 0.95, 0.7), smoothstep(0.6, 1.0, body) * (1.0 - h));
	ALBEDO = col * body * 2.4;
}
