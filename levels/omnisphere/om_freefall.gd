class_name OmFreefall
extends RefCounted
## OMNISPHERE: THE DROP, the opening (JS freefall.js). PROG stowed away on cargo tug 9; the plant's air defence makes him, the Repo-Man gunship comes up for the tug and he goes out of the back ramp. A Ratchet & Clank style freefall onto Receiving Pad 3: the fall is locked on to the pad (he steers round the fall line, never off it), the camera hangs above and behind him looking down the drop, and everything the plant puts up comes at him. He fires his own guns: hip fire from a free reticle that soft-locks and, trigger held, rides its target; or aim down sights, the view over his right shoulder, reticle at centre. He rolls out of the way of missiles (jump), and at the bottom the pack lights on its own and brakes him onto the pad. The fall is scripted in time (FALL keys), so the landing is always at T_LAND, on the music's last hit.

const T_LAND := 57.6
const T_STALL := T_LAND - 2.3
const T_REPO := 27.5
const FALL := [[0.0, 0.0], [2.4, 22.0], [16.0, 22.0], [18.5, 27.0], [24.5, 27.0], [27.0, 23.0], [49.0, 23.0], [51.5, 28.0], [T_STALL, 28.0], [T_LAND, 1.6]]      # [t, m/s]
const PAD := Vector3(0, 6, 0)
const I_JUMP := 4.6
# off the ramp (fall seconds): he drops away on his back watching Tug 9; the second missile takes it ~25 m over him (T_HIT), he half-rolls belly-down (FLIP0..FLIP1) as the view swings from the tug down the drop (LB0..LB1)
const T_HIT := 2.1
const FLIP0 := 2.45
const FLIP1 := 3.45
const LB0 := 2.55
const LB1 := 3.85
const TUG_V := 9.0
const RAMP_END := Vector3(0, -1.65, -10.8)
# PROG's body: model-space pose deltas (animator conventions)
const ARCH := {"pelvis": [0, 0, 0], "spine1": [-.14, 0, 0], "spine2": [-.14, 0, 0], "chest": [-.1, 0, 0], "neck": [-.25, 0, 0], "head": [-.32, 0, 0],      # belly to earth: back arched, head up, arms out with the forearms forward, knees bent with the shins up behind
	"clavicleL": [0, 0, .12], "clavicleR": [0, 0, -.12], "upper_armL": [0, -.12, 1.5], "upper_armR": [0, .12, -1.5], "forearmL": [0, -.15, 1.0], "forearmR": [0, .15, -1.0], "handL": [0, 0, .2], "handR": [0, 0, -.2],
	"thighL": [.12, 0, .24], "thighR": [.12, 0, -.24], "shinL": [1.35, 0, 0], "shinR": [1.35, 0, 0], "footL": [.55, 0, 0], "footR": [.55, 0, 0], "toeL": [0, 0, 0], "toeR": [0, 0, 0]}
const DIVE := {"pelvis": [0, 0, 0], "spine1": [.1, 0, 0], "spine2": [.1, 0, 0], "chest": [0, 0, 0], "neck": [-.2, 0, 0], "head": [-.3, 0, 0],      # off the ramp: arms forward over the head, legs together
	"clavicleL": [0, 0, .2], "clavicleR": [0, 0, -.2], "upper_armL": [-2.6, 0, .25], "upper_armR": [-2.6, 0, -.25], "forearmL": [-.2, 0, 0], "forearmR": [-.2, 0, 0], "handL": [0, 0, 0], "handR": [0, 0, 0],
	"thighL": [.05, 0, .05], "thighR": [.05, 0, -.05], "shinL": [.3, 0, 0], "shinR": [.3, 0, 0], "footL": [.6, 0, 0], "footR": [.6, 0, 0], "toeL": [0, 0, 0], "toeR": [0, 0, 0]}
const BRAKE := {"pelvis": [0, 0, 0], "spine1": [.06, 0, 0], "spine2": [.06, 0, 0], "chest": [.04, 0, 0], "neck": [0, 0, 0], "head": [.12, 0, 0],      # the pack braking him: upright, legs down and bent for the landing, arms out for balance
	"clavicleL": [0, 0, .1], "clavicleR": [0, 0, -.1], "upper_armL": [-.2, 0, .95], "upper_armR": [-.2, 0, -.95], "forearmL": [0, -.3, .5], "forearmR": [0, .3, -.5], "handL": [0, 0, .1], "handR": [0, 0, -.1],
	"thighL": [-.45, 0, .1], "thighR": [-.3, 0, -.1], "shinL": [.75, 0, 0], "shinR": [.6, 0, 0], "footL": [-.25, 0, 0], "footR": [-.2, 0, 0], "toeL": [0, 0, 0], "toeR": [0, 0, 0]}
const LIMP := {"pelvis": [0, 0, 0], "spine1": [.2, 0, 0], "spine2": [.15, 0, 0], "chest": [.1, 0, 0], "neck": [.3, 0, 0], "head": [.3, .3, 0],      # knocked out: everything loose
	"clavicleL": [0, 0, 0], "clavicleR": [0, 0, 0], "upper_armL": [-1.8, 0, .6], "upper_armR": [-1.6, 0, -.9], "forearmL": [0, 0, .6], "forearmR": [0, 0, -.4], "handL": [0, 0, 0], "handR": [0, 0, 0],
	"thighL": [-.6, 0, .3], "thighR": [.2, 0, -.2], "shinL": [.9, 0, 0], "shinR": [1.3, 0, 0], "footL": [.4, 0, 0], "footR": [.4, 0, 0], "toeL": [0, 0, 0], "toeR": [0, 0, 0]}

static var _keys := {}
static var TAB := PackedFloat32Array()
static var DROP := 0.0
static var START := Vector2.ZERO
static var HEAD := 0.0


static func clamp_(v: float, a: float, c: float) -> float:
	return minf(c, maxf(a, v))


