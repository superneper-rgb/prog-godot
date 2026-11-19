// The bodies the Sigil's throne is made of (levels/underfoint/uf_throne.gd): FOINT CITY's own townsfolk, every species of them, taken and left to rot in a heap. The meshes are the city's (levels/hub/city_folk.gd,
// the same attributes levels/shaders/folk.gdshader reads); here nothing walks. Each body holds one pose, set per copy: INSTANCE_CUSTOM = (left arm raised, right arm raised, how far the head has fallen, seed).
// Heads: outside (track = 0), on the hive's beat a little under half of them come up together. Inside the throne (track = 1) every head turns to `watcher`, as far as a neck goes.
// Colour: the person's own, drained and gone grey-green, wet.
shader_type spatial;

uniform sampler2D atlas : source_color, filter_nearest;
uniform vec3 watcher = vec3(0.0);      // where you are (the level eases it, so they follow a moment late)
uniform float track = 0.0;
uniform float burst = 0.0;             // 0 the heap stands .. 1 it has been thrown apart (the Sigil coming up out of it): each body flung out from burst_mid and dropped on the floor
uniform vec3 burst_mid = vec3(0.0);    // the heap's middle, at floor height

varying vec2 vTile;
varying vec2 vMapUv;
varying vec3 vColor;

mat3 rX(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 rY(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rZ(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	int bn = int(CUSTOM0.x + 0.5);
	vec3 pivot = CUSTOM1.xyz;
	vec4 pose = INSTANCE_CUSTOM;
	mat3 R = mat3(1.0);
	if (bn == 1) {
		if (track > 0.5) {
			vec3 to = (inverse(MODEL_MATRIX) * vec4(watcher, 1.0)).xyz - pivot;
			float yaw = clamp(atan(to.x, to.z), -1.25, 1.25) * (0.8 + 0.2 * pose.w);
			float pitch = clamp(atan(to.y, length(to.xz)), -0.7, 0.7);
			R = rY(yaw) * rX(-pitch);
		} else {
			float beat = fract(TIME / 5.0) * 5.0;
			float up = smoothstep(0.0, 0.12, beat) * (1.0 - smoothstep(1.3, 1.7, beat)) * step(0.55, pose.w);
			R = rZ(pose.z * 0.5 * (pose.w - 0.5) * (1.0 - up)) * rX(pose.z * (1.0 - up * 1.3));
		}
	}
	else if (bn == 2) R = rX(-pose.x) * rZ(-0.1 - 0.25 * pose.x);
	else if (bn == 3) R = rX(-pose.y) * rZ(0.1 + 0.25 * pose.y);
	VERTEX = pivot + R * (VERTEX - pivot);
	if (burst > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float sd = fract(pose.w * 7.31 + o.x * 0.37 + o.z * 0.61);
		float e = clamp(burst * (1.3 - 0.3 * sd), 0.0, 1.0);
		vec2 d = o.xz - burst_mid.xz;
		d /= max(length(d), 0.5);
		float far = e * (2.0 - e) * (6.0 + 15.0 * sd);
		vec3 off = vec3(d.x * far, mix(o.y, burst_mid.y + 0.2, e * e) + sin(e * 3.14159) * (2.0 + 6.0 * sd) - o.y, d.y * far);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	}
	NORMAL = R * NORMAL;
	vTile = UV2;
	vMapUv = UV;
	vec3 c = CUSTOM2.rgb;
	c /= 1.0 + step(1.01, max(c.r, max(c.g, c.b))) * 1.2;
	c = mix(c, COLOR.rgb * (0.35 + 1.4 * dot(c, vec3(0.3, 0.59, 0.11))), CUSTOM0.y);
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(grey) * vec3(0.8, 0.86, 0.66), 0.72);      // drained
	float rot = fract(sin(dot(floor(VERTEX * 9.0), vec3(12.99, 78.23, 37.72)) + pose.w * 40.0) * 43758.5);
	vColor = c * mix(0.34, 0.62, rot);
}

void fragment() {
	vec2 uv = vTile + fract(vMapUv) * 0.25;
	ALBEDO = vColor * texture(atlas, vec2(uv.x, 1.0 - uv.y)).rgb;
	ROUGHNESS = 0.38;
	SPECULAR = 0.55;
}
