// Earth for the Pervert Palace finale's space shot (levels/palace/palace_space.gd): NASA's Blue Marble day map (public domain, assets/third-party/nasa) on a sphere, lit by the shot's own sun
// in the shader: a soft terminator, drifting clouds (noise), the sun's glint on the oceans, the night side's city lights on land, and the blue rim of the atmosphere. Unshaded: the shot's
// light is all in here.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform sampler2D day : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(-0.6, 0.35, 0.7);
uniform vec3 centre;
uniform float spin = 0.0;

varying vec3 wpos;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * n3(p);
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wpos - centre);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float lon = atan(n.x, n.z) + spin;
	vec2 uv = vec2(fract(lon / 6.2831853 + 0.5), acos(clamp(n.y, -1.0, 1.0)) / 3.14159265);
	vec3 col = texture(day, uv).rgb;
	float ndl = dot(n, L);
	float lit = smoothstep(-0.12, 0.28, ndl);
	float c = smoothstep(0.5, 0.78, fbm(n * 6.0 + vec3(TIME * 0.004, 0.0, TIME * 0.002)));
	float water = smoothstep(0.04, 0.16, col.b - max(col.r, col.g));
	col = mix(col, vec3(0.94, 0.95, 0.97), c * 0.88);
	vec3 H = normalize(L + V);
	float glint = pow(max(dot(n, H), 0.0), 70.0) * water * (1.0 - c);
	vec3 dayc = col * (0.1 + 1.25 * max(ndl, 0.0)) + vec3(1.0, 0.92, 0.78) * glint * 1.4;
	float land = (1.0 - water) * (1.0 - c);
	float cities = step(0.86, h3(floor(n * 260.0))) * land;
	vec3 night = vec3(1.0, 0.68, 0.32) * cities * 0.85 + col * 0.015;
	float rim = pow(1.0 - clamp(dot(n, V), 0.0, 1.0), 3.0);
	vec3 atmo = vec3(0.28, 0.55, 1.0) * rim * (0.15 + 1.3 * smoothstep(-0.35, 0.45, ndl));
	ALBEDO = mix(night, dayc, lit) + atmo;
}
