class_name SpireLevel
extends ExportedLevel
## MEAT SPIRE (JS levels/spire/level.js + the logic of rooms.js): the spire is one giant living creature. Climb it, organ by organ, and kill the MAWMOTHER at the crown. This file holds the systems: checkpoints + safety net, zones with rules + arena locks, egg sacs, gazing eyes, secrets, atmosphere per room, HUD, and each room's own per-frame logic.
## The JS builds the climb from a seeded random sequence, so its numbers come through the export (level.json data: rooms, zones, eggs, eyes, secrets, glows, movers' specs, R.spec); nothing is laid out again here. Units are metres, Y up, the spire axis is x = z = 0.

const TOP_Y := 124.0
const ARENA_R := 26.0
const ROLE := {"warden": 0, "brute": 0, "carapace": 0, "mimic": 1, "follower": 1, "crawler": 1, "tongue": 2, "spore": 2, "worm": 2, "scream": 3, "prophet": 3}
const KICKS: Array[float] = [0.25, 0.6, 0.88, 1.08, 1.24, 1.36, 1.46, 1.53]
const LOCK_WALLS: Array[int] = [16, 20, 16]      # gastric, warden, garden: in build order

var mechs: SpireMechs
var boss: SpireBoss
var hud: SpireHud
var cine: SpireArenaIntro
var ambience: SpireAmbience
var gate_a := 0.0
var time_ := 0.0
var last_p: Player = null
var last_combat: Combat = null
var checkpoints_: Array = []
var cp_idx := 0
var zones: Array[Dictionary] = []
var eggs: Array[Dictionary] = []
var eyes: Array[Dictionary] = []
var secrets: Array[Dictionary] = []
var glows: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var ring_pool: Array[Dictionary] = []
var cp_views: Array[Dictionary] = []
var arena_zone: Dictionary = {}
var arena_pods: Array = []
var spec: Dictionary = {}
var _hooked := false
var _mats: Dictionary = {}
var _spawn_pending: Array = []
var _nest_hinted := false
var _heart_hinted := false
var _last_beat_n := -1
var _dummy: Node3D = null
# fog + light per room
var cur_room: Dictionary = {}
var _fog_c := Color.html("#2a0610")
var _sky_c := Color.html("#e0a0a8")
var _gnd_c := Color.html("#4a1020")
var _bg_c := Color.html("#12040a")
var _dens := 0.0105
var p_light: OmniLight3D
var pool_lights: Array[OmniLight3D] = []
var core_light: OmniLight3D
# rooms.js
var trunks: Array = []
var heart: SpireMechs.Breather
var heart_g: Node3D
var valves: Array = []
var waist: SpireMechs.Iris
var lid: SpireMechs.SliderM
var ge: Node3D
var socket_open := false
var split_done := false
var split_t := -1.0
var heart_zone: Dictionary = {}
var garden_lamp_m: Array = []
var bile_surface: Node3D
var bile_bubbles: Node3D
var bile_curtain: Node3D
var _bubbles: Array[Node3D] = []
var _bile_mat: ShaderMaterial = null
var _basin_a0 := 0.0
var _basin_span := 0.0
var _basin_inner := 0.0
var _basin_outer := 0.0
var _floor := 11.9
var _bile := {}
var _shelves: Array[Dictionary] = []
var _vent := Vector2.ZERO
var _bronchi: World.Solid
var _garden_dark := false
var _garden_room: Dictionary = {}
var _capglow_base: Array = []
var _flesh: SpireFlesh


func _keep_solid(d: Dictionary) -> bool:
	return (d.get("extra", {}) as Dictionary).get("id") != "mech"


func one(nm: String) -> Node3D:
	for n: Node3D in node_named(nm):
		return n
	push_warning("SPIRE: nothing exported as " + nm)
	if _dummy == null:
		_dummy = Node3D.new()
		add_child(_dummy)
	return _dummy


func _mat_list(nm: String) -> Array:
	return _mats.get(nm, [])


func solid_by_id(sid: String) -> World.Solid:
	for s: World.Solid in world.solids:
		var ex: Variant = s.data.get("extra")
		if ex is Dictionary and (ex as Dictionary).get("id") == sid:
			return s
	push_warning("SPIRE: no solid " + sid)
	return null


func event(e: Dictionary) -> void:
	if last_combat != null:
		last_combat.events.append(e)


func hurt_p(P: Player, amt: float, sx: float = NAN, sz: float = NAN, kind: String = "bolt") -> bool:
	if last_combat == null:
		return false
	return last_combat.hurt_player(P, amt, P.x if is_nan(sx) else sx, P.z if is_nan(sz) else sz, kind)


func sfx_at(id: String, x: float, y: float, z: float, o: Dictionary = {}) -> void:
	if Game.sfx != null:
		Game.sfx.play_at(id, x, y, z, o)


func toast(m: String) -> void:
	Game.hud.toast(m)


func banner(h: String, sub: String, secs: float) -> void:
	hud.banner(h, sub, secs)


func free_spot(x: float, z: float, y: float) -> bool:
	return not world.blocked(x, z, y, 2.05, 0.9, 0.42)


func refresh_pods() -> void:
	for p: Variant in arena_pods:
		p.cd = 0.0


## This node's materials of its own: the export folds identical materials together, and these change one by one (the JS gives each its own).
func own_mats(root: Node3D, prefix: String = "") -> Array:
	var out: Array = []
	var walk: Array[Node] = [root]
	while walk.size() > 0:
		var n: Node = walk.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if m != null and (prefix == "" or m.resource_name.contains(prefix)):
					var d := m.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(s, d)
					out.append(d)
		walk.append_array(n.get_children())
	return out


func set_alpha(list: Array, a: float) -> void:
	for m: StandardMaterial3D in list:
		m.albedo_color.a = a


func set_color(list: Array, c: Color, a: float) -> void:
	for m: StandardMaterial3D in list:
		m.albedo_color = Color(c.r, c.g, c.b, a)


# ---------------------------------------------------------------------------------------------- build
func build() -> void:
	super.build()
	var dat: Dictionary = info.data
	spec = dat.R.spec
	gate_a = dat.gateA
	checkpoints_ = dat.checkpoints
	world.spawn.merge({"x": 0.0, "y": 0.0, "z": -21.0, "yaw": 0.0}, true)
	world.pod_style = {"color": 0x5a1626, "band": 0xff9ab0}
	_collect_materials()
	_flesh = SpireFlesh.new(self)
	mechs = SpireMechs.new(self, event, sfx_at, func(P: Player, a: float, sx: float, sz: float, k: String) -> bool: return hurt_p(P, a, sx, sz, k))
	for r: Dictionary in dat.rooms:
		r["g"] = one(String(r.id))
		rooms.append(r)
		if r.id == "garden":
			_garden_room = r
	for z: Dictionary in dat.zones:
		z["robots"] = []
		zones.append(z)
		if z.get("name") == "arena":
			arena_zone = z
		elif z.get("rule") == "heart":
			heart_zone = z
	for g: Dictionary in dat.glows:
		glows.append(g)
	_bind_locks()
	_bind_rooms()
	var first := -1      # her centre is the first breather at the crown
	for i in mechs.movers.size():
		var m: SpireMechs.Mover = mechs.movers[i]
		if m is SpireMechs.Breather and float(m.o.y) == TOP_Y:
			first = i
			break
	boss = SpireBoss.new(self, first)
	cine = SpireArenaIntro.new(self)
	ambience = SpireAmbience.new()
	add_child(ambience)
	for i in (dat.eggs as Array).size():
		var e: Dictionary = dat.eggs[i]
		e["g"] = one("SpEgg%d" % i)
		e["shell"] = one("SpEggShell%d" % i)
		e["embryo"] = one("SpEggEmbryo%d" % i)
		e["embryo"].rotation_order = EULER_ORDER_XYZ
		e["state"] = "idle"
		e["st"] = 0.0
		e["t_"] = null
		e["kick"] = 0.0
		e["nk"] = randf_range(2.0, 6.0)
		e["kx"] = 0.0
		e["kz"] = 0.0
		e["kicks"] = 0
		eggs.append(e)
	for i in (dat.eyes as Array).size():
		var e: Dictionary = dat.eyes[i]
		e["g"] = one("SpEye%d" % i)
		e["ball"] = one("SpEyeBall%d" % i)
		e["pupil"] = one("SpEyePupil%d" % i)
		e["lid_u"] = one("SpEyeLidU%d" % i)
		e["lid_d"] = one("SpEyeLidD%d" % i)
		e["iris"] = own_mats(e["ball"], "spIris")
		for m: StandardMaterial3D in e["iris"]:
			m.emission_enabled = true
			m.emission_energy_multiplier = 1.0
		e["t_"] = null
		e["tgt"] = Vector3(e.x, e.y, float(e.z) + 1.0)
		eyes.append(e)
	for i in (dat.secrets as Array).size():
		var s: Dictionary = dat.secrets[i]
		s["g"] = one("SpSecret%d" % i)
		s["got"] = false
		secrets.append(s)
	for i in checkpoints_.size():
		cp_views.append({"orb": one("SpCpOrb%d" % i), "ring": one("SpCpRing%d" % i), "orb_m": own_mats(one("SpCpOrb%d" % i)), "ring_m": own_mats(one("SpCpRing%d" % i)), "on": -1})
	# floor hazards: wound rings that erupt (a pool of meshes)
	for _i in 8:
		ring_pool.append(_make_ring())
	hud = SpireHud.new(self)
	add_child(hud)
	p_light = OmniLight3D.new()
	p_light.light_color = Color.hex(0xff6a50ff)
	p_light.light_energy = 50.0 / PI
	p_light.omni_range = 38.0
	p_light.omni_attenuation = 1.4
	add_child(p_light)
	for _i in 2:
		var l := OmniLight3D.new()
		l.light_color = Color.hex(0xff7a8aff)
		l.light_energy = 0.0
		l.omni_range = 18.0
		l.omni_attenuation = 1.5
		add_child(l)
		pool_lights.append(l)
	core_light = OmniLight3D.new()
	core_light.light_color = Color.hex(0xff6a30ff)
	core_light.light_energy = 0.0
	core_light.omni_range = 26.0
	core_light.omni_attenuation = 1.5
	core_light.position = Vector3(0.0, TOP_Y + 9.0, 0.0)
	add_child(core_light)


