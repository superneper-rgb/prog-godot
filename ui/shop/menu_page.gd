class_name MenuPage
extends Control
## What a vendor terminal's screen draws (JS mainHTML, slotHTML, the .vd-* stylesheet): the header, the panels, the carousel and the prompts, boxed at the CSS's numbers in design pixels. Clicks go through the rectangles noted while drawing.

var M: VendorMenu = null
var small := false       # @media (max-height: 620px): the description, notes and captions drop out
var tiny := false        # @media (max-height: 540px)
var head_a := 1.0
var head_y := 0.0
var main_a := 1.0
var car_a := 1.0
var car_y := 0.0
var prompt_a := 1.0
var prompt_y := 0.0
var stamp_top := ""
var stamp_sub := ""
var ga := 1.0            # the current group's opacity
var _hits: Array[Dictionary] = []
var _f700: Font = null
var _f600: Font = null
var _f500: Font = null
var _forb: Font = null
var clip_b := 1e9        # lines below this y are out of sight (overflow: hidden)
# the layout
var pad_l := 62.0
var inner_w := 0.0
var r_head := Rect2()
var r_main := Rect2()
var r_car := Rect2()
var r_prompts := Rect2()
var r_cview := Rect2()
var slot_w := 118.0
var slot_h := 76.0
var slot_gap := 12.0
var _order: Array[int] = []
var _pos := {}


func _ready() -> void:
	_f700 = CrtTheme.font(&"raj700")
	_f600 = CrtTheme.font(&"raj600")
	_f500 = CrtTheme.font(&"raj500")
	_forb = CrtTheme.font(&"orb800")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout() -> void:
	var u := M.u
	var W := size.x
	var H := size.y
	inner_w = W - 124.0
	r_head = Rect2(pad_l, 26.0, inner_w, 40.0)
	var ph := maxf(13.0 * u * 1.61, 13.0 * u * 1.2)      # (the key chips set the prompts' height)
	r_prompts = Rect2(pad_l, H - 22.0 - ph, inner_w, ph)
	r_car = Rect2(pad_l, r_prompts.position.y - 10.0 * u - 120.0 * u, inner_w, 120.0 * u)
	r_main = Rect2(pad_l, 26.0 + 40.0 + 8.0, inner_w, r_car.position.y - 16.0 * u - (26.0 + 40.0 + 8.0))
	var arrow := 34.0 * u
	r_cview = Rect2(pad_l + 10.0 * u + arrow + 10.0, r_car.position.y, inner_w - 20.0 * u - 2.0 * arrow - 20.0, r_car.size.y)
	slot_w = 118.0 * u
	slot_h = 76.0 * u
	slot_gap = 12.0 * u
	M._view_m.set_shader_parameter(&"band", Vector2(r_main.position.y / H, (r_main.position.y + r_main.size.y) / H))
	_layout_car(true)


func slot_x(i: int) -> float:
	return float(_pos.get(i, 0.0))


func _layout_car(instant: bool) -> void:
	_order.clear()
	_pos.clear()
	var x := 0.0
	for i in M.n:
		if M.slot_hidden(i):
			continue
		_order.append(i)
		_pos[i] = x
		x += slot_w + slot_gap
	var tw := maxf(0.0, x - slot_gap)
	var vw := r_cview.size.x
	var sc := slot_x(M.sel) + slot_w / 2.0
	var tx: float
	if tw <= vw - 8.0:
		tx = (vw - tw) / 2.0 + (vw / 2.0 - ((vw - tw) / 2.0 + sc)) * 0.22
	else:
		tx = clampf(vw / 2.0 - sc, vw - tw - 6.0, 6.0)
	M.track_to = roundf(tx)
	if instant or M._car_snap:
		M.track_x = M.track_to
		M.bracket_x = M.track_to + slot_x(M.sel)
		M._car_snap = false


func hit_at(p: Vector2) -> Dictionary:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i].r as Rect2).has_point(p):
			return _hits[i]
	return {}


func add_hit(r: Rect2, a: String, v: int = 0) -> void:
	_hits.append({"r": r, "a": a, "v": v})


# ---- drawing helpers ----
func c(col: Color, a: float = 1.0) -> Color:
	return Color(col.r, col.g, col.b, col.a * a * ga)


func w_of(f: Font, s: String, sz: int, sp: float) -> float:
	return CrtTheme.text_w(f, s, sz, sp)


## s at baseline y; letter spacing in em; returns the width
func tx(x: float, y: float, s: String, sz: float, col: Color, f: Font = null, sp_em: float = 0.0, align: String = "l") -> float:
	if y > clip_b:
		return 0.0
	var fnt := f if f != null else _f700
	var isz := maxi(4, roundi(sz))
	var sp := sz * sp_em
	var wd := w_of(fnt, s, isz, sp)
	var x0 := x
	if align == "c":
		x0 = x - wd / 2.0
	elif align == "r":
		x0 = x - wd
	CrtTheme.draw_text(self, fnt, x0, y, s, isz, c(col), sp)
	return wd