static func sm(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func wrap_a(a: float) -> float:
	return atan2(sin(a), cos(a))


static func damp(a: float, c: float, k: float, dt: float) -> float:
	return a + (c - a) * (1.0 - exp(-k * dt))


static func speed_at(t: float) -> float:
	for i in range(1, FALL.size()):
		if t <= float(FALL[i][0]):
			var t0: float = FALL[i - 1][0]
			var v0: float = FALL[i - 1][1]
			var t1: float = FALL[i][0]
			var v1: float = FALL[i][1]
			var u := (t - t0) / (t1 - t0)
			return lerpf(v0, v1, 1.0 - (1.0 - u) * (1.0 - u) if i == FALL.size() - 1 else u)
	return FALL[FALL.size() - 1][1]


static func _ensure_tab() -> void:
	if not TAB.is_empty():
		return
	var n := ceili(T_LAND / .01) + 2
	TAB.resize(n)
	TAB[0] = 0.0
	for i in range(1, n):
		TAB[i] = TAB[i - 1] + speed_at((i - .5) * .01) * .01
	var f := clampf(T_LAND, 0.0, T_LAND) / .01
	var k := int(f)
	DROP = lerpf(TAB[k], TAB[mini(n - 1, k + 1)], f - k)      # ~1510 m of air
	# the fall line: from the jump point (out over the caldera, south-east, on the line pad -> Omnisphere) curving down to vertical over the pad
	var od := Vector2(OmMarks.OMNI.x - PAD.x, OmMarks.OMNI.z - PAD.z).normalized()
	START = Vector2(PAD.x - od.x * 1000.0, PAD.z - od.y * 1000.0)
	HEAD = atan2(PAD.x - START.x, PAD.z - START.y)      # yaw toward the pad (and the Omnisphere beyond it)


static func dist_at(t: float) -> float:
	var f := clampf(t, 0.0, T_LAND) / .01
	var i := int(f)
	return lerpf(TAB[i], TAB[mini(TAB.size() - 1, i + 1)], f - i)


static func frame_at(t: float) -> Vector3:
	var d := dist_at(t)
	var u := d / DROP
	var s := 1.0 - (1.0 - u) * (1.0 - u)
	return Vector3(lerpf(START.x, PAD.x, s), PAD.y + DROP - d, lerpf(START.y, PAD.z, s))


static func _key(k: String) -> int:
	if _keys.is_empty():
		var map := {"upper_armL": &"upperarmL", "upper_armR": &"upperarmR"}
		for q: String in ARCH:
			_keys[q] = -1
		for q: String in _keys:
			for cand: StringName in [StringName(q), map.get(q, StringName(q))]:
				var i: int = Animator.KEYS.find(cand)
				if i >= 0:
					_keys[q] = i
					break
	return _keys.get(k, -1)


## set named pose deltas ({key: [x, y, z]}) on an animator (JS a.pose[k] = [x, y, z])
static func sets(a: Variant, d: Dictionary) -> void:
	for k: String in d:
		var i := _key(k)
		if i >= 0:
			a.pose[i] = Vector3(d[k][0], d[k][1], d[k][2])


## the blend the dive and the fall both use: arch -> dive by dv, -> brake by st
static func set_pose(a: Variant, A: Dictionary, D: Dictionary, dv: float, B: Dictionary, st: float, L: Dictionary = {}, li: float = 0.0) -> void:
	for k: String in A:
		var i := _key(k)
		if i < 0:
			continue
		var v := Vector3.ZERO
		for c in 3:
			var x := lerpf(float(A[k][c]), float(D[k][c]), dv)
			x = lerpf(x, float(B[k][c]), st)
			if li != 0.0:
				x = lerpf(x, float(L[k][c]), li)
			v[c] = x
		a.pose[i] = v


## the wind: forearms, shins and hands shiver, harder the faster he falls
static func flutter(a: Variant, tt: float, f: float) -> void:
	var fl := _key("forearmL")
	if fl < 0:
		return
	var p: PackedVector3Array = a.pose
	p[fl].z += sin(tt * 19.0) * f
	p[_key("forearmR")].z -= sin(tt * 17.0 + 1.0) * f
	p[_key("shinL")].x += sin(tt * 15.0 + 2.0) * f * 1.5
	p[_key("shinR")].x += sin(tt * 16.5) * f * 1.5
	a.pose = p


class Aim:
	var pos := Vector3.ZERO
	var look := Vector3.ZERO
	var dist := 9.0


class CineApi:
	var F: OmFreefall
	var on: bool:
		get:
			return F.on
	var play: bool:
		get:
			return F.phase == "fall" and Game.player != null and not Game.player.dead
	var camera: View.Shot:
		get:
			return F.cam
	var aim: Aim:
		get:
			return F.aim
	func pose_player(a: Variant) -> void:
		F.pose_player(a)


## the phosphor HUD: reticle, altimeter, missile warning, markers, hints (JS #ff-hud)
class FfHud:
	extends Control
	var ret_on := false
	var ret := Vector2.ZERO
	var lock_ := false
	var ads := false
	var hit_a := 0.0
	var hit_p := Vector2(-99, -99)
	var hit_kill := false
	var alt := 0
	var tape := 0.0
	var vel := 0
	var alt_on := false
	var warn := false
	var marks: Array = []      # [pos, on-screen?, angle, scale]
	var hint := ""
	var hint_a := 0.0
	var fade_a := 0.0
	var vig := 0.0
	var font: Font
	var t := 0.0
	const G := Color("#8dffb4")
	const A := Color("#ffb43c")

	func _draw() -> void:
		var vp := size
		if vig > 0.0:
			for i in 6:      # (the vignette: a few soft frames)
				var w := vp.x * .06 * (i + 1) / 6.0
				var c := Color(.08, .024, .008, .09 * vig)
				draw_rect(Rect2(0, 0, w, vp.y), c)
				draw_rect(Rect2(vp.x - w, 0, w, vp.y), c)
				draw_rect(Rect2(0, 0, vp.x, w * .7), c)
				draw_rect(Rect2(0, vp.y - w * .7, vp.x, w * .7), c)
		if ret_on:
			var p := ret
			var col := A if lock_ else G
			var s := (.42 if ads else .62) if lock_ else (.55 if ads else 1.0)
			for q: Array in [[Vector2(-22, -10), Vector2(-22, -22), Vector2(-10, -22)], [Vector2(10, -22), Vector2(22, -22), Vector2(22, -10)], [Vector2(22, 10), Vector2(22, 22), Vector2(10, 22)], [Vector2(-10, 22), Vector2(-22, 22), Vector2(-22, 10)]]:
				draw_polyline(PackedVector2Array([p + (q[0] as Vector2) * s, p + (q[1] as Vector2) * s, p + (q[2] as Vector2) * s]), col, 2.2)
			draw_arc(p, 13.0 * s, 0.0, TAU, 24, Color(col, .7), 1.4)
			draw_circle(p, 2.2, Color("#ffd890") if lock_ else Color("#c8ffd8"))
			if lock_:
				draw_string(font, p + Vector2(-16, 40), "LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, A)
		if hit_a > 0.0:
			var c := A if hit_kill else Color("#e8fff0")
			var s := 14.0 * (1.35 if hit_kill else 1.0)
			draw_line(hit_p + Vector2(-s, -s), hit_p + Vector2(s, s), Color(c, hit_a), 3.0)
			draw_line(hit_p + Vector2(s, -s), hit_p + Vector2(-s, s), Color(c, hit_a), 3.0)
		if alt_on:
			var x := vp.x - 34.0
			var y := vp.y * .5 - 170.0
			draw_string(font, Vector2(x - 40, y), "ALT", HORIZONTAL_ALIGNMENT_RIGHT, 40, 15, Color(G, .75))
			draw_string(font, Vector2(x - 118, y + 38), "%04d" % alt, HORIZONTAL_ALIGNMENT_RIGHT, 118, 40, G)
			draw_string(font, Vector2(x - 40, y + 56), "M", HORIZONTAL_ALIGNMENT_RIGHT, 40, 15, Color(G, .75))
			var ty := y + 68.0
			draw_rect(Rect2(x - 10, ty, 10, 210), Color("#031008"))
			draw_rect(Rect2(x - 10, ty, 10, 210), Color("#2f8a4c"), false, 1.0)
			var h := 210.0 * tape
			draw_rect(Rect2(x - 10, ty + 210.0 - h, 10, h), Color("#2fd46a"))
			draw_rect(Rect2(x - 26, ty + 209.0, 12, 2), A)
			draw_string(font, Vector2(x - 118, ty + 234), "PAD 3", HORIZONTAL_ALIGNMENT_RIGHT, 118, 15, Color(G, .8))
			draw_string(font, Vector2(x - 118, ty + 252), "%d M/S" % vel, HORIZONTAL_ALIGNMENT_RIGHT, 118, 15, Color(G, .8))
		if warn and fmod(t, .32) < .16:
			draw_string(font, Vector2(0, vp.y * .15 + 24), "MISSILE", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 30, A)
		var red := Color("#ff5a3a")
		for m: Array in marks:
			var p: Vector2 = m[0]
			if m[1]:
				var s: float = m[3]
				draw_polyline(PackedVector2Array([p + Vector2(0, -14) * s, p + Vector2(14, 0) * s, p + Vector2(0, 14) * s, p + Vector2(-14, 0) * s, p + Vector2(0, -14) * s]), red, 2.4)
				draw_polyline(PackedVector2Array([p + Vector2(0, -6) * s, p + Vector2(6, 0) * s, p + Vector2(0, 6) * s, p + Vector2(-6, 0) * s, p + Vector2(0, -6) * s]), red, 2.4)
			else:
				var a: float = m[2]
				draw_polyline(PackedVector2Array([p + Vector2(-10, -12).rotated(a), p + Vector2(12, 0).rotated(a), p + Vector2(-10, 12).rotated(a)]), red, 2.4)
				draw_polyline(PackedVector2Array([p + Vector2(-16, -7).rotated(a), p + Vector2(-2, 0).rotated(a), p + Vector2(-16, 7).rotated(a)]), red, 2.4)
		if hint_a > 0.0 and hint != "":
			draw_string(font, Vector2(0, vp.y * .84), hint, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 19, Color(G, hint_a))
		if fade_a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, fade_a))


