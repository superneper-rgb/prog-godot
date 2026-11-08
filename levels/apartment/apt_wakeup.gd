class_name AptWakeup
extends Node
## PROG'S APARTMENT: THE WAKE-UP (JS levels/apartment/wakeup.js; console only in the JS: `cutscene play apartment-wakeup`, Prog only).
##   1. the flat at night: slow camera moves over the kitchen, the coffee table, the rain on the big window, then into the bedroom where he is asleep
##   2. the phone rings on the nightstand; he wakes, sits up and swings his legs off the bed
##   3. still ringing: he finishes the beer on the nightstand (burp), lights a cigarette from the pack on the bed
##   4. picks the phone up: "Go." -- the Boss on the line (subtitles in the shared box); a face close-up and a long drag at "Tommy's MIA."; a drink from a second bottle, "I'll think about it.", and he hangs up on the Boss mid-sentence and stands up
##   5. into the living room, onto the couch: the wallet, the photo of him and Tommy (rendered from the real character models), another drag
##   6. the closet: a suitcase out onto the bed; it opens and expands: two silenced pistols and an SMG; he loads them
##   7. out of the front door, which shuts behind him; fade, and the level door to the hub takes over
## It runs on the level `cine` hook: while `on`, the player gets no input and is not simulated, the frame renders from `camera`, and pose_player(animator) is called after the animator's update. The body, the hands (the animator's own two-bone IK), the props and the camera are all functions of the cutscene clock, so skipping (X / Enter / Space, pad B) and seek(t) just move the clock. Skipping goes straight to the hand-off. Everything it builds lives under its own node in the level and goes with it.

const BOSS := {"name": "BOSS", "color": "#ff6b5e", "rate": 23.0, "pitch": 108.0, "phone": true}
const PROG := {"name": "PROG", "color": "#9ad1ff", "rate": 15.0, "pitch": 92.0}
const PIV := 0.95                                                                    # Prog's actor origin (his hips) above his feet (BUILDS.prog.pivot)
const BED := {"x0": 1.62, "x1": 3.62, "z0": -2.85, "z1": -1.4, "top": 0.55}
const NS := {"x0": 1.62, "x1": 2.05, "z0": -3.4, "z1": -2.95, "top": 0.55}
const CL := {"x0": 5.38, "x1": 5.98, "z0": -2.35, "z1": -1.0, "top": 2.05}
const COUCH_SEAT := 0.45
# where he is: actor origin (hips) and facing. yaw 0 faces +z, PI/2 faces +x
const LIE := {"x": 2.6, "y": 0.55 + 0.2, "z": -2.12, "yaw": PI / 2.0, "pitch": -PI / 2.0 + 0.05}     # on his back, head at the headboard (west)
const UP := {"x": 2.3, "y": 0.55 + 0.21, "z": -2.15, "yaw": PI / 2.0}                                  # sat up in bed, legs out along it
const EDGE := {"x": 2.3, "y": 0.55 + 0.21, "z": -2.64, "yaw": PI}                                    # on the side of the bed, feet on the floor
const COUCH := {"x": -2.9, "y": 0.45 + 0.21, "z": -2.05, "yaw": PI / 2.0}
const SEAT_FEET := 0.44                                                                                  # seated: the feet are this far ahead of the hips
# props at rest (world)
const SPOT := {
	"phone": {"p": Vector3(1.62 + 0.24, 0.55 + 0.008, -2.95 - 0.13), "ry": 0.5},
	"bottle1": {"p": Vector3(2.05 - 0.07, 0.55, -2.95 - 0.07)},
	"bottle2": {"p": Vector3(2.74, 0.55 - 0.01, -2.66)},
	"pack": {"p": Vector3(2.86, 0.55 + 0.012, -2.34), "ry": 0.4}, "lighter": {"p": Vector3(2.98, 0.55 + 0.008, -2.5), "ry": -0.6},
	"phoneBed": {"p": Vector3(1.98, 0.55 + 0.01, -2.42), "ry": 1.9},
	"caseCloset": {"p": Vector3(5.38 + 0.2, 0.12, (-2.35 + -1.0) / 2.0)}, "caseBed": {"p": Vector3(3.3, 0.55 - 0.005, -2.1)},
}
const CASE_L := 0.9      # suitcase: long side along its local z, handle + latches on its +x edge
const CASE_W := 0.55
const CASE_H := 0.2
const HANDLE := Vector3(CASE_W / 2.0 + 0.05, CASE_H / 2.0, 0.0)                                                 # the handle's grip, case-local
const TUNE_MOUTH := Vector3(0.0, 0.06, 0.12)
const TUNE_CIG_AIM := Vector3(0.95, -0.1, 0.1)
const OUT_Z1 := 4.5
const OUT_T := 0.3
const Y := Vector3.UP
const GUNLOC := {"well": {"deagle": Vector3(0.0, -0.2, -0.065), "smg": Vector3(0.0, -0.2, 0.0)}, "slide": {"deagle": Vector3(0.0, 0.035, 0.02), "smg": Vector3(0.0, 0.06, -0.06)}}
const PROP_GRIP := {"bottle1": "bottle", "bottle2": "bottle", "phone": "phone", "cig": "cig", "lighter": "lighter", "wallet": "wallet", "mag_p1": "mag", "mag_p2": "mag", "mag_smg": "mag"}
const PATH := {
	"bedOut": [Vector2(2.3, -3.06), Vector2(3.98, -3.08), Vector2(4.12, -1.05), Vector2(2.72, 0.25), Vector2(2.72, 1.35)],
	"toCouch": [Vector2(2.3, 2.52), Vector2(1.0, 2.52), Vector2(-0.2, 1.2), Vector2(-1.95, -0.55), Vector2(-2.46, -2.05)],
	"couchOut": [Vector2(-2.46, -2.05), Vector2(-1.95, -0.55), Vector2(-0.2, 1.2), Vector2(1.0, 2.52), Vector2(2.1, 2.52)],
	"toCloset": [Vector2(2.72, 1.75), Vector2(2.72, 0.25), Vector2(4.05, -1.05), Vector2(4.95, -1.68)],
	"toCase": [Vector2(4.95, -1.68), Vector2(3.98, -2.1)],
	"caseOut": [Vector2(3.98, -2.1), Vector2(4.12, -1.05), Vector2(2.72, 0.25), Vector2(2.72, 1.35)],
	"toDoor": [Vector2(2.0, 2.52), Vector2(0.9, 2.62), Vector2(-0.35, 3.45), Vector2(-0.76, 3.8)],
	"outDoor": [Vector2(-0.76, 3.8), Vector2(-0.95, 4.25), Vector2(-0.95, 5.55)],
}
## where each prop is when no holder has taken it yet
const DEFAULT_HOLD := {"bottle1": {"rest": "bottle1"}, "bottle2": {"rest": "bottle2"}, "phone": {"rest": "phone"}, "pack": {"rest": "pack"}, "lighter": {"rest": "lighter"}, "case": {"rest": "caseCloset"},
	"p1": {"gun": "tray"}, "p2": {"gun": "tray"}, "smg": {"gun": "smgFoam"}, "mag_p1": {"magTray": "p1"}, "mag_p2": {"magTray": "p2"}, "mag_smg": {"magTray": "smg"}}


## the body: where he is and how bent
class St:
	var ox := 0.0
	var oy := PIV
	var oz := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var hip := 0.0
	var knee := 0.0
	var lean := 0.0
	var lie := 0.0
	var dy := 0.0
	var px := 0.0
	var pz := 0.0
	var vx := 0.0
	var vz := 0.0
	var walk := false


class IkS:
	var p := Vector3.ZERO
	var w := 0.0
	var name := ""
	var u := 0.0
	var next := ""


class Placed:
	var i := -2
	var fp := Vector3.ZERO
	var fq := Quaternion.IDENTITY
	var t := 0.0


## one smoke puff (a slot of the MultiMesh)
class Puff:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var age := 9.0
	var life := 1.0
	var s0 := 0.05
	var gr := 0.3
	var op := 0.2


