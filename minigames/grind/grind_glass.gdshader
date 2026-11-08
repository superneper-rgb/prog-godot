// RAILJACK: the glass (JS composite + drawAscii): the scene, its phosphor bloom, a faint permanent red/blue fringe, the scene re-read as text (glyphs by brightness, tinted green / amber / red / white), and the glitch tears.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D buf : filter_linear, repeat_disable;
uniform sampler2D bloom : filter_linear, repeat_disable;
uniform sampler2D asc : filter_nearest, repeat_disable;
uniform sampler2D glyphs : filter_linear, repeat_disable;
uniform vec2 grid = vec2(198.0, 60.0);
uniform float flick = 1.0;
uniform float fringe = 0.002;
uniform vec3 pn[4];
uniform vec4 acol[4];
uniform float glitch = 0.0;
uniform float seed = 0.0;
uniform vec3 slices[16];
uniform vec2 gl_off = vec2(0.0);
uniform vec2 bar = vec2(0.0);
uniform vec3 bar_col = vec3(0.6, 1.0, 0.75);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 c = vec3(2.0, 10.0, 4.0) / 255.0;
	vec3 s0 = texture(buf, uv).rgb;
	c = mix(c, s0, flick * 0.8);
	c += texture(bloom, uv).rgb * 0.42;
	c += (texture(buf, uv - vec2(fringe, 0.0)).rgb + texture(buf, uv + vec2(fringe, 0.0)).rgb) * 0.07;
	// the scene re-read as text
	vec2 g = uv * grid;
	vec2 cell = floor(g);
	vec2 f = g - cell;
	vec3 s = texture(asc, (cell + 0.5) / grid).rgb;
	float mx = max(s.r, max(s.g, s.b));
	float lum = mx * 2.4;
	if (lum >= 0.16) {
		int ci = min(9, int(lum * 9.0));
		if (glitch > 0.1 && hash(cell) < glitch * 0.15) {
			ci = 1 + int(hash(cell + 7.0) * 9.0);      // corrupted cells during a tear
			ci = min(ci, 9);
		}
		vec3 nc = s / max(mx, 0.0001);
		int bq = 0;
		float bd = 9.0;
		for (int q = 0; q < 4; q++) {
			vec3 e = nc - pn[q];
			float dd = dot(e, e);
			if (dd < bd) {
				bd = dd;
				bq = q;
			}
		}
		float gl = texture(glyphs, vec2((float(ci) + f.x) / 10.0, f.y)).r;
		c += acol[bq].rgb * acol[bq].a * gl;
	}
	if (glitch > 0.0) {
		float gl = min(1.0, glitch);
		for (int i = 0; i < 16; i++) {
			vec3 q = slices[i];
			if (q.x >= 0.0 && uv.y >= q.x && uv.y < q.x + q.y) {
				c = texture(buf, vec2(uv.x - q.z, uv.y)).rgb;
				if (i < 2) {
					float row = floor(uv.y * grid.y);
					c += texture(asc, vec2(uv.x - q.z * 1.6, (row + 0.5) / grid.y)).rgb * 0.5;
				}
			}
		}
		float a = 0.3 * min(1.0, gl * 2.0);
		c += (texture(buf, uv - vec2(gl_off.x, 0.0)).rgb + texture(buf, uv - vec2(gl_off.y, 0.0)).rgb) * a;
		if (uv.y >= bar.x && uv.y < bar.x + bar.y) {      // a bright tracking bar
			c += bar_col * 0.18 * min(1.0, gl * 3.0);
		}
	}
	COLOR = vec4(min(c, vec3(1.0)), 1.0);
}