func _collect_materials() -> void:
	var walk: Array[Node] = [self]
	while walk.size() > 0:
		var n: Node = walk.pop_back()
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			if m != null:
				for s in m.get_surface_count():
					var mt: Material = m.surface_get_material(s)
					if mt is StandardMaterial3D and mt.resource_name != "":
						var nm := mt.resource_name
						var cut := nm.rfind("_")
						if cut > 0 and nm.substr(cut + 1).is_valid_int():
							nm = nm.substr(0, cut)
						if nm.begins_with("obc_sp"):      # (a named material with a hook: obc_<name>_<hash>)
							nm = nm.get_slice("_", 1)
						if not _mats.has(nm):
							_mats[nm] = []
						if not (_mats[nm] as Array).has(mt):
							(_mats[nm] as Array).append(mt)
		walk.append_array(n.get_children())


## the walls of the three arena locks, in build order
func _bind_locks() -> void:
	var walls: Array = []
	for m: SpireMechs.Mover in mechs.movers:
		if m is SpireMechs.SliderM and m.o.get("lockWall", false):
			walls.append(m)
			var i := int(m.o.wallI)
			(m as SpireMechs.SliderM).vis = func(mm: SpireMechs.SliderM, t: float) -> void:      # rising: it swells as it grows; won: the dying flesh sags outward and shudders as it sinks
				var rising := mm.want > 0.5 and mm.u < 0.999
				var dying := mm.want < 0.5 and mm.u > 0.001
				var k := sin(mm.u * PI) if rising else 0.0
				var d := 1.0 - mm.u if dying else 0.0
				mm.body.scale = Vector3(1.0 + 0.03 * sin(t * 6.0 + i) + 0.12 * k, 1.0 - 0.15 * sin(d * PI), 1.0 + 0.25 * k)
				mm.body.rotation = Vector3(-0.35 * sin(d * PI) * 0.6 + (sin(t * 31.0 + i) * 0.04 if dying else 0.0), 0.0, sin(t * 23.0 + i * 2.0) * 0.05 if dying else 0.0)
	var n := 0
	var w0 := 0
	for z: Dictionary in zones:
		if not z.has("lock"):
			continue
		var L: Dictionary = z.lock
		L["walls"] = walls.slice(w0, w0 + LOCK_WALLS[n])
		w0 += LOCK_WALLS[n]
		n += 1
		L["state"] = "idle"
		L["t"] = 0.0
		L["wave"] = 0
		L["queue"] = null
		L["sp_t"] = null
		match String(z.name):
			"warden":
				z["on_clear"] = split
			"gardenlock":
				L["on_wave"] = func(w: int) -> void:
					if w == 1:
						_dark(true)
						toast("THE LAMPS DIE")
						sfx_at("meatSwell", z.x, float(z.y) + 3.0, z.z, {"range": 60.0})
				z["on_reset"] = func() -> void: _dark(false)
				z["on_clear"] = func() -> void: _dark(false)


## the lamps die in the garden: the fog thickens, every lamp goes out
func _dark(on: bool) -> void:
	_garden_dark = on


func _exhale(t: float) -> float:
	return maxf(0.0, SpireMechs.breath_at(t, 6.0))


func _bile_level(t: float) -> float:
	var per: float = _bile.per
	var low: float = _bile.low
	var high: float = _bile.high
	var m := fposmod(t, per)
	if m < 5.5:
		return low
	if m < 6.9:
		return lerpf(low, high, SpireMechs.sstep((m - 5.5) / 1.4))
	if m < 9.6:
		return high
	return lerpf(high, low, SpireMechs.sstep((m - 9.6) / 1.4))


func _bile_warn(t: float) -> float:
	var m := fposmod(t, float(_bile.per))
	return (m - 3.8) / 1.7 if (m > 3.8 and m < 5.5) else (1.0 if (m >= 5.5 and m < 9.6) else 0.0)


func _basin_inner_at(u: float) -> float:
	var k := clampf((u - 0.76) / 0.2, 0.0, 1.0)
	return _basin_inner + (14.5 - _basin_inner) * k * k * (3.0 - 2.0 * k)


func _basin_contains(x: float, z: float) -> bool:
	var u := fposmod(atan2(x, z) - _basin_a0, TAU) / _basin_span
	var r := U.hyp(x, z)
	return u >= 0.0 and u <= 1.0 and r > _basin_inner_at(u) and r < _basin_outer