var lv: ExportedLevel
var bo: Blockout
var audio: OmAudio
var sky: OmSkyFoes
var craft: OmCraft
var on := false
var phase := "off"
var t := 0.0
var it := 0.0
var landed := false
var dead_t := 0.0
var died := false
var lb := false
var ship_t := -1.0
var tail := 0.0
var resetting := false
var reset_t := 0.0
var stall_alt := 30.0
var jump_snd := false
var vel_s := 0.0
var aim_dir := Vector3.ZERO
var F := Vector3.ZERO
var Fp := Vector3.ZERO
var dF := Vector3.ZERO
var off := Vector3.ZERO
var ov := Vector3.ZERO
var pc := Vector3.ZERO
var pv := Vector3.ZERO
var fwd := Vector3.BACK
var right := Vector3.RIGHT
var cam := View.Shot.new()
var aim := Aim.new()
var cine := CineApi.new()
var cam_s_p := Vector3.ZERO
var cam_s_l := Vector3.ZERO
var cam_s_init := false
var cam_i_p := Vector3.ZERO
var cam_i_l := Vector3.ZERO
var body := {"yaw": 0.0, "pitch": 1.3, "bank": 0.0, "dive": 0.0, "brake": 0.0, "limp": 0.0, "roll_a": 0.0, "flip": 0.0, "arms_out": 1.0, "flut": 0.0, "cam_bank": 0.0}
var ret := {"x": 0.0, "y": .22, "idle": 0.0, "lock": null}
var ads := {"on": false, "w": 0.0, "yaw": 0.0, "pitch": 0.0}
var roll := {"t": 9.0, "cd": 0.0, "dir": Vector3.ZERO}
var psi_off := 0.0
var hud: FfHud
var layer: CanvasLayer
var tug: OmCraft.Cargo = null
var ship0: OmCraft.Gunship = null
var events: Array = []
var beep_t := 0.0
var hint_t := 0.0
var was_firing := 0.0
var flak_t := 0.0
var stream_t := 0.0
var hit_t := 0.0
var hit_p := Vector3.ZERO
var hit_kill := false
var hp := {}
var ret_dir := Vector3(0, -1, 0)
var tug_p := Vector3.ZERO
var ship_v := Vector3.ZERO
var msl: Array = []
var _hook := Callable()
var _an: Variant = null
var saved := false
var frame_o := OmSkyFoes.Frame.new()
var air_clouds: MultiMeshInstance3D
var air_streaks: MeshInstance3D
var air_mesh := ImmediateMesh.new()
var air_base: Array[Vector3] = []
var air_anchor := Vector3.ZERO
var fog_d := .0017


func _init(p_lv: ExportedLevel, p_bo: Blockout, p_craft: OmCraft, p_audio: OmAudio, p_sky: OmSkyFoes) -> void:
	lv = p_lv
	bo = p_bo
	craft = p_craft
	audio = p_audio
	sky = p_sky
	cine.F = self
	_hook = _pose
	_ensure_tab()
	layer = CanvasLayer.new()
	layer.layer = 13
	lv.add_child(layer)
	hud = FfHud.new()
	hud.font = load("res://assets/fonts/VT323-Regular.ttf")
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	layer.add_child(hud)
	for m: Array in [[3.55, 1.1, Vector3(3, 4, -17), true], [I_JUMP + T_HIT - 1.15, 1.15, Vector3(0, 1.6, 0), false]]:      # Tug 9's two missiles (intro seconds): the first streaks past the open ramp (that is when he runs), the second takes the tug once he is well clear
		msl.append({"at": m[0], "dur": m[1], "aim": m[2], "miss": m[3], "t": -1.0, "g": null, "from": Vector3.ZERO, "end": Vector3.ZERO, "dir": Vector3.ZERO})
	_build_air()


# ---- the sky he falls through: the ash cloud deck, wisps, wind streaks
func _build_air() -> void:
	var root := Node3D.new()
	root.name = "freefall air"
	lv.add_child(root)
	var seed_ := [7]
	var rnd := func() -> float:
		seed_[0] = (int(seed_[0]) * 16807) % 2147483647
		return float(seed_[0]) / 2147483647.0
	var along := func(u: float, side: float) -> Vector3:
		var s := 1.0 - (1.0 - u) * (1.0 - u)
		return Vector3(lerpf(START.x, PAD.x, s) - cos(HEAD) * side, 0.0, lerpf(START.y, PAD.z, s) + sin(HEAD) * side)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = MsKit.quad()
	mm.instance_count = 230
	var i := 0
	while i < 50:      # high wisps
		var u: float = rnd.call() * .16
		var p: Vector3 = along.call(u, (rnd.call() - .5) * 700.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x + (rnd.call() - .5) * 200.0, PAD.y + DROP * (1.0 - u) + (rnd.call() - .5) * 120.0, p.z + (rnd.call() - .5) * 200.0)))
		mm.set_instance_custom_data(i, Color(rnd.call() * 6.3, 40.0 + rnd.call() * 70.0, rnd.call(), .3))
		i += 1
	var deck := PAD.y + DROP - dist_at(21.5)      # the ash deck: passed through at ~19-24 s
	while i < 230:
		var u := clampf(1.0 - (deck - PAD.y) / DROP + (rnd.call() - .5) * .06, 0.0, 1.0)
		var p: Vector3 = along.call(u, (rnd.call() - .5) * (220.0 if i < 150 else 1100.0))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x + (rnd.call() - .5) * 120.0, deck + (rnd.call() - .5) * 70.0, p.z + (rnd.call() - .5) * 120.0)))
		mm.set_instance_custom_data(i, Color(rnd.call() * 6.3, 55.0 + rnd.call() * 90.0, rnd.call(), .9))
		i += 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://levels/omnisphere/om_cloud.gdshader")
	air_clouds = MultiMeshInstance3D.new()
	air_clouds.multimesh = mm
	air_clouds.material_override = mat
	air_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	air_clouds.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	air_clouds.visible = false
	root.add_child(air_clouds)
	for _k in 90:
		air_base.append(Vector3((rnd.call() - .5) * 36.0, (rnd.call() - .5) * 60.0, (rnd.call() - .5) * 36.0))
	air_streaks = MeshInstance3D.new()
	air_streaks.mesh = air_mesh
	var sm := VhKit.unlit(0xffe8d0, .32)
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.disable_fog = true
	air_streaks.material_override = sm
	air_streaks.extra_cull_margin = 4000.0
	air_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	air_streaks.visible = false
	root.add_child(air_streaks)


func _air_update(cp: Vector3, vel: Vector3, k: float) -> void:
	if air_anchor == Vector3.ZERO:
		air_anchor = cp
	var sp := vel.length()
	var ln := clampf(sp * .045, .2, 2.4)
	var dir := -vel / maxf(1.0, sp)
	air_mesh.clear_surfaces()
	air_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in air_base:      # wind streaks: short lines in a box round the camera, standing still in the world (so they shoot up past him), wrapped
		var x := fposmod(b.x - (cp.x - air_anchor.x) + 18.0, 36.0) - 18.0
		var y := fposmod(b.y - (cp.y - air_anchor.y) + 30.0, 60.0) - 30.0
		var z := fposmod(b.z - (cp.z - air_anchor.z) + 18.0, 36.0) - 18.0
		var p := cp + Vector3(x, y, z)
		air_mesh.surface_add_vertex(p)
		air_mesh.surface_add_vertex(p + dir * ln)
	air_mesh.surface_end()
	(air_streaks.material_override as StandardMaterial3D).albedo_color.a = .3 * k


# ---- the intro props: Tug 9 and the gunship that comes up for it
func _props() -> void:
	if tug != null:
		return
	tug = craft.evac_tug()
	tug.group.visible = false
	ship0 = craft.gunship()
	ship0.group.scale = Vector3.ONE * 1.25
	ship0.group.visible = false
	for m: Dictionary in msl:
		m.g = MsKit.sprite8(lv, 0xffb050, 1.0, 2.4)
		(m.g as Node3D).visible = false


func _hide_missiles() -> void:
	for m: Dictionary in msl:
		if m.g != null:
			(m.g as Node3D).visible = false
		m.t = -1.0


## where the tug is, intro time it (s): its ramp lip sits on the jump point at I_JUMP; it cruises along the heading
func _tug_at(tt: float) -> Vector3:
	var o := frame_at(0.0)
	o += fwd * (TUG_V * (tt - I_JUMP))
	o.y += 1.65 + maxf(0.0, tt - I_JUMP) * 1.2
	return o + fwd * -RAMP_END.z


func _tug_local(x: float, y: float, z: float) -> Vector3:
	return tug.group.quaternion * Vector3(x, y, z) + tug.group.position


func _set_heading(psi: float) -> void:
	fwd = Vector3(sin(psi), 0.0, cos(psi))
	right = Vector3(-cos(psi), 0.0, sin(psi))


