class_name CityCrowd
extends RefCounted
## FOINT CITY pedestrians (JS levels/hub/city-crowd.js createCrowd, update): the townsfolk walking their set loops. Walkers keep to the right, wait at the kerb for the WALK phase (or a gap in the traffic where there is no signal), stop now and then to look
## around, stop when the player stands in their way and turn their heads to look at you. A few stand still with a purpose: people waiting at the bus shelters, the hot-dog vendor and his customers. Everyone is a combat target (flagged npc + crowd): shot, punched or run over
## they fall over, lie there a few seconds and get back up where they fell; whoever sees it runs the other way. Loops and people come from the export (life.json), as the JS built them. The poses run in levels/shaders/folk.gdshader, one MultiMesh per species.

class Cross:
	var s0 := 0.0
	var s1 := 0.0
	var x := 0.0
	var z := 0.0
	var node: CityPlan.Junction = null
	var axis := &"x"


class Loop:
	var path: CityPlan.Path
	var cross: Array[Cross] = []
	var walkers: Array[Person] = []      # (JS: every walker asked of every walker; only the ones on the same loop can answer yes)


class Person:
	var name := &""
	var loop: Loop = null
	var s := 0.0
	var dir := 1
	var v := 0.0
	var vmax := 0.0
	var amp := 1.0
	var phase := 0.0
	var seed_ := 0.0
	var pause := 0.0
	var rest := 0.0
	var x := 0.0
	var z := 0.0
	var hx := 0.0
	var hz := 1.0
	var look := 0.0
	var side := 0.0
	var side0 := 0.0
	var col := Color.WHITE
	var still := false
	var lead: Person = null
	var lag := 0.0
	var squeeze := -1.0     # no room to step round someone ahead: the pace to hold behind them (-1: free)
	var hue := 0.0          # (new townsfolk) a second or third of its species: its own colouring, hue turned this far (turns) and brightness times val
	var val := 1.0
	var flee := 0.0
	var al := 1.0
	var has_al := false
	var go: Cross = null
	var down := -1.0        # JS f.down: undefined until it falls
	var fall := Vector2.ZERO
	var has_fall := false
	var sz := 1.0
	var on_rd := false      # (where it stands now: on a road, a kerb lower)
	var slot := 0
	var T: Target = null
	var batch: Batch = null
	var skin_id := ""       # its new species (tools/folk), or "" for the old one it was exported as
	var cyc := 0.0          # (new townsfolk, FolkSkin) where in its walk cycle, 0..1: advanced by distance over the stride, so the feet stay planted
	var run_w := 0.0        # how far into its run (fleeing)

## one species: its MultiMesh and a buffer of 20 floats per person (JS: instance matrix, aAnim, aLook, aCol)
class Batch:
	var mm: MultiMesh
	var buf := PackedFloat32Array()
	var list: Array[Person] = []
	var skin: FolkSkin = null      # a new species (tools/folk): skinned on the GPU, its own instance data


var plan: CityPlan
var traffic: CityTraffic
var GY := 0.0
var CURB := CityPlan.CURB
var rng := CityPlan.Rng.new(31337)
var folk: Array[Person] = []
var loops: Array[Loop] = []
var batches: Dictionary = {}
var targets: Array[Target] = []
var by_tid: Dictionary = {}
var aliens: CityAliens = null
var people_grid: Dictionary = {}   # key(x, z) -> Array of Person: where everyone stood last frame, for spacing them (any loop)
var _near_out: Array = []
var grid: Dictionary = {}          # JS key(x, z) -> PackedFloat32Array of x, z, r: what walkers step round. A 4 m grid keeps the look-up local.
var movers := PackedFloat32Array() # x, z, r of someone walking the pavements who is not one of the crowd (Sambo, levels/hub/hub_sambo.gd): stepped round like a person, rewritten each frame by its owner
var people_solids: Array[World.Solid] = []
var _near: Array = []

