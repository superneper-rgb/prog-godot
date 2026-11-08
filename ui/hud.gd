class_name Hud
extends Control
## The in-game HUD, ported from class Hud and class UI (index.html hud.js, ui.js) and its CSS: the integrity monitor with its EKG, shield and mana, the weapon readout, crosshair, scope,
## hit marker, damage direction, toasts, cash, subtitles, the near-interact hint, the death screen. Same timings and thresholds. Reads Game.player and Game.combat; each piece only redraws when its signature changes.

# ---- the patient monitor trace (JS class Ecg) ----
## A live ECG: scrolls like a patient monitor. Normal sinus rhythm at ~70 bpm that speeds up into sinus tachycardia as hr rises; vf (0..1) blends in ventricular fibrillation.
class Ecg extends RefCounted:
	var speed := 100.0
	var line := 2.0
	var glow := 8.0
	var gap := 0.09
	var grid := true
	var W := 0
	var H := 0.0
	var buf := PackedFloat32Array()
	var head := 0
	var acc := 0.0
	var t := randf() * 50.0
	var beat_t := 0.05
	var period := 0.86
	var prev_period := 0.86
	var vf := 0.0
	var rhy := 0
	var prev_rhy := 0
	var vf_ph := randf() * 6.0
	var env := 0.6
	var cur := 0.0
	var img: Image
	var tex: ImageTexture

	func _init(p_speed: float, p_line: float, p_glow: float, p_grid: bool = true, p_gap: float = 0.09) -> void:
		speed = p_speed
		line = p_line
		glow = p_glow
		grid = p_grid
		gap = p_gap

	func size_to(w: float, h: float) -> void:
		var iw := int(w)
		if iw != W or h != H:
			W = iw
			H = h
			buf.resize(W)
			buf.fill(0.0)
			head = 0
			img = Image.create_empty(maxi(W, 1), 1, false, Image.FORMAT_RF)
			tex = ImageTexture.create_from_image(img)

	# one heartbeat: P wave, QRS complex, T wave (s seconds after the beat starts; c squeezes it at fast rates)
	static func _g(s: float, c: float, mu: float, sg: float, a: float) -> float:
		var w := maxf(sg * c, 0.014)      # never thinner than ~1.5 samples (the trace is sampled every ~10 ms), or fast beats alias into spikes of random height
		var d := s - mu * c
		return a * exp(-(d * d) / (2.0 * w * w))

	static func wave(s: float, c: float) -> float:
		return _g(s, c, 0.10, 0.028, 0.13) + _g(s, c, 0.185, 0.008, -0.14) + _g(s, c, 0.20, 0.010, 1.0) + _g(s, c, 0.217, 0.010, -0.26) + _g(s, c, 0.36, 0.05, 0.30)

	# supraventricular tachycardia: narrow spiky QRS, no visible P wave, a small T (times scale with the beat period p)
	static func wave_svt(s: float, p: float) -> float:
		return _g(s, p, 0.43, 0.06, -0.12) + _g(s, p, 0.50, 0.07, 0.95) + _g(s, p, 0.58, 0.06, -0.2) + _g(s, p, 0.82, 0.09, 0.15)

	# ventricular tachycardia: wide, bizarre, near-sinusoidal complexes, no P, no T (p = beat period)
	static func wave_vt(s: float, p: float) -> float:
		return _g(s, p, 0.30, 0.10, 1.0) + _g(s, p, 0.68, 0.10, -0.8)

	static func _beat(s: float, r: int, per: float) -> float:
		if r == 2:
			return wave_vt(s, per)
		if r == 1:
			return wave_svt(s, per)
		return wave(s, minf(1.0, maxf(0.55, per / 0.86)))

	func _advance(dt: float, hr: float, p_rhy: int) -> float:
		t += dt
		beat_t += dt
		period = 60.0 / hr          # follows the rate every step, so a change of rate shows at once instead of after the beat in progress
		if beat_t >= period:        # the rhythm changes on a beat boundary
			beat_t -= period
			prev_period = period
			prev_rhy = rhy
			rhy = p_rhy
			if beat_t >= period:
				beat_t = 0.0
		var sinus := _beat(beat_t, rhy, period) + _beat(beat_t + prev_period, prev_rhy, prev_period) + 0.025 * sin(t * 1.7) + 0.012 * (randf() - 0.5)
		# ventricular fibrillation: chaotic, wandering frequency and amplitude, no QRS at all
		vf_ph += dt * 6.283 * (4.4 + 1.6 * sin(t * 0.8) + 0.7 * sin(t * 2.3))
		env += (0.35 + 0.65 * randf() - env) * minf(1.0, dt * 5.0)
		var vfw := maxf(-1.0, minf(1.0, env * (0.75 * sin(vf_ph) + 0.4 * sin(vf_ph * 1.63 + 1.1)) + 0.25 * sin(t * 44.6 + 0.4)))
		cur = sinus + (vfw - sinus) * vf
		return cur

	func step(dt: float, hr: float, p_vf: float, p_rhy: int = 0) -> void:
		if W <= 0:
			return
		vf = p_vf
		acc += speed * minf(dt, 0.05)
		var n := int(floor(acc))
		if n < 1:
			return
		acc -= n
		var sub := minf(dt, 0.05) / n
		for i in n:
			buf[head] = _advance(sub, hr, p_rhy)
			head = (head + 1) % W

	## Hand this frame's trace to its shader.
	func draw(m: ShaderMaterial, color: Color) -> void:
		if W <= 0:
			return
		img.set_data(W, 1, false, Image.FORMAT_RF, buf.to_byte_array())
		tex.update(img)
		m.set_shader_parameter(&"ecg_buf", tex)
		m.set_shader_parameter(&"ecg_w", W)
		m.set_shader_parameter(&"ecg_head", head)
		m.set_shader_parameter(&"ecg_gap", maxi(6, int(floor(W * gap))))
		m.set_shader_parameter(&"ecg_color", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter(&"ecg_line", line)
		m.set_shader_parameter(&"ecg_glow", glow)
		m.set_shader_parameter(&"ecg_grid", 1.0 if grid else 0.0)


# ---- the text of the integrity monitor's screen ----
class HpView extends Control:
	var hp_text := "100"
	var sh_text := ""
	var col := Color(0.22, 1.0, 0.48)
	var sh_col := Color("4db8ff")
	var num_alpha := 1.0
	const SMALL := 8
	const BIG := 24
	func _draw() -> void:
		var w := size.x
		var fb := CrtTheme.font(&"raj700")
		var fs := CrtTheme.font(&"sys")
		var y := CrtTheme.baseline(fb, BIG, 4.0, BIG)
		var sp := SMALL * 0.24
		var c := Color(col.r, col.g, col.b, 0.8)
		var x := CrtTheme.draw_text(self, fs, 9.6, y, "INTEGRITY", SMALL, c, sp)
		if sh_text != "":
			CrtTheme.draw_text(self, fs, x + SMALL * 0.7, y, sh_text, SMALL, Color(sh_col.r, sh_col.g, sh_col.b, 0.8), sp)
		var bc := Color(col.r, col.g, col.b, num_alpha)
		CrtTheme.draw_right(self, fb, w - 9.6, y, hp_text, BIG, bc, BIG * 0.04)


# ---- the weapon readout's screen (CSS .hav) ----
class AmmoView extends Control:
	var icon: Texture2D = null
	var icon_col := Color("8dffb4")
	var big := ""
	var unit := ""
	var msg := ""
	var bar := -1.0        # 0..1, -1 = no bar
	var bar_cls := ""      # "", rl, low
	var bar_alpha := 1.0
	const S := 0.85
	func _draw() -> void:
		var px := 14.0 * S
		var x := px
		if icon != null:
			var iw := 62.0 * S
			var ih := 31.0 * S
			# drop-shadow(0 0 4px rgba(100,255,160,.7)): the screen's own glow carries it
			draw_texture_rect(icon, Rect2(x, (size.y - ih) * 0.5, iw, ih), false, icon_col)
			x += iw + 10.0 * S
		var fb := CrtTheme.font(&"sysb")
		var fs := CrtTheme.font(&"sys")
		var bs := roundi(26.0 * S)
		var ss := roundi(10.0 * S)
		var lb := bs * 1.1
		var ls := ss * 1.1
		var total := lb + ls + (3.0 * S + 5.0 * S if bar >= 0.0 else 0.0)
		var top := (size.y - total) * 0.5
		var by := CrtTheme.baseline(fb, bs, top, lb)
		var ex := CrtTheme.draw_text(self, fb, x, by, big, bs, Color("c8ffd8"), 1.0)
		if unit != "":
			CrtTheme.draw_text(self, fb, ex + 3.0, by, unit, roundi(14.0 * S), Color("6dd896"), 1.0)
		var sy := CrtTheme.baseline(fs, ss, top + lb, ls)
		CrtTheme.draw_text(self, fs, x, sy, msg, ss, Color("5fd890"), 2.0)
		if bar >= 0.0:
			var w := size.x - x - px
			var r := Rect2(x, top + lb + ls + 3.0 * S, w, 5.0 * S)
			draw_rect(r, Color(0.0, 30.0 / 255.0, 12.0 / 255.0, 0.7))
			draw_rect(r, Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.45), false, 1.0)
			var fc := Color("7dff9a")
			if bar_cls == "rl":
				fc = Color("ffd23a")
			elif bar_cls == "low":
				fc = Color("ff4a3a")
			fc.a = bar_alpha
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(maxf(0.0, (w - 2.0) * bar), r.size.y - 2.0)), fc)


