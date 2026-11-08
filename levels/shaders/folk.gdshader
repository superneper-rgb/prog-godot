// FOINT CITY townsfolk (JS levels/hub/city-folk.js folkMaterial, the onBeforeCompile hook, statement for statement): Lambert lit, the bone walk cycle and the atlas tiles. One MultiMesh per species; nothing about a pose runs in script.
// Vertex: VERTEX, NORMAL, UV, UV2 = aTile, CUSTOM0 = aB4 (bone, tint, mode, elbow / knee depth), CUSTOM1.xyz = aPivot, CUSTOM2.rgb = the vertex colour (over 1 for marked parts, so not COLOR). Instance: COLOR.rgb = aCol, COLOR.a = aLook, INSTANCE_CUSTOM = aAnim (phase, walk, seed, amp).
// Mode 5 (at the wheel): INSTANCE_CUSTOM = aSeat (steer, arm direction, elbow bend, thigh angle), the rest of aAnim is 0, 0, seed, 1 (the seed comes from the instance's index: a driver has no more room in a MultiMesh's custom data).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float uTime = 0.0;

varying vec2 vTile;
varying vec2 vMapUv;
varying vec3 vColor;

mat3 rX(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 rY(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rZ(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	vec4 aB4 = CUSTOM0;
	float aBone = aB4.x;
	float aTint = aB4.y;
	float aMode = aB4.z;
	float aJoint = aB4.w;
	vec3 aPivot = CUSTOM1.xyz;
	vec3 aCol = COLOR.rgb;
	float aLook = COLOR.a;
	bool seated = aMode > 4.5;
	vec4 aAnim = seated ? vec4(0.0, 0.0, fract(float(INSTANCE_ID) * 0.37), 1.0) : INSTANCE_CUSTOM;
	vec4 aSeat = INSTANCE_CUSTOM;
	vec3 position = VERTEX;

	float ph = aAnim.x, wk = aAnim.y, sd = aAnim.z, amp = aAnim.w;
	int bn = int(aBone + 0.5);
	float sw = sin(ph) * wk * amp, idle = 1.0 - wk;
	mat3 R = mat3(1.0);
	if (bn == 1) R = rY(aLook + idle * 0.25 * sin(uTime * 0.37 + sd * 13.0)) * rX(0.05 * sin(ph * 2.0) * wk + idle * 0.04 * sin(uTime * 0.9 + sd * 4.0));
	else if (bn == 2) R = rX(-sw * 0.95 + idle * 0.05 * sin(uTime * 1.3 + sd * 9.0)) * rZ(-0.06);
	else if (bn == 3) R = rX(sw * 0.95 + idle * 0.05 * sin(uTime * 1.1 + sd * 7.0)) * rZ(0.06);
	else if (bn == 4 || bn == 9) R = rX(sw * 0.75);
	else if (bn == 5 || bn == 8) R = rX(-sw * 0.75);
	else if (bn == 7) R = rZ(0.14 * sin(uTime * 4.0 + sd * 5.0) + sw * 0.2) * rX(0.1 * sin(uTime * 3.1 + sd));
	if (aMode > 2.5 && aMode < 4.5) {      // aliens: 3 talks with its hands, 4 plays chess
		float tA = smoothstep(0.0, 0.5, sin(uTime * 0.45 + sd * 17.0)), tB = smoothstep(0.0, 0.5, sin(uTime * 0.45 + sd * 17.0 + 2.1));
		if (aMode < 3.5) {
			if (bn == 1) R = rY(aLook + 0.55 * sin(uTime * 0.35 + sd * 13.0)) * rX(0.07 * sin(uTime * 2.6 + sd * 5.0) * (tA + tB));
			else if (bn == 2) R = rX(-0.3 - tA * (0.5 + 0.5 * sin(uTime * 4.1 + sd * 9.0)) * 0.9) * rZ(-0.08 - 0.2 * tA);
			else if (bn == 3) R = rX(-0.3 - tB * (0.5 + 0.5 * sin(uTime * 3.7 + sd * 11.0)) * 0.9) * rZ(0.08 + 0.2 * tB);
		} else {
			float fr = fract(uTime * 0.07 + sd * 3.0), mv = smoothstep(0.82, 0.9, fr) * (1.0 - smoothstep(0.96, 1.0, fr));
			if (bn == 1) R = rY(aLook + 0.12 * sin(uTime * 0.5 + sd * 4.0)) * rX(0.3 + 0.05 * sin(uTime * 0.8 + sd * 3.0) + 0.12 * mv);
			else if (bn == 2) R = rX(-0.55 + 0.03 * sin(uTime * 1.2 + sd * 7.0));
			else if (bn == 3) R = rY(0.3 * sin(mv * 6.28 + sd)) * rX(-1.15 - 0.3 * mv);
		}
	}
	mat3 sR1 = mat3(1.0), sR2 = mat3(1.0);
	float sW = -1.0;
	float jw = smoothstep(aJoint - 0.045, aJoint + 0.045, aPivot.y - position.y);      // 0 above the elbow / knee, 1 below it
	if (aMode < 2.5 && aJoint > 0.0 && bn >= 2 && bn <= 5) {      // walking: knees fold through the swing, elbows bend on the forward swing
		float cp = cos(ph), sp = sin(ph);
		if (bn == 4) sR2 = rX((0.12 + 0.95 * pow(max(0.0, -cp), 1.3)) * wk * min(amp, 1.2) + idle * 0.05);
		else if (bn == 5) sR2 = rX((0.12 + 0.95 * pow(max(0.0, cp), 1.3)) * wk * min(amp, 1.2) + idle * 0.05);
		else if (bn == 2) sR2 = rX(-(0.22 + 0.55 * max(0.0, sp)) * wk - idle * (0.14 + 0.03 * sin(uTime * 0.8 + sd * 3.0)));
		else sR2 = rX(-(0.22 + 0.55 * max(0.0, -sp)) * wk - idle * (0.14 + 0.03 * sin(uTime * 0.7 + sd * 5.0)));
		sR1 = R;
		sW = jw;
	}
	if (seated) {      // sitting at a steering wheel. aSeat = (steer, arm direction, elbow bend, thigh angle); aJoint = elbow / knee depth below the shoulder / hip
		float st = aSeat.x, dir = aSeat.y, bend = aSeat.z, thigh = aSeat.w, sdx = (bn == 2 || bn == 4) ? 1.0 : -1.0;
		R = mat3(1.0);
		if (bn == 1) R = rY(aLook + 0.3 * st) * rX(0.04 + 0.02 * sin(uTime * 0.9 + sd * 4.0));
		else if (bn == 2 || bn == 3) { sR1 = rY(0.3 * st) * rX(-(dir - bend)) * rZ(sdx * -0.16 * min(1.0, dir)); sR2 = rX(-2.0 * bend); R = sR1; sW = jw; }
		else if (bn == 4 || bn == 5) { sR1 = rX(-thigh) * rZ(sdx * 0.07 * min(1.0, thigh)); sR2 = rX(thigh - 0.1 * min(1.0, thigh)); R = sR1; sW = jw; }
	}
	// the upper body turns against the stride (shoulders follow the arm swing), and breathes when it stands
	mat3 Tw = (aMode < 2.5 && bn != 4 && bn != 5 && bn != 8 && bn != 9) ? rY(-0.085 * sin(ph) * wk * min(amp, 1.2)) : mat3(1.0);
	float bob = abs(cos(ph)) * 0.045 * wk * amp + idle * 0.008 * sin(uTime * 1.6 + sd * 6.0);
	vec3 objectNormal = R * NORMAL;
	if (sW >= 0.0) objectNormal = normalize(mix(sR1 * NORMAL, (sR1 * sR2) * NORMAL, sW));
	objectNormal = Tw * objectNormal;
	vec3 transformed = aPivot + R * (position - aPivot);
	if (sW >= 0.0) {      // a two-bone limb bent at its elbow / knee: the part below the joint turns about it
		vec3 K = aPivot - vec3(0.0, aJoint, 0.0), p1 = aPivot + sR1 * (position - aPivot), p2 = aPivot + sR1 * (K - aPivot) + (sR1 * sR2) * (position - K);
		transformed = mix(p1, p2, sW);
	}
	transformed = Tw * transformed;
	if (bn == 0 || bn == 1) transformed.y += idle * 0.006 * sin(uTime * 1.9 + sd * 7.0) * smoothstep(0.6, 1.3, position.y);      // breathing
	if (aMode > 0.5 && aMode < 1.5) transformed.y += 0.07 * sin(uTime * 2.1 + sd * 6.0);      // hovering / gliding
	else if (aMode > 1.5 && aMode < 2.5) {      // squash and stretch
		float q = abs(sin(ph)) * wk * 0.12 + idle * 0.03 * (0.5 + 0.5 * sin(uTime * 2.0 + sd * 5.0));
		transformed.y *= 1.0 - q;
		transformed.xz *= 1.0 + q * 0.6;
	}
	transformed.y += bob;
	vTile = UV2;
	vMapUv = UV;
	vec3 c = CUSTOM2.rgb;
	float glowPart = step(1.01, max(c.r, max(c.g, c.b)));
	c /= 1.0 + glowPart * 1.2;      // restore marked hardware to its base colour; scene lights shade it like the rest of the person
	c = mix(c, aCol * (0.35 + 1.4 * dot(c, vec3(0.3, 0.59, 0.11))), aTint);      // clothes take this person's colour
	vColor = c;
	VERTEX = transformed;
	NORMAL = objectNormal;
}

void fragment() {
	vec2 uv = vTile + fract(vMapUv) * 0.25;
	vec3 t = texture(atlas, vec2(uv.x, 1.0 - uv.y)).rgb;      // (three.js reads its canvases upside down)
	ALBEDO = vColor * t;
}
