// A suit's cloth standing in for Prog's own tank top, shorts and boots (JS phantom-suit.js clothMat + shadeGLSL): flat colour, every facet its own slightly different tone (a hash of the
// facet's direction in the bind pose, so it never swims when he moves), faint darker bands like quilted panel seams. Flat shaded and double-sided, as the JS Lambert.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float cell = 9.0;
uniform bool bands = false;
uniform float amp = 0.2;

varying vec3 v_bp;

void vertex() {
	v_bp = CUSTOM0.xyz;
}

void fragment() {
	vec3 face_n = abs(normalize(cross(dFdx(v_bp), dFdy(v_bp)) + vec3(1e-9)));
	float fh = fract(sin(dot(floor(face_n * cell + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float shade_k = (1.0 - amp / 2.0) + amp * fh;
	if (bands) {
		shade_k *= 1.0 - 0.11 * step(fract(v_bp.y * 5.5), 0.07);
		shade_k *= 0.96 + 0.08 * smoothstep(0.0, 1.9, v_bp.y);
	}
	ALBEDO = color * shade_k;
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;       // flatShading: the facet's own normal, facing the viewer on both sides
}