## the per-room closures of rooms.js, on the movers the spec table built
func _bind_rooms() -> void:
	var eyelid := 0
	var eyelid_phase: Array[float] = [0.0, 2.1]
	for m: SpireMechs.Mover in mechs.movers:
		if m is SpireMechs.Trunk:
			trunks.append(m)
		elif m is SpireMechs.Iris:
			if m.o.get("shrink", false):
				(m as SpireMechs.Iris).gate = false      # valves stay shut-off (no collider) until the split
				valves.append(m)
				for p: Dictionary in (m as SpireMechs.Iris).petals:
					(p.s as World.Solid).no_cam = true
			elif int(m.o.get("k", 0)) == 14:
				waist = m
		elif m is SpireMechs.Breather and float(m.o.y) == 60.8:
			heart = m
		elif m is SpireMechs.SliderM and m.o.get("tag") == "greatlid":
			lid = m
		elif m is SpireMechs.SliderM and m.o.get("tag") == "eyelid":
			# eyelid shelves: lids that slide out of the body (stand on them), tremble, and slide back in
			var phase: float = eyelid_phase[eyelid]
			eyelid += 1
			var ph := func(t: float) -> float: return fposmod(t + phase, 6.4)
			(m as SpireMechs.SliderM).target = func(t: float) -> float:
				var m2: float = ph.call(t)
				return 0.0 if m2 < 3.8 else (SpireMechs.sstep((m2 - 3.8) / 0.45) if m2 < 4.25 else (1.0 if m2 < 5.95 else 1.0 - SpireMechs.sstep((m2 - 5.95) / 0.45)))
			(m as SpireMechs.SliderM).vis = func(mm: SpireMechs.SliderM, t: float) -> void:
				var m2: float = ph.call(t)
				var w := 1.0 if (m2 > 3.1 and m2 < 3.8) else 0.0
				mm.g.position.x += sin(t * 47.0) * 0.05 * w
				mm.g.position.z += cos(t * 41.0) * 0.05 * w
		elif m is SpireMechs.Custom and m.kind == "alveolus":
			pass
	heart.s.set_off(true)
	heart_g = one("SpHeartG")
	heart_g.visible = false
	solid_by_id("spF").set_off(true)
	solid_by_id("spS5").set_off(true)
	ge = one("SpGreatEye")
	ge.rotation_order = EULER_ORDER_XYZ
	# shelves on the trunks (they part with them, and dip + shake on every beat)
	for s: World.Solid in world.solids:
		var ex: Variant = s.data.get("extra")
		if ex is Dictionary and (ex as Dictionary).get("id") == "spShelf":
			var g := one("SpShelf_%d" % int(ex.shelfI))
			(trunks[int(ex.trunkK)] as SpireMechs.Trunk).attach(s, g, ex.along, ex.side)
			_shelves.append({"s": s, "g": g, "base": float(ex.baseY)})
	# alveoli: membrane sacs that swell on the exhale (wider, a little higher) and shrink on the inhale
	var alv: Array[World.Solid] = []
	for s: World.Solid in world.solids:
		if s.tag == "alveolus":
			alv.append(s)
	var ai := 0
	for m: SpireMechs.Mover in mechs.movers:
		if m is SpireMechs.Custom and m.kind == "alveolus":
			var s := alv[ai]
			ai += 1
			var ex: Dictionary = s.data.get("extra", {})
			var y: float = ex.baseY
			var r0: float = ex.r0
			var key := str(y).trim_suffix(".0")
			var g := one("SpAlv_" + key)
			var sac := one("SpAlvSac_" + key)
			m.solids = [s]
			(m as SpireMechs.Custom).fn = func(t: float, _dt: float, _P: Player) -> void:
				var e := _exhale(t)
				var r := r0 + 0.9 * e
				s.r = r
				s.hx = r
				s.hz = r
				var top := y + 0.35 * e
				s.bottom = top - 1.0
				s.top = top
				world._rebuild_shape(s)
				g.position.y = top
				sac.scale = Vector3(r * 1.03, 0.35, r * 1.03)
	# forces
	_basin_a0 = spec.aS
	_basin_span = spec.SPAN
	_basin_inner = spec.R_IN
	_basin_outer = spec.R_OUT
	_floor = spec.FLOOR
	_bile = spec.BILE
	mechs.pool(_floor - 2.0, 18.0, _basin_contains, _bile_level, 9.0, 0.55)
	_vent = Vector2(spec.vent.x, spec.vent.z)
	mechs.updraft(_vent.x, _vent.y, 1.75, 80.8, 87.6, func(t: float) -> float: return 1.0 if _exhale(t) > 0.15 else 0.0, 7.0)
	_bronchi = solid_by_id("spBronchi")
	mechs.wind(85.0, 91.0, func(x: float, y: float, z: float) -> bool: return y > 86.4 and y < 90.0 and _bronchi.top_at(x, z) != null,
		func(t: float) -> Vector2:
			var e := SpireMechs.breath_at(t, 6.0)
			var l := U.hyp(_bronchi.cx, _bronchi.cz)
			if l == 0.0:
				l = 1.0
			var k := 1.7 * e if e > 0.0 else 0.9 * e
			return Vector2(_bronchi.cx / l * k, _bronchi.cz / l * k))
	bile_surface = one("bile-liquid")
	bile_bubbles = one("bile-bubbles")
	bile_curtain = one("bile-curtain")
	for i in 30:
		_bubbles.append(one("SpBubble%d" % i))


## the split (set piece): the trunks part, the heart is revealed, the spiral reverses
func split() -> void:
	if split_done:
		return
	split_done = true
	heart_g.visible = true
	solid_by_id("spF").set_off(false)
	heart.s.set_off(false)
	solid_by_id("spS5").set_off(false)
	for tr: SpireMechs.Trunk in trunks:
		tr.want = 1.0
	for v: SpireMechs.Iris in valves:
		v.gate = true
	heart_zone["spawned"] = false
	toast("THE SPIRE SPLITS OPEN")
	event({"t": &"meatBoom", "id": -1, "x": 0.0, "y": 58.0, "z": 0.0, "r": 6.0, "big": true})
	sfx_at("meatBoom", 0.0, 58.0, 0.0, {"range": 160.0})
	split_t = 0.0


func _room_updaters(dt: float, P: Player, C: Combat, t: float) -> void:
	# the shelves dip + shake on every beat
	var b := SpireMechs.beat_at(t)
	for sh: Dictionary in _shelves:
		var s: World.Solid = sh.s
		var top: float = float(sh.base) - 0.05 * b
		s.set_span(top - 1.0, top)
		(sh.g as Node3D).position.y = top
	if split_t >= 0.0 and split_t <= 5.0:
		split_t += 1.0 / 60.0
		if randf() < 0.1:
			event({"t": &"summon", "x": randf_range(-6.0, 6.0), "y": randf_range(54.0, 64.0), "z": randf_range(-6.0, 6.0)})
	# the bile: drained most of the time, then it rises (bubbles first), stays high, drains again
	var lv := _bile_level(t)
	var on := lv > _floor - 0.2
	bile_surface.visible = on
	bile_bubbles.visible = on
	if on:
		bile_surface.position.y = lv
		bile_bubbles.position.y = lv
	var depth := lv - _floor
	bile_curtain.visible = on and depth > 0.05
	if bile_curtain.visible:
		bile_curtain.position.y = _floor
		bile_curtain.scale.y = maxf(0.001, depth)
	var warn := _bile_warn(t)
	_flesh.set_bile(t, warn)
	if on:
		for bi in _bubbles.size():
			var bn: Node3D = _bubbles[bi]
			var phase := fmod(t * (0.7 + warn * 0.9) + bi * 0.713, 1.0)
			var sz := (0.09 + (bi % 4) * 0.045) * sin(PI * phase)
			bn.visible = phase < 0.92
			bn.position.y = -0.08 + phase * 0.25
			bn.scale = Vector3(sz, sz * (1.0 - phase * 0.5), sz)
	# stand on the brow and the lid lifts; the eye rolls back into the head (set piece)
	var a_sock: float = spec.aSock
	var rw: float = spec.RW
	var sb: Dictionary = spec.SB
	if not socket_open and P != null and not P.dead and U.hyp(P.x - float(sb.x), P.z - float(sb.z)) < float(sb.r) + 0.5 and absf(P.y - float(sb.y)) < 1.0:
		socket_open = true
		lid.want = 1.0
		toast("THE SOCKET OPENS")
		sfx_at("meatSwell", sb.x, 74.0, sb.z, {"range": 80.0})
		event({"t": &"screamCall", "id": -1, "x": ge.position.x, "y": 74.0, "z": ge.position.z})
	var k := SpireMechs.sstep(lid.u)
	ge.position = Vector3(sin(a_sock) * (rw - 0.2 - k * 2.4), 73.5 - k * 0.6, cos(a_sock) * (rw - 0.2 - k * 2.4))
	ge.rotation.x = -k * 1.4
	ge.scale = Vector3.ONE * (1.0 - 0.35 * k)
	# the lung's sprays
	_flesh.set_points_opacity("updraft", 0.12 + 0.7 * (1.0 if _exhale(t) > 0.15 else 0.0))
	_flesh.set_points_opacity("gust", 0.6 * absf(SpireMechs.breath_at(t, 6.0)))
	# the waist squeezes the throat skin
	var skin := node_named("Throat skin")
	if not skin.is_empty():
		var w := 1.0 - 0.07 * (1.0 - waist.u) + 0.02 * waist.warn * sin(t * 30.0)
		(skin[0] as Node3D).scale = Vector3(w, 1.0, w)
	# the lung's breath pushes floating spore sacs about
	var e := SpireMechs.breath_at(t, 6.0)
	for r: Robot in C.enemies.robots:
		if r.get("floater") == true and not r.dead and r.y > 78.0 and r.y < 92.0:
			var l := U.hyp(r.x, r.z)
			if l == 0.0:
				l = 1.0
			r.kvx += r.x / l * e * 1.6 * dt
			r.kvz += r.z / l * e * 1.6 * dt


# ---------------------------------------------------------------------------------------------- floor hazards: wound rings that erupt
func _make_ring() -> Dictionary:
	var g := Node3D.new()
	g.visible = false
	add_child(g)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.125, 0.19, 0.9)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.disable_fog = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1.0, 0.125, 0.19, 0.25)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.07
	tm.rings = 36
	tm.ring_segments = 6
	var t := MeshInstance3D.new()
	t.mesh = tm
	t.material_override = rm
	g.add_child(t)
	var dc := CylinderMesh.new()
	dc.top_radius = 0.92
	dc.bottom_radius = 0.92
	dc.height = 0.001
	dc.radial_segments = 28
	dc.rings = 1
	var d := MeshInstance3D.new()
	d.mesh = dc
	d.material_override = dm
	g.add_child(d)
	return {"g": g, "rm": rm, "dm": dm, "used": false}