func chamf_tl_br(r: Rect2, q: float) -> PackedVector2Array:      # clip-path: polygon(q 0, 100% 0, 100% calc(100% - q), calc(100% - q) 100%, 0 100%, 0 q)
	var x := r.position.x
	var y := r.position.y
	var x2 := r.end.x
	var y2 := r.end.y
	return PackedVector2Array([Vector2(x + q, y), Vector2(x2, y), Vector2(x2, y2 - q), Vector2(x2 - q, y2), Vector2(x, y2), Vector2(x, y + q)])


func chamf_tr_bl(r: Rect2, q: float) -> PackedVector2Array:      # the buttons' and price strip's: polygon(0 0, calc(100% - q) 0, 100% q, 100% 100%, q 100%, 0 calc(100% - q))
	var x := r.position.x
	var y := r.position.y
	var x2 := r.end.x
	var y2 := r.end.y
	return PackedVector2Array([Vector2(x, y), Vector2(x2 - q, y), Vector2(x2, y + q), Vector2(x2, y2), Vector2(x + q, y2), Vector2(x, y2 - q)])


func chamf_all(r: Rect2, q: float) -> PackedVector2Array:
	var x := r.position.x
	var y := r.position.y
	var x2 := r.end.x
	var y2 := r.end.y
	return PackedVector2Array([Vector2(x + q, y), Vector2(x2 - q, y), Vector2(x2, y + q), Vector2(x2, y2 - q), Vector2(x2 - q, y2), Vector2(x + q, y2), Vector2(x, y2 - q), Vector2(x, y + q)])


func hex_h(r: Rect2, q: float) -> PackedVector2Array:      # polygon(q 0, calc(100% - q) 0, 100% 50%, calc(100% - q) 100%, q 100%, 0 50%)
	var x := r.position.x
	var y := r.position.y
	var x2 := r.end.x
	var y2 := r.end.y
	var m := (y + y2) / 2.0
	return PackedVector2Array([Vector2(x + q, y), Vector2(x2 - q, y), Vector2(x2, m), Vector2(x2 - q, y2), Vector2(x + q, y2), Vector2(x, m)])


func poly(pts: PackedVector2Array, col: Color) -> void:
	if col.a * ga <= 0.003:
		return
	draw_colored_polygon(pts, c(col))


