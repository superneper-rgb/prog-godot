// Explosions and rings (JS FX.update "explosions"): the whole animation from the spawn values. INSTANCE_CUSTOM = (t0, r, dur, mode). mode: 0 core ball, 1 fire ball, 2 burst ring, 3 ping / wave ring (grows over dur), 4 ripple (slows as it grows).
#include "res://levels/shaders/common.gdshaderinc"
uniform float now = 0.0;
varying float v_a;

void vertex() {
	float b = now - INSTANCE_CUSTOM.x;
	float r = INSTANCE_CUSTOM.y;
	int mode = int(INSTANCE_CUSTOM.w + 0.5);
	float s = 0.0;
	float a = 0.0;
	if (b >= 0.0) {
		if (mode >= 3) {
			float k = b / INSTANCE_CUSTOM.z;
			if (k < 1.0) {
				s = max(0.01, r * min(1.0, mode == 4 ? sqrt(k) : k));
				a = max(0.0, COLOR.a * (1.0 - k));
			}
		} else {
			float k = b / 0.55;
			if (k < 1.0) {
				float e = 1.0 - pow(1.0 - k, 3.0);
				if (mode == 0) { s = max(0.01, r * 0.45 * e * (1.0 - k * 0.5)); a = max(0.0, 1.0 - k * 1.6); }
				else if (mode == 1) { s = max(0.01, r * 0.8 * e); a = max(0.0, 0.9 - k); }
				else { s = max(0.01, r * 1.15 * e); a = max(0.0, 0.8 - k * 1.2); }
			}
		}
	}
	VERTEX *= s;
	v_a = a;
}

void fragment() {
	ALBEDO = add_display(COLOR.rgb, v_a);      // JS: tone-mapped, then added on the display value
	ALPHA = 1.0;
}