## schedule a rupture at (x, z) on floor y
func hazard(x: float, z: float, y: float, o: Dictionary = {}) -> Dictionary:
	var slot: Dictionary = {}
	for s: Dictionary in ring_pool:
		if not s.used:
			slot = s
			break
	if slot.is_empty():
		return {}
	slot.used = true
	(slot.g as Node3D).visible = true
	var h := {"x": x, "z": z, "y": y, "t": 0.0, "r": o.get("r", 1.9), "lead": o.get("lead", 1.3), "dmg": o.get("dmg", 14.0), "track": o.get("track", false), "zone": o.get("zone"), "fired": false, "fire_t": 0.0, "slot": slot}
	hazards.append(h)
	sfx_at("mindWind", x, y, z, {"dur": h.lead, "range": 40.0})
	return h


func _clear_hazards(zone: Variant = null) -> void:
	for h: Dictionary in hazards.duplicate():
		if zone == null or h.zone == zone:
			_drop_hazard(h)


func _drop_hazard(h: Dictionary) -> void:
	h.slot.used = false
	(h.slot.g as Node3D).visible = false
	hazards.erase(h)


func _hazards_step(dt: float, P: Player, C: Combat) -> void:
	for h: Dictionary in hazards.duplicate():
		h.t = float(h.t) + dt
		var ht: float = h.t
		var lead: float = h.lead
		var lock := lead * 0.55
		var locked := ht >= lock
		if h.track and not locked and P != null and not P.dead:
			var k := minf(1.0, dt * 7.0)
			h.x = float(h.x) + (P.x - float(h.x)) * k
			h.z = float(h.z) + (P.z - float(h.z)) * k
			if h.zone != null:
				var dx := float(h.x) - float(h.zone.x)
				var dz := float(h.z) - float(h.zone.z)
				var d := U.hyp(dx, dz)
				var m := float(h.zone.leash) - 0.8
				if d > m:
					h.x = float(h.zone.x) + dx / d * m
					h.z = float(h.zone.z) + dz / d * m
		var hx: float = h.x
		var hy: float = h.y
		var hz: float = h.z
		var hr: float = h.r
		var g: Node3D = h.slot.g
		var rm: StandardMaterial3D = h.slot.rm
		var dm: StandardMaterial3D = h.slot.dm
		g.position = Vector3(hx, hy + 0.07, hz)
		if not h.fired:
			var u := clampf(ht / lead, 0.0, 1.0)
			var sc := hr * (1.18 - 0.18 * (ht - lock) / (lead - lock)) if locked else hr * 1.18
			var pulse := 1.0 + 0.06 * sin(time_ * 40.0) if locked else 1.0
			g.scale = Vector3(sc * pulse, 1.0, sc * pulse)
			rm.albedo_color = Color(Color(0.45 + 0.55 * u, 0.05 + 0.1 * (1.0 - u), 0.08).linear_to_srgb(), 0.95 if locked else 0.55)
			dm.albedo_color.a = 0.18 + 0.3 * u if locked else 0.08
			if ht >= lead:      # RUPTURE
				h.fired = true
				h.fire_t = 0.0
				event({"t": &"wormSlam", "x": hx, "y": hy, "z": hz, "r": hr})
				event({"t": &"boltHit", "x": hx, "y": hy + 0.3, "z": hz, "kind": "world", "bk": "bile", "nx": 0.0, "ny": 1.0, "nz": 0.0})
				sfx_at("meatSwell", hx, hy, hz, {"range": 50.0})
				if C != null:
					for i in 4:
						var a := i * TAU / 4.0 + randf_range(-0.3, 0.3)
						var s := 0.22 + randf() * 0.12
						C.enemies.fire_from(-7, hx, hy + 0.4, hz, sin(a) * s, 1.0, cos(a) * s, {"kind": "bile", "speed": 9.0 + randf() * 3.0, "dmg": 4.0, "r": 0.3})
				if P != null and not P.dead and U.hyp(P.x - hx, P.z - hz) < hr + 0.3 and P.y > hy - 0.6 and P.y < hy + 2.2 and hurt_p(P, h.dmg, hx, hz, "bolt"):
					P.vy = maxf(P.vy, 7.5)
					P.grounded = false
					P.mode = &"normal"
					P.ledge = null
					P.slow_t = maxf(P.slow_t, 0.8)
					P.slow_mul = minf(P.slow_mul if P.slow_mul != 0.0 else 1.0, 0.6)
					var l := U.hyp(P.x - hx, P.z - hz)
					if l == 0.0:
						l = 1.0
					P.ix += (P.x - hx) / l * 4.0
					P.iz += (P.z - hz) / l * 4.0
		else:      # the flash after the rupture
			h.fire_t = float(h.fire_t) + dt
			var k := clampf(float(h.fire_t) / 0.35, 0.0, 1.0)
			g.scale = Vector3(hr * (1.0 + 0.6 * k), 1.0, hr * (1.0 + 0.6 * k))
			rm.albedo_color = Color(Color(1.0, 0.9 - 0.6 * k, 0.5 - 0.4 * k).linear_to_srgb(), 0.9 * (1.0 - k))
			dm.albedo_color.a = 0.4 * (1.0 - k)
			if k >= 1.0:
				_drop_hazard(h)


# ---------------------------------------------------------------------------------------------- atmosphere: per-room fog + light
func _room_at(y: float) -> Dictionary:
	var room: Dictionary = rooms[0]
	for r: Dictionary in rooms:
		if r.has("fog") and y >= float(r.y0) and y < float(r.y1):
			room = r
	return room


func _atmosphere(dt: float, P: Player) -> void:
	var y := P.y if P != null else 0.0
	var r := _room_at(y)
	if r != cur_room:
		if not cur_room.is_empty() and r.has("title"):
			hud.room_card(r)
		cur_room = r
	var k := 1.0 - exp(-dt * 1.4)
	var dark := _garden_dark and r == _garden_room
	var dens: float = 0.085 if dark else float(r.dens)
	_fog_c = _fog_c.lerp(Color.hex((int(r.fog) << 8) | 0xff), k)
	_dens = lerpf(_dens, dens, k)
	Game.view.set_fog_exp2(_fog_c, _dens)
	_bg_c = _bg_c.lerp(Color.hex((int(r.get("bg", r.fog)) << 8) | 0xff), k)
	Game.view.set_background(_bg_c)
	_sky_c = _sky_c.lerp(Color.hex((int(r.sky) << 8) | 0xff), k)
	_gnd_c = _gnd_c.lerp(Color.hex((int(r.ground) << 8) | 0xff), k)
	# blood grade: rooms keep their own hue, but pink/magenta light loses its blue so it reads as dark wet red, not candy pink
	var sky := _sky_c.srgb_to_linear()
	sky.b = minf(sky.b, sky.g * 0.85)
	Game.view.set_hemi((sky * 0.88).linear_to_srgb(), _gnd_c, 0.8)
	if P != null:
		p_light.position = Vector3(P.x, P.y + 4.0, P.z)
		if r.has("light"):      # the carried light: deep red, not salmon
			var c := Color.hex(((0x3a7a50 if dark else int(r.light)) << 8) | 0xff).srgb_to_linear()
			c.g *= 0.72
			c.b = minf(c.b, c.g) * 0.75
			p_light.light_color = p_light.light_color.lerp(c.linear_to_srgb(), k)
		# the two nearest glow sources get the pooled lights
		var a: Variant = null
		var b: Variant = null
		var da := 1e9
		var db := 1e9
		for gl: Dictionary in glows:
			var gx: float = gl.x
			var gy: float = gl.y
			var gz: float = gl.z
			var d := Vector3(gx - P.x, (gy - P.y) * 1.4, gz - P.z).length()
			if d > float(gl.range) + 10.0:
				continue
			if d < da:
				b = a
				db = da
				a = gl
				da = d
			elif d < db:
				b = gl
				db = d
		for i in 2:
			var gl: Variant = a if i == 0 else b
			var l := pool_lights[i]
			if gl == null:
				l.light_energy = maxf(0.0, l.light_energy - dt * 200.0 / PI)
				continue
			l.position = Vector3(gl.x, gl.y, gl.z)
			l.light_color = Color(gl.color[0], gl.color[1], gl.color[2]).linear_to_srgb()
			l.omni_range = gl.range
			var inten: float = gl.i
			if dark and int(gl.get("i", 0)) == 26:
				inten = 3.0
			l.light_energy = inten * 0.65 * (0.75 + 0.25 * sin(time_ * 7.0 + float(gl.x)) if gl.get("flick", false) else 1.0) / PI
	core_light.light_energy = boss.core_glow * 140.0 / PI
	for rm: Dictionary in rooms:
		(rm.g as Node3D).visible = P == null or (float(rm.y1) > y - 46.0 and float(rm.y0) < y + 52.0)