## a polygon filled with a vertical gradient
func poly_grad(pts: PackedVector2Array, top: Color, bot: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for p: Vector2 in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p: Vector2 in pts:
		cols.append(c(top.lerp(bot, (p.y - y0) / maxf(y1 - y0, 0.001))))
	draw_polygon(pts, cols)


func rect(r: Rect2, col: Color) -> void:
	draw_rect(r, c(col))


func rect_h(r: Rect2, c0: Color, c1: Color) -> void:      # a left-to-right gradient
	draw_primitive(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([c(c0), c(c1), c(c1), c(c0)]), PackedVector2Array())


func rect_v(r: Rect2, c0: Color, c1: Color) -> void:      # top to bottom
	draw_primitive(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([c(c0), c(c0), c(c1), c(c1)]), PackedVector2Array())


## one key chip (JS vdKey + .vd-k): returns its width
func key_chip(x: float, cy: float, k: String, sz: float) -> float:
	var pad := M.dev == "pad"
	var fs := sz * 0.92
	var h := fs * 1.75
	var ink := M.th("glass2")
	var isz := maxi(4, roundi(fs))
	if pad and ["A", "B", "X", "Y"].has(k):
		var bg: Color = {"A": Color("#2e9e4a"), "B": Color("#c8392d"), "X": Color("#2d6fd0"), "Y": Color("#cfa21c")}[k]
		var d := fs * 1.8
		draw_circle(Vector2(x + d / 2.0, cy), d / 2.0, c(bg))
		var col := Color("#1a1400") if k == "Y" else Color.WHITE
		tx(x + d / 2.0, CrtTheme.baseline(_f700, isz, cy - d / 2.0, d), k, fs, col, _f700, 0.0, "c")
		return d
	var w := maxf(fs * 1.9, w_of(_f700, k, isz, fs * 0.04) + 12.0)
	var r := Rect2(x, cy - h / 2.0, w, h)
	if pad:
		w = maxf(fs * 2.4, w_of(_f700, k, isz, fs * 0.04) + 10.0)
		r = Rect2(x, cy - h / 2.0, w, h)
		draw_rect(r, c(Color("#5b6672")))
		tx(x + w / 2.0, CrtTheme.baseline(_f700, isz, r.position.y, h), k, fs, Color.WHITE, _f700, 0.04, "c")
		return w
	poly(chamf_tl_br(r, 3.0), M.th("ink2"))
	tx(x + w / 2.0, CrtTheme.baseline(_f700, isz, r.position.y, h), k, fs, ink, _f700, 0.04, "c")
	return w


## a button (.vd-btn): spec {k: key or "", label, small, price, cls, a, tick}. w <= 0: as wide as its content. Returns its size.
func btn(x: float, y: float, w: float, s: Dictionary) -> Vector2:
	var u := M.u
	var fs := 14.0 * u
	var isz := maxi(4, roundi(fs))
	var pad_x := 16.0 * u
	var h := 11.0 * u * 2.0 + maxf(fs, fs * 0.92 * 1.75)
	var cls: String = s.get("cls", "")
	var label: String = s.get("label", "")
	var price: String = s.get("price", "")
	var ks: String = s.get("k", "")
	var sp := fs * 0.18
	var lw := w_of(_f700, label, isz, sp)
	var kw := 0.0
	if ks != "":
		kw = maxf(fs * 0.92 * 1.9, w_of(_f700, ks, maxi(4, roundi(fs * 0.92)), fs * 0.04) + 12.0) + 10.0
	if s.get("tick", false):
		kw = fs * 0.9 + 10.0
	var pw := 0.0
	if price != "":
		pw = w_of(_f700, price, isz, fs * 0.06) + 10.0
	var sm: String = s.get("small", "")
	var smw := 0.0
	if sm != "":
		smw = w_of(_f700, sm, maxi(4, roundi(fs * 0.78)), fs * 0.78 * 0.14) + 6.0
	var bw := w if w > 0.0 else pad_x * 2.0 + kw + lw + smw + pw
	var r := Rect2(x, y, bw, h)
	if y > clip_b or y < -9000.0:      # (off the page, or a measuring pass)
		return Vector2(bw, h)
	var t := M.theme_id == "weapon"
	var edge := M.th("edge")
	var i0 := edge.lerp(Color("#06121a"), 0.66)
	var i1 := edge.lerp(Color("#03080c"), 0.86)
	var txt := M.th("ink")
	var pcol := M.th("sel")
	if t:
		i0 = Color("#651421")
		i1 = Color("#250810")
	match cls:
		"main":
			edge = M.th("sel")
			i0 = M.th("sel").lerp(Color("#141006"), 0.7)
			i1 = M.th("sel").lerp(Color("#060503"), 0.88)
			if t:
				i0 = Color("#173c47")
				i1 = Color("#08191f")
		"off":
			edge = M.cm("edge", 35.0)
			i0 = Color("#11050af0") if t else Color8(4, 8, 10, 217)
			i1 = i0
			txt = M.th("dim")
			pcol = M.th("dim")
		"poor":
			edge = M.th("bad")
			i0 = Color("#50100a") if t else Color8(80, 16, 10, 230)
			i1 = Color("#1e0604") if t else Color8(30, 6, 4, 242)
			txt = Color("#ffd9d2")
			pcol = Color("#ff9d8e")
		"done":
			edge = M.th("good")
			i0 = Color("#06140e") if t else Color8(6, 20, 10, 230)
			i1 = i0
			txt = M.th("good")
	poly(chamf_tr_bl(r, 11.0), edge)
	poly_grad(chamf_tr_bl(r.grow(-1.5), 10.4), i0, i1)
	var bx := x + pad_x
	var cy := y + h / 2.0
	var base := CrtTheme.baseline(_f700, isz, y, h)
	if ks != "":
		bx += key_chip(bx, cy, ks, fs) + 10.0
	elif s.get("tick", false):
		var a := Vector2(bx, cy - 1.0)
		draw_polyline(PackedVector2Array([a, a + Vector2(fs * 0.3, fs * 0.3), a + Vector2(fs * 0.9, -fs * 0.3)]), c(txt), 2.0)
		bx += fs * 0.9 + 10.0
	bx += tx(bx, base, label, fs, txt, _f700, 0.18)
	if sm != "":
		tx(bx + 6.0, base, sm, fs * 0.78, M.th("dim"), _f700, 0.14)
	if price != "":
		tx(x + bw - pad_x, base, price, fs, pcol, _f700, 0.06, "r")
	if s.has("a"):
		add_hit(r, s.a)
	return Vector2(bw, h)


## a flex-wrap row of buttons; returns the height it took
func btn_row(x: float, y: float, w: float, specs: Array) -> float:
	var u := M.u
	var gap := 9.0 * u
	var cx := x
	var cy := y
	var line_h := 0.0
	for s: Dictionary in specs:
		var ww: float = w if s.get("full", false) else 0.0
		var sz := btn(-99999.0, -99999.0, ww, s)
		if cx > x and cx + sz.x > x + w:
			cx = x
			cy += line_h + gap
			line_h = 0.0
		btn(cx, cy, ww, s)
		cx += sz.x + gap
		line_h = maxf(line_h, sz.y)
	return cy + line_h - y


## .vd-pn: the chamfered well with a thin edge; returns the inner rect
func panel(r: Rect2, view_: bool = false) -> Rect2:
	poly(chamf_all(r, 14.0), M.th("edge"))
	var inr := r.grow(-1.0)
	poly_grad(chamf_all(inr, 13.5), M.th("well"), M.th("glass2"))
	if view_:      # radial-gradient(ellipse 60% 55% at 50% 52%, edge 12%, transparent 70%)
		var e := M.cm("edge", 12.0)
		var ctr := inr.position + Vector2(inr.size.x * 0.5, inr.size.y * 0.52)
		var rx := inr.size.x * 0.6 * 0.7
		var ry := inr.size.y * 0.55 * 0.7
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		pts.append(ctr)
		cols.append(c(e))
		for i in 33:
			var a := i / 32.0 * TAU
			pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
			cols.append(c(Color(e.r, e.g, e.b, 0.0)))
		for i in range(1, 33):
			draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), PackedColorArray([cols[0], cols[i], cols[i + 1]]), PackedVector2Array())
	return inr