# ---- render look for the drop: thinner haze (the plant shows from 1.5 km), a deeper far plane; all put back after
func _look(v: bool) -> void:
	var c: Camera3D = Game.camera
	if v and not saved:
		saved = true
		c.near = .3
		c.far = 4600.0
	if not v and saved:
		saved = false
		c.near = .1
		c.far = 2400.0
		Game.view.set_fog_exp2(Game.view.fog_color, .0017)


func _script() -> Array:      # timeline (fall seconds): what comes up at him
	return [[T_HIT + .4, _blow_tug], [3.0, func() -> void: audio.pa("fall")],      # (the second missile blows it at T_HIT; this is the backstop)
		[7.0, func() -> void:
			sky.spawn("hornet", {"side": -.7})
			sky.spawn("hornet", {"side": .8})], [9.5, func() -> void: sky.spawn("hornet", {"side": 0.0, "y": -90.0})],
		[12.5, func() -> void:
			sky.spawn("wasp", {"side": -.4, "dist": 30.0})
			sky.spawn("wasp", {"side": .5, "dist": 34.0})],
		[15.0, func() -> void:
			sky.spawn("hornet", {"side": -1.3})
			sky.spawn("hornet", {"side": 1.2})
			_sam()],
		[18.6, func() -> void:
			for s: float in [-.6, 0.0, .7]:
				sky.spawn("wasp", {"side": s, "dist": 26.0, "y": -70.0})],
		[21.5, func() -> void: sky.spawn("mule", {"side": 0.0, "y": -110.0})], [23.0, func() -> void:
			sky.spawn("hornet", {"side": -.9})
			sky.spawn("hornet", {"side": .9})],
		[25.5, func() -> void:
			sky.spawn("wasp", {"side": -.3, "dist": 30.0})
			sky.spawn("wasp", {"side": .4, "dist": 30.0})
			_sam()
			_sam()],
		[T_REPO, func() -> void: sky.spawn("ship", {"side": PI * .85, "dist": 50.0, "y": -150.0, "leave_at": 48.5})],
		[34.0, func() -> void:
			sky.spawn("hornet", {"side": -1.0})
			sky.spawn("hornet", {"side": 1.0})], [39.0, func() -> void:
			sky.spawn("wasp", {"side": -.5, "dist": 30.0})
			sky.spawn("wasp", {"side": .6, "dist": 30.0})],
		[42.0, func() -> void:
			_sam()
			_sam()], [44.5, func() -> void: sky.spawn("hornet", {"side": .2})],
		[49.5, func() -> void:
			sky.spawn("wasp", {"side": -.4, "dist": 28.0})
			sky.spawn("wasp", {"side": .4, "dist": 28.0})], [51.0, _sam],
		[53.6, _break_off]]


## a SAM from the launchers on the plant: it climbs out of the haze far below
func _sam() -> void:
	var a := randf() * 6.3
	var d := 30.0 + randf() * 40.0
	sky.missile(Vector3(pc.x + cos(a) * d, -300.0, pc.z + sin(a) * d), {"vel": Vector3.UP, "v0": 60.0, "speed": 62.0, "turn": 1.1, "dmg": 20.0, "life": 9.0, "arm_t": .2})


## the last few hundred metres: whatever is still up there peels off (the plant does not shoot at its own pad)
func _break_off() -> void:
	for f in sky.foes:
		if not f.dead:
			f.st = "leave"
			f.vel = Vector3(0, 30, 0)
			f.leave_at = 0.0
	for m in sky.missiles:
		m.life = minf(m.life, m.t + .3)


func _blow_tug() -> void:
	if tug == null or not tug.group.visible:
		return
	var p := _tug_local(0.0, 1.6, 0.0)
	sky.blast(p, 7.0, {"sound": "ffTugHit"})
	sky.blast(p + fwd * 3.0, 4.0, {"quiet": true})
	Game.fx.shake = maxf(Game.fx.shake, 1.6)
	tug.group.visible = false
	_hide_missiles()
	tug_p = p
	sky.wreck(p - F)
	ship_t = 0.0
	ship_v = fwd * TUG_V + right * 7.0      # the gunship peels off through the smoke
	ship_v.y = 5.0
	Game.hud.toast("TUG 9 IS GONE", 1.4)


# Tug 9, the gunship and the missiles, intro seconds (it keeps counting after he jumps, so the tug flies on until it is hit)
func _tug_fly(dt: float) -> void:
	if tug.group.visible:
		tug.group.position = _tug_at(it)
		tug.group.rotation = Vector3(sin(it * 1.7) * .02, HEAD, sin(it * 1.1) * .03)
		tug.update(dt)
		tug_p = tug.group.position
	# the gunship: climbs out of the haze off the tug's left quarter, searchlight on the bay; once the tug blows it banks away and is gone
	if ship_t < 0.0:
		var su := sm((it - .8) / 2.4)
		ship0.group.visible = it > .8
		if ship0.group.visible and tug.group.visible:
			ship0.group.position = _tug_local(lerpf(-40.0, -17.0, su), lerpf(-60.0, -3.0, su), lerpf(-30.0, -8.0, su))
			ship0.group.rotation = Vector3(.15, HEAD + PI * .62, -.18)
			ship0.update(dt)
	elif ship0.group.visible:
		ship_t += dt
		ship_v.y += 4.0 * dt
		ship0.group.position += ship_v * dt
		ship0.group.rotation = Vector3(lerpf(.15, -.25, sm(ship_t)), HEAD + PI * .62 - sm(ship_t / 2.0) * 1.1, lerpf(-.18, .55, sm(ship_t / 1.5)))
		ship0.update(dt)
		if ship_t > 5.0:
			ship0.group.visible = false
	for m: Dictionary in msl:
		if m.g == null:
			continue
		var g: Node3D = m.g
		if float(m.t) < 0.0 and it >= float(m.at) and it < float(m.at) + float(m.dur) and tug.group.visible and ship0.group.visible:
			m.t = 0.0
			m.from = ship0.group.position
			g.visible = true
			g.position = m.from
			audio.play_at("ffMissile", m.from)
		if float(m.t) < 0.0 or not g.visible:
			continue
		m.t = float(m.t) + dt
		var u := float(m.t) / float(m.dur)
		if u < 1.0:
			var a: Vector3 = m.aim
			m.end = _tug_local(a.x, a.y, a.z)
			m.dir = (m.end as Vector3) - g.position
			g.position = (m.from as Vector3).lerp(m.end, u * u)
		elif m.miss:      # on past the ramp, out into the dark
			if (m.dir as Vector3).length_squared() > 1e-6:
				g.position += (m.dir as Vector3).normalized() * (2.0 * (m.from as Vector3).distance_to(m.end) / float(m.dur) * dt)
			if u > 2.2:
				g.visible = false
		else:
			_blow_tug()
			continue
		sky.smoke.emit(g.position.x, g.position.y, g.position.z, {"size": .9, "grow": 3.0, "life": 2.5, "col": 0xb8b0a8, "alpha": .5})


# ---- start / stop
func start(from: float = 0.0, retry: bool = false) -> void:
	_props()
	_stop_shared()
	sky.clear()
	var P: Player = Game.player
	if P == null:
		return
	on = true
	landed = false
	dead_t = 0.0
	t = from
	phase = "fall" if from > 0.0 or retry else "intro"
	it = 0.0
	psi_off = 0.0
	lb = false
	ship_t = -1.0
	tail = 0.0
	resetting = false
	_set_heading(HEAD)
	off = Vector3.ZERO
	ov = Vector3.ZERO
	ret.x = 0.0
	ret.y = .22
	ret.lock = null
	roll.t = 9.0
	roll.cd = 0.0
	cam_s_init = false
	ads.on = false
	ads.w = 0.0
	hp.clear()
	hit_t = 0.0
	events = _script().filter(func(e: Array) -> bool: return float(e[0]) >= from - 1e-3 and not (from > 0.0 and float(e[0]) < .8))
	body = {"yaw": HEAD, "pitch": 1.3, "bank": 0.0, "dive": 0.0, "brake": 0.0, "limp": 0.0, "roll_a": 0.0, "flip": 0.0, "arms_out": 1.0, "flut": 0.0, "cam_bank": 0.0}
	F = frame_at(t)
	Fp = F
	air_clouds.visible = true
	air_streaks.visible = true
	air_anchor = Vector3.ZERO
	_look(true)
	hud.visible = true
	Game.hud.hide_xhair = true
	hud.hint_a = 0.0
	P.dead = false
	P.jet_on = false
	P.jetting = false
	P.grounded = false
	P.vx = 0.0
	P.vz = 0.0
	P.vy = -speed_at(t)
	P.crouching = false
	P.ledge = null
	P.mode = &"normal"
	P.wall_run = null
	P.flip = -1
	_hide_missiles()
	hud.fade_a = 1.0
	if phase == "intro":
		tug.group.visible = true
		tug.ramp_open = 1.0
		tug.thrust = .8
		tug.cruise = .6
		ship0.group.visible = false
		tug.group.position = _tug_at(0.0)
		tug.group.rotation = Vector3(0.0, HEAD, 0.0)
		audio.pa("tug")
		audio.loop("ffWind", .25)
		_place_intro(P, 0.0)
	else:
		tug.group.visible = false
		ship0.group.visible = false
		_place_fall(P)
		audio.cue("musicDrop", 0.0, t)
		audio.loop("ffWind", 1.0)
		_hint("" if retry else _hint_text())
	_an = Game.animator
	if _an != null:
		_an.pose_hook = _hook