# ---------------------------------------------------------------------------------------------- runtime systems
func _hook(C: Combat) -> void:
	_hooked = true
	boss.hook(C)
	var base: Callable = C.enemies.spawn_hook
	C.enemies.spawn_hook = func(pt: Dictionary, o: Dictionary) -> Variant:      # the MawNest's called-in reinforcements are meat followers here, not metal robots
		var q := o
		if o.get("kind") == "robot":
			q = o.duplicate()
			q["kind"] = "follower"
		return base.call(pt, q) if base.is_valid() else Game.spawn_enemy(pt, q)
	for i in eggs.size():
		var e: Dictionary = eggs[i]
		var tg := Target.new(9500 + i, e.x, e.z, e.y, {"r": 0.6, "h": 1.6, "max": 22.0, "hp": 22.0})
		tg.respawn_t = 1e9
		e["t_"] = tg
		C.targets.append(tg)
	for e: Dictionary in eyes:
		var sz: float = e.size
		var tg := Target.new(int(e.id), e.x, e.z, float(e.y) - sz, {"r": sz * 0.9, "h": sz * 2.0, "max": 1e6, "hp": 1e6})
		tg.respawn_t = 1e9
		e["t_"] = tg
		C.targets.append(tg)


func _spawn_unit(z: Dictionary, u: Dictionary, n: int) -> Robot:
	var zx: float = z.x
	var zz: float = z.z
	var leash: float = z.leash
	var kind: String = u.kind
	for t in 14:
		var px: float
		var pz: float
		var py: float = u.get("y", z.y)
		if u.has("x"):
			px = u.x
			pz = u.z
		elif u.has("ox"):
			px = zx + float(u.ox) + (randf_range(-1.5, 1.5) if t != 0 else 0.0)
			pz = zz + float(u.oz) + (randf_range(-1.5, 1.5) if t != 0 else 0.0)
		elif u.get("at") == 0:
			px = zx
			pz = zz
		else:
			var b: float = z.get("face", atan2(-zx, -zz))
			var a := b + (-1.0 if n % 2 != 0 else 1.0) * (0.5 + 0.45 * floori(n / 2.0)) + randf_range(-0.2, 0.2) + t * 0.5
			var d := minf(3.6, leash * 0.6)
			px = zx + sin(a) * d
			pz = zz + cos(a) * d
		var air := kind == "spore" or kind == "crawler" or kind == "tongue" or u.has("x")
		if not air and (U.hyp(px - zx, pz - zz) > leash - 0.4 or not free_spot(px, pz, py)):
			continue
		var rb := Game.spawn_enemy({"x": px, "y": py, "z": pz, "yaw": u.get("yaw", atan2(-px, -pz))}, {"kind": kind})
		if rb == null:
			return null
		rb.zone = z
		rb.respawn_t = 1e9
		var props: Variant = u.get("props")
		if props is Dictionary:
			for k: String in props:
				var key := "no_wall" if k == "noWall" else k
				var v: Variant = props[k]
				if v is Dictionary and key == "cling":
					v = v.duplicate()
					v["r"] = v.get("R", 0.0)
				rb.set(key, v)
		if rb.has_method(&"setup"):
			rb.call(&"setup")
		if kind == "spore" or kind == "crawler" or kind == "tongue" or u.get("noLeash", false):
			rb.no_leash = true
		(z.robots as Array).append(rb)
		return rb
	return null


func _nearest_zone(x: float, y: float, z: float) -> Variant:
	var best: Variant = null
	var bd := 1e9
	for q: Dictionary in zones:
		if absf(y - float(q.y)) > 6.0:
			continue
		var d := U.hyp(x - float(q.x), z - float(q.z))
		if d < float(q.leash) + 4.0 and d < bd:
			bd = d
			best = q
	return best


func _housekeeping(P: Player, C: Combat) -> void:
	for z: Dictionary in zones:
		if not z.spawned and not z.has("lock") and not P.dead and not (z == heart_zone and not _trunks_ready()) and U.hyp(P.x - float(z.x), P.z - float(z.z)) < float(z.trig) and absf(P.y - float(z.y)) < float(z.dy):
			z.spawned = true
			var units: Array = z.units
			for i in units.size():
				_spawn_pending.append([z, units[i], i])
	if not _spawn_pending.is_empty():      # open encounters spawn one unit per frame (a creature view is built on its own frame: no hitch)
		var q: Array = _spawn_pending.pop_front()
		_spawn_unit(q[0], q[1], q[2])
	for r: Robot in C.enemies.robots.duplicate():
		if r.dead:
			r.respawn_t = 1e9
			if r.dead_t > (r.corpse_t if r.corpse_t != 0.0 else 5.5):
				Game.despawn_enemy(r)
			continue
		if r.zone == null:
			r.zone = r.owner.zone if (r.owner != null and r.owner.zone != null) else _nearest_zone(r.x, r.y, r.z)
		var z: Variant = r.zone
		if z != null and not r.no_leash:
			var dx: float = r.x - float(z.x)
			var dz: float = r.z - float(z.z)
			var d := U.hyp(dx, dz)
			var leash: float = z.leash
			if d > leash:
				r.x = float(z.x) + dx / d * leash
				r.z = float(z.z) + dz / d * leash
		if not r.no_leash and (r.y < (float(z.y) if z != null else 0.0) - 7.0 or r.y < -20.0):
			r.hp = 0.0
			Game.despawn_enemy(r)
		# THE NEST CALLS, THE SPIRE ANSWERS: when a Maw Nest screams, two meat followers burst out of the flesh beside it (twice per nest, at most four of its kin alive)
		if r.get("scream") == true:
			if z != null and r.state == &"attack" and r.atk == &"call" and not r.get_meta("answered", false):
				r.set_meta("answered", true)
				var calls: int = int(r.get_meta("calls", 0)) + 1
				r.set_meta("calls", calls)
				if calls <= 2:
					var kin := 0
					for q: Robot in C.enemies.robots:
						if q.owner == r and not q.dead:
							kin += 1
					var n := mini(2, 4 - kin)
					for i in n:
						var a := r.yaw + (1.0 if i != 0 else -1.0) * 1.4 + randf_range(-0.3, 0.3)
						var rb := _spawn_unit(z, {"kind": "follower", "ox": r.x - float(z.x) + sin(a) * 1.8, "oz": r.z - float(z.z) + cos(a) * 1.8, "y": r.y}, i)
						if rb != null:
							rb.owner = r
							event({"t": &"summon", "x": rb.x, "y": rb.y + 0.3, "z": rb.z})
					if not _nest_hinted and n > 0:
						_nest_hinted = true
						toast("THE NEST CALLS. KILL IT BEFORE IT CALLS AGAIN")
			elif r.get_meta("answered", false) and r.state != &"attack":
				r.set_meta("answered", false)
	# THE HEART: every fourth beat is a systole that shakes the whole chamber. A Gristle Brute's carapace is cracked open by it (a window on its soft back from any side), and the small fry are knocked off their feet. Readable: the shelves dip on every beat; the big one booms.
	var beat_n := floori(time_ / 1.15)
	if beat_n != _last_beat_n:
		_last_beat_n = beat_n
		if beat_n % 4 == 0 and not heart_zone.is_empty():
			var hz := heart_zone
			var any := false
			for r: Robot in C.enemies.robots:
				if r.dead or r.zone != hz or absf(r.y - float(hz.y)) > 14.0:
					continue
				if r.get("brute") == true:
					r.set("exposed_t", maxf(float(r.get("exposed_t")), 1.6))
					event({"t": &"ringHit", "x": r.x, "y": r.y + 1.5, "z": r.z})
					any = true
				elif r.follower and r.get("floater") != true and r.state != &"dead" and r.state != &"stagger":
					r.hit_heavy = true
					r.poise = 0.0
					r.slot = &""
					r.set_(&"stagger")
					any = true
			if any:
				sfx_at("meatBoom", 0.0, float(hz.y) + 4.0, 0.0, {"range": 60.0})
				if not _heart_hinted:
					_heart_hinted = true
					toast("THE BEAT CRACKS ITS SHELL OPEN. STRIKE ON THE BOOM")


func _trunks_ready() -> bool:
	for tr: SpireMechs.Trunk in trunks:
		if tr.u <= 0.85:
			return false
	return true


# ---- arena locks: walls rise, waves spawn one after another, walls fall
func _encounter_reward(z: Dictionary, P: Player, C: Combat) -> void:
	if z.get("rewarded", false):
		return
	z["rewarded"] = true
	var health := minf(25.0, P.max_hp - P.hp)
	P.hp += health
	for i in Weapons.WEAPONS.size():
		var w: Variant = Weapons.WEAPONS[i]
		if not C.owned.has(i) or w.get("energy") == true:
			continue
		C.ammo[i] = minf(float(w.mag_size), C.ammo[i] + ceilf(w.mag_size * 0.35))
		C.reserve[i] = minf(float(w.max - w.mag_size), C.reserve[i] + ceilf((w.max - w.mag_size) * 0.35))
	toast("ENCOUNTER CLEARED · RECOVERED HEALTH + AMMO")
	event({"t": &"encounterReward", "x": z.x, "y": float(z.y) + 1.0, "z": z.z, "health": health})