## the photo's white border, crease, date stamp and caption (JS the 2D canvas it is printed on)
class PrintTop:
	extends Control
	const B := 18.0
	const W := 384.0
	const H := 288.0
	var mono: SystemFont
	var ser: SystemFont

	func _draw() -> void:
		draw_line(Vector2(B + W * 0.62, B), Vector2(B + W * 0.55, B + H), Color(1, 1, 1, 0.35), 2.0)
		mono = SystemFont.new()      # (kept: the draw refers to the font's atlas)
		mono.font_names = PackedStringArray(["Courier New", "monospace"])
		mono.font_weight = 700
		draw_string(mono, Vector2(B + W - 104.0, B + H - 12.0), "'99 6 14", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ff8a2a"))
		ser = SystemFont.new()
		ser.font_names = PackedStringArray(["Georgia", "serif"])
		ser.font_italic = true
		draw_string(ser, Vector2(B + 6.0, H + B * 2.0 + 22.0 - 10.0), "me + tommy", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#5a4a3a"))


var on := false
var camera := View.Shot.new()
var t := 0.0
var hold := false      # JS TUNE.hold: the clock stands still (tests)
var _level: ExportedLevel
var _ei := 0
var _leaving := false
var _skip_at := -1.0
var _st: St = null
var _ember := 0.0
var _flame := 0.0
var _exhale := 0.0
var _ringing := false
var _kick := 0.0
var _snap_hands := false
var _dt := 0.0
var TL := {}
var _ev: Array = []
var g: Node3D = null
var P: Player = null
var an: Animator = null
var _hooked: Animator = null
var _line: Variant = null
var _tv_was := false
var _prev_armed: Variant = null
var _photo: Node3D = null
var PR := {}
var _smoke: Array[Puff] = []
var _smoke_n := 0
var _wisp_t := 0.0
var _smoke_mm: MultiMesh
var _cig_ember: MeshInstance3D
var _cig_glow: MeshInstance3D
var _flame_n: MeshInstance3D
var _flame_core: MeshInstance3D
var _phone_screen: MeshInstance3D
var _guns := {}
var _kase := {}
var _hall_tube: MeshInstance3D
var _hall_light: OmniLight3D
var _front_door: Node3D = null
var _fade: ColorRect = null
var _hint: Label = null
var _hint_t := 0.0
var _order := 0
var hands := HandPose.new()
var _ik_s := {"R": IkS.new(), "L": IkS.new()}
var _palm_off := {"R": Vector3.ZERO, "L": Vector3.ZERO}
var _placed := {}
# frame-local geometry
var O := Vector3.ZERO
var BF := Vector3.FORWARD
var BR := Vector3.RIGHT
var HEAD := Vector3.ZERO
# the photo while it prints
var _ph_vp: SubViewport = null
var _ph_print: SubViewport = null
var _ph_frames := 0
var _ph_made: Array = []
var _pose_i := {}


func _init(level: ExportedLevel) -> void:
	name = "AptWakeup"
	_level = level


static func _win(x: float, a: float, b: float) -> float:
	return Cutscene.ease_((x - a) / (b - a))


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


# ==================================================== sounds (the game's Sfx helpers)
func _snd(k: String, parts: Array) -> void:
	CineParts.play(CineParts.sound("wk." + k, parts))


func _s_ring() -> void:
	var p := []
	for i in 10:
		var f := 1568.0 if i % 2 == 1 else 1175.0
		p.append(["t", i * 0.085, 0.07, f, f, {"type": "square", "gain": 0.06, "wet": 0.25}])
	p.append(["n", 0.0, 0.9, {"type": "bandpass", "f0": 160.0, "q": 3.0, "gain": 0.12, "wet": 0.1}])      # chirp + the buzz on the wood
	_snd("ring", p)


func _s_click() -> void:
	_snd("click", [["n", 0.0, 0.03, {"type": "highpass", "f0": 2500.0, "gain": 0.3, "wet": 0.05}], ["t", 0.0, 0.04, 900.0, 500.0, {"type": "square", "gain": 0.06, "wet": 0.05}]])


func _s_beep() -> void:
	_snd("beep", [["t", 0.0, 0.09, 520.0, 520.0, {"type": "sine", "gain": 0.09, "wet": 0.1}], ["t", 0.1, 0.12, 390.0, 390.0, {"type": "sine", "gain": 0.09, "wet": 0.1}]])


func _s_rustle(d: float = 0.25) -> void:
	_snd("rustle%.2f" % d, [["n", 0.0, d, {"type": "bandpass", "f0": 1400.0, "f1": 700.0, "q": 0.8, "gain": 0.1, "wet": 0.08, "attack": 0.08}]])


func _s_sheets() -> void:
	_snd("sheets", [["n", 0.0, 1.1, {"type": "bandpass", "f0": 900.0, "f1": 500.0, "q": 0.6, "gain": 0.12, "wet": 0.15, "attack": 0.3}]])


func _s_groan() -> void:
	_snd("groan", [["t", 0.0, 0.9, 120.0, 92.0, {"type": "sawtooth", "gain": 0.05, "wet": 0.2}], ["n", 0.0, 0.9, {"type": "bandpass", "f0": 500.0, "q": 2.0, "gain": 0.04, "attack": 0.2, "wet": 0.2}]])


func _s_clink() -> void:
	_snd("clink", [["t", 0.0, 0.25, 2350.0, 2300.0, {"type": "sine", "gain": 0.05, "wet": 0.3}], ["t", 0.0, 0.18, 3900.0, 3850.0, {"type": "sine", "gain": 0.025, "wet": 0.3}]])


func _s_glug() -> void:
	var p := []
	for i in 3:
		p.append(["t", i * 0.16, 0.12, 210.0 + i * 25.0, 120.0, {"type": "sine", "gain": 0.12, "wet": 0.1}])
		p.append(["n", i * 0.16, 0.08, {"type": "lowpass", "f0": 600.0, "gain": 0.08, "wet": 0.05}])
	_snd("glug", p)


func _s_burp() -> void:
	_snd("burp", [["t", 0.0, 0.55, 96.0, 70.0, {"type": "sawtooth", "gain": 0.16, "wet": 0.2}], ["t", 0.0, 0.55, 190.0, 140.0, {"type": "square", "gain": 0.03, "wet": 0.2}], ["n", 0.0, 0.5, {"type": "bandpass", "f0": 420.0, "f1": 260.0, "q": 2.5, "gain": 0.12, "attack": 0.03, "wet": 0.2}]])


func _s_crinkle() -> void:
	var p := []
	for i in 7:
		p.append(["n", i * 0.035 + randf() * 0.02, 0.03, {"type": "highpass", "f0": 3500.0 + randf() * 2500.0, "gain": 0.1, "wet": 0.03}])
	_snd("crinkle", p)


func _s_flick() -> void:
	_snd("flick", [["n", 0.0, 0.04, {"type": "highpass", "f0": 4200.0, "gain": 0.3, "wet": 0.05}], ["t", 0.02, 0.05, 2400.0, 1600.0, {"type": "square", "gain": 0.04, "wet": 0.05}], ["n", 0.07, 0.35, {"type": "bandpass", "f0": 1200.0, "f1": 600.0, "q": 0.8, "gain": 0.08, "attack": 0.04, "wet": 0.05}]])


func _s_shut() -> void:
	_snd("shut", [["t", 0.0, 0.04, 3000.0, 2000.0, {"type": "square", "gain": 0.06, "wet": 0.05}], ["n", 0.0, 0.03, {"type": "highpass", "f0": 3000.0, "gain": 0.2, "wet": 0.05}]])


func _s_drag(d: float = 0.8) -> void:
	var p := [["n", 0.0, d, {"type": "bandpass", "f0": 2200.0, "f1": 3400.0, "q": 0.9, "gain": 0.09, "attack": d * 0.6, "wet": 0.05}]]
	for i in 8:
		p.append(["n", 0.1 + i * d * 0.1 + randf() * 0.03, 0.025, {"type": "highpass", "f0": 5000.0, "gain": 0.08, "wet": 0.02}])
	_snd("drag%.2f" % d, p)


func _s_breath_out() -> void:
	_snd("breathOut", [["n", 0.0, 1.3, {"type": "bandpass", "f0": 1600.0, "f1": 900.0, "q": 0.7, "gain": 0.1, "attack": 0.25, "wet": 0.12}]])


func _s_creak(len_: float = 0.9) -> void:
	_snd("creak%.2f" % len_, [["t", 0.0, len_, 340.0, 190.0, {"type": "sawtooth", "gain": 0.04, "wet": 0.3}], ["n", 0.0, len_, {"type": "bandpass", "f0": 600.0, "f1": 350.0, "q": 4.0, "gain": 0.06, "attack": 0.1, "wet": 0.25}]])


func _s_thud() -> void:
	_snd("thud", [["t", 0.0, 0.14, 120.0, 55.0, {"gain": 0.14, "wet": 0.15}], ["n", 0.0, 0.1, {"type": "lowpass", "f0": 900.0, "gain": 0.12, "wet": 0.1}]])


func _s_latch() -> void:
	_snd("latch", [["n", 0.0, 0.03, {"type": "bandpass", "f0": 3000.0, "q": 5.0, "gain": 0.4, "wet": 0.1}], ["t", 0.0, 0.06, 700.0, 420.0, {"type": "square", "gain": 0.07, "wet": 0.1}]])


func _s_whirr() -> void:
	var p := [["t", 0.0, 1.1, 180.0, 420.0, {"type": "sawtooth", "gain": 0.025, "wet": 0.15}], ["n", 0.0, 1.1, {"type": "bandpass", "f0": 1800.0, "f1": 2600.0, "q": 3.0, "gain": 0.04, "wet": 0.1}]]
	for i in 4:
		p.append(["n", 0.25 + i * 0.22, 0.03, {"type": "bandpass", "f0": 2600.0, "q": 4.0, "gain": 0.25, "wet": 0.1}])
	_snd("whirr", p)


func _s_clack() -> void:
	_snd("clack", [["n", 0.0, 0.05, {"type": "bandpass", "f0": 1800.0, "q": 2.0, "gain": 0.3, "wet": 0.1}], ["t", 0.0, 0.08, 260.0, 120.0, {"gain": 0.2, "wet": 0.12}]])


func _s_rl(id: String, ph: String) -> void:
	Game.sfx.play("rl", {"id": id, "ph": ph, "kind": "mag"})


func _s_bolt() -> void:
	_snd("bolt", [["n", 0.0, 0.05, {"type": "bandpass", "f0": 2400.0, "q": 3.0, "gain": 0.35, "wet": 0.15}], ["t", 0.0, 0.07, 500.0, 300.0, {"type": "square", "gain": 0.05, "wet": 0.15}]])


func _s_slam() -> void:
	_snd("slam", [["t", 0.0, 0.3, 90.0, 45.0, {"gain": 0.3, "wet": 0.35}], ["n", 0.0, 0.25, {"type": "lowpass", "f0": 700.0, "gain": 0.3, "wet": 0.35}], ["n", 0.03, 0.04, {"type": "bandpass", "f0": 2800.0, "q": 4.0, "gain": 0.25, "wet": 0.2}]])


func _s_step() -> void:
	_snd("step", [["n", 0.0, 0.06, {"type": "lowpass", "f0": 500.0, "gain": 0.08, "wet": 0.1}]])


# ==================================================== props
func _prop(nm: String) -> Node3D:
	var p := Node3D.new()
	p.name = nm
	g.add_child(p)
	PR[nm] = p
	return p


func _bottle(p: Node3D) -> void:
	var glass := CineParts.phong(0x3a2008, {"shininess": 110.0, "specular": 0x8a7a60, "opacity": 0.92})
	var label := CineParts.lam(0xc9b27a)
	var cap := CineParts.lam(0x8a8a86)
	CineParts.cyl(p, 0.034, 0.034, 0.17, 0.0, 0.085, 0.0, glass, 12)
	CineParts.cyl(p, 0.013, 0.034, 0.05, 0.0, 0.195, 0.0, glass, 12)
	CineParts.cyl(p, 0.013, 0.013, 0.06, 0.0, 0.25, 0.0, glass, 10)
	CineParts.cyl(p, 0.0345, 0.0345, 0.07, 0.0, 0.09, 0.0, label, 12)
	CineParts.cyl(p, 0.014, 0.014, 0.008, 0.0, 0.283, 0.0, cap, 10)


func _make_props() -> void:
	_bottle(_prop("bottle1"))
	_bottle(_prop("bottle2"))
	var pn := _prop("phone")
	CineParts.box(pn, 0.08, 0.16, 0.014, 0.0, 0.0, 0.0, CineParts.phong(0x15161a, {"shininess": 90.0}))
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.145)
	_phone_screen = CineParts.mesh(pn, qm, CineParts.basic(0x0a0f12), 0.0, 0.0, 0.0075)
	pn.scale = Vector3.ONE * 1.25
	var pk := _prop("pack")
	CineParts.box(pk, 0.058, 0.09, 0.022, 0.0, 0.0, 0.0, CineParts.lam(0x9a1b1b))
	CineParts.box(pk, 0.06, 0.03, 0.023, 0.0, 0.032, 0.0, CineParts.lam(0xefeae0))
	pk.scale = Vector3.ONE * 1.3
	var lt := _prop("lighter")
	CineParts.box(lt, 0.026, 0.052, 0.013, 0.0, 0.0, 0.0, CineParts.phong(0xc9ccd2, {"shininess": 100.0}))
	CineParts.box(lt, 0.027, 0.012, 0.0135, 0.0, 0.031, 0.0, CineParts.phong(0x6b6e75))
	_flame_n = CineParts.glow(lt, 0xff9a3a, 0.11)
	_flame_n.position = Vector3(0.0, 0.075, 0.0)
	_flame_core = CineParts.glow(lt, 0xffe9a8, 0.05)
	_flame_core.position = Vector3(0.0, 0.066, 0.0)
	lt.scale = Vector3.ONE * 1.4
	var cg := _prop("cig")      # origin at the filter end, the cigarette points along +y
	CineParts.cyl(cg, 0.0046, 0.0046, 0.026, 0.0, 0.013, 0.0, CineParts.lam(0xd9a066), 8)
	CineParts.cyl(cg, 0.0045, 0.0045, 0.062, 0.0, 0.057, 0.0, CineParts.lam(0xf4f1e8), 8)
	_cig_ember = CineParts.cyl(cg, 0.0047, 0.0047, 0.006, 0.0, 0.0885, 0.0, CineParts.basic(0xff5a1e), 8)
	_cig_glow = CineParts.glow(cg, 0xff6a2a, 0.07)
	_cig_glow.position.y = 0.09
	cg.scale = Vector3.ONE * 1.7
	# (the smoke: JS 80 sprites, one MultiMesh here)
	_smoke_mm = MultiMesh.new()
	_smoke_mm.transform_format = MultiMesh.TRANSFORM_3D
	_smoke_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_smoke_mm.mesh = q
	_smoke_mm.instance_count = 80
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _smoke_mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://cutscenes/cine_glow_mix.gdshader")
	sm.set_shader_parameter(&"col", Color.hex(0xb9bbc2ff))
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 15, 40))
	g.add_child(mmi)
	for i in 80:
		_smoke.append(Puff.new())
		_smoke_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var leather := CineParts.lam(0x3b2414)
	var stitch := CineParts.lam(0x6a4a2a)
	var wl := _prop("wallet")      # a bifold, hinged along its spine (local y); opens by rotating the two halves
	for s: float in [-1.0, 1.0]:
		var h := Node3D.new()
		h.name = "half%d" % int(s)
		wl.add_child(h)
		CineParts.box(h, 0.1, 0.085, 0.007, s * 0.05, 0.0, 0.0, leather)
		CineParts.box(h, 0.096, 0.004, 0.0075, s * 0.05, 0.036, 0.0, stitch)
		wl.set_meta("h_p" if s > 0.0 else "h_m", h)
	wl.scale = Vector3.ONE * 1.35
	_photo = _prop("photo")
	var pq := QuadMesh.new()
	pq.size = Vector2(0.15, 0.11)
	CineParts.mesh(_photo, pq, CineParts.basic(0xffffff, {"double": true}))
	_photo.scale = Vector3.ONE * 1.25
	_make_case()
	for id: String in ["p1", "p2", "smg"]:
		var wid := "legacy_smg" if id == "smg" else "pistol"      # the plain SERVICE PISTOL and SUBMACHINE GUN models
		var info := _weapon_info(wid)
		var path := "res://assets/weapons/%s.glb" % wid
		if info == null or not ResourceLoader.exists(path):
			continue
		var p := _prop(id)
		p.add_child((load(path) as PackedScene).instantiate())
		p.scale = Vector3.ONE * 1.15      # (the size the game draws them in his hands)
		if id != "smg":      # the suppressors
			var can := CineParts.phong(0x1c1d21, {"shininess": 40.0})
			var m := info.muzzle
			CineParts.cyl(p, 0.019, 0.019, 0.17, m.x, m.y, m.z + 0.085, can, 14).rotation.x = PI / 2.0
			CineParts.cyl(p, 0.0195, 0.0195, 0.012, m.x, m.y, m.z + 0.006, CineParts.phong(0x55575c), 14).rotation.x = PI / 2.0
		_guns[id] = {"p": p, "info": info}
		var mq := _prop("mag_" + id)
		var sm_ := id == "smg"
		CineParts.box(mq, 0.03 if sm_ else 0.024, 0.15 if sm_ else 0.1, 0.05 if sm_ else 0.04, 0.0, 0.0, 0.0, CineParts.phong(0x24252a))
		CineParts.box(mq, 0.031 if sm_ else 0.025, 0.012, 0.051 if sm_ else 0.041, 0.0, 0.05, 0.0, CineParts.phong(0xb08a3a, {"shininess": 90.0}))
	# the hallway outside the front door (only ever seen through it, in this cutscene)
	var hall := Node3D.new()
	hall.name = "outside hallway"
	g.add_child(hall)
	var fz := OUT_Z1 + OUT_T
	var wall_m := CineParts.lam(0x5a5a46)
	var floor_m := CineParts.lam(0x3a3128)
	var door_m := CineParts.lam(0x4a2a1a)
	CineParts.box(hall, 4.6, 0.05, 2.2, -0.95, -0.025, fz + 1.1, floor_m)
	CineParts.box(hall, 4.6, 0.05, 2.2, -0.95, 2.55, fz + 1.1, CineParts.lam(0x40403a))
	CineParts.box(hall, 4.6, 2.6, 0.08, -0.95, 1.3, fz + 2.2, wall_m)
	CineParts.box(hall, 0.08, 2.6, 2.2, -3.25, 1.3, fz + 1.1, wall_m)
	CineParts.box(hall, 0.08, 2.6, 2.2, 1.35, 1.3, fz + 1.1, wall_m)
	CineParts.box(hall, 0.95, 2.05, 0.04, -1.9, 1.025, fz + 2.15, door_m)      # the neighbour's door, number plate
	CineParts.box(hall, 0.12, 0.1, 0.01, -1.9, 1.7, fz + 2.125, CineParts.lam(0xb8a060))
	_hall_tube = CineParts.box(hall, 1.1, 0.04, 0.08, -0.95, 2.5, fz + 1.2, CineParts.basic(0xe8f0c8))
	_hall_light = CineParts.light(hall, 0xd8e8b0, 2.2, 5.5, -0.95, 2.3, fz + 1.2)
	PR["hall"] = hall


func _weapon_info(wid: String) -> WeaponView.Info:
	var wv: WeaponView = Game.animator.wv
	for i: WeaponView.Info in wv.infos:
		if i.id == wid:
			return i
	return null


