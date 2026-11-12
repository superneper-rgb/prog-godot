class_name OmEscape
extends RefCounted
## OMNISPHERE: THE COLLAPSE (JS escape.js). Juniper walks out (punches the west wall, stomps across the island, hauls up the podium, every footfall shakes the floor). The bridge south drops segment by segment; the climb up the outside on maintenance brackets (rusted ones tear loose a second after you land); the conduit run (sections blow out ahead of you, surges race along the line, a second gunship strafes); THE CATCH: a section shears off over the podium and Juniper catches it and presses it back up while you run across ("Please don't fall."). Debris rains the whole time. The art is exported; bridge, brackets, conduit pieces and the span are found by name, their solids by vhId.

const SPEC := [[160.0, 53.4, 22.4, false], [152.5, 53.4, 26.8, true], [160.0, 53.4, 31.2, false], [152.5, 53.4, 35.6, false], [159.0, 53.4, 40.0, true]]


## the podium's surface at radius r from the sphere's axis, as landmark.js draws it: flat at 31 to r 40, a gentle fall to 29 at r 64, then a chamfer down to the rim at r 70 (23). null = off the podium
static func podium_y(r: float) -> Variant:
	if r <= 40.0:
		return 31.0
	if r <= 64.0:
		return 31.0 - (r - 40.0) / 12.0
	if r <= 70.0:
		return 29.0 - (r - 64.0)
	return null


class Fall:
	var s: World.Solid
	var g: Node3D
	var z := 0.0
	var fall := 0.0
	var v := 0.0
	var rot := 0.0
	var at := 0.0
	var rails: Array[World.Solid] = []      # (the bridge's side rails ride with the piece)


class Plat extends Fall:
	var top := 0.0
	var holds := false
	var x := 0.0
	var pz := 0.0
	var a := 0.0
	var shake := 0.0
	var gone := false
	var yaw0 := 0.0


class Piece:
	var s0 := 0.0
	var s1 := 0.0
	var g: Node3D
	var line: Array[StandardMaterial3D] = []
	var solids: Array = []
	var homes: Array = []
	var breakable := false
	var gone := false
	var is_catch := false


class Chase:
	var s: OmCraft.Gunship
	var T: OmProp
	var hb: OmCraft.Hitboxes
	var pos := Vector3.ZERO
	var yaw := 0.0
	var bank := 0.0
	var t := 0.0
	var ph := "wait"
	var pts: Array = []
	var dur := 0.0
	var fire_t := 0.0
	var passes := 0
	var crash_v := Vector3.ZERO
	var leave_dir := Vector3.ZERO
	var done := false
	var wait_t := 2.5


