// The gravity pulse's shock ring (sky_items.gd): a flat ring on the deck that races outward and fades (instance `fade`). Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.71, 0.49, 1.0);
uniform float power = 2.0;
instance uniform float fade = 1.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(r - 0.9));
	float wash = (1.0 - smoothstep(0.2, 0.95, r)) * 0.12;
	float teeth = 0.7 + 0.3 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 24.0);
	ALBEDO = tint * power * (ring * teeth + wash) * fade * step(r, 1.0);
}
