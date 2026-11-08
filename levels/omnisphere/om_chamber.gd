class_name OmChamber
extends RefCounted
## OMNISPHERE: the CONTAINMENT CHAMBER (JS chamber.js), the inside of Juniper's drum dressed as the room FOINT drains him in. The art is exported; here: seven capacitor banks (one blows with every cuff you break, the rest when he stands up), the wall-sized output board (falling with every cuff), the grounding-plate stencils (Label3D: exported canvases lose their alpha).

const BANKS := [30, 75, 115, 210, 250, 290, 330]


class Bank:
	var g: Node3D
	var core: Node3D
	var tube: Node3D
	var halo: MeshInstance3D
	var ch: Node3D
	var x := 0.0
	var z := 0.0
	var blown := false
	var ph := 0.0


var lv: ExportedLevel
var sets: OmSets
var audio: OmAudio
var F := 18.0
var banks: Array[Bank] = []
var board: VhKit.Canvas
var output := 98.4
var shown := -1.0
var days := 211
var status := "COMPLIANT"
var t := 0.0
var font_b: Font
var font_m: Font


func _init(p_lv: ExportedLevel, J: Dictionary, p_sets: OmSets, p_audio: OmAudio) -> void:
	lv = p_lv
	sets = p_sets
	audio = p_audio
	F = J.floor
	var root := Node3D.new()
	root.name = "OmChamber"
	lv.add_child(root)
	for i in BANKS.size():
		var a := deg_to_rad(float(BANKS[i]))
		var b := Bank.new()
		b.x = float(J.x) + cos(a) * 24.0
		b.z = float(J.z) + sin(a) * 24.0
		b.g = VhKit.one(lv, "om-bank-%d" % i)
		b.core = VhKit.one(lv, "om-bank-%d-core" % i)
		b.tube = VhKit.one(lv, "om-bank-%d-tube" % i)
		b.ch = VhKit.one(lv, "om-bank-%d-ch" % i)
		b.halo = MsKit.sprite8(root, 0x6dffb8, .55, 7.0)
		b.halo.position = Vector3(b.x, F + 7.6, b.z)
		b.halo.scale.y = 14.0
		b.ph = randf() * 6.0
		banks.append(b)
	font_b = ThemeDB.fallback_font
	font_m = load("res://assets/fonts/VT323-Regular.ttf")
	board = VhKit.Canvas.new(1024, 576, _draw_board)
	lv.add_child(board)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = board.get_texture()
	m.disable_fog = true
	for mi in VhKit.meshes(VhKit.one(lv, "om-board")):
		mi.material_override = m
	# the floor: stencils on the grounding plate
	for d: float in [20.0, 95.0, 245.0, 320.0]:
		var s := Label3D.new()
		s.text = "GROUNDING PLATE  -  OFF THE FLOOR DURING A DRAW"
		s.font_size = 64
		s.pixel_size = 16.0 / 1650.0
		s.modulate = Color(.902, .667, .078, .9)
		s.outline_size = 0
		s.shaded = false
		s.double_sided = true
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		root.add_child(s)
		var ad := deg_to_rad(d)
		s.position = Vector3(float(J.x) + cos(ad) * 39.5, F + .12, float(J.z) + sin(ad) * 39.5)
		s.quaternion = Quaternion.from_euler(Vector3(0, -ad - PI / 2.0, 0)) * Quaternion(Vector3.RIGHT, -PI / 2.0)


func _draw_board(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1024, 576), Color("#04100a"))
	c.draw_rect(Rect2(10, 10, 1004, 556), Color("#1f6b3c"), false, 6.0)
	c.draw_rect(Rect2(10, 10, 1004, 54), Color("#e0a010"))
	c.draw_string(font_b, Vector2(30, 52), "FOINT  //  PROJECT OMNISPHERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#120c09"))
	var col := Color("#ffb43c") if output < 50.0 else Color("#8dffb4")
	var g := Color("#8dffb4")
	c.draw_string(font_m, Vector2(40, 130), "SIPHON OUTPUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, g)
	c.draw_string(font_b, Vector2(40, 290), "%.1f%%" % output, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, col)
	c.draw_rect(Rect2(40, 318, 944, 46), col, false, 4.0)
	c.draw_rect(Rect2(46, 324, 932.0 * output / 100.0, 34), col)
	c.draw_string(font_m, Vector2(40, 430), "ASSET STATUS:  " + status, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, g)
	c.draw_string(font_m, Vector2(40, 486), "DAYS WITHOUT INCIDENT:  %d" % days, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, g)
	c.draw_string(font_m, Vector2(40, 540), "TOMORROW BELONGS TO WHOEVER BUYS IT.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#4fae74"))


func _blow_bank(b: Bank) -> void:
	if b.blown:
		return
	b.blown = true
	b.core.visible = false
	b.tube.visible = false
	MsKit.opa(b.halo, 0.0)
	b.ch.visible = false
	var p := Vector3(b.x, F + 7.0, b.z)
	sets.boom(b.x, F + 7.0, b.z, 6.0, 0.0, {"harmless": true})
	Game.fx.explosion(p, 5.0)
	Game.fx.sparks(p, 60, 14.0, null, 0x9dffd8)
	audio.play_at("emBlow", p)
	for k in 3:
		sets.after(.12 + k * .14, func() -> void: Game.fx.sparks(Vector3(b.x, F + 3.0 + randf() * 9.0, b.z), 14, 8.0, null, 0xd8fff2))


## a wrist cuff came off (n = how many are off now): a bank blows, the board drops
func cuff(n: int) -> void:
	var left: Array[Bank] = []
	for x in banks:
		if not x.blown:
			left.append(x)
	if not left.is_empty():
		_blow_bank(left[(n * 3) % left.size()])
	output = maxf(0.0, [98.4, 71.2, 46.9, 23.1, 4.8][mini(4, n)])
	days = 0
	status = "NON-COMPLIANT" if n >= 2 else "UNDER REVIEW"


## he is up: every bank left goes, the board hits zero
func release() -> void:
	var k := 0
	for x in banks:
		if not x.blown:
			var b := x
			sets.after(.2 + k * .26, func() -> void: _blow_bank(b))
			k += 1
	output = 0.0
	days = 0
	status = "NO LONGER AN ASSET"


func reset(stage: String) -> void:
	var late := stage == "escape"
	for b in banks:
		b.blown = late
		b.core.visible = not late
		b.tube.visible = not late
		b.ch.visible = not late
		MsKit.opa(b.halo, 0.0 if late else .55)
	output = 0.0 if late else 98.4
	days = 0 if late else 211
	status = "NO LONGER AN ASSET" if late else "COMPLIANT"
	shown = -1.0


func update(dt: float) -> void:
	t += dt
	if shown != output:
		shown = output
		board.redraw()
	for b in banks:
		if not b.blown:
			MsKit.opa(b.halo, .4 + .2 * sin(t * 3.0 + b.ph))
			var sc := 1.0 + sin(t * 9.0 + b.ph) * .06
			b.core.scale.x = sc
			b.core.scale.z = sc