class Debris:
	var chunk: MeshInstance3D = null
	var ring: MeshInstance3D = null
	var rock: MeshInstance3D = null
	var gy := 0.0
	var v := 0.0
	var vv := Vector3.ZERO
	var w := 0.0


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
var J: Dictionary
var OMNI: Vector3
var bridge: Array[Fall] = []
var plats: Array[Plat] = []
var pieces: Array[Piece] = []
var path: OmPath
var LEN := 0.0
var C0 := 0.0
var C1 := 0.0
var span: Piece
var span_mid: Vector3
var span_t: Vector3
var stand_y := 29.0
var wy := 0.0
const WRECK_H := 1.8
var PATH: Array = []
var stomp_cd := 0.0
var chase: Chase = null
## BUG-108 (tracker): true once the service lift is moving (set by the level from the summit). The chase gunship aims each pass at where PROG stands when the pass starts, but the lift carries him 7.5 m/s up, so its track went through the rider. It breaks off instead. Godot only.
var chase_clear := Callable()
var debris: Array[Debris] = []
var esc := {"on": false, "t": 0.0, "surge_t": 7.0, "surge": null, "conduit": false, "sphere_down": false, "ring_cut": false, "pulsed": false}
var cs := {"ph": "idle", "t": 0.0, "dy": 0.0, "v": 0.0, "cross_t": 0.0}
var surge_sprite: MeshInstance3D
var spots := {}
var chunk_mesh: BoxMesh
var chunk_mat: StandardMaterial3D
var ring_mesh: ArrayMesh
var rock_mesh: SphereMesh
var rock_mat: StandardMaterial3D
var ring_mat: StandardMaterial3D


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
	J = OmAct2.J
	OMNI = OmMarks.OMNI
	root = Node3D.new()
	root.name = "OmEscape"
	lv.add_child(root)
	var data: Dictionary = lv.info.data.omni_data.conduit
	path = OmPath.new(data.pts, data.len)
	LEN = path.length
	C0 = data.c0
	C1 = data.c1
	var sol := VhKit.solids(W)
	for i in 8:
		var b := Fall.new()
		b.s = (sol["bridge-%d" % i] as Array)[0]
		b.g = VhKit.one(lv, "om-bridge-%d" % i)
		b.z = -122.0 - i * 12.0 - 6.0
		b.rails = OmRails.bridge_rails(W, b.z)
		b.rot = (randf() - .5) * .6
		bridge.append(b)
	for i in SPEC.size():
		var q: Array = SPEC[i]
		var p := Plat.new()
		var pp := _polar(q[0], q[1], q[2])
		p.top = q[2]
		p.holds = q[3]
		p.x = pp.x
		p.pz = pp.z
		p.a = pp.a
		p.g = VhKit.one(lv, "om-plat-%d" % i)
		p.s = (sol["plat-%d" % i] as Array)[0]
		p.rot = (randf() - .5) * .8
		plats.append(p)
	var specs: Array = data.pieces
	for i in specs.size():
		var d: Dictionary = specs[i]
		var pc := Piece.new()
		pc.s0 = d.s0
		pc.s1 = d.s1
		pc.breakable = d.breakable
		pc.is_catch = d.get("catch", false)
		pc.g = VhKit.one(lv, "om-pc-%d" % i)
		for mi in VhKit.meshes(VhKit.one(lv, "om-pc-%d-line" % i)):
			var own := StandardMaterial3D.new()
			own.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			own.albedo_color = _lin_line(.43, 1.0, .72)
			own.disable_fog = true
			mi.material_override = own
			pc.line.append(own)
		pc.solids = sol.get("pc-%d" % i, [])
		for s: World.Solid in pc.solids:
			pc.homes.append([s.top, s.top_low, s.bottom])
		pieces.append(pc)
		if pc.is_catch:
			span = pc
	var sC := (C0 + C1) / 2.0
	span_mid = path.at(sC)
	span_t = path.tan(sC)
	stand_y = float(_or(podium_y(U.hyp(span_mid.x - OMNI.x, span_mid.z - OMNI.z)), 29.0))
	wy = atan2(-span_t.z, span_t.x)
	# ---- Juniper's walk (the path the level gives him): out of the drum, punch the west panel, through his hole with arms in, tear the lower siphon lines out on the pad, leap to the island, haul up the podium, stand under the catch span (waits catch), then round under the sphere to the west side, below the riser (waits power)
	var jx: float = J.x
	var jz: float = J.z
	PATH = [{"x": jx - 6.0, "y": 18.0, "z": jz + 3.0}, {"x": jx - 24.0, "y": 18.0, "z": jz + 5.0}, {"x": jx - 36.0, "y": 18.0, "z": jz, "punch": true, "yaw": -PI / 2.0},
		{"x": jx - 50.0, "y": 18.0, "z": jz, "tuck": true},
		{"x": jx - 50.0, "y": 18.0, "z": jz, "punch": true, "id": "rip", "yaw": 2.47},
		{"x": jx - 52.0, "y": 18.0, "z": jz - 6.0, "tuck": true}, {"x": jx - 60.0, "y": 8.0, "z": jz - 17.0, "leap": true, "tuck": true},
		_opy(11.25, 79.0, 8.0, {"tuck": true}),
		_opy(11.25, 79.0, 25.0, {"climb": true, "yaw": _inward(11.25)}),
		_opy(11.25, 74.0, 29.8, {"climb": true}),
		_opy(11.25, 63.0, podium_y(63.0), {"climb": true}),
		{"x": span_mid.x, "y": stand_y + WRECK_H, "z": span_mid.z, "wait": "catch", "id": "stand", "yaw": atan2(-span_t.z, span_t.x)},
		_opy(150.0, 46.0, podium_y(46.0), {}), _opy(180.0, 58.0, podium_y(58.0), {"wait": "power", "id": "power", "yaw": PI / 2.0})]
	surge_sprite = MsKit.sprite8(root, 0xb8fff0, 0.0, 9.0)
	chunk_mesh = BoxMesh.new()
	chunk_mesh.size = Vector3(3.0, 2.0, 1.5)
	chunk_mat = MsKit.std(0x5c3a26, .9, .2)
	ring_mesh = MsKit.ring(1.6, 2.0, 24)
	ring_mat = VhKit.unlit(0xff3020, .8)
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock_mesh = MsKit.sphere(1.1, 8, 6)
	rock_mat = MsKit.std(0x2a1a14, .9)
	rock_mat.emission_enabled = true
	rock_mat.emission = MsKit.lin(0xff5010)
	rock_mat.emission_energy_multiplier = .8
	var LAND_x := (jx - 54.0 + jx - 48.8) / 2.0
	var LAND_z := (jz + 7.6 + jz + 14.2) / 2.0
	var mid := path.at_u(.52)
	var g5 := path.at(5.0)
	var GT := snappedf(g5.y + 3.2, .01)
	var ce := path.at(C1 + 12.0)
	var END := path.at_u(1.0)
	spots = {"pad": _polar(180.0, 50.0, 18.0), "landing": Vector3(LAND_x, J.floor, LAND_z + 1.0), "gantry": Vector3(g5.x, GT, g5.z), "climb_spawn": Vector3(plats[1].x, plats[1].top, plats[1].pz), "corner": Vector3(mid.x, mid.y + 2.9, mid.z), "end": Vector3(END.x, END.y + 3.05, END.z), "catch_end": Vector3(ce.x, ce.y + 3.3, ce.z)}


