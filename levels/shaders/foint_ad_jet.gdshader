// The FOINT CITY billboard's hover jets (levels/hub/foint_ad_monitor.gd): an open cone under each pod, glowing out of the nozzle and fading down its length and at its silhouette.
// UV.x runs round the cone, UV.y from the nozzle (0) to the cone's end (1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.55, 0.75, 1.0);
uniform float power = 1.0;     // the jet's thrust: the script raises it when the monitor kicks up
uniform float t = 0.0;

void fragment() {
	float edge = abs(dot(NORMAL, VIEW));
	float flick = 0.86 + 0.14 * sin(t * 41.0 + UV.x * 18.85) * sin(t * 13.0 + UV.y * 9.0);
	float k = pow(1.0 - UV.y, 2.4) * pow(edge, 1.6) * flick * power;
	ALBEDO = color * k;
}