func _dash_circle(ctr: Vector2, r: float, pattern: Array, rot: float, col: Color, w: float) -> void:
	var total := 0.0
	for d: float in pattern:
		total += d
	var circ := TAU * r
	var reps := int(circ / total)
	var ang := rot
	for _i in reps:
		for j in range(0, pattern.size(), 2):
			var a1 := ang + float(pattern[j]) / r
			draw_arc(ctr, r, ang, a1, maxi(2, int(float(pattern[j]) / 6.0) + 1), col, w)
			ang = a1 + float(pattern[j + 1]) / r


## .vd-schem: the technical drawing behind the subject. kind: "w" weapon, "a" armor (labels), "p" vials
func schem(r: Rect2, kind: String) -> void:
	var col := M.th("sel") if M.theme_id == "weapon" else M.th("edge")
	var s := maxf(r.size.x / 400.0, r.size.y / 300.0)
	var o := r.position + (r.size - Vector2(400, 300) * s) / 2.0
	var t := M._clock
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var A := 0.5
	var cg := c(Color(col.r, col.g, col.b, 0.12 * A))
	var ct := c(Color(col.r, col.g, col.b, 0.5 * A))
	var cr := c(Color(col.r, col.g, col.b, 0.28 * A))
	var seg := PackedVector2Array()
	for q in 21:
		var x := o.x + q * 20.0 * s
		if x >= r.position.x and x <= r.end.x:
			seg.append(Vector2(x, r.position.y))
			seg.append(Vector2(x, r.end.y))
	for q in 16:
		var y := o.y + q * 20.0 * s
		if y >= r.position.y and y <= r.end.y:
			seg.append(Vector2(r.position.x, y))
			seg.append(Vector2(r.end.x, y))
	draw_multiline(seg, cg, 1.0)
	var ctr: Vector2 = P.call(200.0, 150.0)
	var a1 := t / 60.0 * TAU
	var a2 := -t / 95.0 * TAU
	if kind == "w":
		draw_arc(ctr, 128.0 * s, 0.0, TAU, 64, cr, s)
		_dash_circle(ctr, 138.0 * s, [2.0 * s, 10.0 * s], a1, ct, 1.2 * s)
		_dash_circle(ctr, 104.0 * s, [40.0 * s, 14.0 * s, 4.0 * s, 14.0 * s], a2, cr, s)
		var ln: Array = [[200, 8, 200, 28], [200, 272, 200, 292], [14, 150, 34, 150], [366, 150, 386, 150], [30, 30, 56, 30], [30, 30, 30, 56], [370, 30, 344, 30], [370, 30, 370, 56], [30, 270, 56, 270], [30, 270, 30, 244], [370, 270, 344, 270], [370, 270, 370, 244]]
		for e: Array in ln:
			draw_line(P.call(e[0], e[1]), P.call(e[2], e[3]), ct, 1.2 * s)
	else:
		_dash_circle(ctr, 128.0 * s, [60.0 * s, 8.0 * s, 4.0 * s, 8.0 * s], a1, cr, s)
		_dash_circle(ctr, 140.0 * s, [2.0 * s, 9.0 * s], a2, ct, 1.2 * s)
		var ln: Array = [[200, 6, 200, 24], [200, 276, 200, 294], [118, 150, 100, 150], [282, 150, 300, 150], [130, 20, 108, 20], [108, 20, 108, 42], [270, 20, 292, 20], [292, 20, 292, 42], [130, 280, 108, 280], [108, 280, 108, 258], [270, 280, 292, 280], [292, 280, 292, 258]]
		for e: Array in ln:
			draw_line(P.call(e[0], e[1]), P.call(e[2], e[3]), ct, 1.2 * s)
		if kind == "a":
			var lr: Array = [[150, 60, 126, 60], [150, 120, 116, 120], [150, 200, 120, 200], [250, 90, 278, 90], [250, 170, 286, 170], [250, 240, 272, 240]]
			for e: Array in lr:
				draw_line(P.call(e[0], e[1]), P.call(e[2], e[3]), cr, s)
			for q: Array in [[62, 62, "HELM"], [54, 122, "TORSO"], [62, 202, "LEGS"], [282, 93, "PLATE"], [290, 173, "CORE"]]:
				var q0: Vector2 = P.call(q[0], q[1])
				tx(q0.x, q0.y, q[2], 9.0 * s, Color(col.r, col.g, col.b, 0.55 * A), _f600, 0.2)


