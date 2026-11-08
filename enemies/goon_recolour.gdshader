// FOINT goon: the base-map recolour of the GOINT costumes (JS foint-goon-dress.js RECOLOUR): dyes the toad's own texture by brightness or, with a split, by where the texel sits on the body at rest.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 u_dark = vec3(1.0);
uniform vec3 u_light = vec3(1.0);
uniform vec4 u_band = vec4(0.05, 0.3, 0.0, 0.05);
uniform vec4 u_led = vec4(0.0);
uniform vec4 u_split = vec4(0.0, 0.0, 9.0, 0.0);
uniform vec3 u_shirt = vec3(1.0);
uniform vec3 u_pants = vec3(1.0);
uniform vec3 u_print_a[2];
uniform vec3 u_print_b[2];

varying vec3 v_rest;

void vertex() {
	v_rest = CUSTOM0.xyz;      // (a skinned VERTEX is already posed here: the rest position is baked into CUSTOM0)
}

void fragment() {
	vec3 src = texture(albedo_tex, UV).rgb;
	vec3 c = src;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sa = (mx - mn) / (mx + 1e-4);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float skin = max(step(1.12, v_rest.y) * (1.0 - step(0.46, abs(v_rest.x))), step(0.83, abs(v_rest.x)));      // the head and the hands
	float grey = 1.0 - smoothstep(0.32, 0.55, sa) * smoothstep(0.03, 0.07, mx);      // near-black counts as cloth whatever its tint
	float emblem = (1.0 - grey) * (1.0 - skin);
	vec3 ra = vec3(abs(v_rest.x), v_rest.yz);
	for (int i = 0; i < 2; i++) {
		if (all(greaterThan(ra, u_print_a[i])) && all(lessThan(ra, u_print_b[i]))) {
			emblem = max(emblem, 0.8);
		}
	}
	lum = mix(lum, u_band.w, emblem);
	grey = max(grey, emblem);
	vec3 t = (lum + u_band.z) * mix(u_dark, u_light, smoothstep(u_band.x, u_band.y, lum));
	if (u_split.w > 0.5) {
		float k = clamp(0.62 + lum * 2.6, 0.45, 1.45);
		vec3 cloth = mix(u_pants, u_shirt, smoothstep(u_split.x - 0.012, u_split.x + 0.012, v_rest.y));
		float keep = max(1.0 - smoothstep(u_split.y - 0.015, u_split.y + 0.015, v_rest.y), smoothstep(u_split.z - 0.02, u_split.z + 0.02, abs(v_rest.x)));
		t = mix(cloth * k, c * 0.85, keep);
	}
	c = mix(c, t, grey);
	float led = u_led.w * step(0.2, src.r) * (1.0 - smoothstep(0.03, 0.08, src.g / (src.r + 1e-4)));
	ALBEDO = mix(c, u_led.rgb, led);
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
}