## the suitcase: shell, foam, latches, a lid hinged on its far (-x) edge, and the expanding insert (two trays on scissor arms that rise and slide apart)
func _make_case() -> void:
	var k := Node3D.new()
	k.name = "suitcase"
	g.add_child(k)
	PR["case"] = k
	var shell := CineParts.phong(0x3a3d45, {"shininess": 50.0})
	var foam := CineParts.lam(0x34363d)
	var trim := CineParts.phong(0xb9bcc4, {"shininess": 100.0})
	var CL_ := CASE_L
	var W := CASE_W
	var H := CASE_H
	var th := 0.02
	CineParts.box(k, W, th, CL_, 0.0, th / 2.0, 0.0, shell)
	CineParts.box(k, th, H, CL_, W / 2.0 - th / 2.0, H / 2.0, 0.0, shell)
	CineParts.box(k, th, H, CL_, -W / 2.0 + th / 2.0, H / 2.0, 0.0, shell)
	CineParts.box(k, W, H, th, 0.0, H / 2.0, CL_ / 2.0 - th / 2.0, shell)
	CineParts.box(k, W, H, th, 0.0, H / 2.0, -CL_ / 2.0 + th / 2.0, shell)
	CineParts.box(k, W - 2.0 * th, 0.07, CL_ - 2.0 * th, 0.0, th + 0.035, 0.0, foam)
	for s: float in [-1.0, 1.0]:
		CineParts.box(k, 0.05, 0.025, 0.025, W / 2.0 + 0.025, H / 2.0, s * 0.09, trim)
	CineParts.box(k, 0.025, 0.03, 0.21, HANDLE.x, HANDLE.y, 0.0, CineParts.lam(0x1a1b1e))      # the handle on the latch edge
	var latches: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		var l := Node3D.new()
		l.position = Vector3(W / 2.0 + 0.008, H - 0.03, s * 0.26)
		k.add_child(l)
		CineParts.box(l, 0.014, 0.05, 0.05, 0.0, 0.0, 0.0, trim)
		latches.append(l)
	var lid := Node3D.new()
	lid.position = Vector3(-W / 2.0, H, 0.0)
	k.add_child(lid)
	CineParts.box(lid, W, 0.06, CL_, W / 2.0, 0.03, 0.0, shell)
	CineParts.box(lid, W - 0.04, 0.012, CL_ - 0.04, W / 2.0, -0.004, 0.0, foam)
	var strip_m := CineParts.basic(0x0c1418)
	CineParts.box(lid, 0.02, 0.006, CL_ - 0.1, W - 0.05, -0.012, 0.0, strip_m)      # a light strip in the lid: on as it opens
	var lid_light := CineParts.light(lid, 0xcfe6ff, 0.0, 1.8, W - 0.1, -0.12, 0.0)
	var trays := []
	for s: float in [-1.0, 1.0]:      # each half of the insert: a foam tray, and the pistol + magazine in it (placed by the code below)
		var tr_ := Node3D.new()
		tr_.position = Vector3(0.0, th + 0.075, s * CL_ / 4.0)
		k.add_child(tr_)
		CineParts.box(tr_, W - 0.06, 0.04, CL_ / 2.0 - 0.04, 0.0, 0.02, 0.0, foam)
		CineParts.box(tr_, W - 0.05, 0.012, CL_ / 2.0 - 0.03, 0.0, -0.004, 0.0, trim)
		var arms := []
		for a: float in [-1.0, 1.0]:
			arms.append(CineParts.box(tr_, 0.012, 0.012, 0.16, a * (W / 2.0 - 0.05), -0.04, 0.0, trim))
		trays.append({"tr": tr_, "s": s, "arms": arms})
	_kase = {"lid": lid, "latches": latches, "trays": trays, "strip": strip_m, "lid_light": lid_light}