## The new townsfolk (tools/folk/README.md's roster, levels/hub/folk_skin.gd) take the old walkers' places person by person (user, 2026-11-15: no more Earth animals or
## plain humans; FOINT CITY's people are their own species; the strange ones stay, rebuilt). Old species -> the new species of its 1st, 2nd... walker. A new species only
## steps in once its files are there (assets/folk/<id>.glb + .json): until then that walker stays the old one.
## The disguised suit is SAMBO FENRIR's (levels/hub/hub_sambo.gd) and he is one of a kind (user, 2026-11-19): its old walker walks as a heart_tech, and no second one is drawn.
const NEW_FOLK := {
	&"frog": ["fin_exec"], &"wanderer": ["gardener"], &"crane": ["lilac_spider"], &"mantis": ["walkman"], &"rhino": ["cook"], &"skelly": ["nurse"],
	&"moleboss": ["mob_boss"], &"snail": ["manta_maid"], &"gremlin": ["mop_fringe"], &"worm": ["naga"], &"squidface": ["accountant"], &"lanky": ["snakeneck"],
	&"granny": ["veg_granny"], &"jogger": ["climber"], &"kid": ["bean_clock"], &"pizza": ["grocery_dad"],
	&"agent": ["fish_biker", "demon_tail", "manta_goth", "lounge_singer"],
	&"tvbot": ["tvbot"], &"cratebot": ["cratebot"], &"brainjar": ["brainjar"], &"fishbowl": ["fishbowl"], &"binocular": ["binocular"], &"conehat": ["conehat"],
	&"cone": ["cone"], &"slime": ["slime"], &"ufo": ["ufo"], &"blob": ["blob"], &"twohead": ["twohead"], &"stilts": ["stilts"], &"noodle": ["noodle"],
	&"disguised": ["heart_tech"], &"hotdog": ["hotdog"], &"cyclops": ["cyclops"], &"grinbuddy": ["grinbuddy"], &"sandwich": ["sandwich"],
}
## the new species with no old walker to replace: each gets a walker of its own on the loops
const EXTRA_FOLK := ["mechanic", "couch_worm", "arch_legs", "heart_tech", "cyclops_gamer", "jelly_drill", "hole_chest", "spiral_rain"]
const EXTRA_TID := 889000
const MORE := 40           # walkers added beyond one walking each: this many species get a second (no species twice on one street)
const TINT := 0.07         # a second or third of a species: its hue turned up to this either way (turns; 0.07 is 25 degrees), brightness 0.85-1.15
const TINT_TEST := 0.0     # not 0: every second and third turned exactly this far instead (0.5 = their colours flipped), to judge the look
## species whose colours are who they are (a hot dog, a traffic cone, the doom-sayer's board, the robots' screens): their copies vary only in brightness
const KEEP_HUE := ["hotdog", "cone", "sandwich", "tvbot", "cratebot"]

