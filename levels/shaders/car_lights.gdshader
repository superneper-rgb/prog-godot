// FOINT CITY car lights: the head blade, the tail bar, the accent lines, a taxi's sign. tools/cars/build_cars.py bakes the light's colour into the vertex colour and its strength into UV.x; the bloom does the rest.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform float gain = 3.2;

void fragment() {
	ALBEDO = COLOR.rgb * UV.x * gain;
}