# ---- the crosshair, hit marker, damage direction ----
class Reticle extends Control:
	var sp := 11.0
	var ads := false
	var pow_on := false
	var c := Color("3fb6ff")
	var g := Color(63.0 / 255.0, 182.0 / 255.0, 1.0, 0.9)
	var offset := Vector2.ZERO
	func _bracket(o: Vector2, side: float, w: float, h: float, col: Color, grow: float) -> void:
		# one side of the brackets: the open side faces the centre. A soft stroke under it stands in for drop-shadow.
		var x0 := o.x + (-w - sp if side < 0.0 else sp)
		var y0 := o.y - h * 0.5
		var lw := 2.0 + grow
		if pow_on:
			# border-radius 50%: the half ellipse, open towards the centre
			var pts := PackedVector2Array()
			var cx := x0 + (w if side < 0.0 else 0.0)
			var cy := o.y
			for i in 15:
				var a := PI * 0.5 + PI * i / 14.0
				pts.append(Vector2(cx + (cos(a) if side < 0.0 else -cos(a)) * w, cy + sin(a) * h * 0.5))
			draw_polyline(pts, col, lw, true)
		else:
			var xo := x0 if side < 0.0 else x0 + w
			var xi := x0 + w if side < 0.0 else x0
			draw_line(Vector2(xo, y0 - grow * 0.5), Vector2(xo, y0 + h + grow * 0.5), col, lw)
			draw_line(Vector2(xi, y0 + 1.0), Vector2(xo, y0 + 1.0), col, lw)
			draw_line(Vector2(xi, y0 + h - 1.0), Vector2(xo, y0 + h - 1.0), col, lw)
		# the nub
		var nx := x0 - 4.0 if side < 0.0 else x0 + w
		draw_rect(Rect2(nx - grow * 0.5, o.y - 1.0 - grow * 0.5, 4.0 + grow, 2.0 + grow), col)
	func _draw() -> void:
		var o := size * 0.5 + offset
		var h := 18.0 if ads else 26.0
		var w := 12.0 if pow_on else (7.0 if ads else 9.0)
		var g1 := Color(g.r, g.g, g.b, g.a * 0.28)
		var k1 := Color(0, 0, 0, 0.45)
		for side: float in [-1.0, 1.0]:
			_bracket(o, side, w, h, g1, 3.0)
			_bracket(o, side, w, h, k1, 1.0)
			_bracket(o, side, w, h, c, 0.0)
		draw_circle(o, 3.0, Color(g.r, g.g, g.b, g.a * 0.3))
		draw_circle(o, 1.5, c)


class HitMark extends Control:
	var kill := false
	var offset := Vector2.ZERO
	func _draw() -> void:
		var o := size * 0.5 + offset
		var col := Color("ff4a3a") if kill else Color.WHITE
		var d := Vector2(16.0, 16.0) * 0.7071
		var e := Vector2(16.0, -16.0) * 0.7071
		for w: Vector2 in [Vector2(7.0, 0.14), Vector2(5.0, 0.24)]:
			draw_line(o - d, o + d, Color(0, 0, 0, w.y), w.x, true)
			draw_line(o - e, o + e, Color(0, 0, 0, w.y), w.x, true)
		draw_line(o - d, o + d, col, 3.0, true)
		draw_line(o - e, o + e, col, 3.0, true)


class HitDirs extends Control:
	var arrows: Array = []    # [deg, t, tint]
	func _draw() -> void:
		var o := size * 0.5
		for a: Array in arrows:
			var k := clampf(1.0 - float(a[1]) / 0.9, 0.0, 1.0)        # hdir .9s ease-out to opacity 0
			var op := 1.0 - (1.0 - pow(1.0 - clampf(float(a[1]) / 0.9, 0.0, 1.0), 2.0))
			op = minf(op, k)
			var ang := deg_to_rad(float(a[0]))
			var dir := Vector2(sin(ang), -cos(ang))
			var side := Vector2(dir.y, -dir.x)
			# the triangle: left -18, top -170, 36 x 44, apex out, gradient from the apex to nothing at the base
			var apex := o + dir * 170.0
			var base := o + dir * 126.0
			var col: Color = a[2]
			col.a = op
			var clear := Color(col.r, col.g, col.b, 0.0)
			draw_polygon(PackedVector2Array([apex, base + side * 18.0, base - side * 18.0]), PackedColorArray([col, clear, clear]))


class ScopeLines extends Control:
	var r := 300.0
	var c := Color("c9f6ff")
	var rng := "RNG ---"
	var zoom := "ZOOM 5X"
	func _draw() -> void:
		var o := size * 0.5
		var u := r / 50.0
		var k := Color(0, 0, 0, 0.5)
		for w: Array in [[0.22, -48.0, -3.0], [0.22, 3.0, 48.0], [0.75, -48.0, -28.0], [0.75, 28.0, 48.0]]:
			var lw: float = maxf(1.0, float(w[0]) * u)
			var a: float = w[1]
			var b: float = w[2]
			draw_line(o + Vector2(a, 0) * u, o + Vector2(b, 0) * u, k, lw + 1.5)
			draw_line(o + Vector2(0, a) * u, o + Vector2(0, b) * u, k, lw + 1.5)
			draw_line(o + Vector2(a, 0) * u, o + Vector2(b, 0) * u, c, lw)
			draw_line(o + Vector2(0, a) * u, o + Vector2(0, b) * u, c, lw)
		for m: float in [10.0, 16.0, 22.0]:
			for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_circle(o + d * m * u, maxf(0.8, 0.24 * u), c)
		draw_circle(o, 0.5 * u, Color("ff3b3b"), true, -1.0, true)
		var f := CrtTheme.font(&"mono")
		var fs := roundi(minf(size.x, size.y) * 0.015)
		var sp := fs * 0.2
		CrtTheme.draw_text(self, f, o.x - r * 0.78, o.y + r * 0.62, rng, fs, c, sp)
		CrtTheme.draw_text(self, f, o.x + r * 0.38, o.y + r * 0.62, zoom, fs, c, sp)


# ---- MANA: implant power pool, a slim glass bar sitting on top of the health box (Hud.mana) ----
class ManaView extends Control:
	var num := "100"
	var pow_name := ""
	var f := 1.0
	var cost_left := 0.0
	var cost_w := 0.0
	var low := false
	var pow_on := false
	var shake := 0.0
	func _colors() -> Array:
		var mc := Color("4fb8ff")
		var mg := Color(79.0 / 255.0, 184.0 / 255.0, 1.0, 0.55)
		if pow_on:
			mc = Color("9dff5a")
			mg = Color(157.0 / 255.0, 1.0, 90.0 / 255.0, 0.55)
		elif low:
			mc = Color("7f8cff")
		return [mc, mg]
	func _draw() -> void:
		var cols := _colors()
		var mc: Color = cols[0]
		var mg: Color = cols[1]
		var fr := CrtTheme.font(&"raj600")
		var fb := CrtTheme.font(&"raj700")
		var w := size.x
		var row_h := 15.0
		var by := CrtTheme.baseline(fb, 15, 0.0, row_h)
		fr.draw_string_outline(get_canvas_item(), Vector2(0, by), "MANA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(mg.r, mg.g, mg.b, 0.2))
		CrtTheme.draw_text(self, fr, 0.0, by, "MANA", 10, mc, 2.4)
		var nw := CrtTheme.text_w(fb, num, 15, 0.6)
		CrtTheme.draw_text(self, fb, w - nw, by, num, 15, Color("e8f6ff"), 0.6)
		if pow_name != "":
			CrtTheme.draw_right(self, fr, w - nw - 8.0, by, pow_name, 10, Color(mc.r, mc.g, mc.b, 0.75), 1.2)
		# the bar
		var bar_y := row_h + 3.0
		var r := Rect2(shake, bar_y, w, 9.0)
		for i in 3:      # box-shadow 0 0 6px var(--mg)
			var g := float(3 - i) * 2.0
			draw_rect(r.grow(g), Color(mg.r, mg.g, mg.b, 0.09))
		draw_rect(r, Color(2.0 / 255.0, 10.0 / 255.0, 22.0 / 255.0, 0.8))
		var fw := w * clampf(f, 0.0, 1.0)
		if fw > 0.0:
			for i in 2:
				draw_rect(Rect2(r.position.x, r.position.y - 1.0 - i, fw, 9.0 + 2.0 + i * 2.0).grow(0.0), Color(mg.r, mg.g, mg.b, 0.14))
			# linear-gradient(180deg, #9fdcff, var(--mc) 45%, #1d6fd6)
			var top := Color("9fdcff") if not pow_on else mc.lightened(0.4)
			var bot := Color("1d6fd6") if not pow_on else mc.darkened(0.5)
			var y0 := r.position.y
			var y1 := y0 + 9.0 * 0.45
			var y2 := y0 + 9.0
			var x0 := r.position.x
			draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + fw, y0), Vector2(x0 + fw, y1), Vector2(x0, y1)]), PackedColorArray([top, top, mc, mc]))
			draw_polygon(PackedVector2Array([Vector2(x0, y1), Vector2(x0 + fw, y1), Vector2(x0 + fw, y2), Vector2(x0, y2)]), PackedColorArray([mc, mc, bot, bot]))
		if cost_w > 0.0:
			draw_rect(Rect2(r.position.x + w * cost_left, r.position.y, w * cost_w, 9.0), Color(1.0, 80.0 / 255.0, 70.0 / 255.0, 0.55) if low else Color(1, 1, 1, 0.28))
		for t: float in [0.25, 0.5, 0.75]:
			draw_rect(Rect2(r.position.x + w * t, r.position.y, 1.0, 9.0), Color(0, 0, 0, 0.55))
		draw_rect(r, Color("ff5a4a") if shake != 0.0 else Color(120.0 / 255.0, 200.0 / 255.0, 1.0, 0.35), false, 1.0)


