class_name OmSummit
extends RefCounted
## OMNISPHERE: THE SUMMIT (JS summit.js), the top of the collapse. THE LIFT: the feed riser's service lift, under fire, until a pulse out of the core kills the hoist and the safety dogs catch the cage; jetpack up the ledges. THE RING: a walkway 8 m wide, 170 m up, turning (it carries you). THE EMITTERS: each one's shutters open to vent; shoot the capacitor bank behind them. When one dies its beam cuts out and the current it held goes home: a bolt from the core down to Juniper. Three and he is whole again and the sphere starts coming apart. THE JUMP: the heavy lifter swings round under you with its ramp down; go over the railing and the dive takes it from there. Everything is laid out relative to the Omnisphere's axis.

const TOWER := {"low_y": 67.4, "jam_y": 155.0, "top_y": 173.5}
const SHAFT := {"u0": -95.0, "u1": -89.0, "w0": 6.5, "w1": 11.5}
const EM_FIRST := .6
const EM_STAGGER := .8
const EM_WARN := .5
const EM_OPEN := 8.0
const EM_SHUT := [1.6, 2.4]
const R0 := 73.0      # the ring's walkway radii (landmark.js RING: orad + 7, orad + 15.5)
const R1 := 81.5
const LIFT_R := 128.0
const LIFT_Y := 62.0
const OX := -340.0
const OY := 168.0
const OZ := -310.0
const DECK := OY + 2.02
const CORE_R := 66.0 * .62


class Em:
	var k := 0
	var a := 0.0
	var g: Node3D
	var leaves: Array = []      # [node, sign]
	var lens: MeshInstance3D
	var beam_a: MeshInstance3D
	var beam_b: MeshInstance3D
	var hit: MeshInstance3D
	var cap_glow: MeshInstance3D
	var warn: MeshInstance3D
	var steam: Array = []
	var beacon: OmSecurity.Beacon
	var T: OmProp
	var armor: World.Solid
	var body: Array = []
	var ph := "shut"
	var t := 0.0
	var open := 0.0
	var dead := false
	var dead_t := 0.0
	var last_hp := 260.0
	var hurt := 0.0
	var lbl: Label


var lv: ExportedLevel
var W: World
var root: Node3D
var sec: OmSecurity
var sets: OmSets
var craft: OmCraft
var audio: OmAudio
var marks: OmMarks
var act2: OmAct2
var alarm: Callable
var jun: OmJuniper
var cage: Node3D
var gate: Node3D
var cables: Array[MeshInstance3D] = []
var lift_floor: World.Solid
var lift_rails: Array = []
var lift_gate: World.Solid
var lift := {"y": 67.4, "v": 0.0, "ph": "down", "t": 0.0, "gate": 0.0, "jolt": 0.0, "bucket": 0.0, "caught": false}
var ems: Array[Em] = []
var bolt_r: OmRibbon
var aura_r: OmRibbon
var bolt_light: OmniLight3D
var jun_light: OmniLight3D
var bolt := {"t": -1.0, "dur": 1.5, "re": 0.0, "to": Vector3.ZERO, "from": Vector3.ZERO}
var power := 0
var ins := {"on": false, "t": 0.0, "dur": 0.0, "kind": ""}
var cine_cam := View.Shot.new()
var lifter: OmCraft.Cargo
var ride := {"ph": "off", "t": 0.0, "ang": 0.0, "from": Vector3.ZERO, "pos": Vector3.ZERO, "yaw": 0.0, "circ": 0.0, "lock_ang": false}
var pilot_name := "TOMMY"
var later: Array = []
var st := {"t": 0.0, "on": false, "ring_on": false, "final": -1.0, "fail_t": 0.0, "spark_t": 0.0, "fall_t": 0.0, "drop_t": 0.0, "music": false, "aura_t": 0.0}
var beacon_g: Node3D
var beacon_parts: Array = []
var layer: CanvasLayer
var ride_mark: Label
var cu := 0.0
var cw := 0.0
var spots := {}
var font: Font
var ring_g: Node3D


static func X(u: float) -> float:
	return OX + u


static func Z(w: float) -> float:
	return OZ + w


static func _R(a: float, c: float) -> float:
	return a + randf() * (c - a)


