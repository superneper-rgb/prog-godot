class_name SigilFace
extends Control
## The Sigil's face: phosphor lines, as a 1990s machine would draw a face, that watches you and moves its mouth, over the words it came up with. Drawn to whatever size it is given, so the same face is on the
## little set in its cell (levels/underfoint/sigil_screen.gd) and filling the glass of the terminal when it speaks (ui/sigil_terminal.gd). `look`: where the eyes go (-1 .. 1); `speaking`: 0 .. 1 opens the mouth.
## A placeholder for the Sigil's real face, which is the user's.

const GREEN := Color(0.35, 1.0, 0.45)
## the head's outline, then the lines inside it (pairs), about the face's middle, in a 240-high picture
const HEAD: Array[Vector2] = [Vector2(-52, -70), Vector2(0, -84), Vector2(52, -70), Vector2(66, -20), Vector2(56, 40), Vector2(28, 78), Vector2(0, 88), Vector2(-28, 78), Vector2(-56, 40), Vector2(-66, -20)]
const WIRES: Array[Vector2] = [Vector2(-52, -70), Vector2(-20, -30), Vector2(52, -70), Vector2(20, -30), Vector2(-66, -20), Vector2(-20, -30), Vector2(66, -20), Vector2(20, -30), Vector2(-20, -30), Vector2(20, -30),
	Vector2(0, -84), Vector2(0, -30), Vector2(-20, -30), Vector2(-12, 20), Vector2(20, -30), Vector2(12, 20), Vector2(-12, 20), Vector2(12, 20), Vector2(-56, 40), Vector2(-12, 20), Vector2(56, 40), Vector2(12, 20),
	Vector2(-28, 78), Vector2(-22, 50), Vector2(28, 78), Vector2(22, 50), Vector2(-56, 40), Vector2(-22, 50), Vector2(56, 40), Vector2(22, 50)]

var look := 0.0
var tint := GREEN                        # the phosphor: green, or amber when it is angry
var speaking := 0.0
var caption := "HIVE NODE ACTIVATED"      # "" = none (the terminal has its own text)
var backdrop := true                      # fill behind the face and rule the tube's lines over it (the set's own glass; the terminal's CRT shader does this itself)
var _mouth := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	_mouth += (speaking - _mouth) * minf(1.0, dt * 10.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var k := size.y / 240.0
	if backdrop:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.035, 0.012))
	var tear := 6.0 * k * (randf() - 0.5) if fmod(t, 3.7) < 0.12 else 0.0      # the picture slips now and then
	var c := Vector2(size.x * 0.5 + tear, (104.0 + sin(t * 0.6) * 2.0) * k)
	var dim := tint * Color(1, 1, 1, 0.55)
	var pts := PackedVector2Array()
	for p in HEAD:
		pts.append(c + p * k)
	pts.append(c + HEAD[0] * k)
	draw_polyline(pts, tint, 2.0 * k, true)
	var i := 0
	while i < WIRES.size():
		draw_line(c + WIRES[i] * k, c + WIRES[i + 1] * k, dim, 1.2 * k, true)
		i += 2
	var blink := 0.15 if fmod(t, 4.3) < 0.14 else 1.0
	for s: float in [-1.0, 1.0]:      # the eyes: a lozenge each, and what looks out of it
		var e := c + Vector2(s * 31.0, -11.0) * k
		draw_polyline(PackedVector2Array([e + Vector2(-17, 0) * k, e + Vector2(0, -8 * blink) * k, e + Vector2(17, 0) * k, e + Vector2(0, 8 * blink) * k, e + Vector2(-17, 0) * k]), tint, 1.6 * k, true)
		draw_circle(e + Vector2(look * 8.0, 0.0) * k, 4.2 * blink * k, tint)
	var open := _mouth * (3.0 + 9.0 * absf(sin(t * 9.0)) * (0.5 + 0.5 * sin(t * 2.7))) + 1.5
	draw_polyline(PackedVector2Array([c + Vector2(-22, 50) * k, c + Vector2(0, 47) * k, c + Vector2(22, 50) * k]), tint, 1.6 * k, true)
	draw_polyline(PackedVector2Array([c + Vector2(-22, 50) * k, c + Vector2(-8, 50 + open) * k, c + Vector2(8, 50 + open) * k, c + Vector2(22, 50) * k]), tint, 1.6 * k, true)
	if caption != "":
		draw_string(ThemeDB.fallback_font, Vector2(14.0 * k + tear, 222.0 * k), caption + ("_" if fmod(t, 1.0) < 0.5 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(15.0 * k), tint)
	if backdrop:
		var y := 0.0
		while y < size.y:      # the tube's lines, and the bar that rolls down it
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.38), 1.0)
			y += 3.0
		draw_rect(Rect2(0, fmod(t * 46.0, size.y + 60.0) - 30.0, size.x, 22.0), Color(0.35, 1.0, 0.45, 0.07))
