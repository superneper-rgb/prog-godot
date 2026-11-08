// The Wall Wretch's tongue (JS enemies/wall-wretch-view.js update): a ribbon along a curve from the mouth to the tip, round and thick at the mouth, widening into a flat spade. The JS rebuilds these vertices in script every frame; here the same maths runs per vertex. UV.x: along it; UV.y: around it.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, shadows_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

instance uniform vec3 from_pt;
instance uniform vec3 to_pt;
instance uniform vec3 side;       // sin(yaw), 0, cos(yaw)
instance uniform vec4 shape;      // x: sag; y: wobble; z: bulge; w: time
instance uniform float flash;

varying float v_k;

vec3 centre(float k) {
	float i = k * 30.0;
	float bl = shape.z * sin(k * PI);
	vec3 p = from_pt + (to_pt - from_pt) * k;
	p.x += sin(shape.w * 18.0 + i) * shape.y * k + side.x * bl;
	p.y -= shape.x * 4.0 * k * (1.0 - k);
	p.z += cos(shape.w * 16.0 + i) * shape.y * k + side.z * bl;
	return p;
}

void vertex() {
	float k = UV.x;
	vec3 a = centre(max(0.0, k - 1.0 / 30.0));
	vec3 b = centre(min(1.0, k + 1.0 / 30.0));
	vec3 T = normalize(b - a);
	vec3 ref = abs(T.y) > 0.7 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 S = normalize(cross(ref, T));             // frame: the ribbon's flat side keeps one orientation
	vec3 N = cross(T, S);
	float w = 0.085 + 0.025 * k + 0.19 * pow(smoothstep(0.5, 0.96, k), 1.3);
	float th = 0.08 - 0.06 * smoothstep(0.1, 0.8, k) - 0.006 * smoothstep(0.8, 1.0, k);      // round and thick at the mouth, widening into a flat spade
	if (k > 0.94) {
		float f = sqrt(max(0.0, 1.0 - pow((k - 0.94) / 0.06, 2.0)));
		w *= f;
		th *= f;
	}
	w *= 1.0 + 0.05 * sin(k * 40.0 + shape.w * 2.0);
	float an = UV.y * 6.2831853;
	float ca = cos(an);
	float sa = sin(an);
	VERTEX = centre(k) + S * ca * w + N * sa * th;
	NORMAL = normalize(S * ca * th + N * sa * w);
	v_k = k;
	UV = vec2(UV.y, k * 6.0);
}

void fragment() {
	vec3 alb = texture(skin, UV).rgb * vec3(0.8714, 0.4793, 0.4342);      // JS tongueM.color 0xf0b8b0
	ALBEDO = alb;
	ROUGHNESS = 0.45;
	float rim = pow(1.0 - abs(dot(VIEW, NORMAL)), 2.6);
	EMISSION = vec3(0.09 + flash * 0.8, 0.0495 + flash * 0.3, 0.045 + flash * 0.2) + vec3(0.32, 0.0048, 0.0091) * 0.55 * rim * (0.6 + 0.6 * alb.r);      // the wetSkin rim (JS sss 0x9a0c18, 0.55) and the JS's faint self-glow
}
