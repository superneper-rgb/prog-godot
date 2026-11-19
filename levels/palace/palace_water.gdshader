// The bay round the Pervert Palace site (levels/palace/palace_city.gd): black-violet water that carries the city's light. Rolling swell (two scrolling noise normals), a sky tint at grazing
// angles, and each light in `uL` (x, y, z, warmth) laid on it as a broken column of glitter running from under the light toward the camera, as lights on night water do.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.012, 0.01, 0.02);
uniform vec3 sky : source_color = vec3(0.09, 0.05, 0.14);
uniform vec3 cold : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 amber : source_color = vec3(1.0, 0.6, 0.22);
uniform vec3 red : source_color = vec3(1.0, 0.12, 0.08);
uniform vec4 uL[24];      // x, y, z, colour: 0 cold blue-white, 0.5 amber, 1 red
uniform float uLN = 0.0;
uniform float glitter = 0.7;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	vec3 n1 = texture(noise_tex, p * 0.035 + vec2(t * 0.012, t * 0.007)).rgb;
	vec3 n2 = texture(noise_tex, p * 0.11 - vec2(t * 0.02, -t * 0.015)).rgb;
	vec2 tilt = (n1.rg - 0.5) * 0.5 + (n2.rg - 0.5) * 0.3;
	vec3 nw = normalize(vec3(tilt.x, 1.0, tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 v = normalize(cam - wpos);
	vec3 ns = normalize(vec3(tilt.x * 0.25, 1.0, tilt.y * 0.25));      // (a calmer normal for how much sky it mirrors: the swell only breaks it up)
	float fres = pow(1.0 - clamp(dot(v, ns), 0.0, 1.0), 3.0);
	vec3 col = deep + sky * (0.12 + fres * 1.6);
	// the glitter columns: for each light, how near this point is to the line from under the light toward the camera, and broken up by the swell
	vec3 glit = vec3(0.0);
	for (int i = 0; i < 24; i++) {
		if (float(i) >= uLN) { break; }
		vec4 L = uL[i];
		vec2 lp = L.xz;
		vec2 to_cam = cam.xz - lp;
		float len = length(to_cam);
		if (len < 0.5) { continue; }
		vec2 dir = to_cam / len;
		vec2 rel = p - lp;
		float along = dot(rel, dir);
		float across = abs(rel.x * dir.y - rel.y * dir.x);
		float reach = clamp(L.y - wpos.y, 2.0, 120.0) * 2.2;
		float width = min(0.16 + along * 0.009, 0.75);
		float k = step(0.0, along) * step(along, min(len, reach)) * smoothstep(width, width * 0.2, across) * smoothstep(6.0, 40.0, len - along);      // (it thins out before it reaches you)
		float sparkle = smoothstep(0.45, 0.85, n2.b + n1.g * 0.5 - 0.15 * sin(along * 0.9 + t * 1.3));
		float fade = 1.0 - along / max(reach, 1.0);
		vec3 lc = L.w < 0.5 ? mix(cold, amber, L.w * 2.0) : mix(amber, red, L.w * 2.0 - 1.0);
		glit += lc * k * sparkle * fade * fade;
	}
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = glit * glitter;
}
