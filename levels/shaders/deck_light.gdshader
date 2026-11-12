// The Deck's lamps as light (levels/hub/deck_look.gd): one box per lamp, drawn from inside like a screen-space decal. FOINT CITY is lit in its materials (unshaded, baked shade), so a real
// light would barely show. Each box reads the depth under it, lights the surface it finds in a downward cone (whatever stands there: street, pier, car, Prog), and marches the
// ray through the cone for a soft shaft in the rain. The box's top centre is the lamp; its half width is the pool's radius at the bottom.
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float surf_k = 8.0;        // how much brighter a lit surface gets (it multiplies what is there, so a crossing's paint stays paint)
uniform float surf_add = 0.045;    // plus a little of the lamp's own colour, so the pool still shows on near-black asphalt
uniform float shaft_k = 0.0035;    // the shaft: the lamp light the rain catches, per metre of cone the ray crosses
uniform float r_top = 0.5;         // the cone's radius at the lamp
uniform float uplift = 0.0;        // how far the box reaches above the lamp: the spill that lights the steel around a lamp hung under the slab

varying flat vec3 v_center;
varying flat vec3 v_half;
varying flat vec4 v_col;

void vertex() {
	v_center = MODEL_MATRIX[3].xyz;
	v_half = 0.5 * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_col = INSTANCE_CUSTOM;
}

float cone_at(vec3 p, vec3 apex, float tan_a) {
	float h = apex.y - p.y;
	if (h < 0.0) {      // above the lamp: only its spill on the steel around it
		return uplift > 0.0 && -h < uplift ? (1.0 - smoothstep(0.4, 5.0, length(p - apex))) * 3.2 : 0.0;
	}
	float r = r_top + h * tan_a;
	float d = length(p.xz - apex.xz);
	float edge = 1.0 - smoothstep(r * 0.2, r, d);
	return edge / (1.0 + h * h * 0.012);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vp.xyz /= vp.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 apex = v_center + vec3(0.0, v_half.y - uplift, 0.0);
	float tan_a = max(v_half.x - r_top, 0.1) / (2.0 * v_half.y - uplift);
	vec3 lc = v_col.rgb * v_col.a;

	// the surface: lit only where it is inside this box (the box is drawn over whatever is in front of it too)
	vec3 col = vec3(0.0);
	vec3 q = abs(wp - v_center);
	if (q.x < v_half.x && q.y < v_half.y && q.z < v_half.z) {
		vec3 n = normalize(cross(dFdx(wp), dFdy(wp)));
		if (dot(n, cam - wp) < 0.0) {
			n = -n;
		}
		float lam = sqrt(max(dot(n, normalize(apex - wp)), 0.0));      // only faces that face the lamp (the deck seen from below is not lit by the lamps above it); walls catch some
		vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
		col += lc * cone_at(wp, apex, tan_a) * lam * (scene * surf_k + surf_add);
	}

	// the shaft: march the view ray through the box, up to the surface
	vec3 rd = wp - cam;
	float ts = length(rd);
	rd /= ts;
	vec3 inv = 1.0 / (rd + vec3(1e-6));
	vec3 t_a = (v_center - v_half - cam) * inv;
	vec3 t_b = (v_center + v_half - cam) * inv;
	vec3 tmin = min(t_a, t_b);
	vec3 tmax = max(t_a, t_b);
	float t0 = max(max(max(tmin.x, tmin.y), tmin.z), 0.0);
	float t1 = min(min(min(tmax.x, tmax.y), tmax.z), ts);
	if (t1 > t0) {
		const int N = 8;
		float dt = (t1 - t0) / float(N);
		float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));      // interleaved gradient noise: no banding between the steps
		float acc = 0.0;
		for (int i = 0; i < N; i++) {
			vec3 p = cam + rd * (t0 + (float(i) + jit) * dt);
			float fall = 0.75 + 0.25 * sin(p.y * 1.7 + TIME * 9.0 + sin(p.x * 3.1 + p.z * 2.3) * 4.0);      // the rain moving through it
			acc += cone_at(p, apex, tan_a) * fall;
		}
		col += lc * acc * dt * shaft_k;
	}
	ALBEDO = col;
}