# ==================================================== the photo: Prog and Tommy side by side, rendered once from the real models
func _render_photo() -> void:
	const W := 384
	const H := 288
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.hex(0x7a8ea8ff)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.hex(0xfff1dcff).lerp(Color.hex(0x4a3b2cff), 0.5)      # (JS a HemisphereLight, 1.5: its middle)
	env.ambient_light_energy = 1.5 / PI
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.hex(0xffe2b0ff)
	sun.light_energy = 1.6 / PI
	var root := Node3D.new()
	vp.add_child(root)
	root.add_child(sun)
	sun.basis = Basis.looking_at(-Vector3(2.0, 4.0, 5.0).normalized(), Vector3.UP)
	var ground := CineParts.mesh(root, _plane(12.0, 12.0), CineParts.lam(0x5a5448))
	ground.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	var wall := CineParts.mesh(root, _plane(12.0, 5.0), CineParts.lam(0x8a5a44))
	wall.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.5, -1.4))
	var ps := {"prog": [-0.42, 0.18], "tommy": [0.38, -0.12]}
	for id: String in ["prog", "tommy"]:
		var B := Builds.character_build(id)
		var a := Animator.new((load(B.file) as PackedScene).instantiate(), B)
		vp.add_child(a.actor)
		_ph_made.append(a)
		var hug := id == "prog"
		a.pose_hook = func(x: Animator) -> void:      # Prog's arm round Tommy's shoulders, Tommy's thumb up
			if hug:
				x.pose[Animator.UPPER_ARM_L] = Vector3(-0.25, 0.2, 1.25)
				x.pose[Animator.FOREARM_L] = Vector3(-0.2, 0.0, 0.6)
				x.pose[Animator.HEAD] = Vector3(0.05, -0.2, 0.05)
			else:
				x.pose[Animator.UPPER_ARM_R] = Vector3(-1.0, 0.0, -0.35)
				x.pose[Animator.FOREARM_R] = Vector3(-1.6, 0.0, 0.0)
				x.pose[Animator.HEAD] = Vector3(0.0, 0.2, -0.05)
		var q := Player.new(null)
		for i in 12:
			a.update(0.05, q)
		a.actor.position = Vector3(float(ps[id][0]), a.B.pivot * a.B.scale, 0.0)
		a.actor.rotation = Vector3(0.0, float(ps[id][1]), 0.0)
		a.pose_hook = Callable()
	var c := Camera3D.new()
	c.fov = 34.0
	c.near = 0.1
	c.far = 30.0
	vp.add_child(c)
	c.look_at_from_position(Vector3(0.0, 1.25, 4.1), Vector3(0.0, 1.0, 0.0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_ph_vp = vp
	_ph_frames = 0


static func _plane(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


## print it: warm faded colours, a white border, grain, a crease and a date stamp. Two frames after the 3D render; then it is one texture and everything else goes.
func _photo_step() -> void:
	if _ph_vp == null:
		return
	_ph_frames += 1
	if _ph_frames == 3:
		const B := 18
		var vp := SubViewport.new()
		vp.size = Vector2i(384 + B * 2, 288 + B * 2 + 22)
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = Color("#efe9da")
		bg.size = Vector2(vp.size)
		vp.add_child(bg)
		var tr_ := TextureRect.new()
		tr_.texture = _ph_vp.get_texture()
		tr_.position = Vector2(B, B)
		tr_.size = Vector2(384, 288)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://cutscenes/photo_print.gdshader")
		tr_.material = sm
		vp.add_child(tr_)
		var top := PrintTop.new()
		top.size = Vector2(vp.size)
		vp.add_child(top)
		_ph_print = vp
	elif _ph_frames == 5:      # (the fonts' glyphs reach the atlas with the first draw: drawn again)
		_ph_print.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _ph_frames == 8:
		var im := _ph_print.get_texture().get_image()
		(_photo.get_child(0).material_override as StandardMaterial3D).albedo_texture = ImageTexture.create_from_image(im)
		_ph_print.queue_free()
		_ph_print = null
		_ph_vp.queue_free()
		_ph_vp = null
		_ph_made.clear()


# ==================================================== the timeline (built once per play from the line lengths)
static func _path_len(pts: Array) -> float:
	var d := 0.0
	for i in range(1, pts.size()):
		d += (pts[i] as Vector2).distance_to(pts[i - 1])
	return d


static func _path_at(pts: Array, dist: float) -> Vector2:
	var rem := dist
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var l := a.distance_to(b)
		if rem <= l or i == pts.size() - 1:
			return a.lerp(b, clampf(rem / (l if l != 0.0 else 1.0), 0.0, 1.0))
		rem -= l
	return pts[pts.size() - 1]


static func _dir_end(pts: Array) -> float:
	var a: Vector2 = pts[pts.size() - 2]
	var b: Vector2 = pts[pts.size() - 1]
	return atan2(b.x - a.x, b.y - a.y)


static func _start_dir(pts: Array) -> float:
	var q := _path_at(pts, minf(_path_len(pts), 0.45))
	var p0: Vector2 = pts[0]
	return atan2(q.x - p0.x, q.y - p0.y)


static func _turn_dur(a: float, b: float) -> float:      # a pivot on the spot: about 2 s for an about-turn (quicker swung the hands round at 10 m/s)
	return 0.3 + 0.55 * absf(_wrap(b - a))


var _b_segs: Array = []
var _b_shots: Array = []
var _b_fades: Array = []
var _b_ik := {"R": [], "L": []}
var _b_hold := {}
var _b_lines: Array = []
var _c := 0.0


func _E(tm: float, fn: Callable) -> void:
	_order += 1
	_ev.append({"t": tm, "fn": fn, "n": _order})


func _seg(t0: float, t1: float, f: Callable) -> void:
	_order += 1
	_b_segs.append({"t0": t0, "t1": t1, "f": f, "n": _order})


func _shot(t0: float, o: Dictionary) -> void:
	_order += 1
	var d := o.duplicate()
	d["t0"] = t0
	d["n"] = _order
	_b_shots.append(d)


func _H(nm: String, tm: float, place: Dictionary, blend: float = 0.3) -> void:
	if not _b_hold.has(nm):
		_b_hold[nm] = []
	_order += 1
	_b_hold[nm].append({"t": tm, "place": place, "blend": blend, "n": _order})


func _IK(side: String, tm: float, tgt: String, w: float = 1.0) -> void:
	_order += 1
	_b_ik[side].append([tm, tgt, w, _order])


func _walk(t0: float, pts: Array, v: float = 1.45, from_yaw: Variant = null) -> float:
	var td := 0.0 if from_yaw == null else _turn_dur(from_yaw, _start_dir(pts))
	var d := _path_len(pts)
	var t1 := t0 + td + d / v
	_seg(t0, t1, func(tt: float) -> St: return _walk_state(tt, t0, pts, v, from_yaw))
	var s := t0 + td + 0.2
	while s < t1 - 0.2:
		_E(s, _s_step)
		s += 0.62 / (v / 1.45)
	return t1


func _say(who: Dictionary, text: String, gap: float = 0.55, hold: float = 0.85) -> Dictionary:
	var t0 := _c + gap
	var d: float = text.length() / float(who["rate"])
	var l := {"who": who, "text": text, "t0": t0, "t1": t0 + d + hold}
	_b_lines.append(l)
	_c = l["t1"]
	return l


func _shot_at(tm: float, o: Dictionary, d: float = 40.0) -> void:
	var x := o.duplicate()
	x["d"] = d
	_shot(tm, x)


static func _v2(a: Vector3, b: Vector3) -> Array:
	return [a, b]


func _sort_by(arr: Array, key: String) -> void:
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[key] < b[key] if a[key] != b[key] else a["n"] < b["n"])


func _build() -> Dictionary:
	var K := {}
	_b_segs = []
	_b_shots = []
	_b_fades = []
	_b_ik = {"R": [], "L": []}
	_b_hold = {}
	_b_lines = []
	_ev = []
	TL = {"K": K}      # (the state functions read it while it is built)
	# ---- 1. the flat (TV snow on, the camera drifting)
	_b_fades.append([0.0, 1.6, 1.0, 0.0])
	_shot(0.0, {"a": _v2(Vector3(-3.0, 1.55, 1.35), Vector3(-4.35, 1.42, 1.95)), "b": _v2(Vector3(-4.1, 0.95, 4.2), Vector3(-4.85, 0.9, 4.1)), "d": 5.6, "fov": 48.0})                 # kitchen: the sink, the counter
	_shot(5.6, {"a": _v2(Vector3(0.35, 0.72, -0.45), Vector3(-0.15, 0.62, -0.8)), "b": _v2(Vector3(-1.05, 0.43, -2.1), Vector3(-1.3, 0.45, -2.3)), "d": 5.4, "fov": 46.0})             # the coffee table: cans, the ashtray
	_shot(11.0, {"a": _v2(Vector3(-4.9, 1.35, -0.4), Vector3(-4.25, 1.22, -1.55)), "b": _v2(Vector3(-1.6, 1.25, -4.5), Vector3(-1.0, 1.3, -4.5)), "d": 5.2, "fov": 52.0})               # rain down the big window
	_shot(16.2, {"a": _v2(Vector3(3.15, 1.9, 0.62), Vector3(2.95, 1.5, -0.55)), "b": _v2(Vector3(2.35, 0.7, -2.2), Vector3(2.2, 0.68, -2.25)), "d": 6.2, "fov": 50.0})              # into the bedroom: him, asleep
	_seg(0.0, 22.4, _lie_state)
	K["ring0"] = 17.6
	var rt: float = K["ring0"]
	while rt < 37.0:
		_E(rt, func() -> void:
			if _ringing:
				_s_ring())
		rt += 2.3
	_E(float(K["ring0"]) - 0.01, func() -> void: _ringing = true)
	K["stir"] = 19.7
	_E(K["stir"], _s_sheets)
	K["wake"] = 21.2
	_E(K["wake"], _s_groan)
	# ---- 2. up
	K["sitUp"] = 22.4
	K["swing"] = 24.2
	K["seated"] = 26.0
	_shot(22.4, {"a": _v2(Vector3(4.35, 1.6, -4.25), Vector3(4.15, 1.5, -4.2)), "b": _v2(Vector3(2.3, 0.8, -2.4), Vector3(2.3, 1.05, -2.7)), "d": 9.4, "fov": 50.0})
	_seg(K["sitUp"], K["swing"], func(tt: float) -> St: return _sit_up_state(_win(tt, K["sitUp"], K["swing"])))
	_seg(K["swing"], K["seated"], func(tt: float) -> St: return _swing_state(_win(tt, K["swing"], K["seated"])))
	_E(K["sitUp"], _s_sheets)
	_E(float(K["swing"]) + 0.2, _s_creak.bind(0.6))
	# ---- 3. the beer (left hand), the burp, the cigarette (right hand)
	var b1 := 26.2
	K["b1"] = b1
	_IK("L", b1, "bottle1", 0.0)
	_IK("L", b1 + 0.7, "bottle1", 1.0)
	_IK("L", b1 + 1.4, "drinkL", 1.0)
	_IK("L", b1 + 3.6, "drinkL", 1.0)
	_IK("L", b1 + 4.2, "bottle1", 1.0)
	_IK("L", b1 + 4.7, "bottle1", 0.0)
	_H("bottle1", b1 + 0.7, {"hand": "L", "aim": "up"}, 0.12)
	_H("bottle1", b1 + 1.2, {"hand": "L", "aim": "drink"}, 0.35)
	_H("bottle1", b1 + 3.7, {"hand": "L", "aim": "up"}, 0.35)
	_H("bottle1", b1 + 4.2, {"rest": "bottle1"}, 0.12)
	K["drink1"] = [b1 + 1.3, b1 + 3.6]
	_E(b1 + 0.75, _s_clink)
	for d: float in [1.6, 2.2, 2.8, 3.3]:
		_E(b1 + d, _s_glug)
	_E(b1 + 4.2, _s_clink)
	K["burp"] = b1 + 4.5
	_E(K["burp"], _s_burp)
	var cg := b1 + 5.2      # 31.4
	K["cig"] = cg
	_IK("R", cg, "pack", 0.0)
	_IK("R", cg + 0.6, "pack", 1.0)
	_IK("R", cg + 1.3, "mouthR", 1.0)
	_IK("R", cg + 1.6, "mouthR", 1.0)
	_IK("R", cg + 2.2, "lighter", 1.0)
	_IK("R", cg + 2.5, "lighter", 1.0)
	_IK("R", cg + 3.2, "lightR", 1.0)
	_IK("R", cg + 4.6, "lightR", 1.0)
	_IK("R", cg + 5.2, "lighter", 1.0)
	_IK("R", cg + 5.5, "lighter", 1.0)
	_IK("R", cg + 6.0, "restR", 0.0)
	_H("cig", 0.0, {"hide": true}, 0.0)
	_H("cig", cg + 0.6, {"hand": "R", "aim": "cigHand"}, 0.1)
	_H("cig", cg + 1.45, {"mouth": true}, 0.15)
	_H("lighter", cg + 2.5, {"hand": "R", "aim": "lighter"}, 0.12)
	_H("lighter", cg + 5.2, {"rest": "lighter"}, 0.15)
	_E(cg + 0.6, _s_crinkle)
	_E(cg + 2.5, _s_rustle.bind(0.15))
	K["flame"] = [cg + 3.3, cg + 4.5]
	_E(cg + 3.3, _s_flick)
	_E(cg + 4.5, _s_shut)
	K["lit"] = cg + 3.6
	_E(K["lit"], _s_drag.bind(0.8))
	K["exhale"] = [[cg + 4.7, cg + 6.2]]
	_E(cg + 4.7, _s_breath_out)
	K["drags"] = [[cg + 3.6, cg + 4.5, 1.0]]
	_shot(31.8, {"a": _v2(Vector3(2.05, 1.32, -3.55), Vector3(2.1, 1.3, -3.5)), "b": func() -> Vector3: return _head_pt(0.0, 0.0, -0.08), "d": 5.2, "fov": 40.0})                        # close as he lights up
	# ---- 4. the call (left hand: the phone)
	var ph := cg + 5.6      # 37.0
	K["ph"] = ph
	_IK("L", ph, "phone", 0.0)
	_IK("L", ph + 0.7, "phone", 1.0)
	_IK("L", ph + 1.5, "earL", 1.0)
	_H("phone", ph + 0.7, {"hand": "L", "aim": "phoneHand"}, 0.12)
	_H("phone", ph + 1.3, {"hand": "L", "aim": "ear"}, 0.3)
	_E(ph + 0.7, func() -> void:
		_ringing = false
		_s_rustle(0.15))
	K["answer"] = ph + 1.55
	_E(K["answer"], _s_click)
	_shot(ph - 0.4, {"a": _v2(Vector3(3.0, 1.25, -4.38), Vector3(2.95, 1.25, -4.3)), "b": _v2(Vector3(2.2, 0.95, -2.8), Vector3(2.28, 1.12, -2.7)), "d": 3.0, "fov": 52.0})
	_c = float(K["answer"]) + 0.5
	var A := {"a": _v2(Vector3(3.0, 1.25, -4.38), Vector3(2.95, 1.25, -4.3)), "b": _v2(Vector3(2.28, 1.12, -2.7), Vector3(2.28, 1.12, -2.7)), "fov": 52.0}
	var B_ := {"a": _v2(Vector3(3.7, 1.4, -4.0), Vector3(3.62, 1.38, -3.92)), "b": _v2(Vector3(2.2, 1.12, -2.7), Vector3(2.2, 1.12, -2.7)), "fov": 44.0}
	_say(PROG, "Go.", 0.0, 0.6)
	_shot_at(_c - 1.4, A)
	var l := _say(BOSS, "We have a problem.")
	_shot_at(float(l["t0"]) - 0.2, B_)
	l = _say(PROG, "You people always have problems.")
	_shot_at(float(l["t0"]) - 0.2, A)
	l = _say(BOSS, "The government is requesting your services again.")
	_shot_at(float(l["t0"]) - 0.2, B_)
	l = _say(PROG, "Yea, and what did I tell you stupid fucks last time?")
	_shot_at(float(l["t0"]) - 0.2, A)
	l = _say(BOSS, "Tommy's MIA.", 0.9, 0.5)
	# the close-up and the long drag
	K["mia"] = _c
	_shot(_c - 0.6, {"a": func() -> Vector3: return _head_pt(1.15, -0.42, 0.02), "b": func() -> Vector3: return _head_pt(0.12, 0.0, 0.06), "d": 6.4, "fov": 34.0, "push": 0.18})
	_IK("R", _c + 0.1, "restR", 0.0)
	_IK("R", _c + 0.8, "mouthR", 1.0)
	_IK("R", _c + 2.6, "mouthR", 1.0)
	_IK("R", _c + 3.3, "restR", 0.0)
	K["drags"].append([_c + 0.9, _c + 2.6, 1.6])
	_E(_c + 0.9, _s_drag.bind(1.7))
	K["exhale"].append([_c + 2.9, _c + 4.6])
	_E(_c + 2.9, _s_breath_out)
	_c += 4.0
	l = _say(PROG, "MIA?", 0.2, 0.9)
	l = _say(BOSS, "Yea, MIA. We can't get ahold of him and it's been 3 weeks.")
	_shot_at(float(l["t0"]) - 0.2, B_)
	l = _say(PROG, "Must mean Natalia must be drug binging again.")
	_shot_at(float(l["t0"]) - 0.2, A)
	l = _say(BOSS, "Yea, we've already taken care of that by sending her to rehab a week ago, she should be back soon.")
	_shot_at(float(l["t0"]) - 0.2, B_)
	l = _say(BOSS, "You know where to find us, you need to link up.", 0.5)
	# another drink (right hand, the bottle on the bed)
	var b2 := _c + 0.1
	K["b2"] = b2
	_shot_at(b2 - 0.1, A)
	_IK("R", b2, "bottle2", 0.0)
	_IK("R", b2 + 0.7, "bottle2", 1.0)
	_IK("R", b2 + 1.4, "drinkR", 1.0)
	_IK("R", b2 + 2.9, "drinkR", 1.0)
	_IK("R", b2 + 3.5, "bottle2", 1.0)
	_IK("R", b2 + 3.9, "restR", 0.0)
	_H("bottle2", b2 + 0.7, {"hand": "R", "aim": "up"}, 0.12)
	_H("bottle2", b2 + 1.2, {"hand": "R", "aim": "drink"}, 0.35)
	_H("bottle2", b2 + 3.0, {"hand": "R", "aim": "up"}, 0.35)
	_H("bottle2", b2 + 3.5, {"rest": "bottle2"}, 0.12)
	K["drink2"] = [b2 + 1.3, b2 + 2.9]
	_E(b2 + 0.75, _s_clink)
	for d: float in [1.6, 2.2]:
		_E(b2 + d, _s_glug)
	_c = b2 + 3.6
	l = _say(PROG, "I'll think about it.", 0.2)
	# hung up on mid-sentence
	l = _say(BOSS, "Prog, this is a matter of-", 0.5, 0.0)
	_shot_at(float(l["t0"]) - 0.2, B_)
	var hang: float = float(l["t1"]) + 0.05
	K["hang"] = hang
	l["t1"] = hang
	_IK("L", hang, "earL", 1.0)
	_IK("L", hang + 0.45, "chestL", 1.0)
	_IK("L", hang + 0.95, "phoneBed", 1.0)
	_IK("L", hang + 1.3, "restL", 0.0)
	_H("phone", hang + 0.05, {"hand": "L", "aim": "phoneHand"}, 0.3)
	_H("phone", hang + 0.95, {"rest": "phoneBed"}, 0.15)
	_E(hang, _s_beep)
	_E(hang + 0.95, _s_thud)
	var stand := hang + 1.2
	var stand_e := stand + 1.4
	K["stand"] = stand
	K["standE"] = stand_e
	var bed_feet := Vector2(float(EDGE["x"]), float(EDGE["z"]) - SEAT_FEET)
	_seg(K["seated"], stand, func(_tt: float) -> St: return _seat_state(EDGE))
	_seg(stand, stand_e, func(tt: float) -> St: return _stand_up_state(EDGE, bed_feet, _win(tt, stand, stand_e)))
	_E(stand + 0.2, _s_creak.bind(0.5))
	# ---- 5. the couch, the wallet, the photo
	_shot(stand - 0.3, {"a": _v2(Vector3(1.95, 1.75, -3.95), Vector3(2.0, 1.7, -3.9)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.45), "d": 9.0, "fov": 54.0})
	var tt_ := _walk(stand_e, PATH["bedOut"], 1.45, EDGE["yaw"])
	var t_cut := tt_
	tt_ = _walk(tt_, PATH["toCouch"])      # (a cut hides the jump between the two walks)
	var tc := tt_
	_shot(t_cut, {"a": _v2(Vector3(0.55, 1.4, -3.05), Vector3(0.5, 1.3, -2.95)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.35), "d": 30.0, "fov": 50.0})
	var dc := _dir_end(PATH["toCouch"])
	var sit := tc + _turn_dur(dc, COUCH["yaw"])
	var sit_e := sit + 1.3
	K["sit"] = sit
	K["sitE"] = sit_e
	var couch_feet := Vector2(float(COUCH["x"]) + SEAT_FEET, float(COUCH["z"]))
	_seg(tc, sit, func(_tt: float) -> St: return _stand_state(couch_feet.x, couch_feet.y, COUCH["yaw"], tc, dc))     # turns round to sit
	_seg(sit, sit_e, func(t2: float) -> St: return _stand_up_state(COUCH, couch_feet, 1.0 - _win(t2, sit, sit_e)))
	_E(sit + 0.9, _s_creak.bind(0.7))
	var wal := sit_e + 0.4
	K["wal"] = wal
	_IK("R", wal, "pocketR", 0.0)
	_IK("R", wal + 0.7, "pocketR", 1.0)
	_IK("R", wal + 1.4, "chestR", 1.0)
	_IK("L", wal + 1.0, "restL", 0.0)
	_IK("L", wal + 1.5, "chestL", 1.0)
	_H("wallet", 0.0, {"hide": true}, 0.0)
	_H("wallet", wal + 0.7, {"hand": "R", "aim": "wallet"}, 0.15)
	_E(wal + 0.7, _s_rustle.bind(0.3))
	K["walOpen"] = [wal + 1.5, wal + 1.9]
	_H("photo", 0.0, {"hide": true}, 0.0)
	_H("photo", wal + 2.2, {"hand": "L", "aim": "photo"}, 0.2)
	_IK("L", wal + 2.1, "chestL", 1.0)
	_IK("L", wal + 2.9, "viewL", 1.0)
	_IK("R", wal + 2.3, "chestR", 1.0)
	_IK("R", wal + 2.9, "lapR", 1.0)
	_E(wal + 2.2, _s_rustle.bind(0.15))
	var photo := wal + 2.9
	K["photo"] = photo
	_shot(wal - 0.2, {"a": _v2(Vector3(-1.25, 1.2, -2.8), Vector3(-1.35, 1.18, -2.7)), "b": func() -> Vector3: return _hip_pt(0.2, 0.0, 0.35), "d": 3.2, "fov": 48.0})
	_shot(photo, {"a": func() -> Vector3: return _eye_cam(), "b": func() -> Vector3: return (PR["photo"] as Node3D).global_position, "d": 4.4, "fov": 30.0, "push": 0.3})                       # the photo, from just over his head
	# the face, and a drag (the right hand, the wallet on his knee)
	var face := photo + 4.4
	K["face"] = face
	_shot(face, {"a": func() -> Vector3: return _head_pt(1.15, -0.4, 0.0), "b": func() -> Vector3: return _head_pt(0.12, 0.0, 0.05), "d": 5.4, "fov": 34.0, "push": 0.18})
	_IK("R", face + 0.3, "lapR", 1.0)
	_IK("R", face + 0.9, "mouthR", 1.0)
	_IK("R", face + 2.5, "mouthR", 1.0)
	_IK("R", face + 3.1, "lapR", 1.0)
	_H("wallet", face + 0.15, {"rest": "lap"}, 0.3)
	K["drags"].append([face + 1.0, face + 2.5, 1.5])
	_E(face + 1.0, _s_drag.bind(1.5))
	K["exhale"].append([face + 2.8, face + 4.4])
	_E(face + 2.8, _s_breath_out)
	var put := face + 4.6      # photo back in the wallet, the wallet back in his pocket
	K["put"] = put
	_IK("L", put, "viewL", 1.0)
	_IK("L", put + 0.5, "chestL", 1.0)
	_IK("L", put + 0.9, "restL", 0.0)
	_IK("R", put, "lapR", 1.0)
	_IK("R", put + 0.5, "chestR", 1.0)
	_IK("R", put + 1.1, "pocketR", 1.0)
	_IK("R", put + 1.6, "restR", 0.0)
	_H("wallet", put, {"hand": "R", "aim": "wallet"}, 0.2)
	_H("photo", put + 0.55, {"hide": true}, 0.0)
	_H("wallet", put + 1.15, {"hide": true}, 0.0)
	K["walClose"] = [put + 0.55, put + 0.85]
	_E(put + 0.55, _s_rustle.bind(0.15))
	var up2 := put + 1.4
	var up2_e := up2 + 1.3
	K["up2"] = up2
	K["up2E"] = up2_e
	_seg(sit_e, up2, func(_tt: float) -> St: return _seat_state(COUCH))
	_seg(up2, up2_e, func(t2: float) -> St: return _stand_up_state(COUCH, couch_feet, _win(t2, up2, up2_e)))
	_shot(up2 - 0.2, {"a": _v2(Vector3(0.55, 1.4, -3.05), Vector3(0.5, 1.45, -2.95)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.45), "d": 8.0, "fov": 50.0})
	# ---- 6. the closet and the suitcase
	tt_ = _walk(up2_e, PATH["couchOut"], 1.45, COUCH["yaw"])
	var tw := tt_
	tt_ = _walk(tt_, PATH["toCloset"])
	_shot(tw, {"a": _v2(Vector3(2.25, 1.75, -3.7), Vector3(2.3, 1.7, -3.6)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.4), "d": tt_ - tw + 0.4, "fov": 52.0})
	var cl := tt_ + 0.1
	K["cl"] = cl
	K["clOpen"] = [cl, cl + 1.0]
	_E(cl, _s_creak.bind(0.9))
	K["bend"] = [cl + 0.8, cl + 1.6, cl + 2.6, cl + 3.3]      # down, hold, up
	var t_arr := tt_
	var dcl := _dir_end(PATH["toCloset"])
	_seg(tt_, cl + 3.4, func(t2: float) -> St: return _stand_state(4.95, -1.68, PI / 2.0, t_arr, dcl, _bend_k(t2)))
	_shot(cl - 0.3, {"a": _v2(Vector3(4.05, 1.6, -3.55), Vector3(4.15, 1.5, -3.45)), "b": _v2(Vector3(5.3, 0.9, -1.7), Vector3(5.15, 0.75, -1.7)), "d": 4.0, "fov": 52.0})
	_IK("R", cl + 0.9, "caseHandle", 0.0)
	_IK("R", cl + 1.6, "caseHandle", 1.0)
	_IK("R", cl + 2.0, "caseHandle", 1.0)
	_IK("R", cl + 3.0, "carryR", 1.0)
	_H("case", 0.0, {"rest": "caseCloset"}, 0.0)
	_H("case", cl + 2.0, {"carry": true}, 0.25)
	_E(cl + 2.0, _s_clack)
	tt_ = _walk(cl + 3.4, PATH["toCase"], 1.2, PI / 2.0)
	_shot(cl + 3.4, {"a": _v2(Vector3(2.35, 1.5, -2.55), Vector3(2.4, 1.45, -2.5)), "b": _v2(Vector3(3.6, 0.85, -2.1), Vector3(3.55, 0.85, -2.1)), "d": 30.0, "fov": 52.0})
	var place := tt_ + 0.1
	K["place"] = place
	_IK("R", place, "carryR", 1.0)
	_IK("R", place + 0.9, "caseHandle", 1.0)
	_IK("L", place + 0.2, "restL", 0.0)
	_IK("L", place + 0.8, "caseSide", 1.0)
	_H("case", place, {"rest": "caseBed"}, 0.9)
	_E(place + 0.9, _s_thud)
	K["latch"] = [place + 1.5, place + 1.75]
	_IK("R", place + 1.35, "latchR", 1.0)
	_IK("R", place + 1.85, "latchR", 1.0)
	_IK("L", place + 1.35, "latchL", 1.0)
	_IK("L", place + 1.85, "latchL", 1.0)
	_E(place + 1.5, _s_latch)
	_E(place + 1.75, _s_latch)
	K["lid"] = [place + 2.0, place + 3.0]
	_IK("R", place + 2.1, "lidEdge", 1.0)
	_IK("R", place + 2.8, "lidEdge", 1.0)
	_IK("R", place + 3.2, "restR", 0.0)
	_IK("L", place + 2.2, "restL", 0.0)
	_E(place + 2.0, _s_creak.bind(0.8))
	var ex0 := place + 3.3
	var ex1 := place + 4.6
	K["expand"] = [ex0, ex1]
	_E(ex0, _s_whirr)
	_E(ex1, _s_clack)
	_shot(ex0 - 0.4, {"a": _v2(Vector3(3.95, 2.1, -1.05), Vector3(3.85, 1.95, -1.2)), "b": _v2(Vector3(3.3, 0.6, -2.1), Vector3(3.3, 0.6, -2.1)), "d": 2.6, "fov": 50.0})      # looking down into it
	_shot(ex1 + 0.8, {"a": _v2(Vector3(2.35, 1.45, -2.55), Vector3(2.4, 1.4, -2.5)), "b": _v2(Vector3(3.6, 0.95, -2.1), Vector3(3.65, 0.98, -2.1)), "d": 30.0, "fov": 50.0})
	var tg := ex1 + 0.9
	for id: String in ["p1", "p2"]:
		tg = _load_pistol(id, tg)
	tg = _load_smg(tg)
	var dcs := _dir_end(PATH["toCase"])
	var tps := place - 0.1
	_seg(place - 0.1, tg + 0.2, func(_tt: float) -> St: return _stand_state(3.98, -2.1, -PI / 2.0, tps, dcs))
	# ---- 7. out of the door
	tt_ = _walk(tg + 0.2, PATH["caseOut"], 1.45, -PI / 2.0)
	_shot(tg + 0.1, {"a": _v2(Vector3(2.0, 1.75, -3.9), Vector3(2.05, 1.7, -3.85)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.45), "d": tt_ - tg, "fov": 54.0})
	var td := tt_
	tt_ = _walk(tt_, PATH["toDoor"])
	_shot(td, {"a": _v2(Vector3(0.7, 1.55, 0.6), Vector3(0.55, 1.5, 0.85)), "b": func() -> Vector3: return _hip_pt(0.0, 0.0, 0.45), "d": 60.0, "fov": 50.0, "lookMix": {"to": Vector3(-0.95, 1.25, 4.4), "t0": tt_ - 0.6, "d": 1.2}})
	var knob := tt_ + 0.45
	K["knob"] = knob
	_IK("L", knob, "knob", 0.0)
	_IK("L", knob + 0.6, "knob", 1.0)
	_IK("L", knob + 2.0, "knob", 1.0)
	_IK("L", knob + 2.4, "restL", 0.0)
	_E(knob + 0.7, _s_bolt)
	_E(knob + 1.0, _s_bolt)
	K["door"] = [knob + 1.3, knob + 2.1, knob + 2.9]      # pulled open with him, then swinging on
	_E(knob + 1.3, _s_creak.bind(1.2))
	var t_door := tt_
	var dd := _dir_end(PATH["toDoor"])
	_seg(tt_, knob + 2.6, func(_tt: float) -> St: return _stand_state(-0.76, 3.8, 0.0, t_door, dd))
	tt_ = _walk(knob + 2.6, PATH["outDoor"], 1.35, 0.0)
	K["shut"] = [tt_ + 0.1, tt_ + 1.0]
	_E(tt_ + 1.0, _s_slam)
	_seg(tt_, tt_ + 30.0, func(_tt: float) -> St: return _stand_state(-0.95, 5.55, 0.0, -9.0, 0.0))
	K["fadeOut"] = tt_ + 1.0 + 1.4
	K["end"] = float(K["fadeOut"]) + 1.0
	_b_fades.append([K["fadeOut"], K["end"], 0.0, 1.0])
	for x: String in ["R", "L"]:
		(_b_ik[x] as Array).sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[3] < b[3])
	for k: String in _b_hold:
		_sort_by(_b_hold[k], "t")
	_sort_by(_b_shots, "t0")
	_sort_by(_b_segs, "t0")
	for ln: Dictionary in _b_lines:
		_E(ln["t0"], _say_line.bind(ln))
		_E(ln["t1"], func() -> void:
			if _line != null and _line["src"] == ln:
				_end_line())
	_sort_by(_ev, "t")
	return {"K": K, "segs": _b_segs, "shots": _b_shots, "fades": _b_fades, "ik": _b_ik, "hold": _b_hold, "lines": _b_lines}


## a pistol: picked out of its tray, magazine in, slide racked, tucked in his waistband (p1 on the right hip, p2 on the left)
func _load_pistol(id: String, t0: float) -> float:
	var side := 1 if id == "p1" else -1
	_IK("R", t0, "restR", 0.0)
	_IK("R", t0 + 0.6, "grip_" + id, 1.0)
	_IK("R", t0 + 3.6, "grip_" + id, 1.0)
	_IK("R", t0 + 3.9, "restR", 0.0)
	_H(id, t0 + 0.6, {"gun": "ready"}, 0.55)
	_H(id, t0 + 3.1, {"gun": "hipR" if side > 0 else "hipL"}, 0.5)
	_IK("L", t0 + 0.6, "restL", 0.0)
	_IK("L", t0 + 1.0, "mag_" + id, 1.0)
	_IK("L", t0 + 1.6, "well_" + id, 1.0)
	_IK("L", t0 + 1.8, "well_" + id, 1.0)
	_IK("L", t0 + 2.2, "slide_" + id, 1.0)
	_IK("L", t0 + 2.4, "slideBack_" + id, 1.0)
	_IK("L", t0 + 2.75, "restL", 0.0)
	_H("mag_" + id, t0 + 1.0, {"hand": "L", "aim": "mag"}, 0.12)
	_H("mag_" + id, t0 + 1.7, {"inGun": id}, 0.12)
	_E(t0 + 1.0, _s_rl.bind("pistol", "fetch"))
	_E(t0 + 1.75, _s_rl.bind("pistol", "insert"))
	_E(t0 + 2.35, _s_rl.bind("pistol", "rack"))
	_E(t0 + 2.45, _s_rl.bind("pistol", "chamber"))
	return t0 + 3.9


## the SMG: both hands, magazine in, charging handle; carried low in the right hand to the door
func _load_smg(t0: float) -> float:
	_IK("R", t0, "restR", 0.0)
	_IK("R", t0 + 0.7, "grip_smg", 1.0)
	_IK("L", t0, "restL", 0.0)
	_IK("L", t0 + 0.7, "gripL_smg", 1.0)
	_H("smg", t0 + 0.7, {"gun": "ready"}, 0.6)
	_IK("L", t0 + 1.5, "gripL_smg", 1.0)
	_IK("L", t0 + 1.9, "mag_smg", 1.0)
	_IK("L", t0 + 2.5, "well_smg", 1.0)
	_IK("L", t0 + 2.7, "well_smg", 1.0)
	_IK("L", t0 + 3.1, "slide_smg", 1.0)
	_IK("L", t0 + 3.3, "slideBack_smg", 1.0)
	_IK("L", t0 + 3.7, "gripL_smg", 1.0)
	_IK("L", t0 + 4.6, "gripL_smg", 1.0)
	_IK("L", t0 + 5.0, "restL", 0.0)
	_H("mag_smg", t0 + 1.9, {"hand": "L", "aim": "mag"}, 0.12)
	_H("mag_smg", t0 + 2.6, {"inGun": "smg"}, 0.12)
	_IK("R", t0 + 4.6, "grip_smg", 1.0)
	_H("smg", t0 + 4.6, {"gun": "low"}, 0.6)
	_IK("R", t0 + 5.2, "grip_smg", 1.0)
	_IK("R", 999.0, "grip_smg", 1.0)
	_E(t0 + 0.7, _s_clack)
	_E(t0 + 1.9, _s_rl.bind("legacy_smg", "fetch"))
	_E(t0 + 2.65, _s_rl.bind("legacy_smg", "insert"))
	_E(t0 + 3.25, _s_rl.bind("legacy_smg", "rack"))
	_E(t0 + 3.4, _s_rl.bind("legacy_smg", "chamber"))
	return t0 + 5.2


func _bend_k(tt: float) -> float:
	var b: Array = TL["K"]["bend"]
	return _win(tt, b[0], b[1]) if tt < float(b[1]) else 1.0 - _win(tt, b[2], b[3])


# ==================================================== the body: where he is and how bent, as a function of time
func _lie_state(tt: float) -> St:
	var s := St.new()
	s.ox = LIE["x"]
	s.oy = LIE["y"]
	s.oz = LIE["z"]
	s.yaw = LIE["yaw"]
	s.pitch = LIE["pitch"]
	s.lie = 1.0
	s.px = float(LIE["x"]) + 0.9
	s.pz = LIE["z"]
	var st: float = TL["K"]["stir"]
	s.pitch += 0.05 * _win(tt, st, st + 0.6) * (1.0 - _win(tt, st + 1.2, st + 2.2))   # a toss under the noise
	return s


func _sit_up_state(u: float) -> St:
	var s := St.new()
	s.ox = lerpf(LIE["x"], UP["x"], u)
	s.oy = lerpf(LIE["y"], UP["y"], u)
	s.oz = lerpf(LIE["z"], UP["z"], u)
	s.yaw = UP["yaw"]
	s.pitch = lerpf(LIE["pitch"], 0.0, u)
	s.hip = 1.45 * u
	s.lie = 1.0 - u
	s.lean = 0.35 * sin(PI * u)
	s.px = s.ox + 0.4
	s.pz = s.oz
	return s


func _swing_state(u: float) -> St:
	var s := St.new()
	s.ox = lerpf(UP["x"], EDGE["x"], u)
	s.oy = lerpf(UP["y"], EDGE["y"], u)
	s.oz = lerpf(UP["z"], EDGE["z"], u)
	s.yaw = lerpf(UP["yaw"], EDGE["yaw"], u)
	s.hip = 1.45
	s.knee = 1.45 * u
	s.lean = 0.1
	s.px = s.ox + sin(s.yaw) * SEAT_FEET
	s.pz = s.oz + cos(s.yaw) * SEAT_FEET
	return s


func _seat_state(seat: Dictionary) -> St:
	var s := St.new()
	s.ox = seat["x"]
	s.oy = seat["y"]
	s.oz = seat["z"]
	s.yaw = seat["yaw"]
	s.hip = 1.45
	s.knee = 1.45
	s.lean = 0.12
	s.px = float(seat["x"]) + sin(s.yaw) * SEAT_FEET
	s.pz = float(seat["z"]) + cos(s.yaw) * SEAT_FEET
	return s


## u 0 seated .. 1 standing over his feet
func _stand_up_state(seat: Dictionary, feet: Vector2, u: float) -> St:
	var s := _seat_state(seat)
	var k := Cutscene.ease_(u)
	s.ox = lerpf(seat["x"], feet.x, k)
	s.oz = lerpf(seat["z"], feet.y, k)
	s.oy = lerpf(seat["y"], PIV, Cutscene.ease_(clampf(u * 1.25 - 0.15, 0.0, 1.0)))
	s.hip = 1.45 * (1.0 - k)
	s.knee = 1.45 * (1.0 - k)
	s.lean = 0.12 + 0.5 * sin(PI * clampf(u * 1.1, 0.0, 1.0)) - 0.12 * k
	s.px = feet.x
	s.pz = feet.y
	return s


## standing at x z; pivots from yaw0 to yaw1 after t_turn (turn_dur); bend 0..1 = a squat to reach low (the closet)
func _stand_state(x: float, z: float, yaw1: float, t_turn: float, yaw0: float, bend: float = 0.0) -> St:
	var s := St.new()
	var u := _win(t, t_turn, t_turn + _turn_dur(yaw0, yaw1))
	s.ox = x
	s.oz = z
	s.px = x
	s.pz = z
	s.yaw = yaw0 + _wrap(yaw1 - yaw0) * u
	s.lean = 0.75 * bend
	s.hip = 0.55 * bend
	s.knee = 1.0 * bend
	s.dy = -0.2 * bend
	s.oy = PIV + s.dy
	return s


## walking a path: from facing from_yaw, a pivot on the spot toward the first leg (none when from_yaw is null: right after a camera cut), then along it at v (looking a little ahead round the corners); he ends facing along the last leg
func _walk_state(tm: float, t0: float, pts: Array, v: float, from_yaw: Variant) -> St:
	var y0 := _start_dir(pts)
	var td := 0.0 if from_yaw == null else _turn_dur(from_yaw, y0)
	var s := St.new()
	var d := _path_len(pts)
	var tt := tm - t0 - td
	var Tw := d / v
	var r := minf(0.35, Tw / 3.0)
	var vm := d / (Tw - r)
	var tc := clampf(tt, 0.0, Tw)        # speeds up and slows down over r seconds
	var along := 0.5 * vm * tc * tc / r if tc < r else (vm * (tc - r / 2.0) if tc < Tw - r else d - 0.5 * vm * (Tw - tc) ** 2 / r)
	var sp := 0.0 if tt <= 0.0 or tt >= Tw else vm * minf(1.0, minf(tc / r, (Tw - tc) / r))
	var p := _path_at(pts, along)
	var q := _path_at(pts, minf(d, along + 0.45))
	s.px = p.x
	s.ox = p.x
	s.pz = p.y
	s.oz = p.y
	var fwd := atan2(q.x - p.x, q.y - p.y) if d - along > 0.05 else _dir_end(pts)
	s.yaw = float(from_yaw) + _wrap(y0 - float(from_yaw)) * Cutscene.ease_((tm - t0) / td) if tt < 0.0 else fwd
	s.vx = sin(s.yaw) * sp
	s.vz = cos(s.yaw) * sp
	s.walk = true
	return s


func _state_at(tm: float) -> St:
	var sg: Dictionary = TL["segs"][0]
	for x: Dictionary in TL["segs"]:
		if float(x["t0"]) <= tm:
			sg = x
		else:
			break
	return (sg["f"] as Callable).call(tm)


# ==================================================== frame-local geometry (body frame, head, hands)
func _hip_pt(f: float, r: float, h: float) -> Vector3:
	return O + BF * f + BR * r + Y * h


func _head_pt(f: float, r: float, h: float) -> Vector3:
	return HEAD + BF * f + BR * r + Y * h


func _eye_cam() -> Vector3:      # just above his head: the photo insert's camera
	return HEAD + Y * 0.4 + BF * 0.04


func _bone_local(b: int, local: Vector3) -> Vector3:
	return an.actor.global_transform * (an._model_xf * (an.skel.get_bone_global_pose(b) * local))


func _mouth_pt() -> Vector3:
	var hd: Animator.BoneRec = an.by_key.get(&"head") if an != null else null
	return _bone_local(hd.bone, TUNE_MOUTH) if hd != null else _head_pt(0.12, 0.0, -0.05)


func _rest_pt(nm: String) -> Vector3:
	return SPOT[nm]["p"]


func _gun_pt(id: String, local: Vector3) -> Vector3:
	if not _guns.has(id):
		return O
	return (_guns[id]["p"] as Node3D).to_global(local)


func _case_local(x: float, y: float, z: float) -> Vector3:
	return (PR["case"] as Node3D).to_global(Vector3(x, y, z))


func _cig_tip() -> Vector3:
	return (PR["cig"] as Node3D).to_global(Vector3(0.0, 0.09, 0.0))


func _tgt(n: String) -> Vector3:
	match n:
		"bottle1", "bottle2":
			return _rest_pt(n) + Vector3(0.0, 0.13, 0.0)
		"phone":
			return _rest_pt(n) + Vector3(0.0, 0.04, 0.0)
		"phoneBed":
			return _rest_pt(n) + Vector3(0.0, 0.06, 0.0)
		"pack":
			return _rest_pt(n) + Vector3(0.0, 0.05, 0.0)
		"lighter":
			return _rest_pt(n) + Vector3(0.0, 0.04, 0.0)
		"drinkL":
			return _mouth_pt() + BF * 0.2 + BR * -0.04 + Y * 0.05
		"drinkR":
			return _mouth_pt() + BF * 0.2 + BR * 0.04 + Y * 0.05
		"mouthR":
			return _mouth_pt() + BF * 0.06 + BR * 0.05 + Y * -0.03
		"lightR":
			return _cig_tip() + Y * -0.14 + BR * 0.03 + BF * 0.02
		"earL":
			return _head_pt(0.04, -0.22, 0.02)
		"chestL":
			return _hip_pt(0.36, -0.1, 0.3)
		"chestR":
			return _hip_pt(0.36, 0.1, 0.28)
		"viewL":
			return _hip_pt(0.46, -0.02, 0.56)
		"lapR":
			return _hip_pt(0.38, 0.14, 0.1)
		"pocketR":
			return _hip_pt(-0.06, 0.26, -0.02)
		"restR":
			return _hip_pt(0.1, 0.3, -0.25)
		"restL":
			return _hip_pt(0.1, -0.3, -0.25)
		"carryR":
			return _hip_pt(0.06, 0.34, -0.2)
		"caseHandle":
			return _case_local(HANDLE.x, HANDLE.y, HANDLE.z)
		"caseSide":
			return _case_local(0.0, CASE_H * 0.5, -CASE_L / 2.0 - 0.02)
		"latchR":
			return _case_local(CASE_W / 2.0 + 0.02, CASE_H, -0.26)
		"latchL":
			return _case_local(CASE_W / 2.0 + 0.02, CASE_H, 0.26)
		"lidEdge":
			return (_kase["lid"] as Node3D).to_global(Vector3(CASE_W - 0.02, 0.06, -0.12))
		"knob":
			return _front_door.to_global(Vector3(-1.45 + 0.85 - (-1.45 + 0.01), 1.0, -0.07)) if _front_door != null else Vector3(-0.6, 1.0, 4.49)
	var us := n.find("_")
	var head := n.substr(0, us)
	var id := n.substr(us + 1)
	var kind := "smg" if id == "smg" else "deagle"
	match head:
		"grip":
			return _gun_pt(id, _guns[id]["info"].grip_r if _guns.has(id) else Vector3.ZERO)
		"gripL":
			return _gun_pt(id, _guns[id]["info"].grip_l if _guns.has(id) else Vector3.ZERO)
		"mag":
			return (PR[n] as Node3D).global_position if PR.has(n) else O
		"well":
			return _gun_pt(id, GUNLOC["well"][kind])
		"slide":
			return _gun_pt(id, GUNLOC["slide"][kind])
		"slideBack":
			return _gun_pt(id, GUNLOC["slide"][kind] + Vector3(0.0, 0.0, -0.07))
	return O


# hand IK tracks: [t, target, weight]; the target eases between consecutive keys
func _sample_ik(side: String) -> void:
	var list: Array = TL["ik"][side]
	var h: IkS = _ik_s[side]
	h.w = 0.0
	h.name = ""
	if list.is_empty() or t < float(list[0][0]):
		return
	var i := 0
	while i < list.size() - 1 and t >= float(list[i + 1][0]):
		i += 1
	var j := mini(i + 1, list.size() - 1)
	var u := 1.0 if i == j else Cutscene.ease_((t - float(list[i][0])) / (float(list[j][0]) - float(list[i][0])))
	h.p = _tgt(list[i][1]).lerp(_tgt(list[j][1]), u)
	h.w = lerpf(list[i][2], list[j][2], u)
	h.name = list[i][1] if u < 0.5 else list[j][1]      # what the hand is working on (for its grip and wrist, below)
	h.u = u
	h.next = list[j][1]


# ==================================================== the hands themselves: finger poses and wrist aims (hand_pose.gd). Nothing extra to key: each frame a hand's goal follows from what it holds (the prop holders above) or what it is reaching for (the IK target).
static func _surface(n: String) -> bool:      # targets the palm (not the wrist) goes to
	return n.begins_with("bottle1") or n.begins_with("bottle2") or n.begins_with("phone") or n.begins_with("phoneBed") or n.begins_with("pack") or n.begins_with("lighter") or n.begins_with("caseHandle") or n.begins_with("caseSide") or n.begins_with("latchR") or n.begins_with("latchL") or n.begins_with("lidEdge") or n.begins_with("knob") or n.begins_with("mag_")


## which prop this hand holds right now (and how), or null
func _held_by(side: String) -> Variant:
	for nm: String in TL["hold"]:
		var i := _holder_at(nm)
		if i < 0:
			continue
		var pl: Dictionary = TL["hold"][nm][i]["place"]
		if pl.get("hand", "") == side:
			return {"name": nm, "aim": pl["aim"]}
		if pl.get("carry", false) and side == "R":
			return {"name": nm, "aim": "carry"}
	return null


func _inward(side: String) -> Vector3:      # the palm turned toward his middle
	return BR * (-1.0 if side == "R" else 1.0)


func _gun_axes(id: String) -> Array:
	var q: Quaternion = (PR[id] as Node3D).global_basis.get_rotation_quaternion()
	return [q * Vector3.RIGHT, q * Vector3.UP, q * Vector3.BACK]


## [pose, aim] for one hand this frame: aim in world space, or null to leave the wrist to the arm
func _hand_goal(side: String, seated: bool) -> Array:
	# (from where the IK is about to put the hand: before the solve the bone is still wherever the animator left it, down by his side)
	var ik: IkS = _ik_s[side]
	var hb: Vector3 = ik.p if ik.w > 0.05 else an.bone_world_pos(an.by_key[StringName("hand" + side)].bone)
	var to_head := (HEAD - hb).normalized()
	var held: Variant = _held_by(side)
	if held != null:
		match String(held["aim"]):
			"up":
				return ["cyl", HandPose.Aim.new(_inward(side), Y)]
			"drink":      # the neck to his mouth, bottom tipped up
				return ["cyl", HandPose.Aim.new(_inward(side), (_mouth_pt() - hb).normalized() + Y * -0.45)]
			"cigHand":
				return ["pinch", HandPose.Aim.new(_inward(side) + Y * -0.4, _mouth_pt() - hb)]
			"lighter":
				return ["fist", HandPose.Aim.new(_inward(side), Y + BF * 0.2)]
			"phoneHand":      # looking at the screen
				return ["phone", HandPose.Aim.new(to_head, null, BF + Y * 0.5)]
			"ear":      # palm (and the screen) against his head
				return ["phone", HandPose.Aim.new(to_head, null, Y * 0.85 + BF * -0.45)]
			"wallet":
				return ["phone", HandPose.Aim.new(to_head, null, BF + Y * 0.3)]
			"photo":
				return ["pinch", HandPose.Aim.new(_inward(side), _eye_cam() - hb)]
			"mag":
				return ["fist", HandPose.Aim.new(Y, null, BF)]
			"carry":
				return ["cyl", HandPose.Aim.new(_inward(side), BF)]
	var n: String = ik.name if ik.w > 0.15 else ""
	var closing := ik.u > 0.6
	if n != "":
		if n == "bottle1" or n == "bottle2":
			return ["cyl" if closing else "open", HandPose.Aim.new(_inward(side), Y)]
		if n == "phone" or n == "phoneBed" or n == "pack" or n == "lighter":
			return ["phone" if closing else "open", HandPose.Aim.new(-Y, null, BF)]
		if n == "mouthR":
			return ["drag", HandPose.Aim.new(to_head, null, Y)]
		if n == "pocketR":
			return ["flat", HandPose.Aim.new(BF, null, -Y)]
		if n == "lapR" or n == "chestR" or n == "chestL":
			return ["relax", HandPose.Aim.new(-Y + _inward(side) * 0.6, null, BF)]
		if n == "caseHandle":
			return ["cyl" if closing else "open", HandPose.Aim.new(-Y, null, BF)]
		if n == "caseSide":
			return ["flat", HandPose.Aim.new((PR["case"] as Node3D).global_position - hb, null, -Y)]
		if n == "latchR" or n == "latchL":
			return ["pinch", HandPose.Aim.new(-Y, null, BF)]
		if n == "lidEdge":
			return ["cyl", HandPose.Aim.new(Y, null, BF)]
		if n == "knob":
			return ["knob" if closing else "open", HandPose.Aim.new(BF, Y)]
		var us := n.find("_")
		if us > 0:
			var hd := n.substr(0, us)
			var id := n.substr(us + 1)
			if (hd == "grip" or hd == "gripL") and PR.has(id):      # fingers round the grip, thumb up it
				var a := _gun_axes(id)
				return ["cyl" if hd == "gripL" else "pistol", HandPose.Aim.new(a[0] if hd == "gripL" else -a[0], a[1])]
			if (hd == "slide" or hd == "slideBack") and PR.has(id):      # over the top of the slide
				var a := _gun_axes(id)
				return ["pinch", HandPose.Aim.new(-a[1], null, -a[0])]
		if n.begins_with("mag_"):
			return ["fist" if closing else "open", HandPose.Aim.new(-Y, null, BF)]
	if seated:      # resting on his thigh
		return ["relax", HandPose.Aim.new(-Y + _inward(side) * 0.4, null, BF)]
	return ["relax", null]


# ==================================================== prop placement: each prop's current holder, eased from where it was
func _holder_at(nm: String) -> int:
	if not TL["hold"].has(nm):
		return -1
	var l: Array = TL["hold"][nm]
	var i := -1
	for k in l.size():
		if float(l[k]["t"]) <= t:
			i = k
	return i


# (the transform a holder wants, handed back in these two)
var _op := Vector3.ZERO
var _oq := Quaternion.IDENTITY


func _rest_xf(nm: String) -> void:
	if nm == "lap":
		_op = _hip_pt(0.36, 0.08, 0.06)
		_oq = Animator.q_yxz(-PI / 2.0, _st.yaw, 0.0)
		return
	if nm == "caseCloset":      # stood on its edge, handle up
		var s: Vector3 = SPOT["caseCloset"]["p"]
		_op = Vector3(s.x + CASE_H, s.y + CASE_W / 2.0, s.z)
		_oq = Animator.q_yxz(0.0, 0.0, PI / 2.0)
		return
	if nm == "caseBed":
		_op = SPOT["caseBed"]["p"]
		_oq = Quaternion.IDENTITY
		return
	var s: Dictionary = SPOT[nm]
	_op = s["p"]
	var flat := nm == "phone" or nm == "phoneBed" or nm == "pack" or nm == "lighter"
	_oq = Animator.q_yxz(-PI / 2.0 if flat else 0.0, float(s.get("ry", 0.0)), 0.0)
	if nm == "pack" or nm == "lighter":
		_op.y += 0.012


## where a holder wants the prop now (world position + rotation)
func _target_xf(nm: String, h: Dictionary) -> void:
	if h.has("rest"):
		_rest_xf(h["rest"])
	elif h.has("magTray"):
		_mag_tray_xf(h["magTray"])
	elif h.has("mouth"):
		_op = _mouth_pt()
		var w := (BF * TUNE_CIG_AIM.x + Y * TUNE_CIG_AIM.y + BR * TUNE_CIG_AIM.z).normalized()
		_oq = Quaternion(Y, w)
	elif h.has("carry"):      # the handle in his fist
		var b: int = an.by_key[&"handR"].bone
		var a := an.bone_world_pos(b) + HandPose.palm_point("R", an.bone_world_quat(b))
		_oq = Animator.q_yxz(0.0, _st.yaw, PI / 2.0)
		_op = a - _oq * HANDLE
	elif h.has("gun"):
		_gun_xf(nm, h["gun"])
	elif h.has("inGun"):
		var id: String = h["inGun"]
		var qg: Quaternion = (PR[id] as Node3D).quaternion
		_op = _gun_pt(id, GUNLOC["well"]["smg" if id == "smg" else "deagle"]) + qg * Vector3.UP * 0.07
		_oq = qg
	elif h.has("hand"):      # in his hand: the prop sits in the hand's grip frame (hand_pose.gd), so it turns with the wrist
		var side: String = h["hand"]
		if h.get("aim", "") == "photo":      # (the photo is turned up to his eyes and the insert camera, held by its left edge)
			var b: int = an.by_key[StringName("hand" + side)].bone
			_op = an.bone_world_pos(b) + HandPose.palm_point(side, an.bone_world_quat(b))
			var z := (_eye_cam() - _op).normalized()
			var x := Y.cross(z).normalized()
			_oq = Basis(x, z.cross(x), z).get_rotation_quaternion()
			_op += _oq * Vector3.RIGHT * 0.12
			return
		var r := HandPose.grip_xf(an, side, PROP_GRIP.get(nm, "phone"))
		_op = r[0]
		_oq = r[1]


## guns: in their trays, held up in front of him (ready), tucked in his waistband, or the SMG carried low
func _gun_xf(id: String, how: String) -> void:
	var yaw := _st.yaw
	var cq: Quaternion = (PR["case"] as Node3D).quaternion
	match how:
		"tray":      # on its side, corner to corner (the suppressor is long)
			_op = (_kase["trays"][0 if id == "p1" else 1]["tr"] as Node3D).to_global(Vector3(-0.04, 0.05, -0.07))
			_oq = cq * Animator.q_yxz(0.0, 0.75, PI / 2.0)
		"smgFoam":
			_op = _case_local(0.02, 0.12, 0.0)
			_oq = cq * Animator.q_yxz(0.0, 0.0, PI / 2.0)
		"ready":
			if id == "smg":
				_op = _hip_pt(0.42, 0.1, 0.22)
				_oq = Animator.q_yxz(0.25, yaw - 0.35, 0.15)
			else:
				_op = _hip_pt(0.4, 0.08, 0.26)
				_oq = Animator.q_yxz(0.3, yaw - 0.55, 0.25)
		"hipR", "hipL":
			var s := 1.0 if how == "hipR" else -1.0
			_op = _hip_pt(0.2, s * 0.2, -0.02)
			_oq = Animator.q_yxz(PI / 2.0 - 0.2, yaw + s * 0.25 + PI, 0.0)
		"low":
			_op = _hip_pt(0.18, 0.3, -0.12)
			_oq = Animator.q_yxz(0.95, yaw - 0.15, 0.0)


## the magazines lie in the foam next to their guns
func _mag_tray_xf(id: String) -> void:
	if id == "smg":
		_op = _case_local(-0.17, 0.1, 0.24)
	else:
		_op = (_kase["trays"][0 if id == "p1" else 1]["tr"] as Node3D).to_global(Vector3(-0.17, 0.05, 0.1))
	_oq = (PR["case"] as Node3D).quaternion * Animator.q_yxz(0.0, 0.0, PI / 2.0)


# ==================================================== the case, the doors, smoke, the phone screen
func _animate_set() -> void:
	var K: Dictionary = TL["K"]
	var lt: Array = K["latch"]
	for i in 2:
		(_kase["latches"][i] as Node3D).rotation.z = -1.1 * _win(t, lt[i], float(lt[i]) + 0.12)
	var ld: Array = K["lid"]
	(_kase["lid"] as Node3D).rotation.z = 1.95 * _win(t, ld[0], ld[1])
	var glow_k := _win(t, float(ld[0]) + 0.25, float(ld[0]) + 0.45) * (1.0 if sin(t * 40.0) > -0.9 or t > float(ld[0]) + 1.0 else 0.3)
	(_kase["lid_light"] as OmniLight3D).light_energy = 2.4 * glow_k / PI
	(_kase["strip"] as StandardMaterial3D).albedo_color = Color(0.05 + 0.75 * glow_k, 0.08 + 0.82 * glow_k, 0.1 + 0.9 * glow_k).srgb_to_linear().linear_to_srgb()
	var xp: Array = K["expand"]
	var ex := _win(t, xp[0], xp[1])
	for tr_: Dictionary in _kase["trays"]:
		var n: Node3D = tr_["tr"]
		var s: float = tr_["s"]
		n.position.y = 0.02 + 0.075 + 0.11 * Cutscene.ease_(ex * 1.6)
		n.position.z = s * (CASE_L / 4.0 + 0.2 * Cutscene.ease_(ex * 1.4 - 0.4))
		for a: Node3D in tr_["arms"]:
			a.rotation.x = s * (0.9 - 0.9 * Cutscene.ease_(ex * 1.6))
			a.position.y = -0.04 - 0.05 * Cutscene.ease_(ex * 1.6)
	if t > float(K["cl"]) - 0.2:      # flung right back, out of the shot
		_level.closet.set_doors(2.85 * _win(t, K["clOpen"][0], K["clOpen"][1]))
	var D: Array = K["door"]
	var s_: Array = K["shut"]
	var door := 0.0
	if t >= float(D[0]):
		door = 0.55 * _win(t, D[0], D[1]) if t < float(D[1]) else 0.55 + 1.0 * _win(t, D[1], D[2])
	if t >= float(s_[0]):
		door *= 1.0 - _win(t, s_[0], s_[1]) ** 2
	if _front_door != null:
		_front_door.rotation.y = door
	(PR["hall"] as Node3D).visible = door > 0.01
	var w: Node3D = PR["wallet"]
	var open := _win(t, K["walOpen"][0], K["walOpen"][1]) * (1.0 - _win(t, K["walClose"][0], K["walClose"][1]))
	(w.get_meta("h_p") as Node3D).rotation.y = -1.25 * open
	(w.get_meta("h_m") as Node3D).rotation.y = 1.25 * open
	var scr := 0x0a0f12
	if _ringing:
		scr = 0xffffff if sin(t * 16.0) > 0.0 else 0x4fe0ff
	elif t < float(K["hang"]) + 0.3 and t > float(K["answer"]):
		scr = 0x2a90b5
	(_phone_screen.material_override as StandardMaterial3D).albedo_color = Color.hex((scr << 8) | 0xff)
	var lit := t >= float(K["lit"])
	_ember = clampf(0.45 + 0.15 * sin(t * 1.7), 0.3, 0.7) if lit else 0.0
	for dr: Array in K["drags"]:
		var a: float = dr[0]
		var b: float = dr[1]
		if t > a and t < b + 0.3:
			_ember = maxf(_ember, 0.6 + 0.4 * float(dr[2]) / 1.6 * _win(t, a, a + 0.3) * (1.0 - _win(t, b, b + 0.3)))
	_flame = 1.0 if t >= float(K["flame"][0]) and t < float(K["flame"][1]) else 0.0
	_exhale = 0.0
	for e: Array in K["exhale"]:
		if t > float(e[0]) and t < float(e[1]):
			_exhale = 1.0


func _emit_smoke(pos: Vector3, vel: Vector3, life: float, size: float, grow: float, op: float) -> void:
	var p := _smoke[_smoke_n % _smoke.size()]
	_smoke_n += 1
	p.p = pos
	p.v = vel
	p.age = 0.0
	p.life = life
	p.s0 = size
	p.gr = grow
	p.op = op


func _smoke_frame(dt: float) -> void:
	for i in _smoke.size():
		var p := _smoke[i]
		if p.age >= p.life:
			_smoke_mm.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		p.age += dt
		p.p += p.v * dt
		p.v *= exp(-0.9 * dt)
		p.v.y += 0.1 * dt
		var k := p.age / p.life
		var sc := p.s0 + p.gr * p.age
		_smoke_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), p.p))
		_smoke_mm.set_instance_color(i, Color(1, 1, 1, p.op * pow(maxf(1.0 - k, 0.0), 1.4) * minf(1.0, p.age / 0.12)))
	var cig_on: bool = (PR["cig"] as Node3D).visible and _ember > 0.0
	_cig_ember.visible = cig_on
	_cig_glow.visible = cig_on
	if cig_on:
		CineParts.glow_opacity(_cig_glow, 0.35 + 0.65 * _ember)
		_cig_glow.scale = Vector3.ONE * (0.04 + 0.05 * _ember)
		(_cig_ember.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.25 + 0.3 * _ember, 0.08)
	var fl := 0.85 + 0.15 * sin(t * 41.0) + 0.08 * sin(t * 67.0) if _flame > 0.0 else 0.0
	_flame_n.visible = _flame > 0.0
	_flame_core.visible = _flame > 0.0
	_flame_n.scale = Vector3.ONE * (0.1 * fl + 0.01)
	_flame_core.scale = Vector3.ONE * (0.045 * fl + 0.005)
	if dt <= 0.0:
		return
	if cig_on:
		_wisp_t -= dt
		if _wisp_t <= 0.0:
			_wisp_t = 0.09
			_emit_smoke(_cig_tip(), Vector3(0.03 * sin(t * 3.0), 0.1, 0.03 * cos(t * 2.3)), 2.8, 0.02, 0.07, 0.1)
	if _exhale > 0.0:
		var m := _mouth_pt()
		for i in 2:
			_emit_smoke(m, BF * (0.45 + randf() * 0.25) + Vector3((randf() - 0.5) * 0.15, 0.05 + randf() * 0.1, (randf() - 0.5) * 0.15), 2.4 + randf(), 0.05, 0.28, 0.2)
	var bp: float = TL["K"]["burp"]
	if t > bp and t < bp + 0.08:
		_emit_smoke(_mouth_pt(), BF * 0.3, 0.8, 0.04, 0.12, 0.06)