static func _or(v: Variant, d: float) -> float:
	return d if v == null else float(v)


## JS line.material.color.setRGB is linear already; Godot albedo_color takes sRGB
static func _lin_line(r: float, g: float, b: float) -> Color:
	return Color(r, g, b).linear_to_srgb()


func _polar(deg: float, r: float, y: float) -> Dictionary:
	var a := deg_to_rad(deg)
	return {"x": float(J.x) + cos(a) * r, "y": y, "z": float(J.z) + sin(a) * r, "a": a}


func _opy(deg: float, r: float, y: Variant, extra: Dictionary) -> Dictionary:
	var a := deg_to_rad(deg)
	var d := {"x": OMNI.x + cos(a) * r, "y": float(y), "z": OMNI.z + sin(a) * r}
	d.merge(extra)
	return d


static func _inward(deg: float) -> float:      # facing the sphere's axis from that side
	var a := deg_to_rad(deg)
	return atan2(-cos(a), -sin(a))


func free_juniper() -> void:
	jun.breakout(PATH, {
		"smash": func() -> void: act2.smash_frame(),
		"stomp": _stomp,
		"ground": _ground,
		"grip": func(p: Vector3) -> void:
			Game.fx.dust(Vector3(p.x, p.y + 19.0, p.z), 6, 3.0)
			Game.fx.shake = maxf(Game.fx.shake, .5)
			audio.play_at("groan", p),
		"land": func(p: Vector3) -> void:
			Game.fx.shake = maxf(Game.fx.shake, 1.4)
			if p.y < .5:
				Game.fx.sparks(Vector3(p.x, .3, p.z), 60, 14.0, null, 0xff8a30)
				audio.play_at("splash", p)
			else:
				Game.fx.dust(Vector3(p.x, p.y + .3, p.z), 14, 5.0)
			audio.play_at("boomBig", p),
		"punch": func(p: Dictionary) -> void:
			if p.get("id", "") == "rip":
				var at := Vector3(p.x, p.y, p.z)
				if marks != null:
					marks.rip_lines()
				audio.play_at("groan", at)
				audio.play_at("emBlow", at)
				Game.fx.shake = maxf(Game.fx.shake, 1.6)
			else:
				act2.breach_west(),
		"arrive": func() -> void: audio.play_at("groan", Vector3(OMNI.x, 40.0, OMNI.z)),
	}, 3.6)


func _stomp(p: Vector3, side: float) -> void:
	var P: Player = Game.player
	var d := U.hyp(P.x - p.x, P.z - p.z) if P != null else 1e9
	Game.fx.shake = maxf(Game.fx.shake, minf(1.6, 40.0 / maxf(10.0, d)))
	var yaw := jun.group.rotation.y
	var fx_ := p.x + cos(yaw) * side * 5.0
	var fz := p.z - sin(yaw) * side * 5.0
	if p.y < .5:
		Game.fx.sparks(Vector3(fx_, .2, fz), 26, 9.0, null, 0xff8a30)
		Game.fx.dust(Vector3(fx_, .4, fz), 10, 5.0)
		if d < 120.0:
			audio.play_at("splash", Vector3(fx_, 0, fz))
	else:
		Game.fx.dust(Vector3(fx_, p.y + .3, fz), 8, 3.0)
		if d < 90.0:
			audio.play_at("boom", Vector3(fx_, p.y, fz))


