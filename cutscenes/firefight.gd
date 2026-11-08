class_name Firefight
extends Cutscene
## FIREFIGHT CUTSCENE (JS cutscenes/firefight.js): Tommy and Prog crouch behind a parked car on the hub street (east kerb) while gray aliens across the road pour plasma at it. Tommy fires an SMG in each hand, Prog an assault rifle; they pop up over the car in bursts and duck back as bolts splash on the bodywork. Tommy turns to Prog: "Ok, now what?" -- and a gang of green aliens sprints in from the north end of the street and opens up on the grays. One green slows, looks across at the two of them, nods (solidarity) and goes back to the fight. End.
## Both heroes are fresh Animators (they do not use the player's), the aliens are the hub's gray / green NPC models. The game is frozen behind it (menu_open() is true while it runs); a test cutscene: dev console "cutscene play firefight".

# the street: the road is x -4.2..4.2, kerbs 0.15 high, sidewalks to x +-7.5. The cover is the parked car at x 3.3, z -28 (body 0.8 high, cab roof 1.38): it stood at z -20 until the implant vending machine (z -19.4) needed the room in front of it, so everything below is the old layout shifted by DZ.
const DZ := -8.0
const CAR := Vector2(3.3, -20.0 + DZ)
const KERB := 0.15
const PROG_AT := Vector2(4.95, -19.15 + DZ)
const TOMMY_AT := Vector2(4.95, -21.0 + DZ)
const WEST := -PI / 2.0      # yaw that faces -x (across the street, towards the grays)
const GRAYS: Array[Vector2] = [Vector2(-4.6, -16.8 + DZ), Vector2(-5.5, -20.4 + DZ), Vector2(-3.8, -24.0 + DZ), Vector2(-6.0, -27.2 + DZ)]
const TOMMY := {"name": "TOMMY", "color": "#ffd36b", "rate": 15.0, "pitch": 150.0}
const LINE := "Ok, now what?"
## seconds on the cutscene clock
const TL := {"fadeIn": 0.5, "say": 13.6, "greens": 16.6, "engage": 18.0, "look": 20.2, "nod": 20.8, "rejoin": 22.8, "fadeOut": 26.0, "end": 27.2}
## when each hero is up over the car shooting [start, end]; ducked in between (the bolts splash on the car)
const UP_TOMMY := [[1.6, 3.0], [4.6, 5.9], [7.4, 8.8], [10.2, 11.5], [12.3, 13.0], [19.6, 25.8]]
const UP_PROG := [[2.3, 3.7], [5.3, 6.6], [8.2, 9.5], [10.8, 12.1], [12.4, 13.1], [20.0, 25.8]]
const GLANCE_SIGN := -1.0      # which way a positive head yaw turns (tuning handle)

var t := 0.0
var hold := false      # (tuning only: the clock stands still)
var _greens_def: Array = []
var _shots: Array = []
var _ei := 0
var _shake := 0.0
var _ev: Array = []
var _root: Node3D = null
var _line: Variant = null
var _hid := false
var H: Variant = null
var aliens: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _glows: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _wait := 0.0
var _order := 0
var _npcs_hidden: Array = []


func _init() -> void:
	name = "Firefight"
	var g := [[-3.8, -1.2, -1.2, -15.0], [-6.2, -2.0, -5.2, -12.2], [-5.0, -3.0, -2.6, -13.6], [-6.6, -4.4, -4.2, -14.2], [-2.4, -2.6, -0.4, -12.6]]
	_read_js_greens(g)
	_shots = _make_shots()


func _read_js_greens(g: Array) -> void:
	for a: Array in g:      # [0] is the lead: the one nearest the car
		_greens_def.append({"from": Vector2(a[0], a[1]), "to": Vector2(a[2], float(a[3]) + DZ)})


static func _mk_shot(tm: float, p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3) -> Dictionary:
	var d := Vector3(0.0, 0.0, DZ)
	return {"t": tm, "p0": p0 + d, "p1": p1 + d, "l0": l0 + d, "l1": l1 + d}