# ==================================================== Prog's pose (on top of the normal animator)
func _pi(k: String) -> int:
	if not _pose_i.has(k):
		_pose_i[k] = Animator.KEYS.find(StringName(k))
	return _pose_i[k]


func _pset(x: Animator, k: String, v0: float, v1: float, v2: float, m: float = 1.0) -> void:
	var i := _pi(k)
	if i < 0 or m <= 0.0:
		return
	x.pose[i] = x.pose[i].lerp(Vector3(v0, v1, v2), m)


func _padd(x: Animator, k: String, v0: float, v1: float, v2: float) -> void:
	var i := _pi(k)
	if i >= 0:
		x.pose[i] += Vector3(v0, v1, v2)


func _install_hook(a: Animator) -> void:
	_hooked = a
	a.pose_hook = _pose_hook


func _pose_hook(x: Animator) -> void:
	var st := _st
	if st == null:
		return
	var K: Dictionary = TL["K"]
	var leg_w := clampf(maxf(st.hip, st.knee) * 3.0, 0.0, 1.0)
	if leg_w > 0.0 or st.lie > 0.0:
		# The pelvis takes part of the hip bend (the spine leans back up to match): the animator's waist reskin ties the upper thighs and the shorts to the pelvis, so bending only the thighs 90 degrees left the shorts hanging straight down like a skirt.
		var m := maxf(leg_w, st.lie)
		var tilt := 0.62 * st.hip
		_pset(x, "pelvis", -tilt, 0.0, 0.0, m)
		_padd(x, "spine1", 0.55 * tilt * m, 0.0, 0.0)
		_padd(x, "spine2", 0.45 * tilt * m, 0.0, 0.0)
		for sd: Array in [["L", 1.0], ["R", -1.0]]:
			_pset(x, "thigh" + sd[0], -(st.hip - tilt), 0.0, float(sd[1]) * 0.07, m)
			_pset(x, "shin" + sd[0], st.knee, 0.0, 0.0, m)
			_pset(x, "foot" + sd[0], -0.1 * leg_w, 0.0, 0.0, m)
	if st.lie > 0.0:      # asleep: one arm across his belly, the other out at his side, head lolled to the phone
		var m := st.lie
		var b := sin(t * 1.4) * 0.03
		_pset(x, "upper_armR", -0.1, 0.0, -0.3, m)
		_pset(x, "forearmR", -0.45, 0.0, 0.0, m)
		_pset(x, "upper_armL", 0.05, 0.0, 0.4, m)
		_pset(x, "forearmL", -0.3, 0.0, 0.0, m)
		_pset(x, "head", 0.05, -0.55 * (1.0 - _win(t, K["wake"], float(K["wake"]) + 0.8)), 0.0, m)
		_padd(x, "spine2", b * m, 0.0, 0.0)
		_padd(x, "chest", b * m, 0.0, 0.0)
		var ks: float = K["stir"]
		var stir := _win(t, ks, ks + 0.5) * (1.0 - _win(t, ks + 1.3, ks + 2.0))
		_padd(x, "upper_armL", -0.6 * stir, 0.0, 0.3 * stir)
		_padd(x, "head", 0.0, 0.35 * stir, 0.0)
	_padd(x, "spine1", st.lean * 0.5, 0.0, 0.0)
	_padd(x, "spine2", st.lean * 0.5, 0.0, 0.0)
	# head: tipped back to drink, back again for the drags, a nod down to the photo
	var hx := 0.0
	var hy := 0.0
	for d: Array in [K["drink1"], K["drink2"]]:
		hx -= 0.5 * _win(t, d[0], float(d[0]) + 0.5) * (1.0 - _win(t, float(d[1]) - 0.2, float(d[1]) + 0.3))
	for e: Array in K["exhale"]:
		hx -= 0.18 * _win(t, e[0], float(e[0]) + 0.3) * (1.0 - _win(t, float(e[1]) - 0.5, e[1]))
	hx += 0.15 * _win(t, float(K["photo"]) - 0.6, K["photo"]) * (1.0 - _win(t, float(K["face"]) + 0.2, float(K["face"]) + 0.8))
	hx += 0.12 * _win(t, float(K["burp"]) - 0.05, float(K["burp"]) + 0.05) * (1.0 - _win(t, float(K["burp"]) + 0.35, float(K["burp"]) + 0.7))
	if t > float(K["answer"]) and t < float(K["hang"]):
		hy -= 0.12
		hx += 0.06 * (sin(t * 9.0) * 0.6 if _line != null and _line["who"] == PROG else 0.0)
	hx += 0.25 * _win(t, K["expand"][1], float(K["expand"][1]) + 0.5) * (1.0 - _win(t, float(K["end"]) - 18.0, float(K["end"]) - 17.0))
	_padd(x, "head", hx, hy, 0.0)
	_padd(x, "neck", hx * 0.3, 0.0, 0.0)