## the podium (read 7 m in: his toes are on its rise), and the slab under the span
func _ground(x: float, z: float) -> Variant:
	var r := U.hyp(x - OMNI.x, z - OMNI.z)
	if r >= 63.5:
		return null
	var dx := x - span_mid.x
	var dz := z - span_mid.z
	var c := cos(wy)
	var s := sin(wy)
	var lx := dx * c - dz * s
	var lz := dx * s + dz * c
	if absf(lx) < 7.5 and absf(lz) < 5.5:
		return stand_y + WRECK_H
	return podium_y(maxf(0.0, r - 7.0))


func collapse_bridge() -> void:
	for i in bridge.size():
		bridge[i].at = .4 + (bridge.size() - 1 - i) * .35
	act2.door_s.lock(true)
	audio.pa("evac")


# ---- the chase gunship (passes across the conduit; the falling ring takes it)
func launch_chase() -> void:
	if chase != null:
		return
	var c := Chase.new()
	c.s = craft.gunship()
	c.s.group.scale = Vector3.ONE * 1.25
	var start := Vector3(float(J.x) - 40.0, 70.0, float(J.z) + 90.0)
	c.s.group.position = start
	c.pos = start
	c.T = OmProp.make(9790, start.x, start.z, start.y, 4.5, 3.4, 900.0)
	c.T.dead = false
	Game.combat.targets.append(c.T)
	c.hb = OmCraft.Hitboxes.new(c.T)
	audio.play_at("gunshipPass", start)
	Game.hud.toast("GUNSHIP  -  KEEP MOVING")
	chase = c


func _chase_pass(P: Player) -> void:
	var c := chase
	var side := 1.0 if randf() < .5 else -1.0
	var over := Vector3(P.x, P.y + 8.5, P.z)
	var tan := path.tan_u(.5)
	var n := Vector3(-tan.z, 0.0, tan.x).normalized() * side      # across the pipe
	c.pts = [c.pos, over - n * 55.0 + Vector3(0, 22, 0), over, over + n * 55.0 + Vector3(0, 24, 0)]
	c.dur = 5.2
	c.t = 0.0
	c.ph = "pass"
	c.passes += 1
	audio.play_at("gunshipPass", c.pos)


func _update_chase(dt: float, P: Player, C: Combat) -> void:
	var c := chase
	if c == null or c.done:
		return
	c.t += dt
	c.s.update(dt)
	var g := c.s.group
	var T := c.T
	if c.ph != "crash" and T.hp <= 0.0:
		c.ph = "crash"
		T.dead = true
		c.hb.drop()
		c.crash_v = Vector3((randf() - .5) * 8.0, 2.0, (randf() - .5) * 8.0)
		audio.play_at("boomBig", g.position)
		Game.fx.explosion(g.position, 4.0)
		Game.hud.toast("GUNSHIP DOWN")
	if c.ph == "crash":
		c.crash_v.y -= 14.0 * dt
		g.position += c.crash_v * dt
		g.rotation.z += dt * 2.6
		g.rotation.x += dt * .7
		if randf() < dt * 12.0:
			Game.fx.explosion(g.position + Vector3((randf() - .5) * 4.0, 1.0, (randf() - .5) * 4.0), 1.4)
		var ground := W.ground_height(g.position.x, g.position.z, 1.0, g.position.y + 1.0)
		if g.position.y < maxf(1.0, ground + .5):
			sets.boom(g.position.x, g.position.y + 1.0, g.position.z, 9.0, 0.0, {"harmless": true})
			audio.play_at("splash", g.position)
			g.visible = false
			c.done = true
		return
	if c.ph != "leave" and not chase_clear.is_null() and chase_clear.call():
		c.ph = "leave"
		c.t = 0.0
		var away := Vector3(g.position.x - P.x, 0.0, g.position.z - P.z) if P != null else Vector3(0, 0, 1)
		c.leave_dir = away.normalized() if away.length() > .01 else Vector3(0, 0, 1)
	var want := c.yaw
	var bank := 0.0
	if c.ph == "leave":      # climbs away from him, then is gone
		c.pos += (c.leave_dir * 30.0 + Vector3(0, 14.0, 0)) * dt
		want = atan2(c.leave_dir.x, c.leave_dir.z)
		if c.t > 4.0:
			g.visible = false
			T.dead = true
			c.hb.drop()
			c.done = true
			return
	elif c.ph == "wait":
		c.wait_t -= dt
		c.pos.y += sin(c.t) * .02
		if c.wait_t <= 0.0 and P != null:
			_chase_pass(P)
	elif c.ph == "pass":
		var u := minf(1.0, c.t / c.dur)
		c.pos = _bez(c.pts, u)
		var v2 := _bez(c.pts, minf(1.0, u + .02))
		if U.hyp(v2.x - c.pos.x, v2.z - c.pos.z) > .05:
			want = atan2(v2.x - c.pos.x, v2.z - c.pos.z)
			bank = -atan2(sin(want - c.yaw), cos(want - c.yaw)) * 2.4
		if P != null and not P.dead and C != null and u > .3 and u < .7:
			c.fire_t -= dt
			if c.fire_t <= 0.0:
				var o := g.position + Vector3(0, -2, 0)
				var dd := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z).normalized()
				dd.x += (randf() - .5) * .08
				dd.z += (randf() - .5) * .08
				C.enemies.fire_from(T.id, o.x, o.y, o.z, dd.x, dd.y, dd.z, {"kind": "plasma", "speed": 40.0, "dmg": 7.0, "r": .2})
				c.fire_t = .1
		if u >= 1.0:
			c.ph = "wait"
			c.wait_t = 2.2 + randf() * 2.0
	g.position = c.pos
	c.yaw += atan2(sin(want - c.yaw), cos(want - c.yaw)) * minf(1.0, dt * 3.0)
	c.bank += (bank - c.bank) * minf(1.0, dt * 3.0)
	g.rotation = Vector3(-.1, c.yaw, clampf(c.bank, -.7, .7))
	c.hb.sync(g.position.x, g.position.y, g.position.z, c.yaw)


