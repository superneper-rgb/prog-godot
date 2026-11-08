// A soft round glow that always faces the camera (JS cutscene props: new T.Sprite(new T.SpriteMaterial({ map: radial, additive }))), also one smoke pool on a MultiMesh (instance colour = its opacity). A radial 1, .45 at 35%, 0 at the edge.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;
#define ADDITIVE
#include "res://cutscenes/cine_glow.gdshaderinc"