# ==================================================== subtitles (the shared box) + voices
func _say_line(l: Dictionary) -> void:
	_line = {"who": l["who"], "text": l["text"], "t0": l["t0"], "t1": l["t1"], "src": l, "voiced": 0, "shown": -1}
	Game.ui.dialog.show_box(true)
	Game.ui.dialog.set_content("", "", "")


func _end_line() -> void:
	_line = null
	Game.ui.dialog.show_box(false)


func _tick_line() -> void:
	if _line == null:
		return
	if t >= float(_line["t1"]):      # nobody talking: the box goes away (also after a seek)
		_end_line()
		return
	var who: Dictionary = _line["who"]
	var text: String = _line["text"]
	var n := mini(text.length(), maxi(0, floori((t - float(_line["t0"])) * float(who["rate"]))))
	for i in range(int(_line["voiced"]), n):
		var ch := text[i].to_lower()
		var prev := text[i - 1].to_lower() if i > 0 else " "
		if "aeiou".contains(ch) and not "aeiou".contains(prev):
			PhoneVoice.voice_syllable(who, ch, i, PhoneVoice.last_syllable(text, i), prev)
			if who == BOSS:
				_kick = 1.0
	_line["voiced"] = maxi(int(_line["voiced"]), n)
	if n != int(_line["shown"]):
		_line["shown"] = n
		Game.ui.dialog.set_content(String(who["name"]) + (" (PHONE)" if who == BOSS else ""), text.substr(0, n), "SKIP")


