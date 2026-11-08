// Main menu backdrop: one layer of rain streaks (JS rainLayer, rainStep). ENGINE DIFFERENCE: the JS moves every streak in a script loop; here the fall, the wind and the respawn at a fresh spot are worked out in the vertex shader from the clock. UV: x = speed seed, y = 1 on the streak's top end. UV2: x = its identity.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 color = vec3(1.0);
uniform float opacity = 0.3;
uniform float u_time = 0.0;
uniform float seg_len = 0.5;
uniform vec3 box_min = vec3(0.0);
uniform vec3 box_max = vec3(1.0);
uniform float wind = -3.5;
uniform float fall = 24.0;
uniform float fog_k = 0.03;
uniform vec3 fog_col = vec3(0.0);
varying float v_depth;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	float seed = UV.x;
	float v = fall * seed;
	vec3 size = box_max - box_min;
	float raw = (VERTEX.y - box_min.y) - u_time * v;
	float cycle = floor(raw / size.y);
	float y = raw - cycle * size.y;
	float elapsed = (size.y - y) / v;
	float x = hash(vec2(UV2.x, cycle)) * size.x + wind * seed * elapsed;
	x = mod(x, size.x);
	float z = hash(vec2(UV2.x + 3.7, cycle)) * size.z;
	vec3 p = box_min + vec3(x, y, z);
	float k = seg_len * seed / fall;
	p += UV.y * vec3(-wind * k, v * k, 0.0);
	vec4 mv = VIEW_MATRIX * vec4(p, 1.0);
	v_depth = -mv.z;
	POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	float d = v_depth * fog_k;
	ALBEDO = mix(color, fog_col, 1.0 - exp(-d * d));
	ALPHA = opacity;
}