## the 3D subject, the scan and sweep, the corner chips: everything a preview panel carries over its drawing
func view_overlays(inr: Rect2, chip_key: String, chip: String, chip_cls: String, idx_b: String, idx_rest: String, cap_l: String, cap_r: String, vertical: bool) -> void:
	var u := M.u
	var st := VendorMenu.stage
	st.set_view_size(Vector2i(maxi(2, roundi(inr.size.x * M.k)), maxi(2, roundi(inr.size.y * M.k))))
	var tex := st.get_texture()
	var rv := st.reveal
	if rv < 1.0:      # the scan front (see VendorStage)
		if vertical:
			var hh := inr.size.y * rv
			draw_texture_rect_region(tex, Rect2(inr.position.x, inr.end.y - hh, inr.size.x, hh), Rect2(0, tex.get_height() * (1.0 - rv), tex.get_width(), tex.get_height() * rv), c(Color.WHITE))
			var ec := Color(st.edge_col.r, st.edge_col.g, st.edge_col.b, st.edge_a)
			rect(Rect2(inr.position.x + inr.size.x * 0.08, inr.end.y - hh - 1.0, inr.size.x * 0.84, 2.0), ec)
		else:
			var ww := inr.size.x * rv
			draw_texture_rect_region(tex, Rect2(inr.position.x, inr.position.y, ww, inr.size.y), Rect2(0, 0, tex.get_width() * rv, tex.get_height()), c(Color.WHITE))
			var ec := Color(st.edge_col.r, st.edge_col.g, st.edge_col.b, st.edge_a)
			rect(Rect2(inr.position.x + ww - 1.0, inr.position.y + inr.size.y * 0.1, 2.0, inr.size.y * 0.8), ec)
	else:
		draw_texture_rect(tex, inr, false, c(Color.WHITE))
	if vertical:      # .vd-glass
		var g0 := Color(1.0, 200.0 / 255.0, 90.0 / 255.0, 0.1)
		rect_v(Rect2(inr.position, Vector2(inr.size.x, inr.size.y * 0.35)), g0, Color(g0.r, g0.g, g0.b, 0.0))
	# .vd-scan
	var ast: float = M.anim.get("scan", 9.0)
	if ast < 0.23:
		var q := ast / 0.23
		var fade := 1.0 if q < 0.7 else 1.0 - (q - 0.7) / 0.3
		var e2 := M.cm("edge", 30.0)
		var hl := M.th("hl")
		if vertical:
			var hb := inr.size.y * 0.26
			var y := inr.end.y - (-hb + q * (inr.size.y + hb)) - hb
			rect_v(Rect2(inr.position.x, y, inr.size.x, hb * 0.08), Color(0, 0, 0, 0), Color(e2.r, e2.g, e2.b, e2.a * fade))
			rect_v(Rect2(inr.position.x, y + hb * 0.08, inr.size.x, hb * 0.92), Color(hl.r, hl.g, hl.b, hl.a * fade), Color(hl.r, hl.g, hl.b, 0.0))
		else:
			var wb := inr.size.x * 0.3
			var x := inr.position.x - wb + q * (inr.size.x + wb)
			rect_h(Rect2(x, inr.position.y, wb * 0.92, inr.size.y), Color(hl.r, hl.g, hl.b, 0.0), Color(hl.r, hl.g, hl.b, hl.a * fade))
			rect_h(Rect2(x + wb * 0.92, inr.position.y, wb * 0.08, inr.size.y), Color(e2.r, e2.g, e2.b, e2.a * fade), Color(0, 0, 0, 0))
	# .vd-sweep
	var asw: float = M.anim.get("sweep", 9.0)
	if asw < 0.6:
		var q := CrtTheme.bezier(asw / 0.6, 0.3, 0.6, 0.3, 1.0)
		var bw := inr.size.x * 0.4
		var x := inr.end.x - q * (inr.size.x + bw)
		var sel := M.th("sel")
		rect_h(Rect2(x, inr.position.y, bw * 0.5, inr.size.y), Color(1, 1, 1, 0), Color(1, 1, 1, 0.38))
		rect_h(Rect2(x + bw * 0.5, inr.position.y, bw * 0.5, inr.size.y), Color(sel.r, sel.g, sel.b, 0.5), Color(sel.r, sel.g, sel.b, 0.0))
	# .vd-chip, .vd-idx
	var fs := 12.0 * u
	var y0 := inr.position.y + 14.0
	var cw := tx(inr.position.x + 18.0, y0 + fs, chip_key, fs, M.th("dim"), _f700, 0.28)
	var bx := inr.position.x + 18.0 + cw + 8.0
	var bw2 := w_of(_f700, chip, roundi(fs), fs * 0.28) + 20.0
	var br := Rect2(bx, y0 - 3.0, bw2, fs + 8.0)
	var cc := M.th("ink")
	match chip_cls:
		"own":
			cc = M.th("good")
			poly(chamf_tl_br(br, 6.0), M.cm("good", 12.0))
		"eq":
			cc = Color("#111")
			poly(chamf_tl_br(br, 6.0), M.th("sel"))
		_:
			poly(chamf_tl_br(br, 6.0), M.cm("edge", 20.0))
	tx(bx + 10.0, y0 + fs, chip, fs, cc, _f700, 0.28)
	var rx := inr.end.x - 18.0
	var wr := tx(rx, y0 + fs, idx_rest, fs, M.th("dim"), _f700, 0.3, "r")
	tx(rx - wr - 4.0, y0 + fs, idx_b, fs * 1.35, M.th("ink"), _f700, 0.3, "r")
	if not small:      # .vd-cap
		var fc := 10.0 * u
		var d := M.th("dim")
		d.a *= 0.8
		var by := inr.end.y - 12.0
		tx(inr.position.x + 18.0, by, cap_l, fc, d, _f600, 0.32)
		tx(inr.end.x - 18.0, by, cap_r, fc, d, _f600, 0.32, "r")
	# .vd-stamp: 1.5 s
	var ats: float = M.anim.get("stamp", 9.0)
	if ats < 1.5:
		var pct := ats / 1.5
		var a := 1.0
		var sc := 1.0
		if pct < 0.12:
			a = pct / 0.12
			sc = lerpf(1.25, 1.0, a)
		elif pct > 0.8:
			var q := (pct - 0.8) / 0.2
			a = 1.0 - q
			sc = lerpf(1.0, 0.97, q)
		var f1 := 22.0 * u
		var f2 := 12.0 * u
		var w1 := w_of(_forb, stamp_top, roundi(f1), f1 * 0.24)
		var w2 := w_of(_f700, stamp_sub, roundi(f2), f2 * 0.34)
		var sw := (maxf(w1, w2) + 60.0) * sc
		var sh := (f1 * 1.1 + 3.0 + f2 * 1.2 + 20.0) * sc
		var ctr := inr.position + inr.size / 2.0
		var sr := Rect2(ctr - Vector2(sw, sh) / 2.0, Vector2(sw, sh))
		var old := ga
		ga *= a
		poly(hex_h(sr, 16.0), M.th("sel"))
		poly(hex_h(sr.grow(-2.0), 15.0), Color8(6, 8, 10, 230))
		tx(ctr.x, sr.position.y + 10.0 * sc + f1 * sc, stamp_top, f1 * sc, M.th("sel"), _forb, 0.24, "c")
		tx(ctr.x, sr.end.y - 10.0 * sc, stamp_sub, f2 * sc, M.th("ink"), _f700, 0.34, "c")
		ga = old