func _hint_text() -> String:
	return "L STEER   R AIM   LT AIM DOWN SIGHTS   RT FIRE   A ROLL" if Inp.using_pad else "WASD STEER   MOUSE AIM   RIGHT CLICK AIM DOWN SIGHTS   CLICK FIRE   SPACE ROLL"


func _hint(text: String) -> void:
	hud.hint = text
	hud.hint_a = 0.0 if text == "" else 1.0
	hint_t = 6.0


func _stop_shared() -> void:
	if _an != null and _an.pose_hook == _hook:
		_an.pose_hook = Callable()


func stop(keep_body: bool = false) -> void:
	if not on and phase == "off":
		return
	on = false
	phase = "off"
	_stop_shared()
	_look(false)
	air_clouds.visible = false
	air_streaks.visible = false
	hud.visible = false
	hud.marks.clear()
	Game.hud.hide_xhair = false
	Game.combat.aim_over = null
	if tug != null:
		tug.group.visible = false
		ship0.group.visible = false
		_hide_missiles()
	audio.loop("ffWind", 0.0)
	if not keep_body:
		audio.cue("", 1.5)
		sky.clear()
	var P: Player = Game.player
	if P != null:
		P.jet_on = false
		P.jetting = false
		P.invuln = 0.0


# ---- the intro: crouched in Tug 9's bay; the PA, the gunship comes up, he runs for the ramp and goes
func _place_intro(P: Player, tt: float) -> void:
	tug.group.position = _tug_at(tt)
	tug.group.rotation = Vector3(sin(tt * 1.7) * .02, HEAD, sin(tt * 1.1) * .03)
	var run := clampf((tt - 3.3) / (I_JUMP - 3.3), 0.0, 1.0)
	var z := lerpf(.6, RAMP_END.z + .3, run)
	var y := (z + 5.55) / (RAMP_END.z + 5.55) * RAMP_END.y if z < -5.55 else 0.0
	var p := _tug_local(.9 * (1.0 - run * .9), y, z)
	P.x = p.x
	P.y = p.y
	P.z = p.z
	P.yaw = HEAD + PI + (.5 if tt < 2.6 else (lerpf(.5, -.6, sm((tt - 2.6) / .5)) if tt < 3.3 else 0.0))
	P.grounded = true
	P.crouching = tt < 2.7
	var sp := 7.0 if run > 0.0 and run < 1.0 else 0.0
	P.vx = -fwd.x * sp
	P.vz = -fwd.z * sp
	P.vy = 0.0
	P.sprinting = sp > 0.0


func _update_intro(dt: float, P: Player) -> void:
	it += dt
	_tug_fly(dt)
	_place_intro(P, it)
	if it > 1.2 and randf() < dt * 2.5:
		sky.flak()
	if it > 3.3 and not jump_snd:
		jump_snd = true
		audio.play("ffJump")
	# behind the tug's open ramp, low and to the right: the red bay, PROG in it, the gunship climbing on the left; dollies in as he runs at us
	var k := sm((it - 3.0) / 1.6)
	var p := _tug_local(lerpf(3.6, 2.4, k), lerpf(-.6, .2, k), lerpf(-19.0, -15.5, k))
	var l := _tug_local(lerpf(-.6, .4, k), lerpf(1.2, .2, k), lerpf(-1.0, -7.0, k))
	if not cam_s_init:
		cam_i_p = p
		cam_i_l = l
		cam_s_init = true
	var q := 1.0 - exp(-6.0 * dt)
	cam_i_p = cam_i_p.lerp(p, q)
	cam_i_l = cam_i_l.lerp(l, q)
	cam.pos = cam_i_p
	cam.look = cam_i_l
	cam.fov = 62.0
	cam.up = Vector3.UP
	if it >= I_JUMP:      # out
		phase = "fall"
		t = 0.0
		jump_snd = false
		F = frame_at(0.0)
		Fp = F
		off = Vector3(P.x - F.x, 0.0, P.z - F.z)
		ov = fwd * -2.0
		body.dive = 1.0
		body.yaw = HEAD + PI
		body.pitch = .3
		audio.cue("musicDrop", 0.0)
		audio.loop("ffWind", 1.0)
		cam_s_init = false
		lb = true      # (the hint comes up once he has rolled over: _body_pose)


# ---- the fall
func _place_fall(P: Player) -> void:
	F = frame_at(t)
	dF = F - Fp
	Fp = F
	var bob := sin(t * 1.7) * .25
	P.x = F.x + off.x
	P.y = F.y + bob
	P.z = F.z + off.z
	P.vx = ov.x
	P.vz = ov.z
	P.vy = -speed_at(t)
	P.grounded = false
	P.sprinting = false
	P.crouching = false
	P.yaw = body.yaw


func _steer(dt: float, P: Player) -> void:
	var m: Vector2 = Vector2(Inp.move.x, Inp.move.y)
	var late := clampf((t - 46.0) / (T_STALL - 46.0), 0.0, 1.0)
	# aiming down sights the stick steers along the view (whichever way he is looking), otherwise along the heading
	var sf := Vector3(sin(ads.yaw), 0.0, cos(ads.yaw)) if ads.on else fwd
	var sr := Vector3(-cos(ads.yaw), 0.0, sin(ads.yaw)) if ads.on else right
	ov.x += (sr.x * m.x + sf.x * m.y) * 46.0 * dt
	ov.z += (sr.z * m.x + sf.z * m.y) * 46.0 * dt
	ov *= exp(-2.4 * dt)
	if float(roll.t) < .45:
		ov += (roll.dir as Vector3) * (34.0 * (1.0 - float(roll.t) / .45) * dt)
	var spd := U.hyp(ov.x, ov.z)
	if spd > 17.0:
		ov *= 17.0 / spd
	off += ov * dt
	# the leash: free inside R, pulled back beyond it; it closes on the pad over the last stretch
	var R := lerpf(24.0, 1.5, late * late)
	var d := U.hyp(off.x, off.z)
	if d > R:
		var k := (d - R) * (6.0 if late > 0.0 else 3.0)
		off.x -= off.x / d * k * dt
		off.z -= off.z / d * k * dt
		var vr := (ov.x * off.x + ov.z * off.z) / d
		if vr > 0.0:
			ov.x -= off.x / d * vr
			ov.z -= off.z / d * vr
	if late > .5:
		off *= exp(-dt * 3.0 * (late - .5))
	# roll (jump): a barrel roll out of the line of fire, i-frames through the middle of it
	roll.cd = float(roll.cd) - dt
	roll.t = float(roll.t) + dt
	if Inp.btn(&"jump").pressed and float(roll.cd) <= 0.0 and phase == "fall" and t > (FLIP1 if lb else 1.5):
		roll.t = 0.0
		roll.cd = .85
		if m.length() > .2:
			roll.dir = Vector3(sr.x * m.x + sf.x * m.y, 0.0, sr.z * m.x + sf.z * m.y).normalized()
		else:
			roll.dir = sr * (-1.0 if float(body.bank) > 0.0 else 1.0)
		P.invuln = maxf(P.invuln, .4)
		audio.play("ffRoll")
	var sg := signf((roll.dir as Vector3).dot(right))
	if sg == 0.0:
		sg = 1.0
	body.roll_a = sm(float(roll.t) / .5) * TAU * sg if float(roll.t) < .5 else 0.0