func _init(level: ExportedLevel, p: CityPlan, tr: CityTraffic, J: Dictionary, f: CityFolk) -> void:
	plan = p
	traffic = tr
	GY = J["GY"]
	for d: Dictionary in J["loops"]:
		var lp := Loop.new()
		var pts := PackedVector2Array()
		for q: Array in d["pts"]:
			pts.append(Vector2(q[0], q[1]))
		lp.path = CityPlan.Path.new(pts)
		for c: Dictionary in d["cross"]:
			var cr := Cross.new()
			cr.s0 = c["s0"]
			cr.s1 = c["s1"]
			cr.x = c["x"]
			cr.z = c["z"]
			cr.node = plan.nodes[int(c["node"])] if int(c["node"]) >= 0 else null
			cr.axis = StringName(c["axis"])
			lp.cross.append(cr)
		loops.append(lp)
	var order: Array[Person] = []
	for d: Dictionary in J["folk"]:
		var o := Person.new()
		o.name = StringName(d["name"])
		o.loop = loops[int(d["loop"])] if int(d["loop"]) >= 0 else null
		o.s = d["s"]
		o.dir = int(d["dir"])
		o.vmax = d["vmax"]
		o.amp = d["amp"]
		o.phase = d["phase"]
		o.seed_ = d["seed"]
		o.pause = d["pause"]
		o.side = d["side"]
		o.side0 = d["side0"]
		o.col = Color.hex((int(d["col"]) << 8) | 0xff).srgb_to_linear()
		o.still = d["still"]
		o.x = d["x"]
		o.z = d["z"]
		o.hx = d["hx"]
		o.hz = d["hz"]
		o.sz = d["sz"]
		o.slot = int(d["slot"])
		o.T = Target.new(int(d["tid"]), 0.0, 0.0, GY, {"r": d["r"], "h": d["h"], "max": d["max"], "hp": d["max"], "npc": true, "crowd": true, "w": 0.0})
		order.append(o)
		folk.append(o)
		if o.loop != null and not o.still:
			o.loop.walkers.append(o)
		targets.append(o.T)
		by_tid[o.T.id] = o
	var i := 0
	for d: Dictionary in J["folk"]:
		var l := int(d["lead"])
		if l >= 0:
			folk[i].lead = order[l]
		i += 1
	# the new species into the old places, then walkers of their own for the rest
	var seen := {}
	for o in folk:
		var olds: Array = NEW_FOLK.get(o.name, [])
		var k: int = seen.get(o.name, 0)
		seen[o.name] = k + 1
		if not olds.is_empty() and FolkSkin.available(olds[k % olds.size()]):
			o.skin_id = olds[k % olds.size()]
	# the agents walked as two side-by-side pairs, each follower pinned beside its leader; four different species now, each walks for itself, a few
	# metres apart (a pinned follower cannot step round anyone, and the pairs were spaced for human-sized agents)
	var n_free := 0
	for o in folk:
		if o.lead != null and o.skin_id != "":
			o.lead = null
			o.lag = 0.0
			o.side0 = 0.4 + 0.25 * rng.next()
			o.side = o.side0
			n_free += 1
			o.s = fposmod(o.s + 4.0 * n_free * o.dir, o.loop.path.length)
	# more walkers (user, 2026-11-16: the city felt empty and some species were hard to find; no handful repeated over and over). First every species
	# that no one sees walking (the new ones with no old place, and those whose only place is standing still), then MORE others, one each, drawn
	# from a shuffled deck. Each goes to the least crowded street that does not already have its species, into the widest gap between its walkers.
	var kinds: Array[String] = []
	for o in folk:
		if o.skin_id != "" and not kinds.has(o.skin_id):
			kinds.append(o.skin_id)
	for sid: String in EXTRA_FOLK:
		if FolkSkin.available(sid) and not kinds.has(sid):
			kinds.append(sid)
	kinds.sort()
	var walks := {}
	for o in folk:
		if o.skin_id != "" and o.loop != null and not o.still:
			walks[o.skin_id] = true
	var deck: Array[String] = []
	for sid in kinds:
		if not walks.has(sid):
			deck.append(sid)
	var pool := kinds.duplicate()
	for n in range(pool.size() - 1, 0, -1):
		var r := int(rng.next() * (n + 1))
		var tmp: String = pool[n]
		pool[n] = pool[r]
		pool[r] = tmp
	deck.append_array(pool.slice(0, mini(MORE, pool.size())))
	var j := 0
	for sid in deck:
		var best: Loop = null
		var bd := INF
		for lp in loops:
			if lp.path.length < 30.0:      # (the little loop by the dome's gate)
				continue
			var has := false
			for w in lp.walkers:
				if w.skin_id == sid:
					has = true
					break
			var dn := float(lp.walkers.size() + 1) / lp.path.length
			if not has and dn < bd:
				bd = dn
				best = lp
		if best == null:
			continue
		var L := best.path.length
		var ss := PackedFloat32Array()
		for w in best.walkers:
			ss.append(fposmod(w.s, L))
		ss.sort()
		var at := rng.next() * L
		var gap := 0.0
		for k in ss.size():
			var nx := ss[(k + 1) % ss.size()] + (L if k == ss.size() - 1 else 0.0)
			if nx - ss[k] > gap:
				gap = nx - ss[k]
				at = fposmod(ss[k] + gap * 0.5, L)
		var o := Person.new()
		o.skin_id = sid
		o.loop = best
		o.s = at
		o.dir = 1 if rng.next() < 0.5 else -1
		o.vmax = 1.0 + 0.3 * rng.next()
		o.amp = 1.0
		o.phase = rng.next() * TAU
		o.seed_ = rng.next()
		o.pause = 25.0 + rng.next() * 50.0
		o.side0 = 0.4 + 0.25 * rng.next()
		o.side = o.side0
		var q := o.loop.path.at(o.s)
		o.x = q.x
		o.z = q.y
		o.hx = q.z * o.dir
		o.hz = q.w * o.dir
		o.T = Target.new(EXTRA_TID + j, 0.0, 0.0, GY, {"r": 0.4, "h": 1.7, "max": 60.0, "hp": 60.0, "npc": true, "crowd": true, "w": 0.0})
		folk.append(o)
		o.loop.walkers.append(o)
		targets.append(o.T)
		by_tid[o.T.id] = o
		j += 1
	# the second and third of a species each get their own colouring, so a pair never reads as the same person twice
	var met := {}
	for o in folk:
		if o.skin_id == "":
			continue
		if met.has(o.skin_id):
			o.val = 0.85 + 0.3 * rng.next()
			if not KEEP_HUE.has(o.skin_id):
				o.hue = TINT_TEST if TINT_TEST != 0.0 else (rng.next() * 2.0 - 1.0) * TINT
		met[o.skin_id] = true
	for q: Array in J["obstacles"]:
		var k0x: float = q[0]
		var k0z: float = q[1]
		for a in range(-1, 2):
			for b in range(-1, 2):
				var k := _key(k0x + a * 4.0, k0z + b * 4.0)
				if not grid.has(k):
					grid[k] = PackedFloat32Array()
				var g: PackedFloat32Array = grid[k]
				g.append_array([q[0], q[1], q[2]])
				grid[k] = g
	for s: Variant in J["people_solids"]:
		var si := int(s)
		if si >= 0 and si < level.world.solids.size():
			people_solids.append(level.world.solids[si])
	# ---- instanced meshes per species
	var names: Dictionary = {}
	for o in folk:
		var key := StringName("new:" + o.skin_id) if o.skin_id != "" else o.name
		if not names.has(key):
			names[key] = []
		(names[key] as Array).append(o)
	var group := Node3D.new()
	group.name = "Folk"
	var dn: Array = level.node_named("FointDistrict")
	(dn[0] if not dn.is_empty() else level.scene_root).add_child(group)      # (hidden with the district from the hub street)
	for nm: StringName in names:
		var list: Array = names[nm]
		var b := Batch.new()
		b.mm = MultiMesh.new()
		b.mm.transform_format = MultiMesh.TRANSFORM_3D
		b.mm.use_colors = true
		b.mm.use_custom_data = true
		if String(nm).begins_with("new:"):
			b.skin = FolkSkin.make(String(nm).substr(4), group)
			b.mm.mesh = b.skin.mesh
		else:
			b.mm.mesh = f.species_mesh(String(nm))
		b.mm.instance_count = list.size()
		b.buf.resize(list.size() * 20)
		for o: Person in list:
			b.list.append(o)
			o.batch = b
			if b.skin != null:      # modelled at their own height and pace: only a little size variation, the target as tall and wide as they are
				# a walker the city made a giant (the blob, sz 2.1: 3.57 m) stays as tall as it was; the rest vary only a little
				o.sz = o.T.h / b.skin.height if o.sz > 1.2 else clampf(o.sz, 0.97, 1.03)
				o.T.h = b.skin.height * o.sz
				o.T.r = b.skin.radius * o.sz
				o.vmax *= b.skin.speed
				o.cyc = o.seed_
		var mi := MultiMeshInstance3D.new()
		mi.name = "Folk_" + (b.skin.id if b.skin != null else String(nm))
		mi.multimesh = b.mm
		mi.material_override = b.skin.material if b.skin != null else f.material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0      # (the arms and the hover move past the mesh's own box in the shader)
		group.add_child(mi)
		batches[nm] = b