## the wiggle of the "deny" shake (vdshake) on a price
func deny_dx() -> float:
	var a: float = M.anim.get("deny", 9.0)
	if a >= 0.3:
		return 0.0
	var q := a / 0.3
	if q < 0.25:
		return lerpf(0.0, -5.0, q / 0.25)
	if q < 0.55:
		return lerpf(-5.0, 4.0, (q - 0.25) / 0.3)
	if q < 0.8:
		return lerpf(4.0, -2.0, (q - 0.55) / 0.25)
	return lerpf(-2.0, 0.0, (q - 0.8) / 0.2)


## .val / .big in their "deny" and "paid" flashes
func price_col(base: Color) -> Color:
	var ad: float = M.anim.get("deny", 9.0)
	if ad < 0.3 and ad / 0.3 < 0.55:
		return M.th("bad")
	var ap: float = M.anim.get("paid", 9.0)
	if ap < 0.5:
		return M.th("sel").lerp(base, ap / 0.5)
	return base


func _draw() -> void:
	_hits.clear()
	clip_b = 1e9
	ga = 1.0
	_draw_head()
	ga = M.main_a if false else main_a
	draw_set_transform(Vector2.ZERO)
	M.draw_main(self, r_main)
	clip_b = 1e9
	ga = 1.0
	_draw_car()
	_draw_prompts()
	# .vd-flash
	var af: float = M.anim.get("flash", 9.0)
	if af < 0.38:
		var q := af / 0.38
		var op := q / 0.18 if q < 0.18 else 1.0 - (q - 0.18) / 0.82
		var sel := M.th("sel")
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(-1.5), Color(sel.r, sel.g, sel.b, op), false, 3.0)
		for i in 5:
			var a := (5 - i) / 5.0
			draw_rect(r.grow(-14.0 * i - 7.0), Color(sel.r, sel.g, sel.b, 0.4 * op * a * 0.3), false, 14.0)


