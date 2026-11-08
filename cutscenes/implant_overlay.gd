class_name ImplantOverlay
extends Control
## The implant cutscene's red screen (JS implant-inject.js #implantfx, veinSvg): a branching network of veins creeping in from the screen edges in three thicknesses, a red wash at the edges, a multiply tint, a flash at the needle.

var G := 0.0
var pulse := 1.0
var tint := 0.0
var flash := 0.0
var _groups: Array = [[], [], []]      # per depth: [PackedVector2Array of 0..100 points, delay]
var _wash: ColorRect
var _tint: ColorRect
var _rs := 11


var _flash: ColorRect


func _rnd() -> float:
	_rs = (_rs * 1664525 + 1013904223) & 0xffffffff
	return float(_rs) / 4294967296.0


func _grow(x: float, y: float, ang: float, len_: float, depth: int) -> void:
	var n := 7
	var pts := PackedVector2Array([Vector2(x, y)])
	for i in n:
		ang += (_rnd() - 0.5) * 0.9
		x += cos(ang) * len_ / n
		y += sin(ang) * len_ / n
		pts.append(Vector2(x, y))
		if depth < 2 and i > 1 and _rnd() < 0.3:
			_grow(x, y, ang + (-1.0 if _rnd() < 0.5 else 1.0) * (0.5 + _rnd() * 0.7), len_ * 0.6, depth + 1)
	_groups[depth].append([pts, depth * 0.28 + _rnd() * 0.22])      # a branch starts growing once its parent is partway out


func _init() -> void:
	name = "ImplantOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	for i in 22:
		var e := i % 4
		var u := _rnd() * 100.0
		var len_ := 20.0 + _rnd() * 26.0
		if e == 0:
			_grow(u, -2.0, PI / 2.0 + (_rnd() - 0.5) * 0.8, len_, 0)
		elif e == 1:
			_grow(u, 102.0, -PI / 2.0 + (_rnd() - 0.5) * 0.8, len_, 0)
		elif e == 2:
			_grow(-2.0, u, (_rnd() - 0.5) * 0.8, len_ * 1.1, 0)
		else:
			_grow(102.0, u, PI + (_rnd() - 0.5) * 0.8, len_ * 1.1, 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint = ColorRect.new()
	_tint.color = Color.hex(0xc4000aff)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := CanvasItemMaterial.new()
	mm.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mm
	_tint.show_behind_parent = true
	add_child(_tint)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n// radial-gradient(ellipse at 50% 50%, #7a000000 22%, #8a0008aa 62%, #3a0004ee 100%)\nvoid fragment() {\n\tfloat d = length((UV - 0.5) * 2.0) / sqrt(2.0);\n\tvec4 a = vec4(0.478, 0.0, 0.0, 0.0);\n\tvec4 b = vec4(0.541, 0.0, 0.031, 0.667);\n\tvec4 c = vec4(0.227, 0.0, 0.016, 0.933);\n\tCOLOR = d < 0.22 ? a : (d < 0.62 ? mix(a, b, (d - 0.22) / 0.4) : mix(b, c, (d - 0.62) / 0.38));\n}\n"
	var wm := ShaderMaterial.new()
	wm.shader = sh
	_wash.material = wm
	add_child(_wash)      # (the JS's order: tint, veins, wash, flash: the wash lies over the veins)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(Color.hex(0xff2a2aff), 0.0)
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	# (a multiply layer ignores alpha here: its strength, the tint's own opacity times the group's, goes into how far it is from white)
	var tk := clampf(tint * modulate.a, 0.0, 1.0)
	_tint.color = Color(lerpf(1.0, 0.769, tk), lerpf(1.0, 0.0, tk), lerpf(1.0, 0.039, tk))
	var vs := size
	var sx := vs.x / 100.0
	var sy := vs.y / 100.0
	var widths := [0.9, 0.55, 0.3]
	var col := Color.hex(0xb0121aff)
	var glow := Color(1.0, 0.1, 0.1, 0.25)
	for d in 3:
		var w: float = widths[d] * pulse * (sx + sy) * 0.5
		for e: Array in _groups[d]:
			var k := clampf(G * 1.7 - float(e[1]), 0.0, 1.0)
			if k <= 0.003:
				continue
			var pts: PackedVector2Array = e[0]
			var draw_n := k * (pts.size() - 1)
			var out := PackedVector2Array()
			for i in floori(draw_n) + 1:
				out.append(Vector2(pts[i].x * sx, pts[i].y * sy))
			var fr := draw_n - floorf(draw_n)
			if fr > 0.0 and floori(draw_n) + 1 < pts.size():
				var q := pts[floori(draw_n)].lerp(pts[floori(draw_n) + 1], fr)
				out.append(Vector2(q.x * sx, q.y * sy))
			if out.size() >= 2:
				draw_polyline(out, glow, w * 3.0, true)
				draw_polyline(out, col, maxf(w, 1.0), true)
	_flash.color.a = flash