static func _sm(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _init(p_lv: ExportedLevel, p_sec: OmSecurity, p_sets: OmSets, p_craft: OmCraft, p_audio: OmAudio, p_marks: OmMarks, p_act2: OmAct2, p_alarm: Callable) -> void:
	lv = p_lv
	W = lv.world
	sec = p_sec
	sets = p_sets
	craft = p_craft
	audio = p_audio
	marks = p_marks
	act2 = p_act2
	alarm = p_alarm
	jun = act2.jun
	ring_g = marks.ring
	root = Node3D.new()
	root.name = "OmSummit"
	lv.add_child(root)
	var sol := VhKit.solids(W)
	cu = (float(SHAFT.u0) + float(SHAFT.u1)) / 2.0
	cw = (float(SHAFT.w0) + float(SHAFT.w1)) / 2.0
	cage = VhKit.one(lv, "om-cage")
	gate = VhKit.one(lv, "om-cage-gate")
	var cb := BoxMesh.new()
	cb.size = Vector3(.14, 1.0, .14)
	var cmat := MsKit.std(0x2a2826, .5, .6)
	for u: float in [-93.2, -90.8]:
		var m := MsKit.part(root, cb, cmat, Vector3(X(u), 0, Z(6.8)), false)
		cables.append(m)
	lift_floor = (sol["lift-floor"] as Array)[0]
	lift_rails = sol["lift-rail"]
	lift_gate = (sol["lift-gate"] as Array)[0]
	lift_gate.set_off(true)
	# ---- the field emitters
	var beam := CylinderMesh.new()      # unit beam along +x from 0
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 1.0
	beam.radial_segments = 16
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	var D := R0 - 5.7
	var beam_len := D - CORE_R
	for k in 3:
		var e := Em.new()
		e.k = k
		e.a = k / 3.0 * TAU + .45
		e.g = VhKit.one(lv, "om-em-%d" % k)
		e.t = EM_FIRST + k * EM_STAGGER
		for i in 2:
			e.leaves.append([VhKit.one(lv, "om-em-%d-leaf-%d" % [k, i]), 1.0 if i == 0 else -1.0])
		var lens := MsKit.disc(1.15, 24)
		e.lens = MsKit.glow(e.g, lens, 0, 0xc8fff0, .95)
		e.lens.position = Vector3(R0 - 5.65, 2.6, 0)
		e.lens.rotation.z = PI / 2.0
		e.beam_a = MsKit.glow(e.g, beam, 0, 0x6dffb8, .55)
		e.beam_b = MsKit.glow(e.g, beam, 0, 0xe8fff8, .9)
		for m: MeshInstance3D in [e.beam_a, e.beam_b]:
			m.rotation.z = PI / 2.0
			m.extra_cull_margin = 80.0
		e.beam_a.position = Vector3(D - beam_len / 2.0, 2.6, 0)
		e.beam_b.position = e.beam_a.position
		e.beam_a.scale = Vector3(1.1, beam_len, 1.1)
		e.beam_b.scale = Vector3(.38, beam_len, .38)
		e.hit = MsKit.sprite8(e.g, 0x9dffd8, .9, 16.0)
		e.hit.position = Vector3(CORE_R + 1.0, 2.3, 0)
		e.cap_glow = MsKit.sprite8(e.g, 0x6dffb8, 0.0, 5.0)
		e.cap_glow.position = Vector3(R0 + .4, 2.9, 0)
		e.warn = MsKit.sprite8(e.g, 0xffa020, 0.0, 4.0)
		e.warn.position = Vector3(R0 - 1.0, 6.3, 2.6)
		for j in 6:
			var sp := MsKit.sprite8(e.g, 0xdfe8e4, 0.0, 1.2)
			e.steam.append([sp, j])
		e.beacon = sec.shoot_beacon(e.g, Vector3(R0 + .9, 2.9, 0), 2.8, 0x6dffb8)
		e.beacon.set_on(false)
		e.T = OmProp.make(9800 + k, 0.0, 0.0, 0.0, 1.15, 2.9, 260.0)
		e.armor = W.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": .3, "hz": 2.05, "top": DECK + 3.5, "bottom": DECK - .3, "tag": "wall"})
		# the housing and the backing plate are solid: you can stand on top of an emitter (it carries you round with the ring)
		e.body = [W.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": 2.4, "hz": 3.35, "top": OY + 5.72, "bottom": OY - .3, "tag": "plat"}), W.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": .7, "hz": 4.5, "top": OY + 2.8, "bottom": OY - 3.2, "tag": "plat"})]
		ems.append(e)
		_place_em(e)
	bolt_r = OmRibbon.new(root, 0xd8fff2)
	aura_r = OmRibbon.new(root, 0xd8fff2)
	bolt_light = OmniLight3D.new()
	bolt_light.light_color = MsKit.srgb(0xb8ffe8)
	bolt_light.omni_range = 260.0
	bolt_light.light_energy = 0.0
	root.add_child(bolt_light)
	jun_light = OmniLight3D.new()
	jun_light.light_color = MsKit.srgb(0x8dffc8)
	jun_light.omni_range = 70.0
	jun_light.light_energy = 0.0
	root.add_child(jun_light)
	# ---- the heavy lifter
	lifter = craft.lifter()
	lifter.group.visible = false
	beacon_g = Node3D.new()
	root.add_child(beacon_g)
	beacon_g.visible = false
	var bg := CylinderMesh.new()
	bg.top_radius = 1.0
	bg.bottom_radius = 1.0
	bg.height = 1.0
	bg.radial_segments = 20
	bg.rings = 1
	bg.cap_top = false
	bg.cap_bottom = false
	for q: Array in [[1.2, 1.0], [3.2, .35], [6.0, .14]]:
		var m := MsKit.glow(beacon_g, bg, 0, 0x5dffa0, 0.0)
		m.scale = Vector3(q[0], 1.0, q[0])
		m.extra_cull_margin = 200.0
		beacon_parts.append([m, q[1]])
	# ---- the markers on the screen (Phosphor CRT)
	font = load("res://assets/fonts/VT323-Regular.ttf")
	layer = CanvasLayer.new()
	layer.layer = 12
	lv.add_child(layer)
	ride_mark = _mark_label()
	for e in ems:
		e.lbl = _mark_label()
	spots = {"station": Vector3(X(-80.0), TOWER.low_y, Z(9.0)), "cage": Vector3(X(cu), TOWER.low_y, Z(cw)), "jam": Vector3(X(cu + 1.0), TOWER.jam_y, Z(cw)), "top": Vector3(X(-92.0), TOWER.top_y, Z(0.0)), "bridge_end": Vector3(X(-78.6), TOWER.top_y, Z(0.0)), "ring_drop": Vector3(X(-77.5), DECK, Z(0.0))}
	_place_lift()