func _draw_head() -> void:
	var u := M.u
	ga = head_a
	draw_set_transform(Vector2(0, head_y))
	var fs := 12.0 * u
	var base := CrtTheme.baseline(_f600, roundi(fs), r_head.position.y, r_head.size.y)
	var x := r_head.position.x + 6.0
	x += tx(x, base, M.sub_a + " ", fs, M.th("dim"), _f600, 0.32)
	x += tx(x, base, "// ", fs, M.th("ink2"), _f700, 0.32)
	tx(x, base, M.sub_c, fs, M.th("dim"), _f600, 0.32)
	# the balance
	var fb := 26.0 * u
	var fsm := 11.0 * u
	var sw := w_of(_f700, "BALANCE", roundi(fsm), fsm * 0.3)
	var bh := 6.0 * u * 2.0 + fb
	var bw := 16.0 * u + 18.0 * u + 12.0 + sw + 12.0 + 5.2 * fb + 22.0 * u
	var r := Rect2(r_head.end.x - bw, r_head.position.y + (r_head.size.y - bh) / 2.0, bw, bh)
	var t := M.theme_id == "weapon"
	poly(hex_h(r, 14.0), M.th("steel_hi") if t else M.th("edge"))
	poly_grad(hex_h(r.grow(-2.0), 13.0), M.th("glass2"), Color(0, 0, 0, 0.92))
	var cy := r.position.y + bh / 2.0
	var dc: Color = M.th("sel") if t else M.th("edge")
	var dx := r.position.x + 16.0 * u + 9.0 * u
	var d := 9.0 * u * 1.41
	draw_colored_polygon(PackedVector2Array([Vector2(dx, cy - d), Vector2(dx + d, cy), Vector2(dx, cy + d), Vector2(dx - d, cy)]), c(dc))
	var q := d * 0.62
	draw_colored_polygon(PackedVector2Array([Vector2(dx, cy - q), Vector2(dx + q, cy), Vector2(dx, cy + q), Vector2(dx - q, cy)]), c(M.th("glass2")))
	var q2 := d * 0.34
	draw_colored_polygon(PackedVector2Array([Vector2(dx, cy - q2), Vector2(dx + q2, cy), Vector2(dx, cy + q2), Vector2(dx - q2, cy)]), c(dc))
	var sx := r.position.x + 16.0 * u + 18.0 * u + 12.0
	tx(sx, CrtTheme.baseline(_f700, roundi(fsm), r.position.y, bh), "BALANCE", fsm, M.th("dim"), _f700, 0.3)
	var bc: Color = M.th("sel") if not M.bal.is_empty() else M.th("ink")
	tx(r.end.x - 22.0 * u, CrtTheme.baseline(_f700, roundi(fb), r.position.y, bh), CrtTheme.money(M.bal_shown), fb, bc, _f700, 0.05, "r")
	draw_set_transform(Vector2.ZERO)


func _draw_car() -> void:
	var u := M.u
	_layout_car(false)
	ga = car_a
	draw_set_transform(Vector2(0, car_y))
	var steel := M.th("steel")
	var aw := 34.0 * u
	var ah := 60.0 * u
	var ay := r_car.position.y + (r_car.size.y - ah) / 2.0
	var ax := r_car.position.x + 10.0 * u
	var kl := 0.86 if float(M.anim.get("kick0", 9.0)) < 0.09 else 1.0
	var kr := 0.86 if float(M.anim.get("kick1", 9.0)) < 0.09 else 1.0
	var mcy := ay + ah / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(ax + aw * (0.5 + 0.5 * kl), mcy - ah / 2.0 * kl), Vector2(ax + aw * (0.5 + 0.5 * kl), mcy + ah / 2.0 * kl), Vector2(ax + aw * (0.5 - 0.5 * kl), mcy)]), c(steel))
	add_hit(Rect2(ax, ay, aw, ah), "prev")
	var rxx := r_car.end.x - 10.0 * u - aw
	draw_colored_polygon(PackedVector2Array([Vector2(rxx + aw * (0.5 - 0.5 * kr), mcy - ah / 2.0 * kr), Vector2(rxx + aw * (0.5 + 0.5 * kr), mcy), Vector2(rxx + aw * (0.5 - 0.5 * kr), mcy + ah / 2.0 * kr)]), c(steel))
	add_hit(Rect2(rxx, ay, aw, ah), "next")
	# the track
	var vx := r_cview.position.x
	var ty := r_cview.position.y + 12.0 * u
	var edge := M.th("edge")
	for i: int in _order:
		var sx := vx + M.track_x + slot_x(i)
		if sx + slot_w < vx - 8.0 or sx > r_cview.end.x + 8.0:
			continue
		var e := M.slots_s[i] if i < M.slots_s.size() else 0.0
		var scale_ := lerpf(0.94, 1.06, e)
		var dy := lerpf(6.0, -2.0, e)
		var op := lerpf(0.62, 1.0, e)
		var old := ga
		ga = car_a * op
		var w := slot_w * scale_
		var h := slot_h * scale_
		var r := Rect2(sx + (slot_w - w) / 2.0, ty + dy + (slot_h - h) / 2.0, w, h)
		var edge_c: Color = (M.th("sel") if M.theme_id == "weapon" else edge) if i == M.sel else M.cm("edge", 32.0)
		# (only what lies inside the carousel's view is drawn whole: the view's own edge fades it)
		poly(chamf_tl_br(r, 10.0), edge_c)
		var top: Color = M.th("well").lerp(edge, 0.22) if i == M.sel else M.th("well")
		poly_grad(chamf_tl_br(r.grow(-1.0), 9.5), top, M.th("glass2"))
		M.draw_slot(self, M.items[i], i, r)
		add_hit(r, "slot", i)
		ga = old
	# the bracket
	var bx := vx + M.bracket_x
	var bs := 1.0
	var asn: float = M.anim.get("snap", 9.0)
	if asn < 0.16:
		bs = lerpf(1.12, 1.0, CrtTheme.bezier(asn / 0.16, 0.2, 0.9, 0.3, 1.0))
	var br := Rect2(bx, ty, slot_w, slot_h)
	var bc := br.get_center()
	br = Rect2(bc - br.size * bs / 2.0, br.size * bs)
	var sel := M.th("sel")
	var cw := 20.0
	var ch := 16.0
	for q: Array in [[br.position.x - 9.0, br.position.y - 11.0, 1, 1], [br.end.x + 9.0, br.position.y - 11.0, -1, 1], [br.position.x - 9.0, br.end.y + 11.0, 1, -1], [br.end.x + 9.0, br.end.y + 11.0, -1, -1]]:
		var p := Vector2(q[0], q[1])
		draw_polyline(PackedVector2Array([p + Vector2(0, ch * q[3]), p, p + Vector2(cw * q[2], 0)]), c(sel), 3.0)
	var fl := 12.0 * u
	var lbl := M.slot_label()
	var lw := w_of(_f700, lbl, roundi(fl), fl * 0.22) + 24.0
	var lr := Rect2(bc.x - lw / 2.0, br.end.y + 9.0, lw, fl + 6.0)
	poly(hex_h(lr, 6.0), sel)
	tx(bc.x, CrtTheme.baseline(_f700, roundi(fl), lr.position.y, lr.size.y), lbl, fl, Color("#111"), _f700, 0.22, "c")
	draw_set_transform(Vector2.ZERO)
	ga = 1.0