## Waves arrive one unit at a time in a readable order: the tank first, then melee, then the ranged / summoner threats you should prioritise, 0.55 s apart, each with a burst of flesh where it appears. 0.8 s before a wave, the floor bulges.
func _queue_wave(L: Dictionary, units: Array) -> void:
	var q: Array = []
	for i in units.size():
		q.append({"u": units[i], "i": i})
	q.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = ROLE.get(a.u.kind, 2)
		var rb: int = ROLE.get(b.u.kind, 2)
		return ra < rb or (ra == rb and int(a.i) < int(b.i)))
	L.queue = q
	L["q_t"] = 0.0
	L["cued"] = false


func _feed_wave(z: Dictionary, L: Dictionary, dt: float) -> void:
	L.q_t = float(L.q_t) - dt
	while L.queue != null and not (L.queue as Array).is_empty() and float(L.q_t) <= 0.0:
		var q: Dictionary = (L.queue as Array).pop_front()
		var rb := _spawn_unit(z, q.u, q.i)
		L.q_t = 0.55
		if rb != null:
			event({"t": &"summon", "x": rb.x, "y": rb.y + 0.3, "z": rb.z})


func _set_walls(L: Dictionary, v: float) -> void:
	for w: SpireMechs.SliderM in L.walls:
		w.want = v


func _locks(dt: float, P: Player, C: Combat) -> void:
	for z: Dictionary in zones:
		if not z.has("lock"):
			continue
		var L: Dictionary = z.lock
		L.t = float(L.t) + dt
		var lt: float = L.t
		var state: String = L.state
		var zx: float = z.x
		var zy: float = z.y
		var zz: float = z.z
		if P.dead and state != "idle" and state != "done":
			L.state = "idle"
			L.queue = null
			L.sp_t = null
			_clear_hazards(z)
			_set_walls(L, 0.0)
			for r: Robot in C.enemies.robots.duplicate():
				if r.zone == z:
					Game.despawn_enemy(r)
			(z.robots as Array).clear()
			L.wave = 0
			if z.has("on_reset"):
				(z.on_reset as Callable).call()
			continue
		if state == "idle":
			if not P.dead and U.hyp(P.x - zx, P.z - zz) < float(z.leash) - float(L.get("inset", 2.2)) and absf(P.y - zy) < 2.5:
				L.state = "closing"
				L.t = 0.0
				_set_walls(L, 1.0)
				toast(String(L.get("closeText", "THE FLESH CLOSES IN")))
				event({"t": &"screamCall", "id": -1, "x": zx, "y": zy + 2.0, "z": zz})
				L.wave = 0
				if L.has("title"):
					banner(L.title, String(L.get("closeText", "")), 2.6)
		elif state == "closing":
			if lt > 1.1:
				L.state = "fight"
				L.t = 0.0
				(z.robots as Array).clear()
				z.spawned = true
				_queue_wave(L, L.waves[0])
				L.sp_t = null
				if L.has("on_wave"):
					(L.on_wave as Callable).call(0)
		elif state == "fight":
			_feed_wave(z, L, dt)
			# SPASM waves: from wave fromWave the floor ruptures every every s (the first first s in): n wound rings, one hunting you, the rest where the flesh twitches
			if L.has("spasm") and int(L.wave) >= int(L.spasm.fromWave):
				var sp: Dictionary = L.spasm
				L.sp_t = (-float(sp.first) if L.sp_t == null else float(L.sp_t)) + dt
				if float(L.sp_t) >= 0.0:
					L.sp_t = float(L.sp_t) - float(sp.every)
					for i in int(sp.n):
						var px := P.x
						var pz := P.z
						if i != 0:
							for _t in 10:
								var a := randf() * TAU
								var d := randf_range(1.5, float(z.leash) - 1.2)
								px = zx + sin(a) * d
								pz = zz + cos(a) * d
								if absf(world.ground_height(px, pz, 0.3, zy + 1.0) - zy) < 0.3 and U.hyp(px - P.x, pz - P.z) > 2.5:
									break
						hazard(px, pz, zy, {"r": sp.get("r", 1.9), "lead": sp.get("lead", 1.4), "dmg": sp.get("dmg", 14.0), "track": i == 0, "zone": z})
					sfx_at("meatSwell", zx, zy, zz, {"range": 40.0})
			var rem: Array[Robot] = []
			var has_boss := false
			var hp_sum := 0.0
			for r: Robot in C.enemies.robots:
				if not r.dead and r.zone == z:
					rem.append(r)
					hp_sum += r.hp
					if r.get("boss_bar") != null and r.get("boss_bar") != "":
						has_boss = true
			var alive := rem.size()
			# failsafe: a straggler that is stuck, unreachable or simply ignored can never strand the player in a sealed arena (bosses are exempt)
			if lt < 1.5 or alive > 2 or has_boss or hp_sum < float(L.get("hp_sum", 1e9)) - 0.01:
				L["idle_t"] = 0.0
			else:
				L["idle_t"] = float(L.get("idle_t", 0.0)) + dt
			L["hp_sum"] = hp_sum
			var idle_t: float = L.idle_t
			if alive > 0 and idle_t > 40.0:
				for r: Robot in rem:
					if not r.get_meta("relocated", false) and not r.no_leash and not r.wretch:
						r.set_meta("relocated", true)
						r.x = zx + randf_range(-2.0, 2.0)
						r.z = zz + randf_range(-2.0, 2.0)
						r.y = zy + (1.5 if r.get("floater") == true else 0.2)
						toast("A STRAGGLER IS DRAGGED OUT")
			if alive > 0 and idle_t > 90.0:
				for r: Robot in rem:
					r.hp = 0.0
					Game.despawn_enemy(r)
				toast("THE FLESH LETS GO OF THE LAST ONE")
			if alive == 0 and lt > 1.0 and not (L.queue != null and not (L.queue as Array).is_empty()):
				L.wave = int(L.wave) + 1
				L.sp_t = null
				_clear_hazards(z)
				var waves: Array = L.waves
				if int(L.wave) < waves.size():
					L.state = "between"
					L.t = 0.0
					toast(String(L.get("waveText", "MORE OF IT")))
					var hints: Array = L.get("hints", [])
					banner("WAVE %d / %d" % [int(L.wave) + 1, waves.size()], String(hints[int(L.wave)]) if int(L.wave) < hints.size() else "", 2.4)
					if L.has("on_wave"):
						(L.on_wave as Callable).call(L.wave)
				else:
					L.state = "done"
					_set_walls(L, 0.0)
					toast(String(L.get("openText", "THE FLESH RELENTS")))
					if z.has("on_clear"):
						(z.on_clear as Callable).call()
					_encounter_reward(z, P, C)
					sfx_at("meatSwell", zx, zy + 1.0, zz, {"range": 45.0})
					var walls: Array = L.walls
					for i in walls.size():      # the walls die: they sag, shudder and sink
						if i % 4 == 0:
							event({"t": &"summon", "x": walls[i].s.cx, "y": zy + 0.5, "z": walls[i].s.cz})
		elif state == "between":
			var rest := float(L.get("rest", 2.6))
			if not L.get("cued", false) and lt > rest - 0.8:
				L["cued"] = true
				event({"t": &"summon", "x": zx, "y": zy + 0.2, "z": zz})
				sfx_at("meatSwell", zx, zy, zz, {"range": 35.0})
			if lt > rest:
				L.state = "fight"
				L.t = 0.0
				(z.robots as Array).clear()
				_queue_wave(L, L.waves[int(L.wave)])


func _checkpoints_step(P: Player, C: Combat) -> void:
	if P.dead:
		return
	for i in range(1, checkpoints_.size()):
		if i == cp_idx:
			continue
		var c: Dictionary = checkpoints_[i]
		if U.hyp(P.x - float(c.x), P.z - float(c.z)) < 2.1 and absf(P.y - float(c.y)) < 2.2 and (i > cp_idx or float(c.y) >= float(checkpoints_[cp_idx].y) - 0.5):
			cp_idx = i
			world.spawn.merge({"x": c.x, "y": c.y, "z": c.z, "yaw": c.get("yaw", 0.0)}, true)
			toast("CHECKPOINT")
	if cp_idx > 0 and boss.mode != "fight" and boss.mode != "intro":
		var c: Dictionary = checkpoints_[cp_idx]
		if P.y < float(c.y) - 7.0 and (P.grounded or P.vy < -14.0):
			C.hurt_player(P, 8.0, P.x, P.z, "shock")
			if not P.dead:
				_teleport_to(P, c)
				P.invuln = maxf(P.invuln, 1.5)
				toast("THE SPIRE SPITS YOU BACK")
	if not P.dead and cp_idx == 0 and P.y < -2.0:
		_teleport_to(P, checkpoints_[0])