func _mark_label() -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	layer.add_child(l)
	return l


func _place_lift() -> void:
	var y := float(lift.y) + float(lift.jolt)
	cage.position.y = y
	gate.visible = float(lift.gate) > .05
	lift_floor.set_span(y - .6, y)
	for s: World.Solid in lift_rails:
		s.set_span(y, y + 1.15)
	lift_gate.set_span(y, y + 1.15)
	lift_gate.set_off(float(lift.gate) < .5)
	# the hoist cables: from the yoke up to the sheaves (gone once they part)
	for m in cables:
		m.visible = lift.ph != "jammed" and lift.ph != "snap"
		var h := maxf(.1, 185.2 - (y + 5.5))
		m.scale.y = h
		m.position.y = y + 5.5 + h / 2.0


func on_lift(P: Player) -> bool:
	return P != null and not P.dead and absf(P.y - lift_floor.top) < .3 and lift_floor.top_at(P.x, P.z) != null


func on_ring(P: Player) -> bool:
	if P == null or P.dead:
		return false
	var r := U.hyp(P.x - OX, P.z - OZ)
	return r > R0 and r < R1 and absf(P.y - DECK) < .3


## keep the emitters' target, armour, housing and beacon in the ring's turning frame
func _place_em(e: Em) -> void:
	var q := e.a - ring_g.rotation.y
	var c := cos(q)
	var s := sin(q)
	e.T.x = OX + c * (R0 + .35)
	e.T.z = OZ + s * (R0 + .35)
	e.T.y = DECK - .1
	e.T.bx = e.T.x
	e.T.bz = e.T.z
	e.armor.place(OX + c * (R0 + .45), OZ + s * (R0 + .45), -q)
	e.armor.set_off(e.dead or e.open > .6)
	(e.body[0] as World.Solid).place(OX + c * (R0 - 2.6), OZ + s * (R0 - 2.6), -q)
	(e.body[1] as World.Solid).place(OX + c * (R0 - .3), OZ + s * (R0 - .3), -q)


func ems_dead() -> int:
	var n := 0
	for e in ems:
		if e.dead:
			n += 1
	return n


## standing on anything the ring carries: the walkway, an emitter's housing or its backing plate
func _on_ring_frame(P: Player) -> bool:
	if P == null or P.dead or not P.grounded:
		return false
	var r := U.hyp(P.x - OX, P.z - OZ)
	return r > R0 - 5.2 and r < R1 and P.y > DECK - .3 and P.y < OY + 6.0


func _chest() -> Vector3:
	return jun.group.position + Vector3(0, 11.0, 0)


func _strike() -> void:
	bolt.t = 0.0
	bolt.to = _chest()
	bolt.from = Vector3(OX, OY, OZ) + (bolt.to - Vector3(OX, OY, OZ)).normalized() * CORE_R
	jun.hold(1.0, 7.0)
	jun.brace()
	marks.flare_v = 3.0
	Game.fx.shake = maxf(Game.fx.shake, 1.4)
	audio.play("bolt")
	audio.play("junSurge")
	for _k in 4:
		Game.fx.sparks((bolt.to as Vector3) + Vector3(_R(-5, 5), _R(-4, 6), _R(-5, 5)), 30, 14.0, null, 0xc8fff0)


func _insert(kind: String, dur: float) -> void:
	ins.on = true
	ins.t = 0.0
	ins.dur = dur
	ins.kind = kind
	var P: Player = Game.player
	if P != null:
		P.invuln = maxf(P.invuln, dur + 1.5)


func _insert_camera() -> void:
	var j := jun.group.position
	var yaw := jun.group.rotation.y
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var sd := Vector3(f.z, 0.0, -f.x)
	var u := _sm(float(ins.t) / float(ins.dur))
	if ins.kind == "bolt":      # low in front of him, off his south side: the bolt comes down past the camera into him
		cine_cam.pos = Vector3(j.x + f.x * (21.0 - u * 4.0) + sd.x * 11.0, j.y + 2.0 + u * 2.0, j.z + f.z * (21.0 - u * 4.0) + sd.z * 11.0)
		cine_cam.look = Vector3(j.x + f.x * 3.0, j.y + 17.0 + u * 4.0, j.z + f.z * 3.0)
		cine_cam.fov = 66.0 - u * 6.0
	else:      # the last one: pulling back and up off him, the whole sphere coming apart above
		cine_cam.pos = Vector3(j.x + f.x * (24.0 + u * 26.0) + sd.x * (14.0 + u * 10.0), j.y + 3.0 + u * 22.0, j.z + f.z * (24.0 + u * 26.0) + sd.z * (14.0 + u * 10.0))
		cine_cam.look = Vector3(j.x + (OX - j.x) * u * .5, j.y + 16.0 + u * 80.0, j.z + (OZ - j.z) * u * .5)
		cine_cam.fov = 66.0
	var s: float = Game.fx.shake
	cine_cam.pos.x += (randf() - .5) * s * .3
	cine_cam.pos.y += (randf() - .5) * s * .3