func _draw_prompts() -> void:
	var u := M.u
	ga = prompt_a
	draw_set_transform(Vector2(0, prompt_y))
	var fs := 13.0 * u
	var sp := fs * 0.18
	var list: Array = M.prompts(M.dev)
	var total := 0.0
	var isz := roundi(fs)
	var widths: Array[float] = []
	for p: Array in list:
		var w := 0.0
		for kk: String in p[0]:
			w += _chip_w(kk, fs) + 8.0
		w += w_of(_f700, p[1], isz, sp)
		widths.append(w)
		total += w
	total += 22.0 * u * maxf(0.0, list.size() - 1.0)
	var x := r_prompts.position.x + (r_prompts.size.x - total) / 2.0
	var cy := r_prompts.position.y + r_prompts.size.y / 2.0
	var base := CrtTheme.baseline(_f700, isz, r_prompts.position.y, r_prompts.size.y)
	for i in list.size():
		var p: Array = list[i]
		var x0 := x
		for kk: String in p[0]:
			x += key_chip(x, cy, kk, fs) + 8.0
		tx(x, base, p[1], fs, M.th("ink2"), _f700, 0.18)
		if p.size() > 2:
			add_hit(Rect2(x0, r_prompts.position.y - 3.0, widths[i], r_prompts.size.y + 6.0), p[2])
		x = x0 + widths[i] + 22.0 * u
	draw_set_transform(Vector2.ZERO)
	ga = 1.0


func _chip_w(k: String, sz: float) -> float:
	var fs := sz * 0.92
	if M.dev == "pad":
		if ["A", "B", "X", "Y"].has(k):
			return fs * 1.8
		return maxf(fs * 2.4, w_of(_f700, k, maxi(4, roundi(fs)), fs * 0.04) + 10.0)
	return maxf(fs * 1.9, w_of(_f700, k, maxi(4, roundi(fs)), fs * 0.04) + 12.0)


## a slot's shared bits: number top-left, badge bottom-right, the equipped diamond top-right
func slot_marks(r: Rect2, num: String, badge: String, badge_cls: String, cur: bool) -> void:
	var u := M.u
	var fs := 10.0 * u
	tx(r.position.x + 8.0, r.position.y + 4.0 + fs, num, fs, M.th("dim"), _f700, 0.1)
	var col: Color = M.th("good") if badge_cls == "own" else (Color(M.th("bad"), 0.85) if badge_cls == "poor" else M.th("dim"))
	tx(r.end.x - 6.0, r.end.y - 4.0, badge, fs, col, _f700, 0.14, "r")
	if cur:
		var ctr := Vector2(r.end.x - 9.5, r.position.y + 7.5)
		var d := 5.0
		draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -d), ctr + Vector2(d, 0), ctr + Vector2(0, d), ctr + Vector2(-d, 0)]), c(M.th("sel")))


func icon(tex: Texture2D, r: Rect2, col: Color) -> void:
	var ts := tex.get_size()
	var bw := r.size.x * 0.78
	var bh := r.size.y * 0.72
	var q := minf(bw / ts.x, bh / ts.y)
	var d := ts * q
	draw_texture_rect(tex, Rect2(r.get_center() - d / 2.0, d), false, c(col))