static func _make_shots() -> Array:      # camera: from, to (both ease through the shot), look from, look to; z shifted by DZ (the `follow` shot has no z)
	return [
		_mk_shot(0.0, Vector3(7.4, 2.4, -12.4), Vector3(7.2, 2.2, -13.8), Vector3(0.0, 1.0, -21.0), Vector3(0.0, 1.0, -21.0)),                  # wide: the grays across the road, the car, the two of them behind it
		_mk_shot(5.6, Vector3(7.3, 1.55, -15.0), Vector3(7.0, 1.5, -15.6), Vector3(1.2, 1.1, -21.2), Vector3(1.0, 1.1, -21.2)),               # closer, over their shoulders
		_mk_shot(13.4, Vector3(6.7, 1.45, -16.6), Vector3(6.5, 1.4, -17.1), Vector3(4.95, 1.0, -20.2), Vector3(4.95, 1.0, -20.3)),           # "Ok, now what?"
		_mk_shot(16.4, Vector3(7.0, 2.6, -5.0), Vector3(6.9, 2.4, -6.0), Vector3(-1.5, 1.0, -18.5), Vector3(-1.8, 1.0, -19.5)),               # the green gang arrives from the north
		{"t": 19.9, "p0": Vector3.ZERO, "p1": Vector3.ZERO, "l0": Vector3.ZERO, "l1": Vector3.ZERO, "follow": Vector3(3.3, 0.3, -2.4)},        # the lead green looks across at them and nods
		_mk_shot(22.8, Vector3(7.4, 2.4, -12.4), Vector3(7.2, 2.3, -13.4), Vector3(-0.5, 1.0, -21.0), Vector3(-0.5, 1.0, -21.0)),              # and back to the fight
	]


static func _floor_at(x: float) -> float:
	return KERB if absf(x) > 4.2 else 0.0


func _E(tm: float, fn: Callable) -> void:
	_order += 1
	_ev.append({"t": tm, "fn": fn, "n": _order})
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] if a["t"] != b["t"] else a["n"] < b["n"])


# ---- small visual pieces ----
## a plasma bolt: green halo + a bright elongated core pointing along its flight
func _fire_bolt(from: Vector3, to: Vector3, speed: float = 24.0, on_hit: Callable = Callable()) -> void:
	var g := Node3D.new()
	_root.add_child(g)
	CineParts.glow(g, 0x39ff6a, 0.42)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Color.hex(0xeaffd8ff), 0.95)
	CineParts.box(g, 0.05, 0.05, 0.6, 0.0, 0.0, 0.0, m).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.position = from
	var dir := (to - from).normalized()
	g.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	_bolts.append({"g": g, "from": from, "to": to, "dir": dir, "len": from.distance_to(to), "d": 0.0, "speed": speed, "on_hit": on_hit})


## an impact: green sparks, a brief flash, the splash sound
func _splash(p: Vector3, n: int, color: int = 0x6dff8a) -> void:
	Game.fx.sparks(p, n, 3.5, Vector3(0.0, 0.3, 0.0), color)
	var s := CineParts.glow(_root, color, 0.7)
	s.position = p
	_glows.append({"s": s, "life": 0.14, "max": 0.14})
	Game.sfx.play_at("boltHit", p.x, p.y, p.z, {"kind": "wall", "bk": "plasma", "range": 70.0})