## where the lifter wants to be for a jump off the ring at world angle q: out from the axis, nose pointing along the ring (ramp toward you)
func _hover_at(q: float) -> Vector3:
	return Vector3(OX + cos(q) * LIFT_R, LIFT_Y, OZ + sin(q) * LIFT_R)


func _ensure_pilot() -> void:
	# the pilot: whichever of PROG and TOMMY you are not playing (a posed copy at the controls is a gap: see PORT_STATUS)
	pilot_name = "PROG" if Game.char_pick == "tommy" else "TOMMY"


func call_lifter(P: Player) -> void:
	if ride.ph != "off" and ride.ph != "circle":
		return
	_ensure_pilot()
	var was: String = ride.ph
	ride.ph = "in"
	ride.t = 0.0
	lifter.group.visible = true
	ride.ang = atan2(P.z - OZ, P.x - OX) if P != null else PI
	if was == "circle":
		ride.from = ride.pos
	else:
		var a := float(ride.ang) + 1.4
		var f := _hover_at(a)
		f.y = 140.0
		f += Vector3(cos(a), 0.0, sin(a)) * 260.0
		ride.from = f
		ride.pos = f
	audio.play("lifterPass")
	audio.loop("lifter", .8)


## while you fight on the ring the lifter circles the sphere below it, far enough out to clear FOINT HQ and the riser
func _circle() -> void:
	if ride.ph != "off":
		return
	_ensure_pilot()
	ride.ph = "circle"
	ride.circ = PI * .4
	lifter.group.visible = true
	lifter.ramp_open = 0.0
	audio.loop("lifter", .35)


func _update_lifter(dt: float, P: Player) -> void:
	if ride.ph == "off" or ride.ph == "dive":
		return
	ride.t = float(ride.t) + dt
	lifter.update(dt)
	var g := lifter.group
	if ride.ph == "circle":
		ride.circ = float(ride.circ) + dt * .085
		var a: float = ride.circ
		ride.pos = Vector3(OX + cos(a) * 125.0, 140.0 + sin(float(ride.t) * .5) * 3.0, OZ + sin(a) * 125.0)
		var ty := atan2(-sin(a), cos(a))
		ride.yaw = float(ride.yaw) + atan2(sin(ty - float(ride.yaw)), cos(ty - float(ride.yaw))) * minf(1.0, dt * 2.0)      # nose along the turn
		g.position = ride.pos
		g.rotation = Vector3(-.05, ride.yaw, -.22)
		lifter.thrust = .9
		lifter.cruise = .7
		return
	if P != null and not ride.lock_ang:
		var q := atan2(P.z - OZ, P.x - OX)
		var d := atan2(sin(q - float(ride.ang)), cos(q - float(ride.ang)))
		ride.ang = float(ride.ang) + d * minf(1.0, dt * 1.6)
	var want := _hover_at(ride.ang)
	var u := minf(1.0, float(ride.t) / 5.5)
	var e := 1.0 - pow(1.0 - u, 3.0)
	if ride.ph == "in":
		ride.pos = (ride.from as Vector3).lerp(want, e)
		if u >= 1.0:
			ride.ph = "hold"
	else:
		ride.pos = (ride.pos as Vector3).lerp(want, minf(1.0, dt * 2.2))
	# tail to the sphere so the open bay faces the ring; banks into the turn
	var pos: Vector3 = ride.pos
	var out := Vector3(pos.x - OX, 0.0, pos.z - OZ).normalized()
	var yaw := atan2(out.x, out.z)
	ride.yaw = float(ride.yaw) + atan2(sin(yaw - float(ride.yaw)), cos(yaw - float(ride.yaw))) * minf(1.0, dt * (1.2 if ride.ph == "in" else 3.0))
	g.position = pos + Vector3(0, sin(float(ride.t) * 1.3) * .6, 0)
	var is_in: bool = ride.ph == "in"
	g.rotation = Vector3(-.04 + ((1.0 - e) * -.2 if is_in else 0.0), ride.yaw, sin(float(ride.t) * .9) * .03 + ((1.0 - e) * .5 if is_in else 0.0))
	lifter.thrust = 1.0
	lifter.cruise = 1.0 - u if is_in else 0.0
	lifter.ramp_open = minf(1.0, lifter.ramp_open + dt * .6)


