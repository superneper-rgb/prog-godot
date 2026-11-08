// The wake-up cutscene's photograph (JS levels/apartment/wakeup.js renderPhoto): warm faded colours and grain over the 3D picture.
shader_type canvas_item;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float n = (h(floor(UV * vec2(384.0, 288.0))) - 0.5) * 18.0 / 255.0;
	vec3 o = clamp(vec3(c.r * 0.92 + 22.0 / 255.0, c.g * 0.88 + 14.0 / 255.0, c.b * 0.78 + 8.0 / 255.0) + n, 0.0, 1.0);
	float d = length((UV - 0.5) * vec2(384.0, 288.0));
	float v = 0.45 * clamp((d - 288.0 * 0.35) / (384.0 * 0.7 - 288.0 * 0.35), 0.0, 1.0);      // the vignette
	COLOR = vec4(mix(o, vec3(40.0, 20.0, 0.0) / 255.0, v), 1.0);
}