func _teleport_to(P: Player, c: Dictionary) -> void:
	P.x = c.x
	P.y = c.y
	P.z = c.z
	P.vx = 0.0
	P.vz = 0.0
	P.vy = 0.0
	P.ix = 0.0
	P.iz = 0.0
	P.grounded = true
	P.mode = &"normal"
	P.ledge = null
	P.yaw = c.get("yaw", 0.0)
	P.mode_t = 0.0
	P.air_jump = false
	P.jumping = false
	P.coyote_t = 0.0
	P.buffer_t = 0.0
	P.land_t = 0.0
	P.slamming = false
	P.slow_t = 0.0
	P.slow_mul = 1.0
	Game.rig.snap_to(P)


# ---- egg sacs: shootable; when you come close they wobble for a moment, then hatch
func _eggs_step(dt: float, P: Player, C: Combat) -> void:
	for e: Dictionary in eggs:
		if e.state == "gone":
			continue
		var ex: float = e.x
		var ey: float = e.y
		var ez: float = e.z
		var g: Node3D = e.g
		var near := absf(P.y - ey) < 6.0 and U.hyp(P.x - ex, P.z - ez) < 30.0
		if not near and e.state == "idle":
			g.visible = absf(P.y - ey) < 50.0
			continue
		e.st = float(e.st) + dt
		var tg: Target = e.t_
		if tg != null:
			tg.x = ex
			tg.bx = ex
			tg.z = ez
			tg.bz = ez
			tg.y = ey
			tg.respawn_t = 1e9
		if tg != null and (tg.dead or tg.hp <= 0.0):      # shot before it hatched
			e.state = "gone"
			g.visible = false
			C.targets.erase(tg)
			event({"t": &"meatBoom", "id": -1, "x": ex, "y": ey + 0.8, "z": ez, "r": 0.8, "big": false})
			continue
		var d := U.hyp(P.x - ex, P.z - ez)
		# idle: it pulses with the spire's heartbeat and the embryo squirms, now and then kicking the shell out of shape. Woken (1.6 s): the kicks come faster and harder, the shell stretches thin and trembles, then it bursts and the hatchling drops out.
		e.kick = maxf(0.0, float(e.kick) - dt * 5.0)
		var shell: Node3D = e.shell
		var emb: Node3D = e.embryo
		if e.state == "idle":
			var hb := SpireMechs.beat_at(time_ + ex * 0.1, 1.1)
			e.nk = float(e.nk) - dt
			if float(e.nk) < 0.0:
				e.nk = randf_range(3.0, 7.0)
				e.kick = 0.6
				e.kx = randf_range(-1.0, 1.0)
				e.kz = randf_range(-1.0, 1.0)
			var kick: float = e.kick
			var kx: float = e.kx
			var kz: float = e.kz
			shell.scale = Vector3(1.0 + 0.03 * hb + 0.06 * kick * absf(kx), 1.0 + 0.03 * sin(time_ * 2.0 + ex) + 0.04 * hb, 1.0 + 0.03 * hb + 0.06 * kick * absf(kz))
			shell.position = Vector3(0.05 * kick * kx, 0.82, 0.05 * kick * kz)
			emb.position.y = 0.75 + 0.05 * sin(time_ * 3.0 + ez)
			emb.rotation = Vector3(sin(time_ * 1.3 + ex) * 0.4, time_ * 0.5, kick * 0.8)
			if not P.dead and d < float(e.get("wake", 6.5)) and absf(P.y - ey) < 3.0:
				e.state = "wake"
				e.st = 0.0
				e.kicks = 0
				sfx_at("meatSwell", ex, ey, ez, {"range": 30.0})
		elif e.state == "wake":
			var st: float = e.st
			var k := st / 1.6
			while int(e.kicks) < KICKS.size() and st >= KICKS[int(e.kicks)]:
				e.kicks = int(e.kicks) + 1
				e.kick = 0.6 + 0.4 * k
				e.kx = randf_range(-1.0, 1.0)
				e.kz = randf_range(-1.0, 1.0)
			var kick: float = e.kick
			var kx: float = e.kx
			var kz: float = e.kz
			var stretch := 1.0 + 0.25 * k * k
			var tr := sin(time_ * 45.0) * 0.04 * k
			shell.scale = Vector3(1.0 + 0.1 * k + tr + 0.12 * kick * absf(kx), stretch + 0.1 * kick, 1.0 + 0.1 * k - tr + 0.12 * kick * absf(kz))
			shell.position = Vector3(0.08 * kick * kx, 0.82, 0.08 * kick * kz)
			emb.position.y = 0.75 + sin(time_ * 25.0) * 0.12 * k + 0.25 * kick
			emb.rotation.z = kick * 1.2
			if k >= 1.0:
				e.state = "gone"
				g.visible = false
				C.targets.erase(tg)
				event({"t": &"meatBoom", "id": -1, "x": ex, "y": ey + 0.8, "z": ez, "r": 0.9, "big": false})
				var z: Variant = _zone_named(e.get("zone"))
				if z == null:
					z = _nearest_zone(ex, ey, ez)
				if z == null:
					z = {"name": "egg", "x": ex, "z": ez, "y": ey, "leash": 5.0, "trig": 26.0, "dy": 10.0, "units": [], "spawned": true, "robots": []}
					zones.append(z)
				var props: Variant = e.get("props")
				var u: Dictionary = {"kind": e.kind, "x": ex, "z": ez, "y": ey, "yaw": atan2(P.x - ex, P.z - ez)}
				if props != null:
					u["props"] = props
				_spawn_unit(z, u, 0)


func _zone_named(z: Variant) -> Variant:
	if not (z is Dictionary):
		return null
	for q: Dictionary in zones:
		if q.get("name") == (z as Dictionary).get("name"):
			return q
	return null


# ---- gazing eyes: track you; stand still in their sight and they charge, then fire. Shoot one and it shuts for a while.
func _eyes_step(dt: float, P: Player, C: Combat) -> void:
	var still := P.grounded and U.hyp(P.vx, P.vz) < 1.0 and P.mode == &"normal"
	for e: Dictionary in eyes:
		var ex: float = e.x
		var ey: float = e.y
		var ez: float = e.z
		var sz: float = e.size
		var dx := P.x - ex
		var dy := P.y + 1.3 - ey
		var dz := P.z - ez
		var d := Vector3(dx, dy, dz).length()
		var g: Node3D = e.g
		if absf(dy) > 30.0:
			g.visible = false
			continue
		g.visible = true
		var tg: Target = e.t_
		if tg != null and tg.hp < tg.max:      # shot: it shuts for a while
			tg.hp = tg.max
			e.shut = 7.0
			e.charge = 0.0
			e.lock = 0.0
			event({"t": &"tongueLash", "x": ex, "y": ey, "z": ez, "hit": false})
		e.shut = maxf(0.0, float(e.shut) - dt)
		e.next = float(e.next) - dt
		if float(e.next) < 0.0:
			e.next = randf_range(2.5, 6.0)
			e.blink = 0.22
		e.blink = maxf(0.0, float(e.blink) - dt)
		var shut: float = e.shut
		var blink: float = e.blink
		var lock: float = e.lock
		var lid_open := 0.05 if shut > 0.0 else (absf(blink / 0.22 - 0.5) * 2.0 if blink > 0.0 else (0.55 if lock > 0.0 else 1.0))
		(e.lid_u as Node3D).rotation.x = -lid_open * 0.9 - 0.15
		(e.lid_d as Node3D).rotation.x = PI + lid_open * 0.9 + 0.15
		# look at the player (the ball turns inside the lids): idle it darts in saccades, quick jumps to a new spot near you, then a hold; charging it locks on and tracks smoothly. The pupil shrinks to a pinpoint as it charges and the ball kicks back when it fires.
		e.sac = float(e.sac) - dt
		var charge: float = e.charge
		var focus := charge > 0.0 or lock > 0.0
		if float(e.sac) <= 0.0 or focus:
			e.sac = randf_range(0.3, 1.0)
			var j := 0.0 if focus else 0.8
			e.tgt = Vector3(P.x + randf_range(-j, j), P.y + 1.3 + randf_range(-j, j) * 0.5, P.z + randf_range(-j, j))
		var ball: Node3D = e.ball
		var q0 := ball.quaternion
		var bp := ball.global_position
		if bp.distance_squared_to(e.tgt) > 1e-3:
			ball.look_at(e.tgt, Vector3.UP, true)
		ball.quaternion = q0.slerp(ball.quaternion, 1.0 - exp(-(9.0 if focus else 28.0) * dt))
		e.kick = maxf(0.0, float(e.kick) - dt * 4.0)
		ball.position = Vector3(0.0, 0.0, -0.15 * sz * float(e.kick))
		var pc := 1.0 - 0.55 * clampf(charge, 0.0, 1.0) - (0.25 if lock > 0.0 else 0.0) + 0.35 * clampf(shut / 7.0, 0.0, 1.0)
		(e.pupil as Node3D).scale = Vector3(sz * 0.24 * pc, sz * 0.24 * pc, sz * 0.08)
		var sees := false
		if e.gaze and shut <= 0.0 and not P.dead and d < float(e.range):
			var l := d if d != 0.0 else 1.0
			var o := 1.25 * sz
			sees = world.ray_clear(ex + dx / l * o, ey + dy / l * o, ez + dz / l * o, dx / l, dy / l, dz / l, l - o, 0.04) >= l - o - 0.6
		if lock > 0.0:
			e.lock = lock - dt
			_iris(e, Color(1.0, 0.15, 0.1))
			if float(e.lock) <= 0.0:      # FIRE: a fast red bolt at where you are now
				var l := d if d != 0.0 else 1.0
				var o := 1.3 * sz
				e.charge = 0.0
				e.kick = 1.0
				C.enemies.fire_from(int(e.id), ex + dx / l * o, ey + dy / l * o, ez + dz / l * o, dx / l, dy / l, dz / l, {"kind": "bolt", "speed": 30.0, "dmg": 10.0, "r": 0.2})
		elif sees and still:
			e.charge = charge + dt
			if float(e.charge) > 1.0:
				e.lock = 0.7
				sfx_at("mindWind", ex, ey, ez, {"dur": 0.7, "range": 50.0})
		else:
			e.charge = maxf(0.0, charge - dt * 2.0)
		if float(e.lock) <= 0.0:
			_iris(e, Color(0.3 + clampf(float(e.charge), 0.0, 1.0) * 0.7, 0.03, 0.06))
		ball.scale = Vector3.ONE * (1.0 + (0.06 * sin(time_ * 30.0) if float(e.lock) > 0.0 else 0.0))
		if tg != null:
			tg.x = ex
			tg.bx = ex
			tg.z = ez
			tg.bz = ez
			tg.y = ey - sz


