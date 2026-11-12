// The inventory's 3D preview as the green terminal shows it: the model's light as phosphor, a little of its own colour kept so suits and vials still read apart, raster lines, and the scan front of the shared VendorStage.
shader_type canvas_item;

uniform vec3 phos = vec3(0.5, 1.0, 0.68);
uniform float keep : hint_range(0.0, 1.0) = 0.42;
uniform float reveal = 1.0;
uniform bool vertical = false;
uniform float lines = 140.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = phos * pow(l, 0.8) * 1.7;
	vec3 o = mix(g, c.rgb, keep);
	o *= 0.84 + 0.16 * sin(UV.y * lines * 6.28318);
	float front = vertical ? 1.0 - UV.y : UV.x;
	COLOR = vec4(o, c.a * step(front, reveal)) * tint;
}