func _screen_mark(l: Label, w: Vector3, txt: String, col: Color) -> void:
	var cam: Camera3D = Game.camera
	var vp := cam.get_viewport().get_visible_rect().size
	var behind := cam.is_position_behind(w)
	var p := cam.unproject_position(w)
	if behind:
		p = Vector2(vp.x - p.x, vp.y - 40.0)
	var off := behind or p.x < 40.0 or p.x > vp.x - 40.0 or p.y < 70.0 or p.y > vp.y - 30.0
	p.x = clampf(p.x, 40.0, vp.x - 40.0)
	p.y = clampf(p.y, 70.0, vp.y - 30.0)
	var arrow := "v"
	if off:
		arrow = "<" if p.x <= 40.0 else (">" if p.x >= vp.x - 40.0 else ("^" if p.y <= 70.0 else "v"))
	l.text = arrow + "\n" + txt
	l.add_theme_color_override(&"font_color", col)
	l.reset_size()
	l.position = p - Vector2(l.size.x / 2.0, l.size.y)
	l.visible = true


func _marks(P: Player) -> void:
	var cine: Variant = lv.get(&"cine")
	var cine_on: bool = cine != null and cine.on
	var on_r: bool = (ride.ph == "circle" or ride.ph == "in" or ride.ph == "hold") and st.ring_on and not cine_on
	if on_r and P != null:
		var p := lifter.group.position + Vector3(0, 5, 0)
		var d := roundi(p.distance_to(Vector3(P.x, P.y, P.z)))
		var jump: bool = ride.ph == "hold"
		_screen_mark(ride_mark, p, ("JUMP  -  " if jump else "") + pilot_name + "\n%d M" % d, Color("#ffb43c") if jump else Color("#8dffb4"))
		ride_mark.modulate.a = .45 if jump and fmod(float(st.t), .5) > .25 else 1.0
	else:
		ride_mark.visible = false
	var on_e: bool = st.ring_on and float(st.final) < 0.0 and not cine_on and P != null
	for e in ems:
		if e.dead or not on_e:
			e.lbl.visible = false
			continue
		var w := e.cap_glow.global_position
		var d := roundi(w.distance_to(Vector3(P.x, P.y + 1.4, P.z)))
		var open := e.ph == "open" or e.ph == "warn"
		var nm := "ABC"[e.k]
		_screen_mark(e.lbl, w + Vector3(0, 4.6, 0), ("SHOOT  -  EMITTER " + nm if open else "EMITTER " + nm + "  SHUT %d" % maxi(1, ceili(e.t))) + "\n%d M" % d, Color("#8dffb4") if open else Color("#ffb43c"))


func _after(t: float, fn: Callable) -> void:
	later.append({"t": t, "fn": fn})


func _jam() -> void:
	lift.ph = "snap"
	lift.v = 0.0
	lift.t = 0.0
	audio.play_at("liftSnap", Vector3(X(cu), float(lift.y) + 4.0, Z(cw)))
	marks.pulse({"max": 260.0, "kick": 1.6})
	alarm.call(8.0)
	Game.fx.sparks(Vector3(X(cu), 185.0, Z(6.8)), 50, 14.0, null, 0xffc060)
	sets.boom(X(cu), 185.5, Z(6.8), 5.0, 0.0, {"harmless": true})
	Game.hud.toast("THE HOIST IS GONE  -  CLIMB", 2.4)


func _kill_em(e: Em) -> void:
	if e.dead:
		return
	e.dead = true
	e.dead_t = 0.0
	e.T.dead = true
	e.T.hp = 0.0
	e.beacon.set_on(false)
	e.armor.set_off(true)
	var p := e.cap_glow.global_position
	sets.boom(p.x, p.y, p.z, 6.0, 0.0, {"harmless": true})
	Game.fx.explosion(p, 5.0)
	Game.fx.sparks(p, 70, 16.0, null, 0xc8fff0)
	audio.play_at("emBlow", p)
	for L: Array in e.leaves:
		(L[0] as Node3D).visible = false
	var n := ems_dead()
	Game.hud.toast("EMITTER %s DOWN  -  %d TO GO" % ["ABC"[e.k], 3 - n] if n < 3 else "CONTAINMENT IS GONE", 2.4)
	_after(.45, func() -> void:
		power = n
		_strike()
		if n < 3:
			_insert("bolt", 2.6))
	if n >= 3:
		_after(1.4, finale)
	if n == 1:
		audio.pa("emitter")
	if n == 2:
		_after(1.8, func() -> void: act2.say("mine"))


func finale() -> void:
	if float(st.final) >= 0.0:
		return
	st.final = 0.0
	st.fail_t = 0.0
	marks.breakup()
	alarm.call(60.0)
	audio.pa("critical")
	audio.play("sphereGroan")
	_insert("final", 3.8)
	jun.hold(1.0, 3.0)
	power = 3
	_after(3.6, func() -> void:
		call_lifter(Game.player)
		Game.hud.toast("%s IS COMING UNDER YOU  -  JUMP!" % pilot_name, 3.4))


