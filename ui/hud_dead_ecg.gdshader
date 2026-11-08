// The fibrillation trace behind YOU DIED (#deadEcg): the trace of ui/ecg.gdshaderinc, on its own quad.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://ui/ecg.gdshaderinc"

uniform vec2 canvas_css = vec2(1280.0, 130.0);
uniform float opacity = 0.7;

void fragment() {
	COLOR = ecg_trace(UV * canvas_css, canvas_css) * opacity;
}
