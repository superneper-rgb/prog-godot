// The Pale Punk's skin (JS createPalePunkNPC's onBeforeCompile): eyelids work in bind-space face coordinates, so they follow the skinned head and cover every UV island of the atlas.
shader_type spatial;
uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float npc_blink = 0.0;
uniform vec3 flash = vec3(0.0);
varying vec3 npc_face_position;

void vertex() {
	npc_face_position = CUSTOM0.xyz;
}

void fragment() {
	vec3 col = texture(map, UV).rgb;
	if (npc_blink > 0.0 && npc_face_position.z > 0.08) {
		float eye_x = npc_face_position.x < 0.0 ? -0.093 : 0.085;
		vec2 eye = (npc_face_position.xy - vec2(eye_x, 1.434)) / vec2(0.043, 0.044);
		float area = 1.0 - smoothstep(0.88, 1.0, length(eye));
		float opening = (1.0 - npc_blink) * 1.12;
		float lid = smoothstep(opening - 0.045, opening + 0.045, abs(eye.y));
		lid = mix(lid, 1.0, smoothstep(0.95, 1.0, npc_blink));
		vec3 skin = vec3(0.55, 0.43, 0.32);
		float crease = (1.0 - smoothstep(0.015, 0.085, abs(eye.y))) * smoothstep(0.9, 1.0, npc_blink);
		skin *= 1.0 - crease * 0.38;
		col = mix(col, skin, area * lid);
	}
	ALBEDO = col;
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	EMISSION = flash;
}
