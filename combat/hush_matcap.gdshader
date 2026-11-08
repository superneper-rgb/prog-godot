// The HUSH TWINS' polished finishes (JS MeshMatcapMaterial): the colour comes from a painted studio reflection, looked up by the surface's direction as the camera sees it, so chrome, gold and lacquer read as mirror finishes in any level.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D matcap : source_color, filter_linear;

void fragment() {
	vec3 x = normalize(vec3(VIEW.z, 0.0, -VIEW.x));
	vec3 y = cross(VIEW, x);
	vec2 uv = vec2(dot(x, NORMAL), dot(y, NORMAL)) * 0.495 + 0.5;
	ALBEDO = texture(matcap, vec2(uv.x, 1.0 - uv.y)).rgb;
}