func update(dt: float, P: Player, C: Combat) -> void:
	var fx: Variant = Game.fx
	# the lift
	if lift.ph == "ride":
		lift.t = float(lift.t) + dt
		lift.gate = minf(1.0, float(lift.gate) + dt * 2.0)
		if float(lift.t) > .8:
			lift.v = minf(7.5, float(lift.v) + dt * 2.2)
		var was: float = lift.y
		var rider := on_lift(P)
		lift.y = float(lift.y) + float(lift.v) * dt
		_place_lift()
		if rider:
			P.y = lift_floor.top
			if P.vy < 0.0:
				P.vy = 0.0
			P.grounded = true
		lift.bucket = float(lift.bucket) - dt
		if float(lift.bucket) <= 0.0:
			lift.bucket = .25
			fx.sparks(Vector3(X(float(SHAFT.u0) + .3), float(lift.y) + 1.0, Z(float(SHAFT.w0) + .1)), 3, 3.0, null, 0xffc060)
		var jy := float(TOWER.jam_y) + 3.0
		if was < jy and float(lift.y) >= jy:
			_jam()
	elif lift.ph == "snap":
		lift.t = float(lift.t) + dt
		var t: float = lift.t
		var rider := on_lift(P)
		lift.y = maxf(TOWER.jam_y, float(lift.y) - (14.0 * t if t < .5 else 0.0) * dt * 6.0)
		if t > .5 and float(lift.y) > float(TOWER.jam_y):
			lift.y = TOWER.jam_y
		lift.jolt = sin((t - .5) * 40.0) * .12 * (1.0 - (t - .5) * 2.0) if t > .5 and t < 1.0 else 0.0
		_place_lift()
		if rider:
			P.y = lift_floor.top
			if P.vy < 0.0:
				P.vy = 0.0
			P.grounded = true
		if t > .5 and not lift.caught:
			lift.caught = true
			var at := Vector3(X(cu), lift.y, Z(float(SHAFT.w0) + .2))
			fx.sparks(at, 60, 10.0, null, 0xffd080)
			fx.shake = maxf(fx.shake, 1.2)
			audio.play_at("groan", at)
		if t > 1.2:
			lift.ph = "jammed"
			lift.jolt = 0.0
			_place_lift()
	if not st.on or P == null:
		return
	for i in range(later.size() - 1, -1, -1):
		later[i].t = float(later[i].t) - dt
		if float(later[i].t) <= 0.0:
			var f: Callable = later[i].fn
			later.remove_at(i)
			f.call()
	# the ring turns under you (carry) ...
	var dq := marks.ring_w * dt
	if _on_ring_frame(P):
		var dx := P.x - OX
		var dz := P.z - OZ
		var c := cos(dq)
		var s := sin(dq)
		P.x = OX + dx * c + dz * s
		P.z = OZ - dx * s + dz * c
		P.yaw += dq
	# ... and the slip shoe throws sparks off its rim
	st.spark_t = float(st.spark_t) - dt
	if float(st.spark_t) <= 0.0:
		st.spark_t = .08 + randf() * .1
		fx.sparks(Vector3(X(-81.75), OY + .4, Z(_R(-1, 1))), 4, 6.0, null, 0x9dffd8)
	# the emitters: shut -> warn -> open (vent) -> shut; shoot the bank while it is open
	var T: float = st.t
	for e in ems:
		_place_em(e)
		if e.dead:
			e.dead_t += dt
			var k := maxf(0.0, 1.0 - e.dead_t / .35)
			e.beam_a.scale = Vector3(1.1 * k, e.beam_a.scale.y, 1.1 * k)
			e.beam_b.scale = Vector3(.38 * k, e.beam_b.scale.y, .38 * k)
			MsKit.opa(e.hit, .9 * k)
			MsKit.opa(e.lens, .95 * k)
			MsKit.opa(e.cap_glow, 0.0)
			MsKit.opa(e.warn, 0.0)
			if randf() < dt * 6.0:
				fx.sparks(e.cap_glow.global_position, 4, 5.0, null, 0xffc060)
			continue
		if not st.ring_on:
			e.T.dead = true
			e.beacon.set_on(false)
			continue
		e.t -= dt
		if e.ph == "shut" and e.t <= 0.0:
			e.ph = "warn"
			e.t = EM_WARN
			audio.play_at("emVent", e.cap_glow.global_position)
		elif e.ph == "warn" and e.t <= 0.0:
			e.ph = "open"
			e.t = EM_OPEN
		elif e.ph == "open" and e.t <= 0.0:
			e.ph = "shut"
			e.t = _R(EM_SHUT[0], EM_SHUT[1])
		var want := 1.0 if e.ph == "open" else 0.0
		e.open += (want - e.open) * minf(1.0, dt * (14.0 if want != 0.0 else 6.0))
		for L: Array in e.leaves:
			(L[0] as Node3D).position.y = 2.9 + float(L[1]) * e.open * 1.7
		var live := e.open > .6
		e.T.dead = not live
		e.beacon.set_on(live)
		if live:
			OmProp.arm(e.T)
		if e.T.hp < e.last_hp:
			e.hurt = 1.0
			e.last_hp = e.T.hp
		e.hurt = maxf(0.0, e.hurt - dt * 4.0)
		MsKit.opa(e.cap_glow, e.open * (.55 + .35 * sin(T * 30.0)) + e.hurt * .6)
		e.cap_glow.scale = Vector3.ONE * (5.0 + e.hurt * 3.0)
		MsKit.opa(e.warn, ((.9 if sin(T * 18.0) > 0.0 else .15) if e.ph == "warn" or e.ph == "open" else 0.0))
		for s: Array in e.steam:
			var u := fmod(T * .9 + int(s[1]) / 6.0, 1.0)
			var sp: MeshInstance3D = s[0]
			MsKit.opa(sp, e.open * .45 * (1.0 - u))
			sp.position = Vector3(R0 + .5 + u * 1.5, 4.6 + u * 4.0, (1.0 if int(s[1]) % 2 != 0 else -1.0) * (1.2 + u * 1.2))
			sp.scale = Vector3.ONE * (1.2 + u * 3.5)
		var fl := 1.0 + sin(T * 37.0 + e.k) * .08 + (randf() - .5) * .1
		e.beam_a.scale = Vector3(1.1 * fl, e.beam_a.scale.y, 1.1 * fl)
		e.hit.scale = Vector3.ONE * (16.0 * fl)
		if e.T.hp <= 0.0:
			_kill_em(e)
	st.t = T + dt
	# the bolt home and his aura
	if float(bolt.t) >= 0.0:
		bolt.t = float(bolt.t) + dt
		var u := float(bolt.t) / float(bolt.dur)
		bolt.to = _chest()
		bolt.re = float(bolt.re) - dt
		if float(bolt.re) <= 0.0:
			bolt.re = .045
			bolt_r.clear()
			bolt_r.ribbon(bolt.from, bolt.to, 26, 14.0, 1.3 * (1.0 - u * .5), 5)
			bolt_r.ribbon(bolt.from, bolt.to, 20, 22.0, .6, 2)
			bolt_r.flush()
		bolt_r.node.visible = randf() > .12 and u < 1.0
		bolt_r.set_alpha(minf(1.0, (1.0 - u) * 2.2))
		bolt_light.position = bolt.to
		bolt_light.light_energy = (1.0 - u) * 1800.0 / 200.0
		if u >= 1.0:
			bolt.t = -1.0
			bolt_r.node.visible = false
			bolt_light.light_energy = 0.0
			jun.hold(1.0 if power >= 3 else 0.0, 2.0)
	jun.boost = power * 1.15 + (2.5 if float(bolt.t) >= 0.0 else 0.0)
	jun_light.position = _chest()
	jun_light.light_energy = (power * 260.0 + (900.0 if float(bolt.t) >= 0.0 else 0.0)) / 100.0
	if power > 0 and randf() < dt * (power * 6.0):      # crackle over his body, more the more he has back
		var c := _chest()
		aura_r.clear()
		for _k in power:
			aura_r.ribbon(c + Vector3(_R(-7, 7), _R(-9, 8), _R(-6, 6)), c + Vector3(_R(-8, 8), _R(-10, 9), _R(-6, 6)), 8, 3.0, .25)
		aura_r.flush()
		aura_r.node.visible = true
		st.aura_t = .07
	else:
		st.aura_t = float(st.aura_t) - dt
		if float(st.aura_t) <= 0.0:
			aura_r.node.visible = false
	# the inserts
	if ins.on:
		ins.t = float(ins.t) + dt
		_insert_camera()
		if float(ins.t) >= float(ins.dur):
			ins.on = false
	# after the last emitter: the ring starts to go (explosions closing in from both sides along it), the lifter comes round
	if float(st.final) >= 0.0:
		st.final = float(st.final) + dt
		if float(st.final) > 4.0:
			st.fail_t = float(st.fail_t) + dt
		var me := atan2(P.z - OZ, P.x - OX)
		var gap := PI * maxf(.06, 1.0 - float(st.fail_t) / 13.0)
		if float(st.fail_t) > 0.0 and randf() < dt * 9.0:
			var q := me + PI + (-1.0 if randf() < .5 else 1.0) * (PI - gap) * pow(randf(), .4)
			var r := _R(R0, R1)
			marks.far_boom(Vector3(OX + cos(q) * r, DECK + 1.0, OZ + sin(q) * r), _R(6, 11), .4)
		if float(st.fail_t) > 0.0:
			st.drop_t = float(st.drop_t) - dt
			if float(st.drop_t) <= 0.0:
				st.drop_t = .7 + randf() * .6
				var q := me + (1.0 if randf() < .5 else -1.0) * gap * .95
				var at := Vector3(OX + cos(q) * _R(R0, R1), DECK + 1.0, OZ + sin(q) * _R(R0, R1))
				marks.far_boom(at, 9.0, .9)
				audio.play_at("boomBig", at)
		if float(st.fail_t) > 13.0 and on_ring(P):      # thrown off: the dive takes him
			st.fail_t = -99.0
			P.vy = 14.0
			P.grounded = false
			var o := Vector3(P.x - OX, 0.0, P.z - OZ).normalized()
			P.vx = o.x * 9.0
			P.vz = o.z * 9.0
			C.hurt_player(P, 12.0, OX, OZ, "melee")
			fx.shake = 2.0
	_update_lifter(dt, P)
	_marks(P)
	if ride.ph == "hold":
		beacon_g.visible = true
		beacon_g.position = lifter.group.position + Vector3(0, -1, 0)
		var top := maxf(10.0, DECK - beacon_g.position.y)
		for k in beacon_parts.size():
			var m: MeshInstance3D = beacon_parts[k][0]
			m.scale.y = top
			m.position.y = top / 2.0
			MsKit.opa(m, float(beacon_parts[k][1]) * (.45 + .3 * sin(T * 6.0 + k)))
	else:
		beacon_g.visible = false
	# a fall before the job is done: caught and put back on the last checkpoint's spot (no 170 m wait for the magma)
	if st.ring_on and float(st.final) < 0.0 and P.y < float(TOWER.jam_y) - 8.0 and not P.dead:
		st.fall_t = float(st.fall_t) + dt
		if float(st.fall_t) > .25:
			st.fall_t = 0.0
			P.reset()
			Game.rig.snap_to(P)
	else:
		st.fall_t = 0.0