static func _bez(p: Array, u: float) -> Vector3:
	var v := 1.0 - u
	return (p[0] as Vector3) * (v * v * v) + (p[1] as Vector3) * (3.0 * v * v * u) + (p[2] as Vector3) * (3.0 * v * u * u) + (p[3] as Vector3) * (u * u * u)


## the ring is coming down: the chase ship is caught in it
func kill_chase() -> void:
	if chase != null and chase.ph != "crash" and not chase.done:
		chase.T.hp = 0.0


func _fall_piece(b: Fall, dt: float, floor_y: float) -> void:
	b.v += 20.0 * dt
	b.g.position.y -= b.v * dt
	b.g.rotation.z += b.rot * dt
	var top := b.g.position.y
	b.s.set_span(top - .8, top)
	for r: World.Solid in b.rails:
		r.set_span(top, top + OmRails.H)
	if b.g.position.y < floor_y:
		b.s.set_off(true)
		for r: World.Solid in b.rails:
			r.set_off(true)
		b.g.visible = false


func _free_debris(d: Debris) -> void:
	for o: MeshInstance3D in [d.chunk, d.ring, d.rock]:
		if o != null:
			o.queue_free()


## arc length along the conduit of the point nearest (x, z) (coarse) -> [s, d]
func along(x: float, z: float) -> Array:
	var best := 0.0
	var bd := 1e9
	var d := 0.0
	while d <= LEN:
		var p := path.at(d)
		var q := U.hyp(p.x - x, p.z - z)
		if q < bd:
			bd = q
			best = d
		d += 3.0
	return [best, bd]


func _blow_piece(pc: Piece) -> void:
	if pc.gone:
		return
	pc.gone = true
	for s: World.Solid in pc.solids:
		s.set_off(true)
	pc.g.visible = false
	var m := path.at((pc.s0 + pc.s1) / 2.0)
	sets.boom(m.x, m.y + 2.0, m.z, 8.0, 0.0, {"harmless": true})
	audio.play_at("groan", m)
	for _k in 6:
		var d := Debris.new()
		d.chunk = MsKit.part(root, chunk_mesh, chunk_mat, m + Vector3((randf() - .5) * 8.0, (randf() - .5) * 4.0, (randf() - .5) * 8.0))
		d.chunk.scale = Vector3(.7 + randf(), .5 + randf(), .7 + randf())
		d.vv = Vector3((randf() - .5) * 10.0, 3.0 + randf() * 6.0, (randf() - .5) * 10.0)
		d.w = (randf() - .5) * 6.0
		debris.append(d)