func _ads_step(dt: float, P: Player) -> void:
	var C: Combat = Game.combat
	var can: bool = phase == "fall" and not P.dead and C.cur >= 0 and not (lb and t < LB1 - .3) and t < T_STALL - .5
	var want: bool = can and Inp.btn(&"ads").held
	if want and not ads.on:      # the view swings onto whatever the reticle was on
		ads.yaw = atan2(ret_dir.x, ret_dir.z)
		ads.pitch = clampf(asin(clampf(ret_dir.y, -1.0, 1.0)), -1.38, .9)
	ads.on = want
	ads.w = damp(ads.w, 1.0 if want else 0.0, 10.0 if want else 7.0, dt)


func _reticle(dt: float) -> void:
	var dy: float = Inp.look_yaw
	var dp: float = Inp.look_pitch
	const K := 1.5
	if ads.on:      # aiming down sights the mouse turns the view; the reticle slides to screen centre
		ads.yaw = wrap_a(float(ads.yaw) + dy * .85)
		ads.pitch = clampf(float(ads.pitch) - dp * .85, -1.38, .9)
		ret.x = damp(ret.x, 0.0, 16.0, dt)
		ret.y = damp(ret.y, 0.0, 16.0, dt)
		ret.idle = 0.0
		if t > 47.0:
			psi_off = damp(psi_off, 0.0, 1.2, dt)
		return
	var moved := absf(dy) + absf(dp) > 1e-4
	var vp := hud.size
	ret.x = clampf(float(ret.x) - dy * K, -.92, .92)
	ret.y = clampf(float(ret.y) - dp * K * (vp.x / maxf(1.0, vp.y)), -.85, .85)
	ret.idle = 0.0 if moved else float(ret.idle) + dt
	if float(ret.idle) > 1.6:
		ret.x = damp(ret.x, 0.0, .5, dt)
		ret.y = damp(ret.y, .22, .5, dt)
	# the reticle at the left / right edge turns the view (the heading stays within a quarter turn of the pad)
	var e: float = (absf(float(ret.x)) - .72) / .2 * signf(float(ret.x)) if absf(float(ret.x)) > .72 else 0.0
	if e != 0.0:
		var np := clampf(psi_off - e * 1.1 * dt, -.95, .95)
		ret.x = float(ret.x) + (np - psi_off) * 1.2
		psi_off = np
	elif t > 47.0:
		psi_off = damp(psi_off, 0.0, 1.2, dt)


## a view between two [p, d] views: the position eased straight across, the direction turned by heading and elevation (it tips through the horizon, never over the top)
static func _between(ap: Vector3, ad: Vector3, bp: Vector3, bd: Vector3, u: float) -> Array:
	var ya := atan2(ad.x, ad.z)
	var yb := atan2(bd.x, bd.z)
	var ea := asin(clampf(ad.y, -1.0, 1.0))
	var eb := asin(clampf(bd.y, -1.0, 1.0))
	var y := ya + wrap_a(yb - ya) * u
	var e := lerpf(ea, eb, u)
	var c := cos(e)
	return [ap.lerp(bp, u), Vector3(sin(y) * c, sin(e), cos(y) * c)]


func _fall_camera(dt: float, P: Player) -> void:
	var late := clampf((t - T_STALL + .3) / 2.2, 0.0, 1.0)
	# the view looks down the drop: mostly at the pad (so the plant grows up the screen as he falls), a little along the heading; the camera sits back along that line and lifted toward the screen's top, so PROG hangs in the lower third with the drop opening out above him
	var b := pc + F
	var D := ((PAD - b).normalized() * .6 + Vector3(fwd.x * .7, -.7, fwd.z * .7) * .4).normalized()
	const DIST := 6.2
	const LIFT := 2.9
	var h := Vector3(-D.x * D.y, 1.0 - D.y * D.y, -D.z * D.y)      # h: the view's own 'up' (world up, square to D)
	var hl := h.length()
	if hl == 0.0:
		hl = 1.0
	var v := b - D * DIST + h / hl * LIFT - Vector3(ov.x, 0.0, ov.z) * .06
	var v2 := v + D * 30.0 + Vector3(ov.x, 0.0, ov.z) * .1
	# smoothed in the falling frame (relative to F), so only his steering lags, never the fall: he swings across the frame when he steers
	v -= F
	v2 -= F
	if not cam_s_init:
		cam_s_p = v
		cam_s_l = v2
		cam_s_init = true
	var kx := 1.0 - exp(-4.5 * dt)
	cam_s_p = cam_s_p.lerp(v, kx)
	cam_s_l = cam_s_l.lerp(v2, kx)
	# wind buffet
	var bf := .05 + .08 * clampf(speed_at(t) / 28.0, 0.0, 1.0)
	var p0 := F + cam_s_p + Vector3(sin(t * 13.1) * bf, sin(t * 11.7 + 1.0) * bf, sin(t * 9.3 + 2.0) * bf)
	var l0 := F + cam_s_l
	var fov := lerpf(76.0 + 4.0 * clampf((speed_at(t) - 22.0) / 6.0, 0.0, 1.0), Config.fov, late)
	var bp := p0
	var bd := (l0 - p0).normalized()
	var cy := F.y + pc.y - sin(t * 1.7) * .25      # his body centre without the bob
	# off the ramp: from beside him, looking back up past him at Tug 9 (the second missile, the fireball over his head); then the view swings down the drop
	if lb and t < LB1:
		var dn := lerpf(1.5, 6.0, sm(t / 1.4))      # sinking under him, so he and the tug share the frame
		var ap := Vector3(b.x - right.x * 3.5 + fwd.x * 2.0, cy - dn, b.z - right.z * 3.5 + fwd.z * 2.0)
		var ad := Vector3(lerpf(b.x, tug_p.x, .25) - ap.x, lerpf(cy, tug_p.y, .25) - ap.y, lerpf(b.z, tug_p.z, .25) - ap.z).normalized()
		var f_a := 68.0
		if t < .8:      # from where the intro camera stood
			var u := sm(t / .8)
			var r: Array = _between(cam_i_p, (cam_i_l - cam_i_p).normalized(), ap, ad, u)
			ap = r[0]
			ad = r[1]
			f_a = lerpf(62.0, 68.0, u)
		var u := sm((t - LB0) / (LB1 - LB0))
		var r: Array = _between(ap, ad, bp, bd, u)
		bp = r[0]
		bd = r[1]
		fov = lerpf(f_a, fov, u)
	# aiming down sights: over his right shoulder, along the aim
	if float(ads.w) > .002:
		var e := sm(ads.w)
		var ce := cos(float(ads.pitch))
		var d := Vector3(sin(float(ads.yaw)) * ce, sin(float(ads.pitch)), cos(float(ads.yaw)) * ce)
		var rx := -cos(float(ads.yaw))
		var rz := sin(float(ads.yaw))
		var up := Vector3(-rz * d.y, rz * d.x - rx * d.z, rx * d.y)      # the view's up: right x forward
		var ap := Vector3(b.x - d.x * 3.7 + rx * 1.05 + up.x * .5, cy - d.y * 3.7 + up.y * .5, b.z - d.z * 3.7 + rz * 1.05 + up.z * .5)
		var r: Array = _between(bp, bd, ap, d, e)
		bp = r[0]
		bd = r[1]
		fov = lerpf(fov, 56.0, e)
	var px := bp
	var lx := bp + bd * 30.0
	# the stall hands over to the gameplay rig (done exactly as he touches down)
	var rig: CameraRig = Game.rig
	if phase == "stall" and rig != null:
		var u := sm(1.0 - (P.y - PAD.y - .35) / maxf(1.0, stall_alt - .35))
		px = px.lerp(rig.pos, u)
		lx = lx.lerp(rig.look, u)
	cam.pos = px
	cam.look = lx
	var bank := clampf(-(ov.x * right.x + ov.z * right.z) * .012, -.18, .18) * (1.0 - late) * (1.0 - float(ads.w)) * (0.0 if lb and t < LB1 else 1.0)
	body.cam_bank = damp(body.cam_bank, bank, 4.0, dt)
	var fw := (lx - px).normalized()
	var r := Vector3.UP.cross(fw).normalized()
	cam.up = fw.cross(r).normalized().rotated(fw, float(body.cam_bank))
	cam.fov = fov