# ==================================================== camera
func _pt_of(x: Variant, i: int) -> Vector3:
	return (x as Callable).call() if x is Callable else x[i]


func _update_camera() -> void:
	var sh: Dictionary = TL["shots"][0]
	for s: Dictionary in TL["shots"]:
		if float(s["t0"]) <= t:
			sh = s
		else:
			break
	var u := Cutscene.ease_((t - float(sh["t0"])) / float(sh["d"]))
	var p0 := _pt_of(sh["a"], 0)
	var p1 := _pt_of(sh["a"], 1)
	var l0 := _pt_of(sh["b"], 0)
	var l1 := _pt_of(sh["b"], 1)
	p0 = p0.lerp(p1, u)
	l0 = l0.lerp(l1, u)
	if sh.has("push"):
		p0 = p0.lerp(l0, float(sh["push"]) * u)
	if sh.has("lookMix"):
		var lm: Dictionary = sh["lookMix"]
		l0 = l0.lerp(lm["to"], _win(t, lm["t0"], float(lm["t0"]) + float(lm["d"])))
	var sway := 0.012
	p0.x += sway * sin(t * 0.6)
	p0.y += sway * sin(t * 0.47)
	camera.pos = p0
	camera.look = l0
	camera.fov = float(sh.get("fov", 50.0))