func _update_escape(dt: float, P: Player, C: Combat) -> void:
	var fx: Variant = Game.fx
	# the bridge
	for b in bridge:
		if b.at > 0.0:
			b.at -= dt
			if b.at <= 0.0:
				b.at = 0.0
				b.fall = 1e-3
				sets.boom(-200.0, 16.0, b.z, 6.0, 0.0, {"harmless": true})
				audio.play_at("groan", Vector3(-200.0, 18.0, b.z))
		if b.fall > 0.0 and b.g.visible:
			_fall_piece(b, dt, 4.0)
	if not esc.on:
		return
	esc.t = float(esc.t) + dt
	# brackets: the loose ones shake, spark, then drop once you have stood on them
	for p in plats:
		if p.gone:
			continue
		var on := P != null and not P.dead and P.grounded and absf(P.y - p.top) < .5 and U.hyp(P.x - p.x, P.z - p.pz) < 3.4
		if not p.holds and on and p.shake <= 0.0 and p.fall <= 0.0:
			p.shake = 1.25
			var at := Vector3(p.x, p.top, p.pz)
			audio.play_at("groan", at)
			audio.play_at("sparks", at)
		if p.shake > 0.0:
			p.shake -= dt
			p.g.position.x = p.x + (randf() - .5) * .12
			p.g.position.z = p.pz + (randf() - .5) * .12
			if randf() < dt * 14.0:
				fx.sparks(Vector3(p.x + (randf() - .5) * 4.0, p.top - .5, p.pz + (randf() - .5) * 4.0), 5, 5.0, null, 0xffc060)
			if p.shake <= 0.0:
				p.fall = 1e-3
				p.g.position = Vector3(p.x, p.top, p.pz)
				sets.boom(p.x, p.top - 1.0, p.pz, 2.5, 0.0, {"harmless": true})
		if p.fall > 0.0:
			_fall_piece(p, dt, 4.0)
			if not p.g.visible:
				p.gone = true
	# the conduit: pieces ahead of you blow out, surges run the line
	if P != null and esc.conduit:
		var at: Array = along(P.x, P.z)
		var at_s: float = at[0]
		var on_pipe := float(at[1]) < 4.0 and P.y > 30.0
		for pc in pieces:
			if pc.breakable and not pc.gone and at_s > pc.s0 - 22.0 and at_s < pc.s0:
				_blow_piece(pc)
		esc.surge_t = float(esc.surge_t) - dt
		if float(esc.surge_t) <= 0.0 and esc.surge == null and (cs.ph == "idle" or cs.ph == "gone"):
			esc.surge = {"s": maxf(0.0, at_s - 40.0), "warn": 1.3, "hit": false}
			esc.surge_t = 8.0 + randf() * 4.0
			audio.play_at("draw", path.at(float(esc.surge.s)))
		if esc.surge != null:
			var sg: Dictionary = esc.surge
			if float(sg.warn) > 0.0:
				sg.warn = float(sg.warn) - dt
				var k := .5 + .5 * sin(float(esc.t) * 40.0)
				_line_col(.43 + .57 * k, 1.0, .72 + .28 * k)
			else:
				sg.s = float(sg.s) + 42.0 * dt
				_line_col(.43, 1.0, .72)
				var p := path.at(float(sg.s))
				surge_sprite.position = Vector3(p.x, p.y + 3.2, p.z)
				MsKit.opa(surge_sprite, .95)
				if randf() < .7:
					fx.sparks(surge_sprite.position, 6, 7.0, null, 0xb8fff0)
				if not sg.hit and on_pipe and P.grounded and absf(at_s - float(sg.s)) < 3.5 and not P.dead:
					sg.hit = true
					C.hurt_player(P, 24.0, p.x + 1.0, p.z, "melee")
					P.vy = maxf(P.vy, 9.0)
					P.grounded = false
					fx.shake = maxf(fx.shake, .9)
					audio.play_at("arc", p)
				if float(sg.s) > LEN:
					esc.surge = null
					MsKit.opa(surge_sprite, 0.0)
	_update_catch(dt, P)
	# the falling ring cuts through the conduit behind you
	if marks != null and marks.ring_falling and marks.ring_y < 72.0 and not esc.ring_cut:
		esc.ring_cut = true
		var me: float = float(along(P.x, P.z)[0]) if P != null else -1.0
		for pc in pieces:
			var m := path.at((pc.s0 + pc.s1) / 2.0)
			var r := U.hyp(m.x - OMNI.x, m.z - OMNI.z)
			if r > 68.0 and r < 90.0 and not (me > pc.s0 - 2.0 and me < pc.s1 + 2.0):
				_blow_piece(pc)
	# debris: a red ring, then a burning chunk; conduit chunks tumbling
	if P != null and randf() < dt * 1.6:
		var x := P.x + (randf() - .5) * 16.0
		var z := P.z + (randf() - .5) * 16.0
		var gy := W.ground_height(x, z, .5, 90.0)
		if gy > 5.0 and U.hyp(x - P.x, z - P.z) > 2.5:
			var d := Debris.new()
			d.ring = MsKit.part(root, ring_mesh, ring_mat, Vector3(x, gy + .08, z), false)
			d.ring.rotation.x = -PI / 2.0
			d.rock = MsKit.part(root, rock_mesh, rock_mat, Vector3(x, gy + 40.0, z), false)
			d.gy = gy
			debris.append(d)
	for i in range(debris.size() - 1, -1, -1):
		var d := debris[i]
		if d.chunk != null:
			d.vv.y -= 20.0 * dt
			d.chunk.position += d.vv * dt
			d.chunk.rotation.x += d.w * dt
			if d.chunk.position.y < 0.0:
				_free_debris(d)
				debris.remove_at(i)
			continue
		d.v += 30.0 * dt
		d.rock.position.y -= d.v * dt
		d.rock.rotation.x += dt * 3.0
		if d.rock.position.y <= d.gy + .5:
			sets.boom(d.rock.position.x, d.gy + .5, d.rock.position.z, 3.5, 30.0)
			_free_debris(d)
			debris.remove_at(i)
	if randf() < dt * .7:
		fx.explosion(Vector3(float(J.x) + (randf() - .5) * 110.0, 30.0 + randf() * 60.0, float(J.z) + (randf() - .5) * 110.0), 2.5 + randf() * 3.0)
	# under Juniper's feet
	if P != null and not P.dead and jun.out.on and not jun.out.done and jun.out.phase == "walk" and jun.out.waiting == "":
		var jp := jun.group.position
		var d := U.hyp(P.x - jp.x, P.z - jp.z)
		if d < 7.0 and absf(P.y - jp.y) < 6.0 and stomp_cd <= 0.0:
			stomp_cd = 1.0
			C.hurt_player(P, 14.0, jp.x, jp.z, "melee")
			P.vy = maxf(P.vy, 7.0)
			P.grounded = false
	stomp_cd = maxf(0.0, stomp_cd - dt)
	_update_chase(dt, P, C)
	if esc.sphere_down and marks != null and marks.ring_down:
		kill_chase()