## project a world point through the drop's camera. x, y in -1..1 (y up), z > 1 = behind
func _proj(c: Camera3D, w: Vector3) -> Vector3:
	var vp := hud.size
	var q := c.unproject_position(w)
	return Vector3(q.x / vp.x * 2.0 - 1.0, 1.0 - q.y / vp.y * 2.0, 2.0 if c.is_position_behind(w) else 0.0)


## the aim: a ray from the camera through the reticle, bent onto a target near it (soft lock); feeds combat through Combat.aim_over
func _aim_ray() -> void:
	var c: Camera3D = Game.camera
	var dt_c := c.get_viewport().get_visible_rect().size
	var q := Vector2((float(ret.x) * .5 + .5) * dt_c.x, (-float(ret.y) * .5 + .5) * dt_c.y)
	var o := cam.pos
	var dir := c.project_ray_normal(q)
	ret_dir = dir
	# soft lock: the nearest lockable within a screen radius of the reticle (wider while firing from the hip, tight down the sights). Hip fire holds on: while the trigger is down the reticle rides the locked target until it dies or is dragged well off it
	var firing: bool = Inp.btn(&"fire").held
	var prev: Variant = (ret.lock as Dictionary).T if ret.lock != null else null
	var asp := dt_c.y / dt_c.x * 1.6
	var best: Variant = null
	var lim: float = .075 if ads.on else (.17 if firing else .12)
	var bd := lim * lim
	var keep: Variant = null
	var kx := 0.0
	var ky := 0.0
	for L: Dictionary in sky.lockables():
		var v := _proj(c, Vector3(L.x, L.y, L.z))
		if v.z > 1.0:
			continue
		var dx := v.x - float(ret.x)
		var dy := (v.y - float(ret.y)) * asp
		var d2 := dx * dx + dy * dy
		var w := .6 if L.kind == "missile" else 1.0
		if L.T == prev and firing and not ads.on and d2 < .09 and absf(v.x) < .95 and absf(v.y) < .9:
			keep = L
			kx = v.x
			ky = v.y
		if d2 * w < bd:
			bd = d2 * w
			best = L
	if keep != null:
		best = keep
		ret.x = damp(ret.x, kx, 14.0, get_dt())
		ret.y = damp(ret.y, ky, 14.0, get_dt())
		ret.idle = 0.0
	ret.lock = (best as Dictionary).duplicate() if best != null else null
	var body_c := pc + F
	var cam_to_p := body_c.distance_to(o)
	aim.pos = o
	aim.dist = cam_to_p + .5
	aim.look = Vector3(best.x, best.y, best.z) if best != null else o + dir * 60.0
	# the body turns to the aim: the direction from his chest to what the reticle is on
	var tp: Vector3 = Vector3(best.x, best.y, best.z) if best != null else o + dir * (cam_to_p + 60.0)
	aim_dir = (tp - (body_c + Vector3(0, .3, 0))).normalized()


var _dt := .016


func get_dt() -> float:
	return _dt


func _body_pose(dt: float, P: Player) -> void:
	var C: Combat = Game.combat
	var firing: bool = C.cur >= 0 and (Inp.btn(&"fire").held or C.aim_t > 0.0)
	was_firing = .9 if firing else maxf(0.0, was_firing - dt)
	var off_ramp := lb and t < FLIP1
	var aiming: bool = (was_firing > 0.0 or ads.on) and phase == "fall" and not off_ramp
	body.arms_out = damp(body.arms_out, 0.0 if aiming else 1.0, 18.0 if aiming else 6.0, dt)
	# yaw: the heading, or round to the aim; pitch: belly-down arch, sitting up to shoot level or above
	var d := aim_dir if aim_dir != Vector3.ZERO else fwd
	var e := asin(clampf(d.y, -1.0, 1.0))
	var az := atan2(d.x, d.z)
	var want_yaw := az if aiming else HEAD + psi_off
	var a := clampf(e + 1.3, -.3, .6)
	var want_pitch := a - e if aiming else 1.3 + (ov.x * fwd.x + ov.z * fwd.z) * .012
	var tw := sm((t - .25) / 1.25) if phase == "fall" and not lb and t < 1.6 else 1.0      # (a restart in the air) a half twist round to face the drop
	body.dive = damp(body.dive, 1.0 if phase == "fall" and t < (.45 if lb else 1.1) else 0.0, 4.0, dt)
	if off_ramp:
		# out of the ramp backwards: he tips over onto his back, arms out, watching Tug 9 (head toward it, face up); once it blows he half-rolls belly-down about his long axis, (HEAD + pi, -p, roll pi) being the same as (HEAD, p): so at FLIP1 the frame swaps with no jump
		var f := sm((t - FLIP0) / (FLIP1 - FLIP0))
		body.yaw = HEAD + PI
		body.pitch = lerpf(lerpf(.3, -1.05, sm(t / 1.1)), -1.3, f)
		body.flip = f * PI
	elif tw < 1.0:
		body.yaw = HEAD + PI * (1.0 - tw)
		body.pitch = lerpf(.3, 1.3, tw) + sin(tw * PI) * .4
	else:
		if float(body.flip) != 0.0:      # rolled over: the frame swap, and the controls come up
			body.yaw = HEAD
			body.pitch = 1.3
			body.flip = 0.0
			if phase == "fall":
				_hint(_hint_text())
		var rate := 11.0 if ads.on else 7.0
		body.yaw = float(body.yaw) + clampf(wrap_a(want_yaw - float(body.yaw)), -rate * dt, rate * dt)
		body.pitch = damp(body.pitch, want_pitch, 9.0 if ads.on else 6.0, dt)
	body.brake = damp(body.brake, 1.0 if phase == "stall" else 0.0, 5.0, dt)
	body.limp = damp(body.limp, 1.0 if P.dead else 0.0, 4.0, dt)
	body.bank = damp(body.bank, clampf((ov.x * right.x + ov.z * right.z) * .045, -.6, .6), 6.0, dt)
	body.flut = float(body.flut) + dt


# after the animator's own pose (before the smoothing and the weapon): the skydive body, blended in over whatever it was doing
func _pose(a: Variant) -> void:
	if not on or phase == "intro":
		return
	var P: Player = Game.player
	var st: float = body.brake
	set_pose(a, ARCH, DIVE, body.dive, BRAKE, st, LIMP, body.limp)
	flutter(a, body.flut, .03 + .05 * clampf(speed_at(t) / 28.0, 0.0, 1.0) * (1.0 - st))
	a.py = Vector3.ZERO
	# shooting: the gun comes out, both arms on it, aimed along the real aim in the body's frame
	var armed: bool = float(body.arms_out) < .5 and not P.dead and phase == "fall"
	P.armed = P.armed and armed
	P.aiming = armed
	P.ads = armed and ads.on
	if armed and aim_dir != Vector3.ZERO:
		var v: Vector3 = Quaternion.from_euler(Vector3(body.pitch, body.yaw, 0.0)).inverse() * aim_dir
		P.aim_pitch = clampf(asin(clampf(v.y, -1.0, 1.0)), -.9, 1.0)
		P.aim_yaw = clampf(atan2(v.x, v.z), -.35, .35)


# after everything: the whole body turned into the fall (pitch belly-down, the barrel roll and bank about his long axis)
func pose_player(a: Variant) -> void:
	if not on:
		return
	_an = a
	if a.pose_hook != _hook:
		a.pose_hook = _hook
	if phase == "intro":
		return
	var P: Player = Game.player
	var Q := Quaternion(Vector3.UP, body.yaw) * Quaternion(Vector3.RIGHT, lerpf(body.pitch, .08, body.brake))
	Q = Q * Quaternion(Vector3.UP, float(body.roll_a) + float(body.flip) + float(body.bank) * (1.0 - float(body.brake)))
	if P.dead:
		Q = Q * Quaternion(Vector3.RIGHT, dead_t * 5.0) * Quaternion(Vector3.BACK, dead_t * 3.0)
	var A: Node3D = a.actor
	A.quaternion = Q
	A.position = Vector3(P.x, P.y + float(a.B.pivot) * float(a.B.scale), P.z)
	A.visible = true