func dispose() -> void:
	for nm: StringName in batches:
		(batches[nm] as Batch).list.clear()
	for lp in loops:
		lp.walkers.clear()
	for f in folk:
		f.batch = null
		f.lead = null
	folk.clear()


static func _key(x: float, z: float) -> int:
	return int(floor(x / 4.0)) * 1000 + int(floor(z / 4.0))


## steer the walker's lane on the sidewalk round whatever stands ahead
## everyone within a cell of f (the 4 m grid of where walkers stood last frame), whatever their loop: twin loops run down the same pavement
func _neighbours(f: Person) -> Array:
	_near_out.clear()
	var cx := int(floor(f.x / 4.0))
	var cz := int(floor(f.z / 4.0))
	for a in range(-1, 2):
		for b in range(-1, 2):
			var g: Variant = people_grid.get((cx + a) * 1000 + cz + b)
			if g != null:
				_near_out.append_array(g)
	return _near_out


func _avoid(f: Person, dt: float, near: Array) -> void:
	var want := f.side0
	var rx := -f.hz
	var rz := f.hx
	# other people in the way (standing, coming the other way, or slower on a twin loop): step round them by both bodies' widths (user, 2026-11-16:
	# they stood inside each other; the new species are not all human-sized)
	for o: Person in near:
		if o == f or o.T.dead or o == f.lead or o.lead == f:
			continue
		var dx := o.x - f.x
		var dz := o.z - f.z
		var a := dx * f.hx + dz * f.hz
		if a >= -0.4 and a <= 3.2:
			var lat := dx * rx + dz * rz + f.side
			var need := o.T.r + f.T.r + 0.1
			if absf(lat - want) < need:
				var l := lat - need
				var r2 := lat + need
				want = l if absf(l - f.side0) < absf(r2 - f.side0) else r2
	var g: Variant = grid.get(_key(f.x, f.z))
	if g != null:
		var list: PackedFloat32Array = g
		var i := 0
		var n := list.size()
		while i < n:
			var dx := list[i] - f.x
			var dz := list[i + 1] - f.z
			var a := dx * f.hx + dz * f.hz
			if a >= -0.4 and a <= 3.2:
				var lat := dx * rx + dz * rz + f.side      # the obstacle's offset from the loop's line
				var need := list[i + 2] + 0.42
				if absf(lat - want) < need:
					var l := lat - need
					var r2 := lat + need
					want = l if absf(l - f.side0) < absf(r2 - f.side0) else r2
			i += 3
	var mi := 0
	while mi + 2 < movers.size():
		var dx := movers[mi] - f.x
		var dz := movers[mi + 1] - f.z
		var a := dx * f.hx + dz * f.hz
		if a >= -0.4 and a <= 3.2:
			var lat := dx * rx + dz * rz + f.side
			var need := movers[mi + 2] + f.T.r + 0.1
			if absf(lat - want) < need:
				var l := lat - need
				var r2 := lat + need
				want = l if absf(l - f.side0) < absf(r2 - f.side0) else r2
		mi += 3
	want = clampf(want, -1.35, 1.35)
	f.side += (want - f.side) * minf(1.0, dt * 2.6)
	# the pavement's edge left no room to step round someone level with or ahead of it: hold back behind them next frame instead of walking into them
	f.squeeze = -1.0
	for o: Person in near:
		if o == f or o.T.dead or o == f.lead or o.lead == f:
			continue
		var dx := o.x - f.x
		var dz := o.z - f.z
		var a := dx * f.hx + dz * f.hz
		if a > 0.0 and a <= 1.6 + o.T.r + f.T.r and absf(dx * rx + dz * rz + f.side - want) < o.T.r + f.T.r:
			var same := o.hx * f.hx + o.hz * f.hz > 0.3
			if not same and not o.still and o.T.id > f.T.id:      # two coming head on with no room: one waits, the other goes (both waiting would be for ever)
				continue
			var hold := maxf(0.0, o.v * 0.7) if same else 0.0
			f.squeeze = hold if f.squeeze < 0.0 else minf(f.squeeze, hold)
	mi = 0
	while mi + 2 < movers.size():      # (someone not of the crowd in the way with no room round them: wait)
		var dx := movers[mi] - f.x
		var dz := movers[mi + 1] - f.z
		var a := dx * f.hx + dz * f.hz
		if a > 0.0 and a <= 1.6 + movers[mi + 2] + f.T.r and absf(dx * rx + dz * rz + f.side - want) < movers[mi + 2] + f.T.r:
			f.squeeze = 0.0
		mi += 3