# ---- the key cap in a prompt (JS vdKey): the keyboard's chamfered key, or the pad's round coloured button ----
class VdKey extends Control:
	var k := "X"
	var pad := false
	var fs := 14
	func _init(p_k: String = "X", p_pad: bool = false, p_fs: int = 14) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_key(p_k, p_pad, p_fs)
	func set_key(p_k: String, p_pad: bool, p_fs: int = 14) -> void:
		k = p_k
		pad = p_pad
		fs = p_fs
		var f := CrtTheme.font(&"raj600")
		if pad:
			custom_minimum_size = Vector2(maxf(fs * 1.8, CrtTheme.text_w(f, k, fs) + 10.0), fs * 1.8) if not (k in ["A", "B", "X", "Y"]) else Vector2(fs * 1.8, fs * 1.8)
		else:
			custom_minimum_size = Vector2(maxf(fs * 1.9, CrtTheme.text_w(f, k, fs) + 12.0), fs * 1.75)
		queue_redraw()
	func _draw() -> void:
		var f := CrtTheme.font(&"raj600")
		var w := size.x
		var h := size.y
		var y := CrtTheme.baseline(f, fs, 0.0, h)
		var tw := CrtTheme.text_w(f, k, fs)
		if pad:
			var col := Color("5b6672")
			var ink := Color.WHITE
			match k:
				"A":
					col = Color("2e9e4a")
				"B":
					col = Color("c8392d")
				"X":
					col = Color("2d6fd0")
				"Y":
					col = Color("cfa21c")
					ink = Color("1a1400")
			if k in ["A", "B", "X", "Y"]:
				draw_circle(Vector2(w, h) * 0.5, h * 0.5, col, true, -1.0, true)
			else:
				draw_style_box(CrtTheme.panel(col, 4), Rect2(Vector2.ZERO, Vector2(w, h)))
			draw_string(f, Vector2((w - tw) * 0.5, y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		else:
			# clip-path: polygon(3px 0, 100% 0, 100% calc(100% - 3px), calc(100% - 3px) 100%, 0 100%, 0 3px)
			var c := 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(c, 0), Vector2(w, 0), Vector2(w, h - c), Vector2(w - c, h), Vector2(0, h), Vector2(0, c)]), Color("dfeaf2"))
			draw_string(f, Vector2((w - tw) * 0.5, y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("081018"))


# ---- the near-interact hint (#shophint) ----
class HintBox extends HBoxContainer:
	var cls := ""
	var key_box: VdKey
	var lab: Label
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override(&"separation", 10)
		alignment = BoxContainer.ALIGNMENT_CENTER
		key_box = VdKey.new("X", false, 14)
		key_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(key_box)
		lab = CrtTheme.label("", &"raj600", 15, Color("e2edf5"), 2)
		add_child(lab)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pl := 8.0
		var pr := 18.0
		var r := Rect2(-pl, -7.0, w + pl + pr, h + 14.0)
		if cls.begins_with("drop"):
			pr = 16.0
			r = Rect2(-pl if not cls.contains("dim") else -16.0, -7.0, w + (pl if not cls.contains("dim") else 16.0) + pr, h + 14.0)
			draw_style_box(CrtTheme.panel(Color(8.0 / 255.0, 10.0 / 255.0, 12.0 / 255.0, 0.55), 12, Color(1, 1, 1, 0.12)), r)
			return
		var hc := Color(54.0 / 255.0, 224.0 / 255.0, 1.0, 0.6)
		match cls:
			"armor":
				hc = Color(1.0, 182.0 / 255.0, 39.0 / 255.0, 0.7)
			"closed":
				hc = Color(1.0, 120.0 / 255.0, 100.0 / 255.0, 0.5)
				r = Rect2(-18.0, -7.0, w + 36.0, h + 14.0)
			"talk":
				hc = Color(123.0 / 255.0, 227.0 / 255.0, 74.0 / 255.0, 0.7)
			"plasmid":
				hc = Color(1.0, 154.0 / 255.0, 46.0 / 255.0, 0.75)
		# clip-path: polygon(10px 0, 100% 0, 100% calc(100% - 10px), calc(100% - 10px) 100%, 0 100%, 0 10px), inset 1 px edge
		var c := 10.0
		var a := r.position
		var e := r.end
		var pts := PackedVector2Array([Vector2(a.x + c, a.y), Vector2(e.x, a.y), Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(a.x, e.y), Vector2(a.x, a.y + c), Vector2(a.x + c, a.y)])
		draw_colored_polygon(pts.slice(0, 6), Color(6.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 0.84))
		draw_polyline(pts, hc, 1.0, true)


# ---- the corner save icon (#saveIcon): a short green flash after a milestone save ----
class SaveIcon extends Control:
	var ang := 0.0
	func _draw() -> void:
		var c := Color("5fe36a")
		var o := Vector2(6.0, size.y * 0.5)
		draw_arc(o, 5.0, ang + 0.0, ang + TAU * 0.75, 18, c, 2.0, true)
		var f := CrtTheme.font(&"raj600")
		CrtTheme.draw_text(self, f, 20.0, CrtTheme.baseline(f, 12, 0.0, size.y), "SAVED", 12, c, 3.6)


# ---- state ----
var _group: Control              # everything the dialogue, a cutscene and the menu put away (CSS body.dlg, body.cine, #start)
var ammo_el: Control
var ammo_scr: CrtScreen
var ammo_view: AmmoView
var hp_el: Control
var hp_scr: CrtScreen
var hp_view: HpView
var hp_mat: ShaderMaterial
var mana_view: ManaView
var xh: Reticle
var hm: HitMark
var hdir_view: HitDirs
var scope_el: Control
var scope_fx: ColorRect
var scope_lines: ScopeLines
var hurt_el: ColorRect
var hurt_mat: ShaderMaterial
var mind_el: ColorRect
var mind_mat: ShaderMaterial
var dead_el: Control
var dead_mat: ShaderMaterial
var dead_text: GlowText
var dead_ecg_rect: ColorRect
var dead_ecg_mat: ShaderMaterial
var vc_text: GlowText
var crit_mul: ColorRect
var crit_add: ColorRect
var toast_box: PanelContainer
var toast_lab: Label
var lock_box: PanelContainer
var pad_box: PanelContainer
var pad_dot: ColorRect
var pad_lab: Label
var cash_box: PanelContainer
var cash_lab: Label
var cash_gain: Label
var hint_box: HintBox
var save_el: SaveIcon
var _save_t := 0.0
var _save_op := 0.0
var subs_box: VBoxContainer

var shot_t := 0.0
var show_t := 0.0
var hm_t := 0.0
var hm_pos: Variant = null
var hurt_t := 0.0
var stress := 0.0
var hr := 72.0
var vfw := 0.0
var crit_t := 0.0
var _crit := false
var _hp := -1
var _rhy := 0
var _col := Color(0, 0, 0, 0)
var _hue := -1
var _low := false
var _hurt_sh := ""
var _sh_tint := ""
var ecg: Ecg
var ecg_dead: Ecg
var _sig := ""
var _scope_sig := ""
var _sh_prev := 0.0
var _sh_col_name := ""
var _sh_sig := ""
var _sh_on := 0.0
var _sh_w := 0.0
var _shr_t := 0.0
var _shbrk_t := -1.0
var _shup_t := -1.0
var _mn_m := -1
var _mn_pw: Variant = null
var _mn_aim := false
var _mn_c := -1
var _deny_t := -1.0
var _mind_t := -1.0
var _mind_dur := 1.0
var _dead_on := false
var _dead_op := 0.0
var _toast_t := 0.0
var _toast_op := 0.0
var _lock_op := 0.0
var _ammo_op := 0.0
var _hp_op := 1.0
var _mana_op := 0.0
var hide_xhair := false      # a level's own reticle is up (JS body.ffall #xhair)
var _xh_op := 0.0
var _xh_sp := 11.0
var _xh_sig := ""
var _hm_op := -1.0
var _last_status := ""
var _pad_ok := false
var _gain_t := -1.0
var _cash_gain_t := 0.0
var _cash_gain_sum := 0.0
var _cash := -1
var _hint_h := ""
var _hint_cn := ""
var _low_anim := false
var _time := 0.0
var _pip_hidden := false
var _suppressed := false


func _init() -> void:
	name = "Hud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	CrtTheme.full(self)


func _ready() -> void:
	_group = CrtTheme.full(Control.new())
	_group.name = "Group"
	# order and z_index follow the CSS z-index of each element
	_build_hurt()
	add_child(_group)
	_build_pills()
	_build_ammo()
	_build_reticle()
	_build_scope()
	_build_hp()
	_build_dead()
	_build_cash_hint()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	set_process(false)


# ---- building ----

func _fx_rect(mode: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	CrtTheme.full(r)
	var m := CrtTheme.mat("res://ui/hud_fx.gdshader")
	m.set_shader_parameter(&"mode", mode)
	r.material = m
	return r


func _build_hurt() -> void:
	hurt_el = _fx_rect(0)
	hurt_mat = hurt_el.material
	hurt_el.z_index = 7
	hurt_el.visible = false
	mind_el = _fx_rect(0)
	mind_mat = mind_el.material
	# #mind: radial-gradient(ellipse at center, rgba(120,40,200,.08) 30%, rgba(150,60,235,.6) 100%)
	mind_mat.set_shader_parameter(&"stop", 0.30)
	mind_mat.set_shader_parameter(&"inner", Color(120.0 / 255.0, 40.0 / 255.0, 200.0 / 255.0, 0.08))
	mind_mat.set_shader_parameter(&"outer", Color(150.0 / 255.0, 60.0 / 255.0, 235.0 / 255.0, 0.6))
	mind_el.z_index = 7
	mind_el.visible = false
	_group.add_child(hurt_el)
	_group.add_child(mind_el)


func _pill(bg: Color, radius: int, pad_x: int, pad_y: int, border: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override(&"panel", CrtTheme.panel(bg, radius, border, pad_x, pad_y))
	return p


func _build_pills() -> void:
	# #pad: the controller's state, top left
	pad_box = _pill(Color(10.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.55), 20, 12, 6)
	pad_box.position = Vector2(12, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_dot = ColorRect.new()
	pad_dot.custom_minimum_size = Vector2(10, 10)
	pad_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_dot.color = Color.TRANSPARENT
	pad_dot.draw.connect(func() -> void: pad_dot.draw_circle(Vector2(5, 5), 5.0, Color("4fe07a") if _pad_ok else Color("e0524a"), true, -1.0, true))
	row.add_child(pad_dot)
	pad_lab = CrtTheme.label("", &"sys", 13, Color.WHITE)
	row.add_child(pad_lab)
	pad_box.add_child(row)
	pad_box.z_index = 5
	_group.add_child(pad_box)
	# #lockhint
	lock_box = _pill(Color(10.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.6), 8, 14, 6)
	lock_box.add_child(CrtTheme.label("Click the game to capture the mouse for camera look", &"sys", 13, Color.WHITE))
	lock_box.modulate.a = 0.0
	lock_box.z_index = 5
	_group.add_child(lock_box)
	# #toast
	toast_box = _pill(Color(10.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.7), 8, 16, 8)
	toast_lab = CrtTheme.label("", &"sys", 14, Color.WHITE)
	toast_box.add_child(toast_lab)
	toast_box.modulate.a = 0.0
	toast_box.z_index = 5
	_group.add_child(toast_box)


func _build_ammo() -> void:
	# #hudAmmo: the readout inside assets/ui/weaponwrap-1000.png (screen = 59% x 44% of the frame), green CRT, no glitch. --s scales the whole thing
	var s := 0.85
	var fw := 400.0 * s
	var fh := fw * 339.0 / 1000.0
	ammo_el = Control.new()
	ammo_el.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_el.position = Vector2(8, 48)
	ammo_el.size = Vector2(fw, fh)
	ammo_el.z_index = 6
	ammo_el.modulate.a = 0.0
	_group.add_child(ammo_el)
	var r := Rect2(fw * 0.262, fh * 0.236, fw * 0.591, fh * 0.4425)
	ammo_scr = CrtScreen.new(r.size)
	ammo_scr.position = r.position
	ammo_scr.size = r.size
	ammo_el.add_child(ammo_scr)
	_screen_look(ammo_scr, Color(80.0 / 255.0, 1.0, 140.0 / 255.0, 0.45))
	ammo_view = AmmoView.new()
	ammo_view.size = r.size
	ammo_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_scr.content.add_child(ammo_view)
	ammo_el.add_child(_art("res://assets/ui/cut/weaponwrap.png", Vector2(fw, fh)))


func _art(path: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return t


## The CSS of .hpcrt / .hacrt on a screen: scanlines, a soft vignette, inset light in the screen's colour; radial-gradient(ellipse 90% 90%, rgba(6,24,14,.96), rgba(1,8,4,.99)) behind.
func _screen_look(s: CrtScreen, inset: Color) -> void:
	s.param(&"bg_center", Color(6.0 / 255.0, 24.0 / 255.0, 14.0 / 255.0, 0.98))
	s.param(&"bg_edge", Color(1.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0, 0.98))
	s.param(&"bg_size", Vector2(0.9, 0.9))
	s.param(&"vig_inner", Color(120.0 / 255.0, 1.0, 170.0 / 255.0, 0.05))
	s.param(&"vig_outer", Color(0, 0, 0, 0.55))
	s.param(&"vig_size", Vector2(0.76, 0.88))
	s.param(&"roll_alpha", 0.0)
	s.param(&"flick_period", 0.0)
	s.param(&"inset_a", inset)
	s.param(&"inset_a_blur", 12.0)
	s.param(&"inset_b", Color(0, 0, 0, 0.9))
	s.param(&"inset_b_blur", 3.0)
	s.param(&"glow_amount", 0.6)
	s.param(&"glow_radius", 6.0)
	s.param(&"glow_keep_color", 1.0)


func _build_reticle() -> void:
	xh = Reticle.new()
	CrtTheme.full(xh)
	xh.z_index = 6
	xh.modulate.a = 0.0
	_group.add_child(xh)
	hm = HitMark.new()
	CrtTheme.full(hm)
	hm.z_index = 6
	hm.visible = false
	_group.add_child(hm)
	hdir_view = HitDirs.new()
	CrtTheme.full(hdir_view)
	hdir_view.z_index = 7
	_group.add_child(hdir_view)
	subs_box = VBoxContainer.new()
	subs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subs_box.add_theme_constant_override(&"separation", 4)
	subs_box.alignment = BoxContainer.ALIGNMENT_END
	subs_box.z_index = 7
	_group.add_child(subs_box)


func _build_scope() -> void:
	# #scope: not in the set the dialogue hides, so it sits outside the group
	scope_el = CrtTheme.full(Control.new())
	scope_el.z_index = 5
	scope_el.visible = false
	scope_fx = _fx_rect(2)
	scope_el.add_child(scope_fx)
	scope_lines = ScopeLines.new()
	CrtTheme.full(scope_lines)
	scope_el.add_child(scope_lines)
	add_child(scope_el)


func _build_hp() -> void:
	# #hp: the monitor inside assets/ui/ekgbox-1100.png, screen = 63.5% of the frame's width. CRT filter (scanlines, vignette, a soft glow in the health colour), no glitch
	var s := 0.8
	var fw := 441.0 * s
	var fh := fw * 470.0 / 1100.0
	hp_el = Control.new()
	hp_el.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_el.size = Vector2(fw, fh)
	hp_el.z_index = 6
	_group.add_child(hp_el)
	# the critical flash around the box's edge (hpcrit)
	crit_mul = _crit_rect("res://ui/box_glow_mul.gdshader", Vector2(fw, fh))
	crit_add = _crit_rect("res://ui/box_glow.gdshader", Vector2(fw, fh))
	hp_el.add_child(crit_mul)
	hp_el.add_child(crit_add)
	var r := Rect2(fw * 0.174, fh * 0.295, fw * 0.635, fh * 0.494)
	hp_scr = CrtScreen.new(r.size, "res://ui/hud_ekg.gdshader")
	hp_scr.position = r.position
	hp_scr.size = r.size
	hp_el.add_child(hp_scr)
	_screen_look(hp_scr, Color(0.22, 1.0, 0.48, 0.5))
	hp_scr.param(&"inset_a_blur", 14.0)
	hp_mat = hp_scr.material
	var pad_t := 5.0 * s
	var row := 30.0 * s
	var pad_b := 4.0 * s
	var pad_x := 12.0 * s
	var cv := Rect2(pad_x, pad_t + row + 2.0, r.size.x - pad_x * 2.0, r.size.y - pad_t - row - 2.0 - pad_b)
	hp_mat.set_shader_parameter(&"canvas_rect", Vector4(cv.position.x, cv.position.y, cv.size.x, cv.size.y))
	hp_view = HpView.new()
	hp_view.size = r.size
	hp_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_scr.content.add_child(hp_view)
	hp_el.add_child(_art("res://assets/ui/cut/ekgbox.png", Vector2(fw, fh)))
	ecg = Ecg.new(95.0, 2.0, 7.0)
	ecg.size_to(cv.size.x, cv.size.y)
	stress = 0.0
	hr = 72.0
	vfw = 0.0
	# #mana sits on top of the box
	mana_view = ManaView.new()
	mana_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mana_view.size = Vector2(fw * 0.635, 30.0)
	mana_view.z_index = 6
	mana_view.modulate.a = 0.0
	_group.add_child(mana_view)


func _crit_rect(shader: String, box: Vector2) -> ColorRect:
	var p := Vector2(40, 40)
	var c := ColorRect.new()
	c.color = Color.WHITE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = -p
	c.size = box + p * 2.0
	var m := CrtTheme.mat(shader)
	m.set_shader_parameter(&"box_css", box)
	m.set_shader_parameter(&"pad", p)
	m.set_shader_parameter(&"radius", Vector2(0.001, 0.001))
	# 0 0 0 1px #ff2a2a, 0 0 16px 2px rgba(255,30,30,.75), inset 0 0 14px rgba(255,30,30,.35)
	m.set_shader_parameter(&"outer", Color(1.0, 30.0 / 255.0, 30.0 / 255.0, 0.75))
	m.set_shader_parameter(&"outer_blur", 16.0)
	m.set_shader_parameter(&"outer_spread", 2.0)
	m.set_shader_parameter(&"line", Color(1.0, 42.0 / 255.0, 42.0 / 255.0, 1.0))
	m.set_shader_parameter(&"in_a", Color(1.0, 30.0 / 255.0, 30.0 / 255.0, 0.35))
	m.set_shader_parameter(&"in_a_blur", 14.0)
	m.set_shader_parameter(&"in_b", Color(0, 0, 0, 0))
	m.set_shader_parameter(&"opacity", 0.0)
	c.material = m
	c.visible = false
	return c


func _build_dead() -> void:
	# #deadscr: the black closes in around the text; its own fibrillating trace
	dead_el = CrtTheme.full(Control.new())
	dead_el.z_index = 9
	dead_el.visible = false
	var bg := _fx_rect(1)
	dead_mat = bg.material
	dead_el.add_child(bg)
	dead_ecg_rect = ColorRect.new()
	dead_ecg_rect.color = Color.WHITE
	dead_ecg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dead_ecg_mat = CrtTheme.mat("res://ui/hud_dead_ecg.gdshader")
	dead_ecg_mat.set_shader_parameter(&"ecg_reach", 26)
	dead_ecg_rect.material = dead_ecg_mat
	dead_el.add_child(dead_ecg_rect)
	dead_text = GlowText.new()
	dead_text.margin = 160.0
	CrtTheme.full(dead_text)
	dead_el.add_child(dead_text)
	add_child(dead_el)
	ecg_dead = Ecg.new(320.0, 3.0, 22.0, false, 0.05)
	# #vitalcrit
	vc_text = GlowText.new()
	vc_text.margin = 90.0
	vc_text.z_index = 9
	vc_text.visible = false
	_group.add_child(vc_text)


func _build_cash_hint() -> void:
	# #cash
	cash_box = _pill(Color(8.0 / 255.0, 10.0 / 255.0, 12.0 / 255.0, 0.5), 14, 14, 6, Color(1, 1, 1, 0.1))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	var sm := CrtTheme.label("CASH", &"raj700", 11, Color("8f9cab"), 2)
	sm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sm)
	cash_lab = CrtTheme.label("$0", &"raj700", 22, Color("e6eef6"), 2)
	row.add_child(cash_lab)
	cash_box.add_child(row)
	cash_box.z_index = 12
	cash_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_group.add_child(cash_box)
	cash_gain = CrtTheme.label("", &"raj700", 17, Color("8fe39a"), 1)
	cash_gain.z_index = 12
	cash_gain.modulate.a = 0.0
	cash_gain.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_group.add_child(cash_gain)
	save_el = SaveIcon.new()
	save_el.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_el.size = Vector2(70, 14)
	save_el.anchor_left = 1.0
	save_el.anchor_right = 1.0
	save_el.offset_left = -92.0
	save_el.offset_right = -22.0
	save_el.offset_top = 20.0
	save_el.offset_bottom = 34.0
	save_el.z_index = 60
	save_el.visible = false
	add_child(save_el)
	# #shophint
	hint_box = HintBox.new()
	hint_box.z_index = 12
	hint_box.visible = false
	_group.add_child(hint_box)


func _relayout() -> void:
	var vp := get_viewport_rect().size
	hp_el.position = Vector2(6.0, vp.y - 8.0 - hp_el.size.y)
	var fw := hp_el.size.x
	mana_view.position = Vector2(6.0 + fw * 0.174, vp.y - (8.0 + hp_el.size.y + 14.0) - mana_view.size.y + 3.0)
	cash_box.anchor_left = 1.0
	cash_box.anchor_right = 1.0
	cash_box.offset_right = -14.0
	cash_box.offset_left = -14.0
	cash_box.offset_top = 26.0
	cash_gain.anchor_left = 1.0
	cash_gain.anchor_right = 1.0
	cash_gain.offset_right = -14.0 - 14.0
	cash_gain.offset_left = -14.0 - 14.0
	_center_bottom(toast_box, 34.0)
	_center_bottom(lock_box, 80.0)
	_center_bottom(subs_box, 92.0)
	_hint_place()
	var r := minf(vp.x, vp.y) * 0.47
	var f := CrtTheme.px(self)
	var sm := scope_fx.material as ShaderMaterial
	sm.set_shader_parameter(&"rect_px", vp * f)
	sm.set_shader_parameter(&"r_px", r * f)
	sm.set_shader_parameter(&"lens_blur", minf(vp.x, vp.y) * 0.09 * f)
	sm.set_shader_parameter(&"lens_spread", minf(vp.x, vp.y) * 0.01 * f)
	scope_lines.r = r
	scope_lines.queue_redraw()
	# text in vw / vh: clamp(56px, 13vw, 170px), clamp(24px, 3.4vw, 44px)
	var ds := roundi(clampf(vp.x * 0.13, 56.0, 170.0))
	dead_text.set_text_style("YOU DIED", &"raj700", ds, ds * 0.16, Color("d4101c"))
	var dm := dead_text.glow_mat
	dm.set_shader_parameter(&"lod", Vector3(GlowText.lod_of(10.0), GlowText.lod_of(30.0), GlowText.lod_of(70.0)))
	dm.set_shader_parameter(&"c0", Color(1.0, 26.0 / 255.0, 26.0 / 255.0, 1.0))
	dm.set_shader_parameter(&"c1", Color(1.0, 30.0 / 255.0, 30.0 / 255.0, 0.9))
	dm.set_shader_parameter(&"c2", Color(1.0, 0.0, 0.0, 0.65))
	var vs := roundi(clampf(vp.x * 0.034, 24.0, 44.0))
	vc_text.set_text_style("VITAL SIGNS CRITICAL", &"raj700", vs, vs * 0.24, Color("ff2a2a"))
	var vm := vc_text.glow_mat
	vm.set_shader_parameter(&"lod", Vector3(GlowText.lod_of(6.0), GlowText.lod_of(18.0), GlowText.lod_of(42.0)))
	vm.set_shader_parameter(&"c0", Color(1.0, 26.0 / 255.0, 26.0 / 255.0, 1.0))
	vm.set_shader_parameter(&"c1", Color(1.0, 30.0 / 255.0, 30.0 / 255.0, 0.95))
	vm.set_shader_parameter(&"c2", Color(1.0, 0.0, 0.0, 0.7))
	vc_text.size = Vector2(vp.x, vs * 1.4)
	vc_text.position = Vector2(0.0, vp.y * 0.36 - vs * 0.7)
	# #deadEcg: top 76%, height 18vh, centred on that line
	var dh := vp.y * 0.18
	dead_ecg_rect.position = Vector2(0.0, vp.y * 0.76 - dh * 0.5)
	dead_ecg_rect.size = Vector2(vp.x, dh)
	dead_ecg_mat.set_shader_parameter(&"canvas_css", Vector2(vp.x, dh))
	ecg_dead.size_to(vp.x, dh)


## Fit a bottom-centred box to its text now (CSS: width from the content, left 50%, translateX(-50%)). A Godot container grows with its text but never shrinks back, which left a short line off centre in a wide box.
static func fit_center_bottom(c: Control, bottom: float) -> void:
	var m := c.get_combined_minimum_size()
	c.offset_left = -m.x * 0.5
	c.offset_right = m.x * 0.5
	c.offset_top = -bottom - m.y
	c.offset_bottom = -bottom


func _center_bottom(c: Control, bottom: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_bottom = -bottom
	c.offset_top = -bottom
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _hint_place() -> void:
	# left: 50%; bottom: 17%; translateX(-50%)
	var vp := get_viewport_rect().size
	var b := vp.y * 0.17
	hint_box.anchor_left = 0.5
	hint_box.anchor_right = 0.5
	hint_box.anchor_top = 1.0
	hint_box.anchor_bottom = 1.0
	hint_box.offset_bottom = -b - 7.0
	hint_box.offset_top = -b - 7.0
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN


# ---- JS Hud ----

func toast(m: String, t: float = 1.4) -> void:
	toast_lab.text = m
	_toast_t = t
	fit_center_bottom(toast_box, 34.0)


func on_shot() -> void:
	shot_t = 0.12
	show_t = 0.7


func hit_marker(kill: bool, e: Variant = null) -> void:
	hm_t = 0.18
	hm.kill = kill
	hm_pos = null
	if e is Dictionary and e.has("x") and e.has("y") and e.has("z"):
		hm_pos = Vector3(e.x, e.y, e.z)
	hm.queue_redraw()


static func _hsl(h: float, s: float, l: float) -> Color:
	var a := s * minf(l, 1.0 - l)
	var f := func(n: float) -> float:
		var k := fmod(n + h / 30.0, 12.0)
		return l - a * maxf(-1.0, minf(minf(k - 3.0, 9.0 - k), 1.0))
	return Color(f.call(0.0), f.call(8.0), f.call(4.0))


## Player integrity EKG + red vignette + death screen; call every frame.
func health(dt: float, P: Player, show: bool) -> void:
	hurt_t = maxf(0.0, hurt_t - dt)
	stress = maxf(0.0, stress - dt / 9.0)                    # fear from recent hits fades over ~9 s
	var frac := maxf(0.0, minf(1.0, P.hp / P.max_hp))
	var hp := ceili(P.hp)
	var dead_now := P.dead
	var redraw := false
	if hp != _hp:
		_hp = hp
		hp_view.hp_text = str(hp)
		redraw = true
	_low = frac < 0.3 and not dead_now
	_hp_op = move_toward(_hp_op, 1.0 if show else 0.0, dt / 0.15)
	hp_el.modulate.a = _hp_op
	hp_el.visible = _hp_op > 0.001 and not _pip_hidden
	hp_el.z_index = 10 if dead_now else 6      # #hp.dead: above the death screen
	shield_bar(dt, P, dead_now)
	# critical health (25% or below): the box flashes red around its edges, and the alarm (three quick buzzes) sounds once on crossing the line
	var crit := not dead_now and frac <= 0.25
	var ct := 0.0
	if crit:
		ct = 0.5 - 0.5 * cos(_time / 0.55 * TAU)
	crit_add.visible = crit
	crit_mul.visible = crit
	if crit:
		(crit_add.material as ShaderMaterial).set_shader_parameter(&"opacity", ct)
		(crit_mul.material as ShaderMaterial).set_shader_parameter(&"opacity", ct)
	if crit and not _crit:      # crossing 25%: the alarm and the VITAL SIGNS CRITICAL banner, once, for 5 s
		CrtTheme.sfx("lowHealth")
		crit_t = 5.0
	_crit = crit
	crit_t = maxf(0.0, crit_t - dt) if (crit and show) else 0.0
	vc_text.visible = crit_t > 0.0 and not _pip_hidden
	if vc_text.visible:
		# vcflash .4s: opacity 1 -> .18, the glow breathing with it
		var u := 0.5 + 0.5 * cos(_time / 0.4 * TAU)
		vc_text.modulate.a = lerpf(0.18, 1.0, u)
		vc_text.glow_mat.set_shader_parameter(&"gain", lerpf(0.5, 1.4, u))
	# rhythm: steady sinus ~68 bpm while healthy (down to 80%), then sinus tachycardia climbing to ~165 by 30%; SVT (~195 bpm) below 30%, VTACH (~215 bpm) below 20%; fibrillation when dead
	# (leaving a rhythm needs 4% more health than entering it, so regenerating / flickering health can't flip the rhythm back and forth every beat)
	var drop := maxf(0.0, minf(1.0, (0.8 - frac) / 0.5))
	var prev := _rhy
	var rhy := 0
	if not dead_now:
		rhy = 2 if frac < (0.24 if prev == 2 else 0.2) else (1 if frac < (0.34 if prev >= 1 else 0.3) else 0)
	var hr_t := 250.0 if rhy == 2 else (290.0 if rhy == 1 else minf(185.0, 88.0 + 85.0 * pow(drop, 0.8) + stress * 40.0 * (1.0 - drop) + hurt_t * 25.0))
	if rhy != _rhy:             # entering / leaving SVT or VTACH: the rate jumps straight to the new rhythm's
		_rhy = rhy
		if rhy != 0 or hr > 200.0:
			hr = hr_t
	hr += (hr_t - hr) * (1.0 - exp(-(8.0 if hr_t > hr else 4.0) * dt))
	vfw += ((1.0 if dead_now else 0.0) - vfw) * (1.0 - exp(-(9.0 if dead_now else 30.0) * dt))
	# colour: green -> yellow -> red with damage (hue 120 -> 60 -> 0)
	var c := maxf(0.0, minf(1.0, frac - stress * 0.25))
	var hue := 0 if dead_now else roundi(120.0 * maxf(0.0, minf(1.0, (c - 0.15) / 0.7)))
	if hue != _hue:
		_hue = hue
		_col = _hsl(float(hue), 1.0, 0.55)
		hp_view.col = _col
		hp_scr.param(&"inset_a", Color(_col.r, _col.g, _col.b, 0.5))
		redraw = true
	if show:
		ecg.step(dt, hr, vfw, rhy)
		ecg.draw(hp_mat, _col)
	if dead_now:
		ecg_dead.step(dt, 150.0, 1.0)
		ecg_dead.draw(dead_ecg_mat, _hsl(0.0, 1.0, 0.52))
	# the number blinks while low (hplow .5s alternate)
	var na := 1.0
	if _low:
		na = lerpf(1.0, 0.45, 0.5 - 0.5 * cos(_time / 1.0 * TAU))
	if na != hp_view.num_alpha:
		hp_view.num_alpha = na
		redraw = true
	if redraw:
		hp_view.queue_redraw()
		hp_scr.refresh()
	dead_mat.set_shader_parameter(&"k", (minf(1.0, P.dead_t / 2.4) if dead_now else 0.0))        # the black closes in around the text
	# the death screen's own fade: opacity .4s on, .35s off
	_dead_op = move_toward(_dead_op, 1.0 if _dead_on else 0.0, dt / (0.4 if _dead_on else 0.35))
	dead_el.visible = _dead_op > 0.001
	if dead_el.visible:
		dead_el.modulate.a = _dead_op
		# ydGlow 2.6s: the glow swells
		dead_text.glow_mat.set_shader_parameter(&"gain", lerpf(1.0, 1.5, 0.5 - 0.5 * cos(_time / 2.6 * TAU)))
	var low := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 160.0) if (frac < 0.3 and not dead_now) else 0.0
	var op := minf(1.0, maxf(hurt_t * 1.4, low))
	hurt_el.visible = op > 0.001
	if hurt_el.visible:
		hurt_mat.set_shader_parameter(&"opacity", op)
	var sh_tint := _hurt_sh if hurt_t > 0.0 else ""       # a hit the shield soaked tints the vignette in the shield's colour instead of red
	if sh_tint != _sh_tint:
		_sh_tint = sh_tint
		var outer := Color(190.0 / 255.0, 15.0 / 255.0, 10.0 / 255.0, 0.6)
		if sh_tint == "blue":
			outer = Color(60.0 / 255.0, 150.0 / 255.0, 1.0, 0.5)
		elif sh_tint == "orange":
			outer = Color(1.0, 130.0 / 255.0, 20.0 / 255.0, 0.5)
		hurt_mat.set_shader_parameter(&"outer", outer)
	# #mind: fades out over the slow's duration
	if _mind_t >= 0.0:
		_mind_t += dt
		var mo := 1.0 - _mind_t / _mind_dur
		if mo <= 0.0:
			_mind_t = -1.0
			mind_el.visible = false
		else:
			mind_el.visible = true
			mind_mat.set_shader_parameter(&"opacity", 1.0 - (1.0 - mo) * (1.0 - mo))      # ease-out
	# the arrows around the screen centre
	if not hdir_view.arrows.is_empty():
		for a: Array in hdir_view.arrows:
			a[1] = float(a[1]) + dt
		hdir_view.arrows = hdir_view.arrows.filter(func(a: Array) -> bool: return float(a[1]) < 0.95)
		hdir_view.queue_redraw()
	if show and _low:
		hp_view.queue_redraw()
		hp_scr.refresh()


## The energy shield laid over the integrity monitor: a coloured fill that drains left-to-right as the shield takes damage (health untouched underneath) and refills while it recharges.
## Nothing is shown while the shield is empty, so the monitor then looks exactly as it does without a shield.
func shield_bar(dt: float, P: Player, dead_now: bool) -> void:
	var mx := P.shield_max if P.shield_max > 0.0 else 0.0
	var sh := maxf(0.0, P.shield) if mx > 0.0 else 0.0
	var prev := _sh_prev
	_sh_prev = sh
	if mx > 0.0 and prev > 0.0 and sh <= 0.0 and not dead_now:     # shield failure: the overlay flickers out for a second
		_shbrk_t = 0.0
	var col := P.shield_col if mx > 0.0 else ""
	if col != _sh_col_name:
		_sh_col_name = col
		var c := Color("ff8a1e") if col == "orange" else Color("4db8ff")
		hp_view.sh_col = c
		hp_mat.set_shader_parameter(&"sh_col", Vector3(c.r, c.g, c.b))
		hp_view.queue_redraw()
		hp_scr.refresh()
	var shd := sh > 0.05 and not dead_now
	var brk := _shbrk_t >= 0.0
	_sh_on = move_toward(_sh_on, 1.0 if (shd or brk) else 0.0, dt / 0.15)
	hp_mat.set_shader_parameter(&"sh_on", _sh_on)
	var pc := sh / mx if mx > 0.0 else 0.0
	_sh_w = move_toward(_sh_w, pc, dt / 0.12 * maxf(absf(pc - _sh_w), 0.02))
	if _sh_on > 0.0:
		hp_mat.set_shader_parameter(&"sh_w", _sh_w)
	var rech := P.shield_rech and sh > 0.0 and sh < mx
	var bright := 1.0
	if rech:      # shrech .7s alternate: brightness up to 1.7
		bright = lerpf(1.0, 1.7, 0.5 - 0.5 * cos(_time / 1.4 * TAU))
	hp_mat.set_shader_parameter(&"sh_bright", bright)
	var flash := 0.0
	if _shup_t >= 0.0:      # shup .6s: 0%{.45} -> 100%{0}, ease-out
		_shup_t += dt
		var u := minf(1.0, _shup_t / 0.6)
		flash = 0.45 * (1.0 - u) * (1.0 - u)
		if u >= 1.0:
			_shup_t = -1.0
	if _shbrk_t >= 0.0:     # shbreak 1s steps(12, end)
		_shbrk_t += dt
		var u := minf(1.0, _shbrk_t)
		var su := floorf(u * 12.0) / 12.0
		var keys := [[0.0, 0.9], [0.25, 0.15], [0.40, 0.7], [0.60, 0.1], [0.75, 0.4], [1.0, 0.0]]
		for i in keys.size() - 1:
			var a: Array = keys[i]
			var b: Array = keys[i + 1]
			if su >= float(a[0]) and su <= float(b[0]):
				flash = maxf(flash, lerpf(a[1], b[1], (su - float(a[0])) / (float(b[0]) - float(a[0]))))
				break
		if _shbrk_t >= 1.0:
			_shbrk_t = -1.0
	hp_mat.set_shader_parameter(&"sh_flash", flash)
	var sig := "%d:%d" % [roundi(pc * 400.0), ceili(sh)]
	if sig != _sh_sig:
		_sh_sig = sig
		hp_view.sh_text = ("+%d" % ceili(sh)) if sh > 0.05 else ""
		hp_view.queue_redraw()
		hp_scr.refresh()


func shield_up() -> void:
	_shup_t = 0.0


## The MANA meter above the health box: fill, the equipped power's cost marked on the bar, red shake when a cast is refused (mana_deny()).
func mana(dt: float, P: Player, show: bool) -> void:
	var pw: Variant = _power()
	var pow_o: Variant = _power_state()
	var m := maxf(0.0, minf(P.max_mana, P.mana))
	var f := m / P.max_mana
	var cost := 0.0      # charging: the marker grows with the charge
	if pw != null:
		cost = float(pow_o.ch.cost) if (pow_o != null and pow_o.ch.on) else float(pw.get("mana"))
	_mana_op = move_toward(_mana_op, 1.0 if show else 0.0, dt / 0.15)
	mana_view.modulate.a = _mana_op
	mana_view.visible = _mana_op > 0.001 and not _pip_hidden
	var mi := int(floor(m))
	var aim := P.power_aim
	var ci := roundi(cost)
	if mi != _mn_m or pw != _mn_pw or aim != _mn_aim or ci != _mn_c:
		_mn_m = mi
		_mn_pw = pw
		_mn_aim = aim
		_mn_c = ci
		mana_view.num = str(mi)
		mana_view.f = f
		mana_view.pow_name = (String(pw.get("name")) + (" READY" if aim else "")) if pw != null else ""
		var cw := minf(m, cost) / P.max_mana
		mana_view.cost_left = f - cw
		mana_view.cost_w = cw if aim else 0.0
		mana_view.low = pw != null and m < cost
		mana_view.pow_on = aim
		mana_view.queue_redraw()
	if _deny_t >= 0.0:      # manadeny .35s
		_deny_t += dt
		var u := _deny_t / 0.35
		var s := 0.0
		if u < 0.2:
			s = lerpf(0.0, -4.0, u / 0.2)
		elif u < 0.6:
			s = lerpf(-4.0, 4.0, (u - 0.2) / 0.4)
		elif u < 1.0:
			s = lerpf(4.0, 0.0, (u - 0.6) / 0.4)
		else:
			_deny_t = -1.0
		mana_view.shake = s
		mana_view.queue_redraw()


func mana_deny() -> void:
	_deny_t = 0.0


## The hit's direction, and the vignette. e: {amount, hp_amount, shield, shield_break, shield_col, dx, dz}; cam: the Camera3D.
func hurt(e: Dictionary, cam: Camera3D = null) -> void:
	var hp_part: float = e.get("hp_amount", e.get("amount", 0.0))
	var soaked: bool = e.get("shield", false) and not (e.get("hp_amount", 0.0) > 0.0)
	hurt_t = minf(1.0, 0.4 if soaked else 0.55 + hp_part / 40.0)
	stress = minf(1.0, stress + hp_part / 35.0)        # the heart-rate monitor only reacts to what actually reaches health
	_hurt_sh = e.get("shield_col", "") if (soaked or e.get("shield_break", false)) else ""
	if cam == null:
		cam = Game.camera
	var f := -cam.global_transform.basis.z
	var fl := Vector2(f.x, f.z).length()
	if fl == 0.0:
		fl = 1.0
	var fx := f.x / fl
	var fz := f.z / fl
	var dx: float = e.get("dx", 0.0)
	var dz: float = e.get("dz", 0.0)
	var a := dx * fx + dz * fz
	var r := dx * -fz + dz * fx
	var deg := rad_to_deg(atan2(r, a))       # 0 = ahead, clockwise positive
	var tint := Color("ff3b2a")
	if _hurt_sh != "":
		tint = Color("4db8ff") if _hurt_sh == "blue" else Color("ff8a1e")
	hdir_view.arrows.append([deg, 0.0, tint])
	hdir_view.queue_redraw()


## Purple mind-blast vignette that fades out over the slow's duration.
func mind(dur: float) -> void:
	_mind_dur = maxf(0.4, dur)
	_mind_t = 0.0
	mind_el.visible = true
	mind_mat.set_shader_parameter(&"opacity", 1.0)


## JS body.arena-tv: the arena's menu holds the screen; this much of the HUD steps aside
func arena_tv(on: bool) -> void:
	set_wheel_pip(on)      # (the same set of elements the terminal puts away; each re-reads _pip_hidden every frame)
	subs_box.visible = not on


func dead(on: bool) -> void:
	_dead_on = on


func is_dead_shown() -> bool:
	return _dead_on


## Robot dialogue subtitles (shown only for lines that were actually voiced, i.e. in earshot). e: {name, num, text, dur, speech}.
func subtitle(e: Dictionary) -> void:
	while subs_box.get_child_count() >= 3:
		var o := subs_box.get_child(0)
		subs_box.remove_child(o)
		o.queue_free()
	var nm: String = e.get("name", "")
	var row := _SubLine.new()
	row.setup(nm if nm != "" else "UNIT-%02d" % int(e.get("num", 0)), String(e.get("text", "")), bool(e.get("speech", false)), nm != "")
	subs_box.add_child(row)
	row.hold = maxf(0.9, float(e.get("dur", 0.0)) + 0.5)


class _SubLine extends Control:
	var who := ""
	var txt := ""
	var xl := false
	var named := false
	var hold := 1.0
	var t := 0.0
	const FS := 14
	const SP := 1.12
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func setup(p_who: String, p_txt: String, p_xl: bool, p_named: bool) -> void:
		who = p_who
		txt = p_txt
		xl = p_xl
		named = p_named
		var f := CrtTheme.font(&"monob")
		var w := CrtTheme.text_w(f, who, FS, SP) + 8.0 + CrtTheme.text_w(f, txt, FS, SP)
		if xl:
			w += CrtTheme.text_w(f, "TRANSLATED", 9, 1.26) + 8.0 + 8.0
		custom_minimum_size = Vector2(w + 24.0 + 3.0, roundf(FS * 1.3) + 6.0)
	func _process(dt: float) -> void:
		t += dt
		if t > hold:
			modulate.a = maxf(0.0, 1.0 - (t - hold) / 0.3)
			if t > hold + 0.32:
				queue_free()
	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(0, 0, size.x, h), Color(6.0 / 255.0, 10.0 / 255.0, 16.0 / 255.0, 0.72))
		draw_rect(Rect2(0, 0, 3, h), Color("7be34a") if named else Color("ff5a4a"))
		var f := CrtTheme.font(&"monob")
		var y := CrtTheme.baseline(f, FS, 0.0, h)
		var x := CrtTheme.draw_text(self, f, 15.0, y, who, FS, Color("ff8f7a"), SP) + 8.0
		if xl:
			var tw := CrtTheme.text_w(f, "TRANSLATED", 9, 1.26)
			draw_rect(Rect2(x, y - 11.0, tw + 8.0, 12.0), Color(123.0 / 255.0, 227.0 / 255.0, 74.0 / 255.0, 0.85))
			CrtTheme.draw_text(self, f, x + 4.0, y - 2.0, "TRANSLATED", 9, Color("0b1408"), 1.26)
			x += tw + 16.0
		CrtTheme.draw_text(self, f, x, y, txt, FS, Color("cfeec0") if xl else Color("e6f2fb"), SP)


# the power store and its live state: not ported yet, so empty hands for now (the branches below are the JS's, ready for it)
func _power() -> Variant:
	var ps = Game.get("power_store")
	return ps.equipped() if ps != null else null


func _power_state() -> Variant:
	return Game.get("power")


## The readout, reticle and scope, every frame.
func update(dt: float, combat: Combat, show: bool) -> void:
	_time += dt
	var w: Weapons.Def = combat.weapon if combat != null else null
	shot_t = maxf(0.0, shot_t - dt)
	show_t = maxf(0.0, show_t - dt)
	hm_t = maxf(0.0, hm_t - dt)
	if combat == null:
		ammo_el.visible = false
		xh.visible = false
		return
	# reticle: screen centre, only while actively shooting or in ADS (blue brackets, red when the aim ray is on an enemy)
	var pow_on := combat.power_aim
	var pw: Variant = _power() if pow_on else null
	var vis := show and (pow_on or (w != null and (combat.ads_on or show_t > 0.0)))         # power mode: the reticle is always up (green, red when out of mana)
	var off := Vector2.ZERO
	if vis and combat.pull_aim and Game.camera != null:       # set-piece camera: the reticle sits where the gun is actually aimed, not at screen centre
		if not Game.camera.is_position_behind(combat.aim_point):
			off = Game.camera.unproject_position(combat.aim_point) - get_viewport_rect().size * 0.5
	var sw := combat.scope_w if (show and w != null and w.scope) else 0.0
	var so := clampf((sw - 0.55) / 0.35, 0.0, 1.0)       # scope overlay: fades in as the camera settles at the eye; the normal reticle is hidden while it is up
	var tgt := combat.aim_on_target
	var no_mana := pow_on and pw != null and Game.player.mana < float(pw.get("mana"))
	var cc := Color("3fb6ff")
	var gg := Color(63.0 / 255.0, 182.0 / 255.0, 1.0, 0.9)
	if pow_on:
		cc = Color("9dff5a")
		gg = Color(157.0 / 255.0, 1.0, 90.0 / 255.0, 0.9)
		if tgt:
			cc = Color("ffd23a")
			gg = Color(1.0, 210.0 / 255.0, 58.0 / 255.0, 0.95)
		if no_mana:
			cc = Color("ff5a4a")
			gg = Color(1.0, 90.0 / 255.0, 74.0 / 255.0, 0.9)
	elif tgt:
		cc = Color("ff3b3b")
		gg = Color(1.0, 59.0 / 255.0, 59.0 / 255.0, 0.95)
	var ads := combat.ads_on
	var sp_t := (5.0 if ads else 11.0) + combat.bloom * 700.0 * (0.4 if ads else 1.0) + shot_t * 90.0 * (0.5 if ads else 1.0)
	_xh_sp += (sp_t - _xh_sp) * (1.0 - exp(-dt / 0.025))     # transition: left .06s
	var xo := 0.0 if (sw > 0.3 or not vis) else 1.0
	_xh_op = move_toward(_xh_op, xo, dt / 0.08)
	xh.visible = _xh_op > 0.001 and not _pip_hidden and not hide_xhair
	if xh.visible:
		xh.modulate.a = _xh_op
		var sig := "%.1f|%s|%s|%s|%s|%.0f,%.0f" % [_xh_sp, ads, pow_on, cc.to_html(), gg.to_html(), off.x, off.y]
		if sig != _xh_sig:
			_xh_sig = sig
			xh.sp = _xh_sp
			xh.ads = ads
			xh.pow_on = pow_on
			xh.c = cc
			xh.g = gg
			xh.offset = off
			xh.queue_redraw()
	scope_el.visible = so > 0.01
	if so > 0.01:
		scope_el.modulate.a = so
		scope_lines.c = Color("ffd0d0") if tgt else Color("c9f6ff")
		var zx := "%.1f" % (tan(deg_to_rad(Config.fov * 0.5)) / tan(deg_to_rad(w.scope_fov * 0.5)))
		var rg := ("%d M" % roundi(combat.aim_dist)) if combat.aim_dist != 0.0 else "---"
		var ssig := zx + rg + scope_lines.c.to_html()
		if ssig != _scope_sig:
			_scope_sig = ssig
			scope_lines.rng = "RNG " + rg
			scope_lines.zoom = "ZOOM " + zx + "X"
			scope_lines.queue_redraw()
	var hmo := minf(1.0, hm_t / 0.12) if hm_t > 0.0 else 0.0
	if hmo != _hm_op:
		_hm_op = hmo
		hm.visible = hmo > 0.0
		hm.modulate.a = hmo
		var hoff := Vector2.ZERO          # set-piece camera: the marker pops on the enemy that was hit (the reticle is no longer at screen centre)
		if hm_t > 0.0 and combat.pull_aim and hm_pos != null and Game.camera != null and not Game.camera.is_position_behind(hm_pos):
			hoff = Game.camera.unproject_position(hm_pos) - get_viewport_rect().size * 0.5
		if hoff != hm.offset:
			hm.offset = hoff
			hm.queue_redraw()
	# the readout
	var cur := combat.cur
	var n := roundi(combat.ammo[cur]) if cur >= 0 else -1
	var res := int(combat.reserve[cur]) if cur >= 0 else 0
	var AR := combat.arc
	var rl := combat.rl
	var rp := roundi(rl.u * 20.0) if rl != null else -1
	var chg := combat.yoke.charge if combat.yoke.holding else -1.0
	var pwe: Variant = _power()
	var ps: Variant = _power_state()
	var un: Variant = Game.level.get("hud_unarmed") if Game.level != null else null
	var sig := "%d:%d:%d:%d:%d:%d%d:" % [cur, n, res, rp, roundi(chg * 25.0), 1 if AR.on else 0, 1 if AR.spent else 0]
	if pwe != null:
		var pmana: float = pwe.get("mana")
		sig += "%s%d" % [pwe.get("id"), floori(Game.player.mana / (pmana if pmana != 0.0 else 1.0))]
		if ps != null:
			if ps.ch.on:
				sig += "c%d" % roundi(ps.ch.k * 50.0)
			if pwe.get("drain"):
				sig += "s%d%s" % [roundi(Game.player.mana), ps.spray]
	if un != null:
		sig += "u"
	var want := 1.0 if show else 0.0
	_ammo_op = move_toward(_ammo_op, want, dt / 0.15)
	ammo_el.modulate.a = _ammo_op
	ammo_el.visible = _ammo_op > 0.001 and not _pip_hidden
	var low_anim := false
	if sig != _sig:
		_sig = sig
		_ammo_text(combat, w, cur, n, res, chg, AR, rl, pwe, ps, un)
		ammo_view.queue_redraw()
		ammo_scr.refresh()
	low_anim = ammo_view.bar_cls == "low"
	if low_anim:      # blink .5s alternate
		var a := lerpf(1.0, 0.45, 0.5 - 0.5 * cos(_time / 1.0 * TAU))
		ammo_view.bar_alpha = a
		ammo_view.queue_redraw()
		ammo_scr.refresh()
	elif _low_anim:
		ammo_view.bar_alpha = 1.0
	_low_anim = low_anim


func _ammo_text(combat: Combat, w: Weapons.Def, cur: int, n: int, res: int, chg: float, AR: Combat.Arc, rl: Combat.Reload, pw: Variant, ps: Variant, un: Variant) -> void:
	var v := ammo_view
	v.icon_col = Color("8dffb4")
	v.bar_cls = ""
	if pw != null:
		var ch: bool = ps != null and ps.ch.on
		var pmana: float = pw.get("mana")
		var k := floori(Game.player.mana / (pmana if pmana != 0.0 else 1.0))
		var pct := roundi(ps.ch.k * 100.0) if ps != null else 0
		var drain: float = pw.get("drain") if pw.get("drain") != null else 0.0
		var pname: String = pw.get("name")
		if ch:
			v.big = str(pct)
			v.unit = "% CHARGE"
			v.msg = "%s — %d MANA" % [pname, roundi(ps.ch.cost)]
		elif drain != 0.0:
			v.big = "%.1f" % (Game.player.mana / drain)
			v.unit = "S SPRAYING" if (ps != null and ps.spray) else "S OF SPRAY"
			v.msg = "%s — %s MANA/S" % [pname, str(drain)]
		else:
			v.big = str(k)
			v.unit = " CASTS"
			var mm: Variant = pw.get("mana_max")
			v.msg = "%s — %s MANA" % [pname, ("%s-%s" % [str(pmana), str(mm)]) if mm else str(pmana)]
		v.icon = PlasmidShop.icon_tex(pw)
		if pw.get("color") != null:
			v.icon_col = Color.hex((int(pw.get("color")) << 8) | 0xff)
		v.bar = (float(pct) / 100.0) if ch else minf(1.0, Game.player.mana / Game.player.max_mana)
		v.bar_cls = "rl" if ch else ""
	elif w == null:
		# a level can say what the empty hands mean there (e.g. DEAD AIR: no fighting)
		v.bar = -1.0
		if un != null:
			v.icon = null
			v.big = String(un.title)
			v.unit = ""
			v.msg = String(un.sub)
		else:
			v.icon = WeaponIcons.tex("fists")
			v.big = "FISTS"
			v.unit = ""
			v.msg = "3-HIT COMBO"
	else:
		var f := rl.u if rl != null else (chg if chg >= 0.0 else float(n) / float(w.mag_size))
		var msg := w.name
		if w.energy:
			msg = "OVERHEATED" if AR.spent else ("DISCHARGING" if AR.on else ("RECHARGING" if n < w.mag_size else w.name))
		elif rl != null:
			msg = "RELOADING"
		elif chg >= 0.0:
			msg = "FULL MASS" if chg >= 1.0 else "GATHERING %d%%" % roundi(chg * 100.0)
		elif n <= 0:
			msg = ("RELOADING" if Config.auto_reload != 0 else "PRESS R / X") if res > 0 else "NO AMMO"
		v.icon = WeaponIcons.tex(w.id)
		v.big = str(n)
		v.unit = "%" if w.energy else "/%d" % res
		v.msg = msg
		v.bar = clampf(f, 0.0, 1.0)
		v.bar_cls = "rl" if (rl != null or chg >= 0.0) else ("low" if (float(n) / float(w.mag_size) < 0.25 or AR.spent) else "")


# ---- JS class UI: toast, controller pill, lock hint; called every frame ----
func ui_update(dt: float, show_hint: bool) -> void:
	if not visible:
		return
	var ok := Inp.pad_connected
	var text := "Controller connected" if ok else "No controller: press any button on it (keyboard/mouse active)"
	if text != _last_status:
		_last_status = text
		pad_lab.text = text
		_pad_ok = ok
		pad_dot.queue_redraw()
		toast("Controller connected" if ok else "Controller disconnected — keyboard/mouse active", 1.8)
	if _toast_t > 0.0:
		_toast_t -= dt
	_toast_op = move_toward(_toast_op, 1.0 if _toast_t > 0.0 else 0.0, dt / 0.2)
	toast_box.modulate.a = _toast_op
	toast_box.visible = _toast_op > 0.001 and not _pip_hidden
	_lock_op = move_toward(_lock_op, 0.9 if show_hint else 0.0, dt / 0.3)
	lock_box.modulate.a = _lock_op
	lock_box.visible = _lock_op > 0.001 and not _pip_hidden and not Inp.capture_blocked
	# cash
	var cash := Game.money
	if cash != _cash:
		_cash = cash
		cash_lab.text = CrtTheme.money(cash)
	if _gain_t >= 0.0:      # cashup 1.1s: slides 22 px down and fades
		_gain_t += dt
		var u := minf(1.0, _gain_t / 1.1)
		var e := CrtTheme.bezier(u, 0.0, 0.0, 0.58, 1.0)
		cash_gain.modulate.a = 1.0 - e
		cash_gain.offset_top = 40.0 + 22.0 * e
		if u >= 1.0:
			_gain_t = -1.0
	if _cash_gain_t > 0.0:
		_cash_gain_t -= dt


## The corner save icon, 1.6 s.
func save_icon() -> void:
	_save_t = 1.6
	set_process(true)


func _process(delta: float) -> void:
	_save_t = maxf(0.0, _save_t - delta)
	_save_op = move_toward(_save_op, 0.9 if _save_t > 0.0 else 0.0, delta / 0.35)
	save_el.visible = _save_op > 0.001
	save_el.modulate.a = _save_op
	save_el.ang += delta * TAU / 0.8
	save_el.queue_redraw()
	if _save_t <= 0.0 and _save_op <= 0.0:
		set_process(false)


## JS addMoney's flash: consecutive gains add up on the +$ line.
func money_gain(n: float) -> void:
	_cash_gain_sum = (_cash_gain_sum + n if _cash_gain_t > 0.0 else n) if n > 0.0 else 0.0
	_cash_gain_t = 1.1
	if n > 0.0:
		cash_gain.text = "+" + CrtTheme.money(_cash_gain_sum)
		_gain_t = 0.0
		cash_gain.modulate.a = 1.0


## The near-interact prompt (#shophint). key: the button to show ("" none), text: what follows, cls: "", armor, closed, talk, plasmid, drop, drop dim. An empty text hides it.
func hint(text: String, cls: String = "", key: String = "") -> void:
	var pad := Inp.using_pad
	var h := "%s|%s|%s|%s" % [text, cls, key, pad]
	if h == _hint_h:
		return
	_hint_h = h
	hint_box.visible = text != "" and not _pip_hidden
	if text == "":
		return
	hint_box.cls = cls
	hint_box.lab.text = text
	hint_box.key_box.visible = key != ""
	if key != "":
		hint_box.key_box.set_key(key, pad)
	var col := Color("e2edf5")
	if cls.begins_with("drop"):
		col = Color("8f9cab") if cls.contains("dim") else Color("e6eef6")
	hint_box.lab.label_settings.font_color = col
	hint_box.queue_redraw()
	hint_box.reset_size()
	_hint_place()


## Boot warm-up (JS warmCompositor): the HUD parts that only show in play, drawn for a few frames behind the boot terminal.
func warm(on: bool) -> void:
	for c: CanvasItem in [scope_el, dead_el, hurt_el, mind_el, crit_add, crit_mul, vc_text, hm, xh]:
		c.visible = on


## The terminal wheel is up: most of the HUD steps aside (body.whPip).
func set_wheel_pip(on: bool) -> void:
	_pip_hidden = on
	if on:
		ammo_el.visible = false
		hp_el.visible = false
		mana_view.visible = false
		xh.visible = false
		toast_box.visible = false
		lock_box.visible = false
		pad_box.visible = false
		cash_box.visible = false
		cash_gain.visible = false
		hint_box.visible = false
		vc_text.visible = false
		hdir_view.visible = false
	else:
		pad_box.visible = true
		cash_box.visible = true
		cash_gain.visible = true
		hdir_view.visible = true
		hint_box.visible = _hint_h != "" and not _hint_h.begins_with("|")


## A cutscene, the dialogue box or a menu has the screen (body.cine, body.dlg, #start): the set of elements the CSS hides there.
## a cutscene's letterbox with the HUD hidden keeps its subtitles, just over the bar (JS body.dlg.vh-fin #subs)
func set_subs_free(on: bool) -> void:
	subs_box.reparent(_group.get_parent() if on else _group, false)
	_center_bottom(subs_box, get_viewport().get_visible_rect().size.y * 0.125 + 16.0 if on else 92.0)


func set_suppressed(on: bool) -> void:
	_suppressed = on
	_group.visible = not on