func _hud_frame(dt: float, P: Player) -> void:
	var c: Camera3D = Game.camera
	var show_a := phase == "fall" or phase == "stall"
	var vp := hud.size
	hud.t += dt
	hud.ret_on = phase == "fall" and not P.dead and not (lb and t < FLIP1)
	hud.ret = Vector2((float(ret.x) * .5 + .5) * vp.x, (-float(ret.y) * .5 + .5) * vp.y)
	hud.lock_ = ret.lock != null
	hud.ads = ads.on
	# hit confirmation: an X on whatever took the round (amber when it goes down); the game's own marker sits at screen centre, which the reticle is not
	for T: Variant in hp.keys():
		if T.dead or T.hp <= 0.0:
			if T.hp <= 0.0:
				hit_t = .28
				hit_kill = true
				hit_p = hp[T].p
			hp.erase(T)
	for L: Dictionary in sky.lockables():
		var q: Variant = hp.get(L.T)
		var w := Vector3(L.x, L.y, L.z)
		if q != null and L.T.hp < float(q.h) - .01:
			hit_t = .2
			hit_kill = false
			hit_p = w
		hp[L.T] = {"h": L.T.hp, "p": w}
	hit_t -= dt
	hud.hit_a = minf(1.0, hit_t / .12) if hit_t > 0.0 else 0.0
	if hit_t > 0.0 and not c.is_position_behind(hit_p):
		hud.hit_p = c.unproject_position(hit_p)
	hud.hit_kill = hit_kill
	var alt := maxf(0.0, P.y - PAD.y)
	hud.alt = roundi(alt)
	hud.tape = alt / DROP
	vel_s = damp(vel_s, dF.length() / maxf(dt, 1e-3), 4.0, dt)
	hud.vel = roundi(vel_s)
	hud.alt_on = show_a
	# missiles homing on him: a diamond on each one on screen, a chevron on the screen edge for the rest; the warning, and a beep that speeds up
	var th: Array = sky.threats() if phase == "fall" else []
	hud.warn = not th.is_empty()
	hud.marks.clear()
	for i in mini(6, th.size()):
		var m: OmSkyFoes.Msl = th[i]
		var v := _proj(c, m.g.position)
		var x := v.x
		var y := v.y
		var behind := v.z > 1.0
		if behind:
			x = -x
			y = -y
		var onscr := not behind and absf(x) < .95 and absf(y) < .92
		if not onscr:
			var s := .9 / maxf(maxf(absf(x), absf(y) / .92), 1e-3)
			x *= s
			y *= s
		hud.marks.append([Vector2((x * .5 + .5) * vp.x, (-y * .5 + .5) * vp.y), onscr, atan2(-y, x), clampf(1.6 - m.closing * .3, .7, 1.4)])
	beep_t -= dt
	if not th.is_empty() and beep_t <= 0.0:
		var m0: OmSkyFoes.Msl = th[0]
		beep_t = clampf(m0.closing * .16, .07, .45)
		audio.beep(1600.0 if m0.closing < 1.0 else 1250.0)
	hint_t -= dt
	hud.hint_a = move_toward(hud.hint_a, 0.0 if hint_t <= 0.0 else hud.hint_a, dt / .8)
	hud.vig = .6 + .4 * clampf((speed_at(t) - 16.0) / 12.0, 0.0, 1.0) if show_a else 0.0
	hud.fade_a = maxf(0.0, hud.fade_a - dt / .45) if not resetting else minf(1.0, hud.fade_a + dt / .5)
	hud.queue_redraw()


func update(dt: float, P: Player) -> void:
	_dt = dt
	if not on and tail > 0.0 and P != null:      # after the landing: the smoke in the air fades out
		tail -= dt
		dF = Vector3.ZERO
		sky.update(dt, _frame(P))
		if tail <= 0.0:
			sky.clear()
		return
	if not on or P == null:
		return
	if phase == "intro":
		_update_intro(dt, P)
		_hud_frame(dt, P)
		_air_update(cam.pos, Vector3(0, -3, 0), .2)
		_fog_frame(P)
		sky.update(dt, _frame(P))
		return
	var prev_t := t
	t = minf(T_LAND, t + dt)
	if phase == "fall" and t >= T_STALL:
		phase = "stall"
		stall_alt = P.y - PAD.y
		P.jet_on = true
		P.jetting = true
		P.jet_fuel = Config.jet_fuel if Config.jet_fuel > 0.0 else 1.0
		audio.play("ffJet")
		audio.loop("ffWind", .3)
		_hint("")
		if Game.rig != null:
			P.yaw = HEAD
			Game.rig.snap_to(P)
	for i in range(events.size() - 1, -1, -1):
		if float(events[i][0]) <= t and float(events[i][0]) > prev_t - 1e-6:
			var fn: Callable = events[i][1]
			events.remove_at(i)
			fn.call()
	if P.dead:
		dead_t += dt
		died = true
	_ads_step(dt, P)
	if not P.dead:
		_steer(dt, P)
	_reticle(dt)
	if phase == "fall" and (tug.group.visible or ship0.group.visible):      # Tug 9 flies on over him until the missile gets it
		it += dt
		_tug_fly(dt)
	_set_heading(HEAD + psi_off)
	pc = Vector3(off.x, sin(t * 1.7) * .25 + .95, off.z)
	pv = Vector3(ov.x, 0.0, ov.z)
	_place_fall(P)
	# flak and tracers from the plant while it can reach him
	if phase == "fall" and t > 3.0 and t < 52.0:
		flak_t -= dt
		stream_t -= dt
		if flak_t <= 0.0:
			flak_t = .35 + randf() * .7
			sky.flak(randf() < .12)
		if stream_t <= 0.0:
			stream_t = 1.0 + randf() * 1.4
			sky.stream()
	if phase == "stall":
		P.jetting = true
		P.jet_fuel = maxf(.05, P.jet_fuel - dt * .3)
		if Game.rig != null:
			Game.rig.yaw = HEAD
	sky.update(dt, _frame(P))
	# the bolts and rockets in the air ride the fall with him (they were fired in his frame)
	var C: Combat = Game.combat
	for b: Variant in C.enemies.bolts:
		b.x += dF.x
		b.y += dF.y
		b.z += dF.z
	for q: Variant in C.projs:
		q.x += dF.x
		q.y += dF.y
		q.z += dF.z
	_body_pose(dt, P)
	_fall_camera(dt, P)
	_aim_ray()
	C.aim_over = aim if phase == "fall" else null
	_hud_frame(dt, P)
	_fog_frame(P)
	_air_update(cam.pos, dF / maxf(dt, 1e-3) + Vector3(ov.x, 0.0, ov.z), clampf(speed_at(t) / 24.0, 0.0, 1.0) if phase == "fall" else 0.0)
	# dead in the air: he goes limp and tumbles; the screen goes; back to the start of this section
	if P.dead and dead_t > 2.0 and not resetting:
		resetting = true
		reset_t = .65
	if resetting:
		reset_t -= dt
		if reset_t <= 0.0:
			resetting = false
			if P.dead:
				P.respawn()
				Game.hud.dead(false)
	# the bottom: hand him back to his own legs a hair above the pad
	if phase == "stall" and (t >= T_LAND - .02 or P.y - PAD.y < .35):
		_land(P)


func _frame(P: Player) -> OmSkyFoes.Frame:
	var o := frame_o
	o.F = F
	o.dF = dF
	o.P = P
	o.pc = pc
	o.pv = pv
	o.fwd = fwd
	o.right = right
	o.t = t
	o.dodging = float(roll.t) < .5
	return o


func _fog_frame(P: Player) -> void:
	if not saved:
		return
	var alt := maxf(0.0, (F.y if phase == "intro" else P.y) - PAD.y)
	Game.view.set_fog_exp2(Game.view.fog_color, lerpf(.0017, .00042, clampf((alt - 40.0) / 700.0, 0.0, 1.0)))


func _land(P: Player) -> void:
	landed = true
	died = false
	phase = "done"
	P.y = PAD.y + .3
	P.vy = -3.0
	P.vx = ov.x * .3
	P.vz = ov.z * .3
	P.grounded = false
	P.jet_on = false
	P.jetting = false
	P.armed = false
	P.yaw = HEAD
	var at := Vector3(P.x, P.y, P.z)
	audio.play_at("ffLand", at)
	Game.fx.dust(Vector3(P.x, PAD.y + .05, P.z), 22, 3.2)
	Game.fx.shake = maxf(Game.fx.shake, .8)
	if Game.rig != null:
		Game.rig.yaw = HEAD
	stop(true)
	tail = 6.0
	sky.clear(false)


var stalling: bool:
	get:
		return phase == "stall"