## the escape stage proper (the riser and the ring are live)
func start() -> void:
	st.on = true


func jammed() -> bool:
	return lift.ph == "jammed"


## the ride starts when he steps into the cage. The finale score starts with the ride up
func try_ride(P: Player) -> bool:
	if lift.ph == "down" and on_lift(P):
		lift.ph = "ride"
		lift.t = 0.0
		lift.v = 0.0
		audio.play_at("liftStart", Vector3(X(cu), lift.y, Z(cw)))
		audio.pa("riser")
		if not st.music:
			st.music = true
			audio.cue("musicFinale", 3.0)
		return true
	return false


func ring(on: bool = true) -> void:
	if on and not st.ring_on and not st.music:      # (a checkpoint on the ring: the score comes in partway through)
		st.music = true
		audio.cue("musicFinale", 2.5, 45.0)
	if on and ride.ph == "off":
		_circle()
		Game.hud.toast("%s IS CIRCLING BELOW  -  YOUR WAY OUT" % pilot_name, 3.2)
	st.ring_on = on
	if on:
		marks.ring_w = .05


## he is off the ring: wherever the lifter is, it is under him now
func snap_lifter(P: Player) -> void:
	if ride.ph == "off":
		call_lifter(P)
	ride.ang = atan2(P.z - OZ, P.x - OX)
	ride.ph = "hold"
	ride.pos = _hover_at(ride.ang)
	ride.yaw = atan2(cos(float(ride.ang)), sin(float(ride.ang)))
	ride.t = maxf(float(ride.t), 6.0)
	_update_lifter(0.0, P)
	lifter.ramp_open = 1.0