func _fade_level() -> float:
	var o := 0.0
	for f: Array in TL["fades"]:
		var a: float = f[0]
		var b: float = f[1]
		if t >= a:
			o = lerpf(f[2], f[3], Cutscene.ease_((t - a) / (b - a))) if t < b else float(f[3])
	if _skip_at >= 0.0:
		o = maxf(o, clampf((t - _skip_at) / 0.45, 0.0, 1.0))
	return o


# ==================================================== control
func play() -> bool:
	P = Game.player
	if on or P == null:
		return false
	an = Game.animator
	_prev_armed = {"armed": P.armed, "idx": P.weapon_idx}
	P.armed = false      # (before the photo: its models are posed off the player's state)
	P.rl_on = false
	P.ads = false
	P.vx = 0.0
	P.vz = 0.0
	P.vy = 0.0
	P.grounded = true
	if g == null:
		g = Node3D.new()
		g.name = "wake-up cutscene"
		_level.add_child(g)
		var fd := _level.node_named("front door")
		_front_door = fd[0] if not fd.is_empty() else null
		_make_props()
		_render_photo()
	TL = _build()
	g.visible = true
	on = true
	t = 0.0
	_ei = 0
	_leaving = false
	_skip_at = -1.0
	_st = null
	_ember = 0.0
	_flame = 0.0
	_exhale = 0.0
	_ringing = false
	_kick = 0.0
	_placed.clear()
	_smoke_n = 0
	_wisp_t = 0.0
	for p: Puff in _smoke:
		p.age = 9.0
	_tv_was = _level.props.tv_on
	_level.props.set_tv(true)
	Game.ui.dialog.set_bars(true, true)
	Game.hud.set_suppressed(true)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.ui.add_child(_fade)
	Game.ui.move_child(_fade, Game.ui.dialog.get_index())
	_hint = CrtTheme.label("X  SKIP", &"vt323", 20, Color("#5dff8f"), 4)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	Game.ui.add_child(_hint)
	_hint.position = Vector2(_hint.position.x - 22.0, _hint.position.y - Game.ui.size.y * 0.125 - 14.0)
	_hint_t = 0.0
	_st = _state_at(0.0)
	return true


## straight to the hand-off: a quick fade to black and out of the door
func skip() -> void:
	if not on or _leaving or _skip_at >= 0.0:
		return
	_skip_at = t
	_ringing = false
	_end_line()


func seek(s: float) -> void:
	if not on:
		return
	t = s
	_ei = 0
	while _ei < _ev.size() and float(_ev[_ei]["t"]) < s:
		_ei += 1
	var K: Dictionary = TL["K"]
	_ringing = s > float(K["ring0"]) and s < float(K["ph"]) + 0.7
	for k: String in _placed:
		(_placed[k] as Placed).i = -2
	_end_line()
	for x: Dictionary in TL["lines"]:      # (the line being spoken, without replaying its voice)
		if s >= float(x["t0"]) and s < float(x["t1"]):
			_say_line(x)
			_line["voiced"] = 1000000000
			break
	_snap_hands = true


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_end_line()
	if _fade != null:
		_fade.color.a = 1.0
	var pt: Dictionary = _level.portals[0] if not _level.portals.is_empty() else {}
	if pt.is_empty() or not Game.LEVELS.has(String(pt.get("to", ""))):
		_finish()
		return
	Game.doors.travel(pt)      # (the level is unloaded long before anything else happens here)


func _finish() -> void:
	if not on:
		return
	on = false
	if _hooked != null:
		_hooked.pose_hook = Callable()
		_hooked = null
	_cleanup_ui()
	if g != null:
		g.visible = false
	if _front_door != null:
		_front_door.rotation.y = 0.0
	_level.closet.set_doors(0.0)
	_level.props.set_tv(_tv_was)
	if P != null:
		P.crouch_hide = false
		P.armed = _prev_armed["armed"] if _prev_armed != null else false
		if _prev_armed != null:
			P.weapon_idx = _prev_armed["idx"]
		P.x = ApartmentLevel.SPAWN["x"]
		P.z = ApartmentLevel.SPAWN["z"]
		P.y = ApartmentLevel.SPAWN["y"]
		P.vx = 0.0
		P.vz = 0.0
		Game.rig.snap_to(P)


func _cleanup_ui() -> void:
	_end_line()
	Game.ui.dialog.set_bars(false)
	if Game.started:
		Game.hud.set_suppressed(false)
	Inp.guard_arm()
	if _fade != null:
		_fade.queue_free()
		_fade = null
	if _hint != null:
		_hint.queue_free()
		_hint = null


func update(dt: float) -> void:
	if not on or P == null:
		return
	_photo_step()
	if not hold:
		t += dt
	_hint_t += dt
	if Inp.key_hit(KEY_X) or Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_SPACE) or Inp.key_hit(KEY_KP_ENTER):
		skip()
	if Inp.using_pad and (Inp.btn(&"b").pressed or Inp.btn(&"attack").pressed):
		Inp.btn(&"attack").pressed = false
		skip()
	while _ei < _ev.size() and float(_ev[_ei]["t"]) <= t:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		if _skip_at < 0.0:
			(e["fn"] as Callable).call()
	if _skip_at >= 0.0 and t - _skip_at > 0.5:
		_leave()
		return
	if t >= float(TL["K"]["end"]):
		_leave()
		return
	var st := _state_at(t)
	_st = st
	P.x = st.px
	P.z = st.pz
	P.y = 0.0
	P.yaw = st.yaw
	P.vx = st.vx
	P.vz = st.vz
	P.vy = 0.0
	P.grounded = true
	P.dead = false
	P.crouch_hide = true      # the equipped gun is not drawn (combat re-arms him every frame); his guns here are props
	_kick = maxf(0.0, _kick - dt * 9.0)
	_animate_set()
	_tick_line()
	_update_camera()
	if _fade != null:
		_fade.color.a = _fade_level()
	if _hint != null and _hint_t > 2.5:      # (while a line is up, the subtitle box carries the hint)
		_hint.modulate.a = move_toward(_hint.modulate.a, 0.0 if _line != null else 0.75, dt / 0.6)
	var flick := sin(t * 0.9) > 0.9 and randf() < 0.4
	_hall_light.light_energy = 2.2 * (0.15 if flick else 1.0) / PI
	(_hall_tube.material_override as StandardMaterial3D).albedo_color = Color.hex(0x4a5040ff if flick else 0xe8f0c8ff)
	_dt = dt


## after the animator's own update: place the actor (lying, sitting), solve the hands, put the props where they belong
func pose_player(a: Animator) -> void:
	if not on or _st == null:
		return
	an = a
	if _hooked != a:
		_install_hook(a)
	var st := _st
	var A := a.actor
	A.visible = true
	A.position = Vector3(st.ox, st.oy, st.oz)
	A.rotation = Vector3(st.pitch, st.yaw, 0.0)      # (a Node3D's Euler order is YXZ)
	O = Vector3(st.ox, st.oy, st.oz)
	BF = Vector3(sin(st.yaw), 0.0, cos(st.yaw))
	BR = Vector3(-BF.z, 0.0, BF.x)
	var hd: Animator.BoneRec = a.by_key.get(&"head")
	HEAD = a.bone_world_pos(hd.bone) if hd != null else O + Y * 0.7
	_place_pass(false)
	_sample_ik("R")
	_sample_ik("L")
	var aq := A.global_basis.get_rotation_quaternion()
	# seated, a free hand rests on his thigh (the standing idle arms would hang down through the seat); a beat's hand target blends out from there
	var seat_w := clampf((st.knee - 0.5) / 0.7, 0.0, 1.0) * (1.0 - st.lie)
	if seat_w > 0.0:
		for sd: String in HandPose.SIDES:
			var h: IkS = _ik_s[sd]
			h.p = _hip_pt(0.3, 0.19 if sd == "R" else -0.19, 0.04).lerp(h.p, h.w)
			h.w = maxf(h.w, seat_w)
	# the hands: goals from what they hold / reach for; on a surface or a prop the palm (not the wrist) goes to the target
	var dt := _dt
	for sd: String in HandPose.SIDES:
		var h: IkS = _ik_s[sd]
		var gl := _hand_goal(sd, seat_w > 0.5 and not (h.name != "" and h.w > 0.15 and h.name != "restR" and h.name != "restL"))
		hands.goal(sd, gl[0], gl[1])
		var hs: HandPose.Hand = hands.state[sd]
		var v := Vector3.ZERO
		if hs.aim_w > 0.01 and h.name != "" and _surface(h.name) and _held_by(sd) == null:      # (eased: switching it on at a grab made the wrist pop 5 cm)
			v = HandPose.palm_point(sd, hs.q) * hs.aim_w
		_palm_off[sd] = v if _snap_hands else (_palm_off[sd] as Vector3).lerp(v, 1.0 - exp(-8.0 * dt))
		h.p -= _palm_off[sd]
	var hr: IkS = _ik_s["R"]
	var hl: IkS = _ik_s["L"]
	if hr.w > 0.003:
		a._ik(1, hr.p, aq * Vector3(-0.5, -1.0, -0.35), hr.w)
	if hl.w > 0.003:
		a._ik(0, hl.p, aq * Vector3(0.5, -1.0, -0.35), hl.w)
	if _snap_hands:      # (after a seek: straight to the goals, no easing in from the last spot)
		hands.snap()
		_snap_hands = false
	hands.apply(a, dt, t)
	_place_pass(true)
	_smoke_frame(dt)
	_dt = 0.0


## one pass over the props: hand-held ones (hands = true) after the IK, the rest before it
func _place_pass(hand_pass: bool) -> void:
	var K: Dictionary = TL["K"]
	for nm: String in PR:
		if nm == "hall":
			continue
		var obj: Node3D = PR[nm]
		var i := _holder_at(nm)
		var h: Dictionary
		if i >= 0:
			h = TL["hold"][nm][i]
		elif DEFAULT_HOLD.has(nm):
			h = {"place": DEFAULT_HOLD[nm], "t": -1.0, "blend": 0.0}
		else:
			continue
		var pl: Dictionary = h["place"]
		var hand_dep: bool = pl.has("hand") or pl.has("carry")
		if hand_dep != hand_pass:
			continue
		if not _placed.has(nm):
			_placed[nm] = Placed.new()
		var st: Placed = _placed[nm]
		if pl.has("hide"):
			obj.visible = false
			st.i = i
			continue
		var gun_how: String = pl.get("gun", "")
		obj.visible = not (pl.has("inGun") and t > float(h["t"]) + float(h["blend"])) and not ((gun_how == "tray" or gun_how == "smgFoam" or pl.has("magTray")) and t < float(K["lid"][0]) + 0.3)   # (the guns stay out of sight until the lid is up)
		_target_xf(nm, pl)
		if st.i != i:
			var fresh := st.i == -2
			st.fp = _op if fresh else obj.position
			st.fq = _oq if fresh else obj.quaternion
			st.t = h["t"]
			st.i = i
		var u: float = Cutscene.ease_((t - st.t) / float(h["blend"])) if float(h["blend"]) > 0.0 else 1.0
		obj.position = st.fp.lerp(_op, u)
		obj.quaternion = st.fq.normalized().slerp(_oq.normalized(), u)


## the level is being unloaded (or the cutscene was cut short by it): let go of everything shared
func dispose() -> void:
	if _hooked != null:
		_hooked.pose_hook = Callable()
		_hooked = null
	if on and P != null:
		P.crouch_hide = false
		if _prev_armed != null:
			P.armed = _prev_armed["armed"]
	var was := on
	on = false
	if was:
		_cleanup_ui()
