// Main menu backdrop: its picture on the screen (JS OutputPass): three.js's ACESFilmicToneMapping at the scene's own exposure, then sRGB. The picture comes linear out of its HDR viewport.
shader_type canvas_item;
uniform float exposure = 1.15;
const mat3 ACES_IN = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
const mat3 ACES_OUT = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	c = ACES_IN * (c * exposure / 0.6);
	vec3 a = c * (c + 0.0245786) - 0.000090537;
	vec3 b = c * (0.983729 * c + 0.4329510) + 0.238081;
	c = clamp(ACES_OUT * (a / b), 0.0, 1.0);
	c = mix(12.92 * c, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
	COLOR = vec4(c, 1.0);
}