## back on their feet where they fell (the matrix loop has already stood them up); dazed, they hurry off
func _revive(f: Person) -> void:
	f.down = -1.0
	f.v = 0.0
	f.rest = 0.0
	f.go = null
	f.has_fall = false
	if not f.still:
		f.flee = 4.0 + rng.next() * 3.0


## run the other way (a pair runs together: the leader decides)
func _scare(f: Person, player: Player) -> void:
	if f.still or f.T.dead:
		return
	var w := f.lead if f.lead != null else f
	w.flee = 6.0 + rng.next() * 3.0
	w.rest = 0.0
	if player != null and f.lead == null and (player.x - f.x) * f.hx + (player.z - f.z) * f.hz > 0.0:      # (the lane mirrors with the direction: flip the offset too so nobody jumps, avoid() eases back to the right-hand lane)
		w.dir = -w.dir
		w.side = -w.side


## combat events (hit / kill) for the crowd: the victim flinches or falls away from the shooter, everyone near runs. (JS aliens.onHit: with the aliens.)
func on_event(e: Dictionary, player: Player) -> void:
	if aliens != null:
		aliens.on_hit(e, player)
	var et := String(e.get("t", ""))
	if et != "hit" and et != "kill":
		return
	var f: Person = by_tid.get(int(e.get("tid", -1)))
	if f != null:
		f.fall = Vector2(float(e.get("ux", 0.0)), float(e.get("uz", 0.0)))
		f.has_fall = true
		if et == "kill":
			f.T.respawn_t = 4.0
	var r := 16.0 if et == "kill" else 9.0
	var ex := float(e.get("x", 0.0))
	var ez := float(e.get("z", 0.0))
	for g in folk:
		if (et == "hit" if g == f else U.hyp(g.x - ex, g.z - ez) < r):
			_scare(g, player)