func _line_col(r: float, g: float, b: float) -> void:
	var c := _lin_line(r, g, b)
	for pc in pieces:
		for m in pc.line:
			m.albedo_color = c


# ---- the catch: the span shears, drops onto his hands, he presses it back up
func _set_span(dy: float) -> void:
	cs.dy = dy
	span.g.position.y = dy
	for i in span.solids.size():
		var s: World.Solid = span.solids[i]
		var h: Array = span.homes[i]
		s.set_span(float(h[2]) + dy, float(h[0]) + dy, float(h[1]) + dy)


func _break_span() -> void:
	cs.ph = "break"
	cs.t = 0.0
	cs.v = 0.0
	jun.hold(.42, 3.5)
	alarm.call(10.0)
	if marks != null:      # a shockwave out of the core shears it
		marks.pulse({"max": 500.0, "kick": 1.6})
	for d: float in [C0, C1]:
		var p := path.at(d)
		sets.boom(p.x, p.y + 1.0, p.z, 7.0, 0.0, {"harmless": true})
	audio.play_at("groan", span_mid)
	Game.hud.toast("THE LINE IS GOING", 1.6)


func _update_catch(dt: float, P: Player) -> void:
	var ph: String = cs.ph
	if ph == "idle" or ph == "gone":
		if ph == "idle" and esc.conduit and P != null:
			var at: Array = along(P.x, P.z)
			if float(at[1]) < 7.0 and float(at[0]) > C0 - 32.0 and float(at[0]) < C1:
				if jun.out.waiting == "catch":
					_break_span()
				else:
					jun.hurry(5.0)
		return
	cs.t = float(cs.t) + dt
	var fx: Variant = Game.fx
	var bottom := span_mid.y - 3.0
	var hv := jun.hands()
	var hands := hv.y
	if ph == "break":
		cs.v = float(cs.v) + 22.0 * dt
		_set_span(float(cs.dy) - float(cs.v) * dt)
		span.g.position.x = (randf() - .5) * .3
		if bottom + float(cs.dy) <= hands + .3 or float(cs.dy) < -12.0:
			cs.ph = "caught"
			cs.t = 0.0
			jun.brace()
			jun.hold(1.0, 2.0)
			act2.say("fall")
			fx.shake = maxf(fx.shake, 1.8)
			fx.sparks(hv, 40, 9.0, null, 0xffc060)
			audio.play_at("boomBig", hv)
			Game.hud.toast("HE CAUGHT IT  -  GO", 2.2)
	elif ph == "caught" or ph == "held":
		var target := clampf(hands + .3 - bottom, -12.0, 0.0)
		_set_span(float(cs.dy) + (target - float(cs.dy)) * minf(1.0, dt * 8.0))
		span.g.position.x = sin(float(cs.t) * 23.0) * .05
		if ph == "caught" and float(cs.t) > 1.4:
			cs.ph = "held"
		if ph == "held" and P != null:
			var at: Array = along(P.x, P.z)
			var past := float(at[0]) > C1 + 4.0 and float(at[1]) < 7.0
			var off := P.y < span_mid.y - 12.0
			cs.cross_t = float(cs.cross_t) + dt if past or off else 0.0
			if float(cs.cross_t) > 1.1:
				cs.ph = "drop"
				cs.v = 0.0
				jun.hold(0.0)
				for s: World.Solid in span.solids:
					s.set_off(true)
				audio.play_at("groan", span_mid)
	elif ph == "drop":
		cs.v = float(cs.v) + 22.0 * dt
		span.g.position.y -= float(cs.v) * dt
		if span_mid.y + span.g.position.y < 34.0:
			cs.ph = "gone"
			span.g.visible = false
			span.gone = true
			sets.boom(span_mid.x, 31.0, span_mid.z, 9.0, 0.0, {"harmless": true})
			jun.go("catch")


