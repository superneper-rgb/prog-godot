// THE MOTHERSHIP: the Godmother floor's one trim material (ms_arena.gd): every non-carpet face of the tiles, the pedestal, its columns, the ledge and the room's underside in a single draw each, its finish carried by the vertex colour.
// COLOR.rgb is the linear albedo; COLOR.a picks the finish: 0 lacquered wood (a clear coat, and a little light of its own, PS2 style, as the Godmother's paint has: a side face would go black under the penthouse's top-down pink light), 1 gilt metal, 0.5 a tile's anti-grav lens (lit by `glow` while the tile floats).
shader_type spatial;
render_mode cull_back;

instance uniform float glow = 0.0;
uniform vec3 lens : source_color = vec3(0.78, 0.45, 1.0);

void fragment() {
	float metal = step(0.75, COLOR.a);
	float lens_k = step(0.25, COLOR.a) * (1.0 - metal);
	float wood = (1.0 - metal) * (1.0 - lens_k);
	ALBEDO = COLOR.rgb;
	METALLIC = metal * 0.85;
	ROUGHNESS = mix(0.38, 0.28, metal);
	CLEARCOAT = wood * 0.6;
	CLEARCOAT_ROUGHNESS = 0.25;
	EMISSION = COLOR.rgb * 0.42 * wood + lens * lens_k * (0.1 + glow * 3.0);
}