## may this walker step onto the crossing ahead?
func _crossing_clear(c: Cross, t: float) -> bool:
	if c.node != null:
		return CityPlan.signal_at(c.node, c.axis, t) == CityPlan.G and CityPlan.green_left(c.node, c.axis, t) > 4.0
	for car in traffic.cars:
		var dx := c.x - car.x
		var dz := c.z - car.z
		var d := U.hyp(dx, dz)
		if (d < 22.0 and (dx * car.hx + dz * car.hz > -3.0) and car.v > 0.5) or d < 4.0:
			return false
	return true


func update(t: float, dt: float, player: Player) -> void:
	dt = minf(dt, 0.05)
	if aliens != null:
		aliens.update(t, dt, player)
	var px := player.x
	var pz := player.z
	var p_on := player.y < GY + 2.5 and player.y > GY - 2.0
	traffic.people.clear()
	people_grid.clear()
	for f in folk:
		if not f.T.dead:
			var gk := _key(f.x, f.z)
			if not people_grid.has(gk):
				people_grid[gk] = []
			(people_grid[gk] as Array).append(f)
	for f in folk:
		var T := f.T
		if T.dead:                      # lying where it fell (drawn below), no longer in anyone's way
			f.down = (f.down if f.down >= 0.0 else 0.0) + dt
			continue
		if f.down >= 0.0:
			_revive(f)
		var on_rd := f.on_rd
		T.bx = f.x
		T.x = f.x
		T.bz = f.z
		T.z = f.z
		T.kx = 0.0
		T.kz = 0.0
		T.y = GY - (CURB if on_rd else 0.0)
		if not f.still:
			var fleeing := f.flee > 0.0
			var target := f.vmax
			if f.lead != null and f.dir != f.lead.dir:
				f.dir = f.lead.dir
				f.side = -f.side
			if fleeing:
				f.flee -= dt
				f.rest = 0.0
				target = minf(3.8, f.vmax * 2.4) * maxf(0.2, 0.5 + 0.5 * (f.al if f.has_al else 1.0))      # (slower while still turning round: no moonwalking)
			# a pause to look around now and then (not in the road)
			f.pause -= dt
			if f.pause < 0.0 and f.rest <= 0.0 and not on_rd:
				f.rest = 2.5 + rng.next() * 4.0
				f.pause = 25.0 + rng.next() * 50.0
			if f.rest > 0.0:
				f.rest -= dt
				target = 0.0
			# the kerb before a crossing
			var lp := f.loop
			var ln := lp.path.length
			for c in lp.cross:
				var entry := c.s0 if f.dir > 0 else c.s1
				var d := (entry - f.s) * f.dir
				if d < -ln * 0.5:
					d += ln
				if d > ln * 0.5:
					d -= ln
				var inside := f.s > c.s0 and f.s < c.s1 if f.dir > 0 else f.s < c.s1 and f.s > c.s0
				if not fleeing and not inside and d > 0.0 and d < 1.6 and f.go == null:
					if not _crossing_clear(c, t):
						target = minf(target, maxf(0.0, (d - 0.9) * 2.0))
					else:
						f.go = c
				if f.go == c and not inside and d < 0.0:
					f.go = null
			# the player and other walkers in the way
			if f.squeeze >= 0.0:      # (from _avoid last frame: no room to pass)
				target = minf(target, f.squeeze)
			if p_on and _ahead(f, px, pz, 0.3):
				target = 0.0
			var near := _neighbours(f)
			for o: Person in near:      # anyone ahead going the same way, on this loop or its twin, by both bodies' sizes
				var rr := maxf(0.0, f.T.r + o.T.r - 0.8)
				if o != f and not o.T.dead and not o.still and o.hx * f.hx + o.hz * f.hz > 0.3 and _ahead(f, o.x, o.z, rr):
					# side by side on a bend each is "ahead" of the other and both would wait for ever: then only the one further back gives way
					if _ahead(o, f.x, f.z, rr) and (o.x - f.x) * f.hx + (o.z - f.z) * f.hz < (f.x - o.x) * o.hx + (f.z - o.z) * o.hz:
						continue
					target = minf(target, o.v)
			f.v += (target - f.v) * minf(1.0, dt * (6.0 if target < f.v else (7.0 if fleeing else 2.5)))
			if f.lead != null:
				f.s = fposmod(f.lead.s - f.lead.dir * f.lag + ln, ln)
				f.v = f.lead.v
			else:
				f.s = fposmod(f.s + f.v * dt * f.dir + ln, ln)
			_avoid(f, dt, near)
			var q := lp.path.at(f.s)
			var hx := q.z * f.dir
			var hz := q.w * f.dir
			f.x = q.x - hz * f.side
			f.z = q.y + hx * f.side
			var k := minf(1.0, dt * 6.0)
			var da := atan2(hx * f.hz - hz * f.hx, hx * f.hx + hz * f.hz)
			var ha := atan2(f.hx, f.hz) + da * k      # turn the heading round the short way (a straight blend of opposite headings collapses through zero)
			f.al = hx * f.hx + hz * f.hz
			f.has_al = true
			f.hx = sin(ha)
			f.hz = cos(ha)
			f.phase += dt * f.v * 4.6 / maxf(0.6, f.amp * 0.8)
			var sk := f.batch.skin
			if sk != null:
				f.run_w = smoothstep(1.7, 2.9, f.v)
				f.cyc = fposmod(f.cyc + dt * f.v / (lerpf(sk.stride_walk, sk.stride_run, f.run_w) * f.sz), 1.0)
		f.on_rd = plan.on_road(f.x, f.z)
		if f.on_rd:
			traffic.people.append(f)
		# heads turn to the player close by
		var look := 0.0
		if p_on:
			var dx := px - f.x
			var dz := pz - f.z
			var d := U.hyp(dx, dz)
			if d < 5.0 and d > 0.3:
				var a := wrapf(atan2(dx, dz) - atan2(f.hx, f.hz), -PI, PI)
				look = clampf(a, -1.1, 1.1) * (1.0 - d / 5.0) * 1.6
		f.look += (clampf(look, -1.1, 1.1) - f.look) * minf(1.0, dt * 3.0)
	# instances
	for nm: StringName in batches:
		var b: Batch = batches[nm]
		var bf := b.buf
		var o := 0
		if b.skin != null:
			RenderingServer.material_set_param(b.skin.material.get_rid(), &"uTime", t)
		for f in b.list:
			var yaw := atan2(f.hx, f.hz)
			var y := GY - (CURB if f.on_rd else 0.0)
			var c := cos(yaw) * f.sz
			var s := sin(yaw) * f.sz
			var sz := f.sz
			var xf := Basis(Vector3(c, 0.0, -s), Vector3(0.0, sz, 0.0), Vector3(s, 0.0, c))
			if f.T.dead:                                 # topples away from the shooter, lies a moment, then gets back up
				var fall := f.fall if f.has_fall else Vector2(-f.hx, -f.hz)
				var fl := fall.length()
				if fl == 0.0:
					fl = 1.0
				var u := minf(1.0, (f.down if f.down >= 0.0 else 0.0) / 0.5) * minf(1.0, f.T.respawn_t / 0.7)
				xf = Basis(Vector3(fall.y / fl, 0.0, -fall.x / fl), PI * 0.5 * u * (2.0 - u)) * xf
			var walk := 0.0 if f.still or f.T.dead else minf(1.0, f.v / 0.6)
			bf[o] = xf.x.x
			bf[o + 1] = xf.y.x
			bf[o + 2] = xf.z.x
			bf[o + 3] = f.x
			bf[o + 4] = xf.x.y
			bf[o + 5] = xf.y.y
			bf[o + 6] = xf.z.y
			bf[o + 7] = y
			bf[o + 8] = xf.x.z
			bf[o + 9] = xf.y.z
			bf[o + 10] = xf.z.z
			bf[o + 11] = f.z
			if b.skin != null:      # levels/shaders/folk_skinned.gdshader: COLOR.r head turn; custom = cycle, walk, idle offset, run
				bf[o + 12] = f.look
				bf[o + 13] = f.hue      # COLOR.g, COLOR.b: this one's colouring (0 and 1: as built)
				bf[o + 14] = f.val
				bf[o + 15] = 0.0
				bf[o + 16] = f.cyc
				bf[o + 17] = walk
				bf[o + 18] = f.seed_ * 37.0
				bf[o + 19] = f.run_w * walk
				o += 20
				continue
			bf[o + 12] = f.col.r
			bf[o + 13] = f.col.g
			bf[o + 14] = f.col.b
			bf[o + 15] = f.look
			bf[o + 16] = f.phase
			bf[o + 17] = walk
			bf[o + 18] = f.seed_
			bf[o + 19] = f.amp
			o += 20
		b.mm.buffer = bf
	# colliders for the walkers nearest the player (never switched on around the player)
	_near.clear()
	if p_on:
		for f in folk:
			var d := U.hyp(f.x - px, f.z - pz)
			if d < 12.0 and not f.T.dead:
				_near.append([d, f])
		_near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var j := 0
	for sol in people_solids:
		if j >= _near.size():
			sol.set_off(true)
		else:
			var d: float = _near[j][0]
			var f: Person = _near[j][1]
			var y := GY - (CURB if f.on_rd else 0.0)
			var h := f.T.h      # (was 1.7 * sz: the new species have their own heights)
			sol.bottom = y
			sol.top = y + h
			sol.place(f.x, f.z)
			sol.set_off(d < (0.34 + 0.4) * f.sz)
		j += 1


static func _ahead(f: Person, x: float, z: float, r: float) -> bool:
	var dx := x - f.x
	var dz := z - f.z
	var a := dx * f.hx + dz * f.hz
	if a <= 0.0 or a >= 1.6 + r:
		return false
	return absf(-dx * f.hz + dz * f.hx) < 0.55 + r