## the span is past (a checkpoint after the catch): gone, Juniper moving on
func _span_gone() -> void:
	cs.ph = "gone"
	span.g.visible = false
	span.gone = true
	for s: World.Solid in span.solids:
		s.set_off(true)


func _restore_all() -> void:
	for b in bridge:
		b.fall = 0.0
		b.v = 0.0
		b.at = 0.0
		b.g.visible = true
		b.g.position.y = 18.0
		b.g.rotation = Vector3.ZERO
		b.s.set_off(false)
		b.s.set_span(17.2, 18.0)
		for r: World.Solid in b.rails:
			r.set_off(false)
			r.set_span(18.0, 18.0 + OmRails.H)
	for p in plats:
		p.shake = 0.0
		p.fall = 0.0
		p.v = 0.0
		p.gone = false
		p.g.visible = true
		p.g.position = Vector3(p.x, p.top, p.pz)
		p.g.rotation = Vector3(0.0, -p.a + PI / 2.0, 0.0)
		p.s.set_off(false)
		p.s.set_span(p.top - .6, p.top)
	for pc in pieces:
		pc.gone = false
		pc.g.visible = true
		for s: World.Solid in pc.solids:
			s.set_off(false)
	_line_col(.43, 1.0, .72)
	for d in debris:
		_free_debris(d)
	debris.clear()
	if chase != null:
		chase.s.free_model()
		chase.T.dead = true
		chase.hb.drop()
		chase = null
	esc.surge = null
	esc.surge_t = 7.0
	MsKit.opa(surge_sprite, 0.0)
	esc.conduit = false
	esc.sphere_down = false
	esc.ring_cut = false
	esc.pulsed = false
	if marks != null:
		marks.reset_sphere()
	cs.ph = "idle"
	cs.t = 0.0
	cs.v = 0.0
	cs.cross_t = 0.0
	span.g.position = Vector3.ZERO
	_set_span(0.0)
	span.g.visible = true


## Juniper is free (the release): the bridge goes, he starts walking
func release() -> void:
	free_juniper()
	collapse_bridge()
	act2.door_s.lock(true)


## the escape stage proper: debris, the climb
func start() -> void:
	esc.on = true
	esc.t = 0.0


## the conduit run: surges and the chase gunship
func conduit() -> void:
	esc.conduit = true
	esc.surge_t = 6.0
	launch_chase()
	if jun.out.waiting != "catch" and cs.ph == "idle":
		jun.hurry(1.8)
	if not esc.pulsed:
		esc.pulsed = true
		sets.after(3.0, func() -> void:
			if marks != null:
				marks.pulse({"max": 600.0, "kick": 1.4}))


func reset(stage: String, obj: int, retry: bool) -> void:
	var late := stage == "escape"
	var live := late and act2.released and not retry
	esc.on = false
	if live:      # straight on from the release: the bridge is falling, he is walking
		return
	_restore_all()
	if late:
		for b in bridge:
			b.g.visible = false
			b.s.set_off(true)
			for r: World.Solid in b.rails:
				r.set_off(true)
		act2.door_s.lock(true)
		act2.smash_frame(true)
		act2.breach_west(true)
		if not jun.out.on:
			free_juniper()
		jun.skip_to("power" if obj >= 4 else "stand")      # where he would be by now
		if marks != null:
			marks.rip_lines(true)
		if obj >= 4:
			_span_gone()
	else:
		act2.door_s.lock(false)


func update(dt: float, P: Player, C: Combat) -> void:
	_update_escape(dt, P, C)