func _update_bolts(dt: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["d"] += float(b["speed"]) * dt
		(b["g"] as Node3D).position = (b["from"] as Vector3) + (b["dir"] as Vector3) * minf(b["d"], b["len"])
		if float(b["d"]) >= float(b["len"]):
			(b["g"] as Node3D).queue_free()
			_bolts.remove_at(i)
			if (b["on_hit"] as Callable).is_valid():
				(b["on_hit"] as Callable).call(b["to"])
	for i in range(_glows.size() - 1, -1, -1):
		var g: Dictionary = _glows[i]
		g["life"] -= dt
		if float(g["life"]) <= 0.0:
			(g["s"] as Node).queue_free()
			_glows.remove_at(i)
		else:
			CineParts.glow_opacity(g["s"], float(g["life"]) / float(g["max"]))
	for f: Dictionary in _flashes:
		f["life"] -= dt
		if float(f["life"]) <= 0.0:
			(f["s"] as Node3D).visible = false


# ---- Tommy's voice (a short synthesised line) + subtitles in the shared dialogue box ----
func _say(text: String) -> void:
	_line = {"text": text, "t0": t, "shown": 0, "voiced": 0}
	Game.ui.dialog.show_box(true)
	Game.ui.dialog.set_content("", "", "")


func _end_line() -> void:
	_line = null
	Game.ui.dialog.show_box(false)


func _tick_line() -> void:
	if _line == null:
		return
	var text: String = _line["text"]
	var n := mini(text.length(), floori((t - float(_line["t0"])) * float(TOMMY["rate"])))
	for i in range(int(_line["voiced"]), n):
		var ch := text[i].to_lower()
		var prev := text[i - 1].to_lower() if i > 0 else " "
		if "aeiou".contains(ch) and not "aeiou".contains(prev):
			PhoneVoice.own_syllable(150.0, 1.08, 0.6, 0.1, 0.2, 1.04, 0.78, 0.8, ch, i, PhoneVoice.last_syllable(text, i))
	_line["voiced"] = n
	if n != int(_line["shown"]):
		_line["shown"] = n
		Game.ui.dialog.set_content(TOMMY["name"], text.substr(0, n), "")


# ---- the heroes ----
static func _up_amount(list: Array, tm: float) -> float:
	var u := 0.0
	for r: Array in list:
		u = maxf(u, Cutscene.ease_((tm - float(r[0])) / 0.3) * (1.0 - Cutscene.ease_((tm - float(r[1])) / 0.3)))
	return u


## a stand-in for the player object that an Animator reads
static func _puppet(x: float, z: float, yaw: float) -> Player:
	var p := Player.new(null)
	p.world = Game.world
	p.x = x
	p.y = _floor_at(x)
	p.z = z
	p.yaw = yaw
	p.grounded = true
	p.crouching = true
	p.flip = -1.0
	p.mode = &"normal"
	return p


func _hero_an(id: String) -> Animator:
	var B := Builds.character_build(id)
	var a := Animator.new((load(B.file) as PackedScene).instantiate(), B)
	_root.add_child(a.actor)
	return a


func _build_heroes() -> void:
	var a_t := _hero_an("tommy")
	var a_p := _hero_an("prog")
	var tommy := {"an": a_t, "p": _puppet(TOMMY_AT.x, TOMMY_AT.y, WEST), "guns": [], "tgt": 0, "yaw_to": WEST}
	var prog := {"an": a_p, "p": _puppet(PROG_AT.x, PROG_AT.y, WEST), "next": 0.0, "tgt": 1, "yaw_to": WEST, "glance": 0.0}
	(prog["p"] as Player).armed = true
	(prog["p"] as Player).weapon_idx = Weapons.index_of("rifle")
	var ihead := Animator.KEYS.find(&"head")
	var ineck := Animator.KEYS.find(&"neck")
	a_p.pose_hook = func(a: Animator) -> void:
		var gl: float = prog["glance"]
		a.pose[ihead] += Vector3(0.08 * gl, GLANCE_SIGN * 0.95 * gl, 0.0)
		a.pose[ineck] += Vector3(0.0, GLANCE_SIGN * 0.3 * gl, 0.0)
	var info: WeaponView.Info = null
	for i_: WeaponView.Info in Game.animator.wv.infos:
		if i_.id == "smg":
			info = i_
	for i in 2:      # Tommy's two SMGs (scaled with him)
		var g: Node3D = (load("res://assets/weapons/smg.glb") as PackedScene).instantiate()
		g.scale = Vector3.ONE * (1.15 * a_t.B.scale)
		_root.add_child(g)
		var fl := CineParts.glow(_root, 0xffd27a, 0.3)
		fl.visible = false
		var f := {"s": fl, "life": 0.0}
		_flashes.append(f)
		tommy["guns"].append({"g": g, "info": info, "fl": f, "side": 0 if i == 1 else 1, "fire": 0.0, "next": 0.0})      # (side: 1 = R, 0 = L, as the animator's _ik)
	H = {"tommy": tommy, "prog": prog}


func _gray_alive() -> Array[Dictionary]:
	var o: Array[Dictionary] = []
	for a: Dictionary in aliens:
		if a["kind"] == "gray" and not a["dead"]:
			o.append(a)
	return o


static func _chest(a: Dictionary) -> Vector3:
	var R: GrayAlien = (a["api"] as GrayAlienNpc).R
	return Vector3(R.x, R.y + 0.85, R.z)


## a hero's bullet: tracer to the target, sparks on the alien, a flinch
func _hit(from: Vector3, a: Dictionary) -> void:
	var b := _chest(a) + Vector3(AlleyCine.rr(-0.2, 0.2), AlleyCine.rr(-0.25, 0.25), AlleyCine.rr(-0.2, 0.2))
	Game.fx.tracer(from, b, 0.02, 0.05)
	if randf() < 0.55:
		Game.fx.sparks(b, 3, 2.5, Vector3(1.0, 0.2, 0.0), 0xcfe8a0)
		var R: GrayAlien = (a["api"] as GrayAlienNpc).R
		R.flinch_t = 0.18
		R.hit_x = 1.0
		R.hit_z = AlleyCine.rr(-0.5, 0.5)


func _update_heroes(dt: float) -> void:
	var tommy: Dictionary = H["tommy"]
	var prog: Dictionary = H["prog"]
	var gr := _gray_alive()
	var say_t: float = TL["say"]
	# ---- Prog: the animator's own weapon system (assault rifle). Up = aiming over the car, down = low ready in cover
	var u := _up_amount(UP_PROG, t)
	var p: Player = prog["p"]
	var tg: Variant = gr[int(prog["tgt"]) % gr.size()] if not gr.is_empty() else null
	p.crouching = u < 0.55
	p.aiming = u > 0.45
	p.armed = true
	if tg != null:
		var R: GrayAlien = (tg["api"] as GrayAlienNpc).R
		prog["yaw_to"] = atan2(R.x - p.x, R.z - p.z)
	prog["glance"] = Cutscene.ease_((t - (say_t + 0.7)) / 0.35) * (1.0 - Cutscene.ease_((t - (say_t + 2.6)) / 0.4))      # keeps the rifle on the street but turns his head to Tommy
	p.yaw += AlleyCine.wrap(float(prog["yaw_to"]) - p.yaw) * minf(1.0, dt * 8.0)
	var pan: Animator = prog["an"]
	pan.update(dt, p)
	var wv := pan.wv
	if u > 0.9 and tg != null and t > float(prog["next"]) and not (t > say_t - 0.2 and t < say_t + 2.6):      # a burst: ~11 shots a second
		prog["next"] = t + 0.09
		wv.fire("rifle", 5.0)
		wv.flash(1.0, "rifle")
		Game.sfx.play("rifle")
		_hit(wv.muzzle_world(), tg)
		if randf() < 0.12:
			prog["tgt"] = int(prog["tgt"]) + 1
	# ---- Tommy: two SMGs, IK'd by hand. Up = both guns out toward a gray, ducked = guns up by his shoulders
	u = _up_amount(UP_TOMMY, t)
	p = tommy["p"]
	var an: Animator = tommy["an"]
	tg = gr[int(tommy["tgt"]) % gr.size()] if not gr.is_empty() else null
	var saying := t > say_t - 0.2 and t < say_t + 2.6
	p.crouching = u < 0.55
	p.aiming = false
	if tg != null:
		var R: GrayAlien = (tg["api"] as GrayAlienNpc).R
		tommy["yaw_to"] = atan2(R.x - p.x, R.z - p.z)
	if saying:      # looks at Prog
		tommy["yaw_to"] = 0.0
	p.yaw += AlleyCine.wrap(float(tommy["yaw_to"]) - p.yaw) * minf(1.0, dt * 8.0)
	an.update(dt, p)
	var q := an.actor.global_basis.get_rotation_quaternion()
	var aim_pt: Vector3 = _chest(tg) if tg != null else Vector3(0.0, 1.0, p.z)
	var fw := Vector3(sin(p.yaw), 0.0, cos(p.yaw))
	var i := 0
	for G: Dictionary in tommy["guns"]:
		var side: int = G["side"]
		var sd := "R" if side == 1 else "L"
		var sh := an.bone_world_pos(an.by_key[StringName("upper_arm" + sd)].bone)
		var to_t := (aim_pt - sh).normalized()
		var up := Vector3(fw.x * 0.35, 0.95, fw.z * 0.35).normalized()
		var dir := up.lerp(to_t, u).normalized()
		var hand := sh + dir * (0.5 * (1.0 + 0.2 * u))
		an._ik(side, hand, q * Vector3(-0.5 if side == 1 else 0.5, -1.0, -0.35), 1.0)
		var hb := an.bone_world_pos(an.by_key[StringName("hand" + sd)].bone)
		var gn: Node3D = G["g"]
		var s := gn.scale.x
		var gq := Basis.looking_at(dir, Vector3.UP, true).get_rotation_quaternion()      # (JS lookAt: +z at the target)
		gn.quaternion = gq
		var info: WeaponView.Info = G["info"]
		gn.position = hb + dir * (-float(G["fire"]) * 0.03) - gq * (info.grip_r * s)
		G["fire"] = maxf(0.0, float(G["fire"]) - dt * 14.0)
		var fl: Dictionary = G["fl"]
		var fls: MeshInstance3D = fl["s"]
		if float(fl["life"]) > 0.0:
			fls.position = gn.to_global(info.muzzle)
			fls.visible = true
			fls.scale = Vector3.ONE * (0.22 + 0.2 * randf())
		else:
			fls.visible = false
		if u > 0.9 and tg != null and not saying and t > float(G["next"]):
			G["next"] = t + 0.11 + 0.02 * i
			G["fire"] = 1.0
			fl["life"] = 0.05
			Game.sfx.play("smg")
			_hit(gn.to_global(info.muzzle), tg)
			if randf() < 0.08:
				tommy["tgt"] = int(tommy["tgt"]) + 1
		i += 1


# ---- the aliens ----
## an alien aims at a world point, fires a plasma bolt at it; on_hit gets the impact point
func _shoot(a: Dictionary, target: Vector3, on_hit: Callable) -> void:
	var api: GrayAlienNpc = a["api"]
	var R := api.R
	R.yaw = atan2(target.x - R.x, target.z - R.z)
	api.fire()
	var m := api.view.muzzle_world()
	Game.sfx.play_at("plasma", m.x, m.y, m.z, {"range": 70.0})
	_fire_bolt(m, target, 26.0, on_hit)


func _add_alien(kind: String, x: float, z: float, yaw: float) -> Dictionary:
	var api := GrayAlienNpc.new({"pose": &"aim", "green": kind == "green"})
	_root.add_child(api)
	api.place(x, _floor_at(x), z, yaw)
	var a := {"api": api, "kind": kind, "dead": false, "next": AlleyCine.rr(0.4, 1.6), "hold": 0.0, "tgt_green": null, "look": false, "moving": false, "nod_t": -1.0}
	aliens.append(a)
	# the nod (JS writes on the head after view.update)
	api.view.post_hook = func() -> void:
		if float(a["nod_t"]) >= 0.0:
			var k := sin(clampf(float(a["nod_t"]) / 1.3, 0.0, 1.0) * PI * 2.0 * 2.0)
			var v := api.view
			var e := v.pose.rot[v.j_head].get_euler(EULER_ORDER_XYZ)
			v.pose.euler(v.j_head, e.x + 0.42 * maxf(0.0, k) - 0.05 * minf(0.0, k), e.y, e.z)
	return a


func _update_aliens(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var eng: float = TL["engage"]
	for a: Dictionary in aliens:
		var api: GrayAlienNpc = a["api"]
		var R := api.R
		if not a["dead"] and a["kind"] == "gray":
			a["next"] -= dt
			if float(a["next"]) <= 0.0:
				var gl: Array[Dictionary] = []
				for g: Dictionary in aliens:
					if g["kind"] == "green" and (g["api"] as GrayAlienNpc).is_shown() and not g["dead"]:
						gl.append(g)
				var at_green: bool = t > eng and not gl.is_empty() and (a["tgt_green"] != null or randf() < 0.55)
				if at_green:
					var g: Dictionary = a["tgt_green"] if a["tgt_green"] != null and not a["tgt_green"]["dead"] else gl[randi() % gl.size()]
					a["tgt_green"] = g
					var gr_: GrayAlien = (g["api"] as GrayAlienNpc).R
					_shoot(a, Vector3(gr_.x, gr_.y + 0.8, gr_.z), func(q: Vector3) -> void: _splash(q, 5))
					a["next"] = AlleyCine.rr(0.5, 1.1)
				else:      # at the car: most bolts splash on the bodywork, some fly over it and burn the wall behind
					var over := randf() < 0.28
					var y := AlleyCine.rr(1.55, 2.1) if over else AlleyCine.rr(0.35, 1.3)
					var z := CAR.y + AlleyCine.rr(-1.3, 1.3)
					_shoot(a, Vector3(7.4 if over else CAR.x - 0.95, y, z), func(q: Vector3) -> void:
						_splash(q, 7)
						_shake = maxf(_shake, 0.15 if over else 0.45))
					a["next"] = AlleyCine.rr(0.35, 0.95)
			if a["tgt_green"] == null or t < eng:
				R.yaw = atan2(CAR.x - R.x, CAR.y - R.z)
		if a["kind"] == "green" and api.is_shown() and not a["dead"] and not a["look"] and not a["moving"]:
			a["next"] -= dt
			if float(a["next"]) <= 0.0 and t > eng - 0.6:
				var gl := _gray_alive()
				if not gl.is_empty():
					var g: Dictionary = gl[randi() % gl.size()]
					var gr_: GrayAlien = (g["api"] as GrayAlienNpc).R
					_shoot(a, Vector3(gr_.x, gr_.y + 0.8, gr_.z), func(q: Vector3) -> void:
						_splash(q, 6)
						gr_.flinch_t = 0.18
						gr_.hit_x = -1.0
						gr_.hit_z = 0.4)
				a["next"] = AlleyCine.rr(0.3, 0.8)
		api.update(now, dt)
		if float(a["nod_t"]) >= 0.0:
			a["nod_t"] += dt
			if float(a["nod_t"]) > 1.3:
				a["nod_t"] = -1.0


# ---- camera ----
func _update_camera(dt: float) -> void:
	var si := 0
	for k in _shots.size():
		if t >= float(_shots[k]["t"]):
			si = k
	var sh: Dictionary = _shots[si]
	var nx: float = float(_shots[si + 1]["t"]) if si + 1 < _shots.size() else float(TL["end"])
	var u := Cutscene.ease_((t - float(sh["t"])) / (nx - float(sh["t"])))
	var k := _shake * 0.05
	var p: Vector3 = (sh["p0"] as Vector3).lerp(sh["p1"], u) + Vector3(AlleyCine.rr(-k, k), AlleyCine.rr(-k, k), AlleyCine.rr(-k, k))
	var l: Vector3 = (sh["l0"] as Vector3).lerp(sh["l1"], u)
	if sh.has("follow"):      # the nod: stay on the lead green, from roughly where he is looking (towards the two of them)
		for a: Dictionary in aliens:
			if a["kind"] == "green":
				var R: GrayAlien = (a["api"] as GrayAlienNpc).R
				var fo: Vector3 = sh["follow"]
				l = Vector3(R.x, R.y + 0.95, R.z)
				p = Vector3(R.x + fo.x + AlleyCine.rr(-k, k), R.y + fo.y, R.z + fo.z + AlleyCine.rr(-k, k))
				break
	camera.pos = p
	camera.look = l
	_shake = maxf(0.0, _shake - dt * 3.5)


# ---- run ----
func play() -> void:
	if on:
		return
	on = true
	t = -1.0      # (t < 0 while the fade goes down and the heroes load: update() waits)
	_ei = 0
	_shake = 0.0
	_ev = []
	aliens = []
	_bolts = []
	_glows = []
	_flashes = []
	_line = null
	_wait = 0.0
	H = null
	_root = Node3D.new()
	_root.name = "Firefight"
	Game.level.add_child(_root)
	camera.pos = Game.camera.global_position
	camera.look = Game.camera.global_position - Game.camera.global_basis.z
	camera.fov = 0.0
	enter_cine(false)
	Game.ui.dialog.set_bars(true)
	Game.ui.set_fade(true)


func _begin() -> void:
	_build_heroes()
	if Game.animator != null:      # the player's own model sits this one out
		Game.animator.actor.visible = false
		_hid = true
	_hide_npcs(true)      # so do the street's talkable NPCs (the cherub stands right in this fight)
	var i := 0
	for g: Vector2 in GRAYS:
		var a := _add_alien("gray", g.x, g.y, atan2(CAR.x - g.x, CAR.y - g.y))
		a["next"] = 0.5 + i * 0.35
		(a["api"] as GrayAlienNpc).look_at_point(CAR.x, CAR.y)
		i += 1
	i = 0
	for g: Dictionary in _greens_def:
		var from: Vector2 = g["from"]
		var a := _add_alien("green", from.x, from.y, PI)
		(a["api"] as GrayAlienNpc).set_shown(false)
		a["next"] = 0.3 + i * 0.2
		a["moving"] = false
		i += 1
	t = 0.0
	_E(TL["fadeIn"], Game.ui.set_fade.bind(false))
	_E(TL["say"], _say.bind(LINE))
	_E(float(TL["say"]) + LINE.length() / float(TOMMY["rate"]) + 1.0, _end_line)
	_E(TL["greens"], func() -> void:      # the green gang pours in from the north end of the street, shooting as they run
		var j := 0
		for a: Dictionary in aliens:
			if a["kind"] != "green":
				continue
			var gd: Dictionary = _greens_def[j]
			var from: Vector2 = gd["from"]
			var to: Vector2 = gd["to"]
			var api: GrayAlienNpc = a["api"]
			api.set_shown(true)
			api.place(from.x, _floor_at(from.x), from.y, atan2(to.x - from.x, to.y - from.y))
			a["moving"] = true
			_E(t + j * 0.18, func() -> void:      # staggered starts, on the cutscene clock
				api.move_to(to.x, to.y, 7.0 + j * 0.3, func() -> void:
					a["moving"] = false
					api.look_away()))
			j += 1)
	_E(float(TL["engage"]) + 1.6, func() -> void:
		var gl := _gray_alive()
		if gl.size() > 1:
			_kill_gray(gl[1]))
	_E(float(TL["engage"]) + 3.4, func() -> void:
		var gl := _gray_alive()
		if not gl.is_empty():
			_kill_gray(gl[0]))
	_E(TL["look"], func() -> void:      # the lead green stops firing, turns to the two of them and nods
		var a := _lead_green()
		if a.is_empty():
			return
		a["look"] = true
		a["moving"] = false
		var api: GrayAlienNpc = a["api"]
		api.look_at_point(PROG_AT.x, PROG_AT.y)
		api.R.yaw = atan2(PROG_AT.x - api.R.x, PROG_AT.y - api.R.z)
		api.set_pose(&"idle")
		api.look_at_point(PROG_AT.x, PROG_AT.y))
	_E(TL["nod"], func() -> void:
		var a := _lead_green()
		if not a.is_empty():
			a["nod_t"] = 0.0)
	_E(TL["rejoin"], func() -> void:
		var a := _lead_green()
		if a.is_empty():
			return
		a["look"] = false
		(a["api"] as GrayAlienNpc).set_pose(&"aim")
		(a["api"] as GrayAlienNpc).look_away()
		a["next"] = 0.1)
	_E(TL["fadeOut"], Game.ui.set_fade.bind(true))
	_E(TL["end"], _finish.bind(true))


func _lead_green() -> Dictionary:
	for a: Dictionary in aliens:
		if a["kind"] == "green":
			return a
	return {}


func _kill_gray(a: Dictionary) -> void:
	a["dead"] = true
	var api: GrayAlienNpc = a["api"]
	api.R.hit_x = -1.0
	api.R.hit_z = 0.3
	api.set_pose(&"dead")
	Game.sfx.play("clerkDie")


func _hide_npcs(hide_: bool) -> void:
	for d: Dictionary in Game.dialogue.talkers:
		var ac: Variant = d.get("actor")
		if ac is GrayAlienNpc:
			(ac as GrayAlienNpc).set_shown(not hide_)
		elif ac is Node3D:
			(ac as Node3D).visible = not hide_


func _finish(_ok: bool) -> void:
	if not on:
		return
	on = false
	_end_line()
	if H != null:
		(H["tommy"]["an"] as Animator).pose_hook = Callable()
		(H["prog"]["an"] as Animator).pose_hook = Callable()
		H = null
	if _root != null:
		_root.queue_free()
		_root = null
	if Game.animator != null and _hid:
		Game.animator.actor.visible = true
	_hid = false
	_hide_npcs(false)
	aliens = []
	_bolts = []
	leave_cine()
	Game.get_tree().create_timer(0.12).timeout.connect(Game.ui.set_fade.bind(false))


func skip() -> void:
	if on and t >= 0.0:      # (not while the heroes are still loading)
		_finish(true)


func update(dt: float) -> void:
	if not on:
		return
	if _root != null and not is_instance_valid(_root):      # (the level went from under it: console level change)
		_root = null
		_finish(false)
		return
	if t < 0.0:
		_wait += dt
		if _wait > 0.5:
			_begin()
		return
	if H == null:
		return
	if not hold:
		t += dt
	while _ei < _ev.size() and float(_ev[_ei]["t"]) <= t:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		(e["fn"] as Callable).call()
		if not on:
			return
	_update_heroes(dt)
	_update_aliens(dt)
	_update_bolts(dt)
	_tick_line()
	Game.fx.update(dt)
	Game.enemy_views.flush()
	_update_camera(dt)


## the level is being left under it
func dispose() -> void:
	if on:
		_finish(false)