## the dive has PROG now: the lifter holds its line
func take_lifter() -> void:
	ride.ph = "dive"


func reset(stage: String, obj: int, _retry: bool) -> void:
	if st.music:
		audio.cue("", 1.5)
	later.clear()
	st.on = false
	st.ring_on = false
	st.music = false
	st.final = -1.0
	st.fail_t = 0.0
	st.fall_t = 0.0
	power = 0
	bolt.t = -1.0
	bolt_r.node.visible = false
	aura_r.node.visible = false
	bolt_light.light_energy = 0.0
	jun_light.light_energy = 0.0
	ins.on = false
	lift.ph = "down"
	lift.y = TOWER.low_y
	lift.v = 0.0
	lift.gate = 0.0
	lift.jolt = 0.0
	lift.caught = false
	for e in ems:
		e.dead = false
		e.ph = "shut"
		e.t = EM_FIRST + e.k * EM_STAGGER
		e.open = 0.0
		e.T.hp = e.T.max
		e.last_hp = e.T.max
		e.T.dead = true
		e.beacon.set_on(false)
		for L: Array in e.leaves:
			(L[0] as Node3D).visible = true
			(L[0] as Node3D).position.y = 2.9
		MsKit.opa(e.lens, .95)
		MsKit.opa(e.hit, .9)
		e.beam_a.scale = Vector3(1.1, e.beam_a.scale.y, 1.1)
		e.beam_b.scale = Vector3(.38, e.beam_b.scale.y, .38)
		e.lbl.visible = false
	ride.ph = "off"
	ride.lock_ang = false
	lifter.group.visible = false
	lifter.ramp_open = 0.0
	audio.loop("lifter", 0.0)
	beacon_g.visible = false
	ride_mark.visible = false
	jun.boost = 0.0
	if stage == "escape":
		if obj >= 6:      # past the lift
			lift.ph = "jammed"
			lift.y = TOWER.jam_y
			lift.gate = 1.0
		var dead := maxi(0, obj - 8)      # em1.. objectives: that many emitters already down
		for i in mini(3, dead):
			var e := ems[i]
			e.dead = true
			e.dead_t = 9.0
			e.T.dead = true
			for L: Array in e.leaves:
				(L[0] as Node3D).visible = false
		power = mini(3, dead)
	_place_lift()