func _iris(e: Dictionary, c: Color) -> void:
	for m: StandardMaterial3D in e.iris:
		m.emission = c.linear_to_srgb()


# ---- secrets
func _secrets_step(P: Player) -> void:
	for s: Dictionary in secrets:
		var g: Node3D = s.g
		if s.kind == "bulb" and s.got and P.dead:      # grows back for the next attempt
			s.got = false
			g.visible = true
		if s.got:
			continue
		g.rotation.y = time_ * 1.4
		g.position.y = float(s.y) + 0.9 + sin(time_ * 2.0) * 0.12
		if not P.dead and U.hyp(P.x - float(s.x), P.z - float(s.z)) < 1.3 and absf(P.y - float(s.y)) < 1.8 and not (s.kind == "bulb" and P.hp >= P.max_hp - 4.0):
			s.got = true
			g.visible = false
			if s.kind == "heart":
				P.max_hp += 25.0
				P.hp = P.max_hp
			elif s.kind == "bulb":
				P.hp = minf(P.max_hp, P.hp + 40.0)
			else:
				P.hp = P.max_hp
			toast(String(s.get("text", "SECRET FOUND")))
			event({"t": &"pickup", "x": s.x, "y": float(s.y) + 1.0, "z": s.z})


func _scenery() -> void:
	var beat := SpireMechs.beat_at(time_)
	if shader_ports != null:      # the sky: a faint, endless lattice of flesh (JS sky.js update)
		for k: String in shader_ports.mats:
			if k.begins_with("shader_75102a"):
				var sm: ShaderMaterial = shader_ports.mats[k]
				sm.set_shader_parameter(&"uBeat", beat)
				sm.set_shader_parameter(&"uSky", _sky_c.srgb_to_linear())
				sm.set_shader_parameter(&"uBg", _bg_c.srgb_to_linear())
	_flesh.update(time_, beat, SpireMechs.breath_at(time_))
	for i in cp_views.size():
		var v: Dictionary = cp_views[i]
		var on := i <= cp_idx
		if int(v.on) != int(on):
			v.on = int(on)
			set_color(v.orb_m, Color.hex(0x7affc8ff) if on else Color.hex(0xff6a7aff), 1.0)
			set_alpha(v.ring_m, 0.85 if on else 0.45)
		(v.orb as Node3D).scale = Vector3.ONE * (1.0 + (0.12 if on else 0.22) * beat)
		(v.ring as Node3D).rotation.y = time_ * 0.8


# ---------------------------------------------------------------------------------------------- per-frame entry point
func tick(dt: float) -> void:
	var P: Player = Game.player
	var C: Combat = Game.combat
	time_ += dt
	if C != null and not _hooked:
		_hook(C)
	_scenery()
	if dt > 0.0:
		mechs.update(time_, dt, P)
		last_p = P
		last_combat = C
		_housekeeping(P, C)
		_locks(dt, P, C)
		_hazards_step(dt, P, C)
		_checkpoints_step(P, C)
		_eggs_step(dt, P, C)
		_eyes_step(dt, P, C)
		_secrets_step(P)
		_room_updaters(dt, P, C, time_)
		boss.update(dt, P, C, time_)
		cine.update(dt, P)
		if arena_pods.is_empty() and not C.pickups.is_empty():
			var a := gate_a
			for q: float in [0.8, 2.4, 3.9, 5.5]:
				var px := sin(a + q) * 5.5
				var pz := cos(a + q) * 5.5
				for p: Variant in C.pickups:
					if U.hyp(float(p.x) - px, float(p.z) - pz) < 0.1 and absf(float(p.y) - TOP_Y) < 0.5:
						arena_pods.append(p)
		for p: Variant in arena_pods:
			if p.cd > 0.0 and not p.get_meta("slow", false) and boss.mode == "fight":
				p.set_meta("slow", true)
				p.cd = SpireBoss.POD_CD
			if p.cd <= 0.0:
				p.set_meta("slow", false)
		# the boss fight: camera out and wider, so the player reads small beside her; the angle never changes while shooting
		var r: CameraRig = Game.rig
		var bm := boss.mode
		var maw := bm == "intro" or bm == "fight" or bm == "dying" or bm == "cine"
		var warden := false
		if not maw:
			for q: Robot in C.enemies.robots:
				if q.get("warden") == true and not q.dead and q.state != &"idle" and absf(q.y - P.y) < 8.0 and U.hyp(q.x - P.x, q.z - P.z) < 30.0:
					warden = true
					break
		r.pull_t = 1.0 if (maw or warden) else 0.0
		r.pull_dist = 12.0 if maw else 8.5      # the Warden is car-sized: a little more boom so it cannot fill the screen when it lands on you
		r.pull_fov = 12.0 if maw else 5.0
		if not cine.on:      # a lens standing behind the rim wall sees through it
			boss.rim_mesh.visible = not (r.pull_w > 0.3 and U.hyp(r.pos.x, r.pos.z) > ARENA_R - 2.5)
	boss.view.visual(dt, time_, P)
	_atmosphere(maxf(dt, 0.0), P)
	hud.update_hud(Game.frame_real_dt)
	ambience.update_sound(dt, P, time_)


# ---------------------------------------------------------------------------------------------- console: `cp`, CONTINUE, tests
var checkpoints: Array:
	get:
		return checkpoints_


## any checkpoint name, or "boss" (JS tp)
func tp(where: String) -> bool:
	var P := Game.player
	var c: Variant = null
	if where == "boss":
		c = {"x": sin(gate_a) * 12.0, "y": TOP_Y, "z": cos(gate_a) * 12.0, "yaw": gate_a + PI}
	else:
		for q: Dictionary in checkpoints_:
			if q.name == where:
				c = q
	if c == null:
		return false
	_teleport_to(P, c)
	var i := checkpoints_.find(c)
	if i >= 0:
		cp_idx = i
	world.spawn.merge({"x": c.x, "y": c.y, "z": c.z, "yaw": c.get("yaw", 0.0)}, true)
	return true


func load_checkpoint(which: Variant) -> bool:
	if which is int:
		return int(which) >= 0 and int(which) < checkpoints_.size() and tp(checkpoints_[int(which)].name)
	return tp(String(which))
