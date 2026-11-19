// THE TAKEN's bodies (enemies/taken_view.gd): FOINT CITY's own townsfolk, the city's meshes (levels/hub/city_folk.gd, the attributes levels/shaders/folk.gdshader reads), posed as the hive moves them:
// a dragging walk, arms that hang, reach as it rushes and go up over its head to strike, a head that hangs until the hive looks through it. Their colour drained grey-green and wet, as the throne's.
// One MultiMesh per species; nothing about a pose runs in script but the root (its lean, its fall) and these four numbers.
// Instance: INSTANCE_CUSTOM = (walk phase, walk 0..1.4, seed, reach: 0 hanging .. 1 out in front .. 2 over its head). COLOR = (amber: its wind-up, awake 0..1, hit flash, head turned to you).
shader_type spatial;
render_mode diffuse_lambert;

uniform sampler2D atlas : source_color, filter_nearest;

varying vec2 vTile;
varying vec2 vMapUv;
varying vec3 vColor;
varying float vFlash;

mat3 rX(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 rY(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rZ(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	int bn = int(CUSTOM0.x + 0.5);
	float aJoint = CUSTOM0.w;
	vec3 aPivot = CUSTOM1.xyz;
	float ph = INSTANCE_CUSTOM.x, wk = INSTANCE_CUSTOM.y, sd = INSTANCE_CUSTOM.z, reach = INSTANCE_CUSTOM.w;
	float awake = COLOR.g, look = COLOR.a;
	float sw = sin(ph) * min(wk, 1.0);
	float idle = clamp(1.0 - wk, 0.0, 1.0);
	float t = TIME;
	// the hive's beat: every few seconds the ones that are not after you all lift their heads at once (enemies/taken_view.gd BEAT / LOOK)
	float beat = step(mod(t, 5.0), 1.5);
	float up = max(awake, beat);
	float twitch = step(mod(t * 1.7 + sd * 9.0, 3.1), 0.07) * 0.3;
	mat3 R = mat3(1.0);
	mat3 sR1 = mat3(1.0), sR2 = mat3(1.0);
	float sW = -1.0;
	float jw = smoothstep(aJoint - 0.045, aJoint + 0.045, aPivot.y - VERTEX.y);
	float lift = clamp(reach, 0.0, 2.0);
	if (bn == 1) {      // the head: hanging on its chest, or up and round to you
		R = rY(look * up + (1.0 - up) * (sd - 0.5) * 0.5) * rX(mix(0.62, -0.12 - 0.1 * min(lift, 1.0), up) + twitch) * rZ(0.18 * (1.0 - up) * sin(sd * 20.0) - twitch * 0.5);
	} else if (bn == 2 || bn == 3) {      // the arms: hang and swing; reach in a rush; up over its head for the blow. Never quite together.
		float s = bn == 2 ? 1.0 : -1.0;
		float lag = 0.12 * sin(t * 2.3 + sd * 11.0 + s);
		float raise = -1.45 * min(lift, 1.0) - 1.35 * max(0.0, lift - 1.0);
		sR1 = rX(raise - s * sw * 0.45 * (1.0 - min(lift, 1.0)) + lag + idle * 0.06 * sin(t * 1.1 + sd * 7.0)) * rZ(s * (-0.08 - 0.18 * max(0.0, lift - 1.0)));
		sR2 = rX(-0.35 - 0.25 * min(lift, 1.0) + 0.2 * max(0.0, lift - 1.0));
		R = sR1;
		sW = aJoint > 0.0 ? jw : -1.0;
	} else if (bn == 4 || bn == 5) {      // the legs: a short dragging step, knees never straight
		float s = bn == 4 ? 1.0 : -1.0;
		float cp = cos(ph);
		sR1 = rX(s * sw * 0.7 - 0.12);
		sR2 = rX(0.25 + 0.85 * pow(max(0.0, -s * cp), 1.3) * min(wk, 1.2) + idle * 0.12);
		R = sR1;
		sW = aJoint > 0.0 ? jw : -1.0;
	} else if (bn == 7) {      // a tail, antennae, a hood: limp, swinging
		R = rZ(0.2 * sin(t * 2.0 + sd * 5.0) + sw * 0.25) * rX(0.15 * sin(t * 1.6 + sd));
	}
	vec3 p = VERTEX;
	vec3 transformed = aPivot + R * (p - aPivot);
	vec3 nrm = R * NORMAL;
	if (sW >= 0.0) {      // a two-bone limb bent at its elbow / knee
		vec3 K = aPivot - vec3(0.0, aJoint, 0.0);
		vec3 p2 = aPivot + sR1 * (K - aPivot) + (sR1 * sR2) * (p - K);
		transformed = mix(transformed, p2, sW);
		nrm = normalize(mix(nrm, (sR1 * sR2) * NORMAL, sW));
	}
	float bob = abs(cos(ph)) * 0.05 * min(wk, 1.2) + idle * 0.01 * sin(t * 1.4 + sd * 6.0);
	transformed.y += bob;
	vTile = UV2;
	vMapUv = UV;
	vec3 c = CUSTOM2.rgb;
	float glowPart = step(1.01, max(c.r, max(c.g, c.b)));
	c /= 1.0 + glowPart * 1.2;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(grey) * vec3(0.78, 0.86, 0.66), 0.7);      // drained (the throne's bodies, levels/shaders/uf_fused_folk.gdshader)
	vColor = c;
	vFlash = COLOR.b;
	VERTEX = transformed;
	NORMAL = nrm;
}

void fragment() {
	vec2 uv = vTile + fract(vMapUv) * 0.25;
	vec3 t = texture(atlas, vec2(uv.x, 1.0 - uv.y)).rgb;
	ALBEDO = mix(vColor * t, vec3(0.9), vFlash);
	ROUGHNESS = 0.42;      // wet
	SPECULAR = 0.45;
	EMISSION = vec3(1.0, 0.92, 0.85) * vFlash * 0.6;
}
