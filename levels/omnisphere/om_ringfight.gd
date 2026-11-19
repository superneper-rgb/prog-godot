class_name OmRingFight
extends RefCounted
## OMNISPHERE: the fight on the containment ring. NEW (user, 2026-11-15; not in the JS, where the ring was an empty walk between three emitters on a shutter timer and the way out was a step over the railing).
## THE GARRISONS: each emitter has a squad set down by a dropship; while a guard lives, green arcs feed the emitter's armour and its shutters stay shut. Kill them all and they blow open for good. THE BREAK: when the first emitter dies the ring's drive seizes (it lurches on to the next collider sector and stops turning) and the walkway toward the next emitter loses three 8 m sections: jetpack gaps. The second kill does the same to the next stretch. THE GUNSHIP: the last emitter is also covered by a Repo-Man gunship. Juniper, part charged, puts a bolt into it at each third of its health: it reels, hangs low and takes double damage. Shot down, it goes into the emitter and takes the armour with it. THE RUN: with the last emitter gone the ring falls away sector by sector from behind you, the walkway ahead loses three more sections, and the lifter waits off the far end of that stretch: run, burn, and jump for it there.
## The ring is one exported mesh, so every section that can fall is cut out of it at load (triangles clipped on the section's edges) into a piece of its own. Its colliders are 48 fixed 7.5 degree sectors: a gap is the middle 6 degrees of one, so that sector goes off and two 1 m stubs stand in for what is left of it. The emitters are always fought 0, 1, 2 (OmSummit parks emitter 0 by the drop while you climb), so the run is always the stretch from emitter 2 on to emitter 0.

const SEC := TAU / 48.0
const GAP_H := 3.0 * PI / 180.0      # half a gap: 6 degrees is 8.1 m along the middle of the walkway (a full burn carries 11.6 m; a plain jump about 5)
const GAP_AT := [6, 8, 10]      # sectors past an emitter's own, toward the next emitter
const RM := 77.25      # the walkway's middle, and its two rails
const R_IN := 73.35
const R_OUT := 81.15
const FLOOR_TOP := 170.02
# the Omnisphere's axis, the ring's deck and walkway radii: OmSummit's own values (copied: the two scripts cannot read each other's constants both ways)
const OX := -340.0
const OY := 168.0
const OZ := -310.0
const DECK := OY + 2.02
const R0 := 73.0
const R1 := 81.5
const SEIZE_T := 1.4
const RUN_FROM := 31      # the run: these sectors (the ring's own frame) fall behind you, from the last emitter's arena on
const RUN_N := 20
const ZONE_AT := 15      # sectors into the run: from here on a jump is the way out
const PARK := PI - .35      # where emitter 0 waits (a world angle): 27 m along from where you drop onto the ring
const BOSS_HP := 700.0
# the three garrisons. d = metres along the ring from the emitter (+ = on toward the next one), r = radius, up = a drone's height over the deck
const SQUADS := [
	[{"kind": "goon", "costume": "security", "gun": "smg", "d": -9.0, "r": 75.5}, {"kind": "goon", "costume": "security", "gun": "smg", "d": 10.0, "r": 79.0}, {"kind": "robot", "heavy": "assault", "d": 14.0, "r": 77.0}],
	[{"kind": "drone", "d": -44.0, "r": 77.0, "up": 6.0}, {"kind": "drone", "d": -36.0, "r": 79.0, "up": 7.5}, {"kind": "robot", "heavy": "suppression", "d": 7.0, "r": 77.0}, {"kind": "goon", "costume": "security", "gun": "smg", "d": -8.0, "r": 75.5}, {"kind": "goon", "costume": "hazmat", "d": -4.0, "r": 79.5}],
	[{"kind": "drone", "d": -44.0, "r": 77.0, "up": 6.0}, {"kind": "drone", "d": -36.0, "r": 75.5, "up": 7.5}, {"kind": "robot", "heavy": "elite", "d": 9.0, "r": 77.0}, {"kind": "robot", "heavy": "assault", "d": -11.0, "r": 77.5}, {"kind": "goon", "costume": "security", "gun": "smg", "d": 4.0, "r": 79.5}, {"kind": "goon", "costume": "security", "gun": "smg", "d": -5.0, "r": 75.0}],
]


## a section of the ring that can fall: a gap, or a whole sector of the run
class Gap:
	var c := 0.0      # centre, as an angle in the ring's own frame
	var span := -1      # a gap: the stretch after emitter `span`
	var L := 0      # its sector in the ring's own frame
	var piece: MeshInstance3D
	var pivot := Vector3.ZERO
	var spin := Vector3.ZERO
	var fall := -1.0
	var gone := false
	var sector := -1      # the collider sector it took out
	var stubs: Array[World.Solid] = []      # a gap's [floor, inner rail, outer rail] x the two sides
	var buf: Buf


## vertex data being built: a copy of the ring's arrays (the main mesh) or an empty set (a piece)
class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tg := PackedFloat32Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var off := Vector3.ZERO

	## the point t of the way from source vertex i to j
	func emit(src: Array, i: int, j: int, t: float) -> void:
		var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		v.append(sv[i].lerp(sv[j], t) - off)
		if src[Mesh.ARRAY_NORMAL] != null:
			var a: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
			n.append(a[i].lerp(a[j], t).normalized())
		if src[Mesh.ARRAY_TANGENT] != null:
			var a: PackedFloat32Array = src[Mesh.ARRAY_TANGENT]
			for k in 4:
				tg.append(lerpf(a[i * 4 + k], a[j * 4 + k], t))
		if src[Mesh.ARRAY_COLOR] != null:
			var a: PackedColorArray = src[Mesh.ARRAY_COLOR]
			col.append(a[i].lerp(a[j], t))
		if src[Mesh.ARRAY_TEX_UV] != null:
			var a: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
			uv.append(a[i].lerp(a[j], t))
		if src[Mesh.ARRAY_TEX_UV2] != null:
			var a: PackedVector2Array = src[Mesh.ARRAY_TEX_UV2]
			uv2.append(a[i].lerp(a[j], t))

	func arrays(src: Array) -> Array:
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = v
		if src[Mesh.ARRAY_NORMAL] != null:
			out[Mesh.ARRAY_NORMAL] = n
		if src[Mesh.ARRAY_TANGENT] != null:
			out[Mesh.ARRAY_TANGENT] = tg
		if src[Mesh.ARRAY_COLOR] != null:
			out[Mesh.ARRAY_COLOR] = col
		if src[Mesh.ARRAY_TEX_UV] != null:
			out[Mesh.ARRAY_TEX_UV] = uv
		if src[Mesh.ARRAY_TEX_UV2] != null:
			out[Mesh.ARRAY_TEX_UV2] = uv2
		return out


## the gunship over the last emitter
class Boss:
	var s: OmCraft.Gunship
	var T: OmProp
	var hb: OmCraft.Hitboxes
	var t := 0.0
	var ph := "in"      # in -> fight <-> stagger -> crash -> done
	var from := Vector3.ZERO
	var fire_t := 3.0
	var burst := 0
	var missile_t := 7.0
	var lift := 0.0
	var lv := 0.0
	var stag_t := 0.0
	var strikes := 0
	var last_hp := 0.0
	var crash_t := 0.0
	var crash_from := Vector3.ZERO


var lv: ExportedLevel
var W: World
var sec: OmSecurity
var sets: OmSets
var audio: OmAudio
var marks: OmMarks
var craft: OmCraft
var act2: OmAct2
var jun: OmJuniper
var ems: Array
var ring: Node3D
var root: Node3D
var gaps: Array[Gap] = []
var secs: Array[Gap] = []      # the run's sectors, in the order they fall (its three gaps are in `gaps`)
var floors: Array = []      # the walkway's 48 sector floors and their rails, by world sector
var rails: Array = []
var seized := false
var seize_t := -1.0
var seize_from := 0.0
var seize_to := 0.0
var hold_t := 0.0      # no garrison is sent while the ring is still coming apart
var want := -1
var launched := -1
var squad_n := 0
var wave: OmSecurity.Wave
var later: Array = []
var teth: OmRibbon
var teth_t := 0.0
var safe := Vector3.ZERO
var safe_ok := false
var told := false
var boss: Boss
var boss_due := false
var jbolt: OmRibbon
var jbolt_t := -1.0
var jbolt_re := 0.0
var exit_on := false
var front := -1.0      # how far the collapse has got, metres along the run (-1: not started)
var fall_em: Node3D      # the last emitter's wreck goes down with its sector
var fall_em_t := -1.0


func _init(p_lv: ExportedLevel, p_sec: OmSecurity, p_sets: OmSets, p_audio: OmAudio, p_marks: OmMarks, p_craft: OmCraft, p_act2: OmAct2, p_ems: Array) -> void:
	lv = p_lv
	W = lv.world
	sec = p_sec
	sets = p_sets
	audio = p_audio
	marks = p_marks
	craft = p_craft
	act2 = p_act2
	jun = act2.jun
	ems = p_ems
	ring = marks.ring
	root = Node3D.new()
	root.name = "OmRingFight"
	lv.add_child(root)
	teth = OmRibbon.new(root, 0x6dffb8)
	jbolt = OmRibbon.new(root, 0xd8fff2)
	var gap_L := {}
	for j in 3:
		for g: int in GAP_AT:
			var G := Gap.new()
			G.span = j
			G.L = (_em_sector(j) + g) % 48
			G.c = (G.L + .5) * SEC
			gap_L[G.L] = true
			gaps.append(G)
	for k in RUN_N:
		var L := (RUN_FROM + k) % 48
		if gap_L.has(L):
			continue
		var G := Gap.new()
		G.L = L
		G.c = (L + .5) * SEC
		secs.append(G)
	for G: Gap in gaps + secs:
		G.spin = Vector3(randf_range(-.5, .5), 0.0, randf_range(-.5, .5))
	_cut()
	_find_sectors()
	for G in gaps:
		for _sd in 2:
			G.stubs.append(W.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": 4.25, "hz": .5, "top": FLOOR_TOP, "bottom": FLOOR_TOP - 2.6, "tag": "floor"}))
			for _k in 2:
				G.stubs.append(W.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": .13, "hz": .5, "top": FLOOR_TOP + 1.25, "bottom": FLOOR_TOP, "tag": "wall"}))
		for s in G.stubs:
			s.set_off(true)


func _em_sector(k: int) -> int:
	return int(floor(float(ems[k].a) / SEC))


static func _sector(q: float) -> int:
	return int(floor(fposmod(q, TAU) / SEC)) % 48


## which piece the ring's own angle a belongs to (an index into `all`, -1 = the ring itself). A gap owns the middle of its sector; the slivers either side go with the neighbours
func _owner(a: float, own: PackedInt32Array, is_gap: PackedByteArray, all: Array) -> int:
	var si := _sector(a)
	if is_gap[si] != 0:
		var d := angle_difference((all[own[si]] as Gap).c, a)
		if absf(d) <= GAP_H:
			return own[si]
		return own[(si + (1 if d > 0.0 else 47)) % 48]
	return own[si]


## cut the sections that can fall out of the ring's mesh: the ring keeps everything else, each section gets a mesh of its own about its own middle (so it can tumble)
func _cut() -> void:
	var mi: MeshInstance3D = null
	for c in ring.get_children():
		if c is MeshInstance3D:
			mi = c
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() != 1:
		push_warning("OmRingFight: the ring is not one mesh; the gaps will not show")
		return
	var src := mi.mesh.surface_get_arrays(0)
	var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX] if src[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(sv.size()))
	var main := Buf.new()
	main.v = sv
	if src[Mesh.ARRAY_NORMAL] != null:
		main.n = src[Mesh.ARRAY_NORMAL]
	if src[Mesh.ARRAY_TANGENT] != null:
		main.tg = src[Mesh.ARRAY_TANGENT]
	if src[Mesh.ARRAY_COLOR] != null:
		main.col = src[Mesh.ARRAY_COLOR]
	if src[Mesh.ARRAY_TEX_UV] != null:
		main.uv = src[Mesh.ARRAY_TEX_UV]
	if src[Mesh.ARRAY_TEX_UV2] != null:
		main.uv2 = src[Mesh.ARRAY_TEX_UV2]
	var keep := PackedInt32Array()
	var all: Array = gaps + secs
	var own := PackedInt32Array()
	own.resize(48)
	own.fill(-1)
	var is_gap := PackedByteArray()
	is_gap.resize(48)
	for gi in all.size():
		var G: Gap = all[gi]
		own[G.L] = gi
		is_gap[G.L] = 1 if G.span >= 0 else 0
		G.buf = Buf.new()
		G.buf.off = Vector3(cos(G.c) * RM, 0.0, sin(G.c) * RM)
	var plain := PackedByteArray()      # nothing to cut in this sector or next to it
	plain.resize(48)
	for si in 48:
		plain[si] = 1 if own[si] < 0 and own[(si + 1) % 48] < 0 and own[(si + 47) % 48] < 0 else 0
	var i := 0
	var n_idx := idx.size()
	var ids := [0, 0, 0]
	var ow := [0, 0, 0]
	var ang := [0.0, 0.0, 0.0]
	while i < n_idx:
		ids[0] = idx[i]
		ids[1] = idx[i + 1]
		ids[2] = idx[i + 2]
		i += 3
		var cen := sv[ids[0]] + sv[ids[1]] + sv[ids[2]]
		var ca := atan2(cen.z, cen.x)
		if plain[_sector(ca)] != 0:
			keep.append(ids[0])
			keep.append(ids[1])
			keep.append(ids[2])
			continue
		for k in 3:
			var p := sv[ids[k]]
			ang[k] = atan2(p.z, p.x)
			ow[k] = _owner(ang[k], own, is_gap, all)
		if ow[0] == ow[1] and ow[1] == ow[2]:
			if ow[0] < 0:
				keep.append(ids[0])
				keep.append(ids[1])
				keep.append(ids[2])
			else:
				var b: Buf = (all[ow[0]] as Gap).buf
				for k in 3:
					b.emit(src, ids[k], ids[k], 0.0)
			continue
		# across one edge between two pieces: find that edge (a sector line or a gap's edge) and split on the plane through the axis there
		var lo := 0.0
		var hi := 0.0
		for k in 3:
			var d := angle_difference(ca, ang[k])
			lo = minf(lo, d)
			hi = maxf(hi, d)
		var be := NAN
		var cands: Array = []
		for k in 3:
			var si := _sector(ang[k])
			cands.append(si * SEC)
			cands.append((si + 1) * SEC)
			if is_gap[si] != 0:
				var gc: float = (all[own[si]] as Gap).c
				cands.append(gc - GAP_H)
				cands.append(gc + GAP_H)
		for cb: float in cands:
			var d := angle_difference(ca, cb)
			if d > lo and d < hi and _owner(cb - .001, own, is_gap, all) != _owner(cb + .001, own, is_gap, all):
				be = cb
				break
		if is_nan(be):      # (should not happen: a triangle is at most 3 degrees wide) leave it on the ring
			keep.append(ids[0])
			keep.append(ids[1])
			keep.append(ids[2])
			continue
		var o_lo := _owner(be - .001, own, is_gap, all)
		var o_hi := _owner(be + .001, own, is_gap, all)
		var pn := Vector3(-sin(be), 0.0, cos(be))
		var los: Array = []
		var his: Array = []
		for k in 3:
			var a: int = ids[k]
			var b: int = ids[(k + 1) % 3]
			var da := sv[a].dot(pn)
			var db := sv[b].dot(pn)
			if da <= 0.0:
				los.append([a, a, 0.0])
			else:
				his.append([a, a, 0.0])
			if (da <= 0.0) != (db <= 0.0):
				var t := da / (da - db)
				los.append([a, b, t])
				his.append([a, b, t])
		for side: Array in [[los, o_lo], [his, o_hi]]:
			var poly: Array = side[0]
			var o: int = side[1]
			for k in range(1, poly.size() - 1):
				for q: Array in [poly[0], poly[k], poly[k + 1]]:
					if o < 0:
						keep.append(main.v.size())
						main.emit(src, q[0], q[1], q[2])
					else:
						(all[o] as Gap).buf.emit(src, q[0], q[1], q[2])
	var mat := mi.get_active_material(0)
	var arr := main.arrays(src)
	arr[Mesh.ARRAY_INDEX] = keep
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	mi.mesh = m
	for gi in all.size():
		var G: Gap = all[gi]
		var b := G.buf
		G.buf = null
		if b.v.is_empty():
			continue
		var gm := ArrayMesh.new()
		gm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays(src))
		gm.surface_set_material(0, mat)
		var p := MeshInstance3D.new()
		p.name = "ring-piece-%d" % gi
		p.mesh = gm
		p.layers = mi.layers
		p.cast_shadow = mi.cast_shadow
		G.pivot = mi.position + b.off
		p.position = G.pivot
		ring.add_child(p)
		G.piece = p


func _find_sectors() -> void:
	floors.resize(48)
	rails.resize(48)
	for i in 48:
		rails[i] = []
	for s: World.Solid in W.solids:
		var r := U.hyp(s.cx - OX, s.cz - OZ)
		if r < 72.5 or r > 82.5:
			continue
		var i := _sector(atan2(s.cz - OZ, s.cx - OX))
		if s.tag == "floor" and absf(s.top - FLOOR_TOP) < .05 and r > 75.0 and r < 79.5:
			floors[i] = s
		elif s.tag == "wall" and absf(s.bottom - FLOOR_TOP) < .05 and absf(s.top - FLOOR_TOP - 1.25) < .05:
			(rails[i] as Array).append(s)


func _after(t: float, fn: Callable) -> void:
	later.append({"t": t, "fn": fn})


## guards still standing between you and the active emitter, the gunship included (-1: its garrison is not here yet)
func guards_left() -> int:
	if wave == null or sec.cur_wave != wave:
		return -1
	var down := 0
	var up := 0
	for r: Robot in wave.spawned:
		if r.dead or r.gone:
			down += 1
		else:
			up += 1
	var n := maxi(up, squad_n - down) if wave.pending > 0 else up
	return n + (1 if boss_due else 0)


## the active emitter's garrison is dead: its shutters can go
func guards_down(n_dead: int) -> bool:
	return launched == n_dead and wave != null and sec.cur_wave == wave and wave.pending == 0 and guards_left() == 0


## the ring objective for n_dead emitters down is live: its garrison comes (once the ring has finished coming apart)
func begin(n_dead: int) -> void:
	if n_dead < 3:
		want = maxi(want, n_dead)


func _launch(n: int) -> void:
	launched = n
	sec.open_wave("ring%d" % n)
	wave = sec.cur_wave
	var in_t := 4.5
	var q: float = float(ems[n].a) - ring.rotation.y - marks.ring_w * (in_t + 1.2)      # where the emitter will be when the squad jumps
	var squad: Array = []
	for s: Dictionary in SQUADS[n]:
		var a := q + float(s.d) / RM
		var d := s.duplicate()
		d["land"] = [OX + cos(a) * float(s.r), DECK + float(s.get("up", 0.0)), OZ + sin(a) * float(s.r)]
		squad.append(d)
	squad_n = squad.size()
	var qa := q + .55
	var qb := q - .5
	sec.inject({"via": "ship", "in_t": in_t, "squad": squad,
		"from": [OX + cos(qa) * 230.0, DECK + 46.0, OZ + sin(qa) * 230.0],
		"hover": [OX + cos(q) * 79.5, DECK + 9.5, OZ + sin(q) * 79.5],
		"leave": [OX + cos(qb) * 260.0, DECK + 70.0, OZ + sin(qb) * 260.0]})
	if not told:
		told = true
		Game.hud.toast("DROPSHIP  -  THE GUARDS FEED THE EMITTER'S ARMOUR", 3.2)
	if n == 2:      # the last one: the gunship comes in as the dropship pulls out
		boss_due = true
		_after(9.0, _boss_in)


## an emitter died (n are down now): the ring comes apart a stretch further
func on_kill(n: int) -> void:
	if n >= 3:
		return
	hold_t = 7.0
	_after(3.4, func() -> void:
		var t0 := .5
		if not seized:
			_seize()
			t0 = SEIZE_T + .3
		else:
			_lurch()
		var k := 0
		for G in gaps:
			if G.span == n - 1:
				_after(t0 + k * .55, func() -> void: _drop(G, false))
				k += 1)


func _lurch() -> void:
	audio.play("sphereGroan")
	Game.fx.shake = maxf(Game.fx.shake, 1.6)
	marks.pulse({"max": 260.0, "kick": 1.2})


## the drive seizes: the ring jerks on to the next sector line and stops for good
func _seize() -> void:
	seized = true
	marks.ring_w = 0.0
	seize_from = ring.rotation.y
	seize_to = ceilf((seize_from + SEC * .35) / SEC) * SEC
	seize_t = 0.0
	_lurch()
	Game.hud.toast("THE RING HAS SEIZED  -  BURN ACROSS THE GAPS", 3.2)


func _boom_at(q: float) -> void:
	var p := Vector3(OX + cos(q) * RM, DECK, OZ + sin(q) * RM)
	sets.boom(p.x, p.y, p.z, 7.0, 0.0, {"harmless": true})
	Game.fx.explosion(p, 6.0)
	Game.fx.sparks(p, 60, 16.0, null, 0xffc060)
	audio.play_at("boomBig", p)


## a gap opens (instant: a checkpoint load, it is simply not there)
func _drop(G: Gap, instant: bool) -> void:
	if G.gone:
		return
	G.gone = true
	var q := G.c - ring.rotation.y
	var i := _sector(q)
	G.sector = i
	if floors[i] != null:
		(floors[i] as World.Solid).set_off(true)
	for s: World.Solid in rails[i]:
		s.set_off(true)
	var k := 0
	for sd: float in [-1.0, 1.0]:
		var qa := q + sd * (GAP_H + (SEC / 2.0 - GAP_H) / 2.0)
		for r: float in [RM, R_IN, R_OUT]:
			var s := G.stubs[k]
			k += 1
			s.place(OX + cos(qa) * r, OZ + sin(qa) * r, -qa)
			s.set_off(false)
	if G.piece == null:
		return
	if instant:
		G.piece.visible = false
		return
	G.fall = 0.0
	_boom_at(q)


## a whole sector of the run goes (and the stubs of any gap beside it)
func _drop_sector(G: Gap) -> void:
	if G.gone:
		return
	G.gone = true
	var q := G.c - ring.rotation.y
	var i := _sector(q)
	G.sector = i
	if floors[i] != null:
		(floors[i] as World.Solid).set_off(true)
	for s: World.Solid in rails[i]:
		s.set_off(true)
	for g in gaps:
		if g.L == (G.L + 1) % 48:
			for k in 3:
				g.stubs[k].set_off(true)
		elif g.L == (G.L + 47) % 48:
			for k in 3:
				g.stubs[3 + k].set_off(true)
	if G.piece != null:
		G.fall = 0.0
	if G.L == _em_sector(2):      # the dead emitter stands on this one
		var e: Variant = ems[2]
		fall_em = e.g
		fall_em_t = 0.0
		for s: World.Solid in e.body:
			s.set_off(true)
	_boom_at(q)
	marks.far_boom(Vector3(OX + cos(q) * RM, DECK - 6.0, OZ + sin(q) * RM), 9.0, .5)


func _restore(G: Gap) -> void:
	if G.gone:
		if floors[G.sector] != null:
			(floors[G.sector] as World.Solid).set_off(false)
		for s: World.Solid in rails[G.sector]:
			s.set_off(false)
	for s in G.stubs:
		s.set_off(true)
	G.gone = false
	G.fall = -1.0
	if G.piece != null:
		G.piece.visible = true
		G.piece.position = G.pivot
		G.piece.rotation = Vector3.ZERO


## put back for a stage (re)start. dead = emitters already down: the ring is as it stood after that many (seized, those stretches gone), turned so the last dead emitter is just behind the spawn. None down: emitter 0 is parked by the drop
func reset(dead: int, escape: bool) -> void:
	later.clear()
	for G: Gap in gaps + secs:
		_restore(G)
	_boss_free()
	boss_due = false
	jbolt_t = -1.0
	jbolt.node.visible = false
	exit_on = false
	front = -1.0
	if fall_em != null:
		fall_em.position.y = 0.0
		fall_em.rotation = Vector3.ZERO
	fall_em = null
	fall_em_t = -1.0
	for s: World.Solid in ems[2].body:
		s.set_off(false)
	seized = false
	seize_t = -1.0
	hold_t = 0.0
	want = -1
	launched = -1
	wave = null
	safe_ok = false
	told = false
	teth.node.visible = false
	if dead <= 0:
		if escape:
			ring.rotation.y = float(ems[0].a) - PARK
		return
	seized = true
	marks.ring_w = 0.0
	var e_last: float = ems[mini(dead, 3) - 1].a
	ring.rotation.y = roundf((e_last - (PI - 2.5 * SEC)) / SEC) * SEC
	for G in gaps:
		if G.span < mini(dead, 2):
			_drop(G, true)


## while you ride the lift and climb the riser the ring brings emitter 0 round to the drop and holds it there (so the first fight is always 27 m from where you land, and the run out is always the same stretch). on: you are on your way up
func park(dt: float, on: bool) -> void:
	if not on or seized:
		return
	var d := fposmod(float(ems[0].a) - ring.rotation.y - PARK, TAU)      # how far it still has to come (it only turns one way)
	if d > TAU - .02:
		d = 0.0
	marks.ring_w = clampf(d * .35, 0.0, .25)


# ------------------------------------------------------------------------------------------------ the gunship
func _boss_in() -> void:
	if boss != null:
		return
	var b := Boss.new()
	b.s = craft.gunship()
	b.s.group.scale = Vector3.ONE * 1.25
	var q: float = float(ems[2].a) - ring.rotation.y
	b.from = Vector3(OX + cos(q + .5) * 290.0, DECK + 60.0, OZ + sin(q + .5) * 290.0)
	b.s.group.position = b.from
	b.T = OmProp.make(9790, b.from.x, b.from.z, b.from.y, 4.5, 3.4, BOSS_HP)
	b.T.dead = false
	Game.combat.targets.append(b.T)
	b.hb = OmCraft.Hitboxes.new(b.T)
	b.last_hp = BOSS_HP
	boss = b
	audio.play_at("gunshipPass", b.from)
	Game.hud.toast("GUNSHIP!")


func _boss_free() -> void:
	if boss == null:
		return
	boss.s.free_model()
	boss.T.dead = true
	boss.hb.drop()
	boss = null


## where the gunship flies: back and forth off the outside of the ring by the last emitter
func _boss_path(b: Boss) -> Vector3:
	var q: float = float(ems[2].a) - ring.rotation.y + sin(b.t * .2) * .42
	var r := RM + 24.0 + cos(b.t * .31) * 5.0
	return Vector3(OX + cos(q) * r, DECK + 12.0 + sin(b.t * .7) * 2.5, OZ + sin(q) * r)


## Juniper puts a bolt into it: it reels
func _strike() -> void:
	var b := boss
	if b == null or b.ph == "crash" or b.ph == "done":
		return
	jun.hold(1.0, 7.0)
	jun.brace()
	jbolt_t = 0.0
	audio.play("bolt")
	audio.play("junSurge")
	var p := b.s.group.position
	Game.fx.explosion(p, 3.0)
	Game.fx.sparks(p, 80, 18.0, null, 0xc8fff0)
	Game.fx.shake = maxf(Game.fx.shake, 1.2)
	b.T.hp -= 60.0
	b.last_hp = b.T.hp
	b.ph = "stagger"
	b.stag_t = 5.0
	b.burst = 0
	Game.hud.toast("JUNIPER HIT IT  -  IT IS WIDE OPEN", 2.6)
	_after(2.5, func() -> void: jun.hold(0.0, 2.0))


func _update_boss(dt: float, P: Player, C: Combat) -> void:
	var b := boss
	if b == null or b.ph == "done":
		return
	b.t += dt
	b.s.update(dt)
	var g := b.s.group
	var T := b.T
	if b.ph == "crash":      # down into the emitter it was covering
		b.crash_t += dt
		var u := minf(1.0, b.crash_t / 1.7)
		var to: Vector3 = (ems[2].cap_glow as Node3D).global_position + Vector3(0.0, 2.0, 0.0)
		g.position = b.crash_from.lerp(to, u * u)
		g.rotation.z += dt * 3.4
		g.rotation.x += dt * .9
		if randf() < dt * 14.0:
			Game.fx.explosion(g.position + Vector3((randf() - .5) * 4.0, 1.0, (randf() - .5) * 4.0), 1.6)
		if u >= 1.0:
			sets.boom(to.x, to.y, to.z, 10.0, 30.0)
			Game.fx.explosion(to, 8.0)
			Game.fx.sparks(to, 120, 20.0, null, 0xffc060)
			Game.fx.shake = maxf(Game.fx.shake, 2.0)
			audio.play_at("boomBig", to)
			g.visible = false
			b.ph = "done"
			boss_due = false      # (the emitter's armour went with it: guards_down lets the shutters go)
		return
	# hits during a stagger count twice
	if b.ph == "stagger" and T.hp < b.last_hp:
		T.hp -= b.last_hp - T.hp
	b.last_hp = T.hp
	if T.hp <= 0.0:
		b.ph = "crash"
		b.crash_t = 0.0
		b.crash_from = g.position
		T.dead = true
		b.hb.drop()
		audio.play_at("boomBig", g.position)
		Game.fx.explosion(g.position, 4.0)
		Game.hud.toast("GUNSHIP DOWN")
		return
	if b.ph != "in" and b.strikes < 2 and T.hp <= BOSS_HP * (1.0 - (b.strikes + 1) / 3.0):
		b.strikes += 1
		jun.hold(1.0, 6.0)
		_after(.6, _strike)
	var want_p := _boss_path(b)
	var pos := want_p
	if b.ph == "in":
		var u := minf(1.0, b.t / 4.5)
		pos = b.from.lerp(want_p, 1.0 - pow(1.0 - u, 3.0))
		if u >= 1.0:
			b.ph = "fight"
	elif b.ph == "stagger":
		b.stag_t -= dt
		var q := atan2(want_p.z - OZ, want_p.x - OX)
		var low := Vector3(OX + cos(q) * (RM + 15.0), DECK + 6.5, OZ + sin(q) * (RM + 15.0))
		pos = g.position.lerp(low, minf(1.0, dt * 1.6))
		if randf() < dt * 10.0:
			Game.fx.sparks(g.position + Vector3((randf() - .5) * 5.0, 0.0, (randf() - .5) * 5.0), 10, 8.0, null, 0xc8fff0)
		if b.stag_t <= 0.0:
			b.ph = "fight"
			b.fire_t = 1.5
	else:
		pos = g.position.lerp(want_p, minf(1.0, dt * 1.4))
	# over the riser's tower (or anything else up here): climb and settle at limited speed, never a snap
	var lift_want := OmCraft.hull_lift(W, pos.x, pos.y + 5.0, pos.z, 0.0, 0.0, 10.0) if b.ph != "in" else 0.0
	var tv := clampf((lift_want - b.lift) * 2.2, -2.2, 7.0)
	b.lv += (tv - b.lv) * minf(1.0, dt * 3.5)
	b.lift = maxf(0.0, b.lift + b.lv * dt)
	g.position = pos
	var py := pos.y + b.lift
	g.position.y = py
	if P != null:
		g.rotation.y = atan2(P.x - pos.x, P.z - pos.z)
	g.rotation.x = 0.0
	g.rotation.z = -.15 + (sin(b.t * 9.0) * .35 if b.ph == "stagger" else 0.0)
	b.hb.sync(pos.x, py, pos.z, g.rotation.y)
	if b.ph != "fight" or P == null or P.dead or C == null:
		return
	b.fire_t -= dt
	b.missile_t -= dt
	if b.fire_t <= 0.0:
		if b.burst <= 0:
			b.burst = 7
		var o := g.position + Vector3(0, -2, 0)
		var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z).normalized()
		d.x += (randf() - .5) * .06
		d.z += (randf() - .5) * .06
		C.enemies.fire_from(T.id, o.x, o.y, o.z, d.x, d.y, d.z, {"kind": "plasma", "speed": 36.0, "dmg": 7.0, "r": .2})
		b.burst -= 1
		b.fire_t = .13 if b.burst > 0 else 3.2
	if b.missile_t <= 0.0:
		b.missile_t = 8.0
		for k in 2:
			var a := atan2(P.z - OZ, P.x - OX) + (randf() - .5) * .1
			var to := Vector3(OX + cos(a) * RM, DECK, OZ + sin(a) * RM)
			sets.after(k * .3, func() -> void:
				if boss == b and b.ph == "fight" and is_instance_valid(b.s.group):
					act2._missile(b.s.group.position + Vector3(0, -1.5, 0), to))


# ------------------------------------------------------------------------------------------------ the run
## how far along the run a point is, in metres from where the collapse starts (negative: behind it)
func _run_s(x: float, z: float) -> float:
	return angle_difference(RUN_FROM * SEC - ring.rotation.y, atan2(z - OZ, x - OX)) * RM


## the lifter's place: off the far end of the run (a world angle)
func pickup_angle() -> float:
	return (RUN_FROM + ZONE_AT + 2.5) * SEC - ring.rotation.y


## far enough along the run that going off the ring is the way out (before that a fall puts you back, and costs you)
func in_zone(P: Player) -> bool:
	return not exit_on or (P != null and _run_s(P.x, P.z) >= ZONE_AT * SEC * RM - 1.0)


## the last emitter is gone: the stretch ahead loses its three sections, then the ring starts to go from behind
func start_exit() -> void:
	if exit_on:
		return
	exit_on = true
	front = -1.0
	var k := 0
	for G in gaps:
		if G.span == 2:
			_after(4.2 + k * .4, func() -> void: _drop(G, false))
			k += 1
	_after(5.6, func() -> void: front = 0.0)


func _update_exit(dt: float, P: Player, C: Combat) -> void:
	if front < 0.0:
		return
	var me := _run_s(P.x, P.z)
	var behind := me - front
	front = minf(RUN_N * SEC * RM, front + dt * (6.0 + clampf((behind - 16.0) / 30.0, 0.0, 1.0) * 9.0))
	for G in secs:
		if not G.gone and front >= fposmod(float(G.L - RUN_FROM), 48.0) * SEC * RM:
			_drop_sector(G)
	if randf() < dt * 5.0:      # the stretch already gone keeps going off behind you
		var s := front - 10.0 - randf() * 60.0
		var q := RUN_FROM * SEC - ring.rotation.y + s / RM
		marks.far_boom(Vector3(OX + cos(q) * RM, DECK - randf() * 20.0, OZ + sin(q) * RM), randf_range(6.0, 11.0), .3)
	# off the ring short of the lifter: back on it ahead of the collapse, and it hurts
	if not P.dead and P.y < DECK - 14.0 and not in_zone(P):
		var s := maxf(front + 14.0, _run_s(safe.x, safe.z) if safe_ok else -1e9)
		var q := RUN_FROM * SEC - ring.rotation.y + s / RM
		for G in gaps:      # never onto a hole
			if G.gone and absf(angle_difference(G.c - ring.rotation.y, q)) < GAP_H + .03:
				q = G.c - ring.rotation.y + GAP_H + .06
		P.x = OX + cos(q) * RM
		P.y = DECK + .05
		P.z = OZ + sin(q) * RM
		P.vx = 0.0
		P.vy = 0.0
		P.vz = 0.0
		Game.rig.snap_to(P)
		C.hurt_player(P, 25.0, P.x + sin(q), P.z - cos(q), "melee")      # (from behind him along the run: any shove is onward, never off the edge)


## dq: how far the ring turned this frame. live: the emitters are still being fought
func update(dt: float, P: Player, C: Combat, dq: float, live: bool) -> void:
	for i in range(later.size() - 1, -1, -1):
		later[i].t = float(later[i].t) - dt
		if float(later[i].t) <= 0.0:
			var f: Callable = later[i].fn
			later.remove_at(i)
			f.call()
	if seize_t >= 0.0:
		seize_t += dt
		var u := minf(1.0, seize_t / SEIZE_T)
		ring.rotation.y = lerpf(seize_from, seize_to, 1.0 - pow(1.0 - u, 3.0))
		if randf() < dt * 30.0:
			var a := randf() * TAU
			Game.fx.sparks(Vector3(OX + cos(a) * R0, OY + .4, OZ + sin(a) * R0), 8, 9.0, null, 0xffc060)
		if u >= 1.0:
			seize_t = -1.0
	for G: Gap in gaps + secs:
		if G.fall >= 0.0:
			G.fall += dt
			G.piece.position = G.pivot + Vector3(0.0, -9.0 * G.fall * G.fall, 0.0)
			G.piece.rotation = G.spin * G.fall
			if G.fall > 5.0:
				G.fall = -1.0
				G.piece.visible = false
	if fall_em_t >= 0.0:
		fall_em_t += dt
		fall_em.position.y = -9.0 * fall_em_t * fall_em_t
		if fall_em_t > 5.0:
			fall_em_t = -1.0
	hold_t = maxf(0.0, hold_t - dt)
	if live and want > launched and hold_t <= 0.0:
		_launch(want)
	_update_boss(dt, P, C)
	if jbolt_t >= 0.0:      # Juniper's bolt up into the gunship
		jbolt_t += dt
		jbolt_re -= dt
		if jbolt_re <= 0.0 and boss != null:
			jbolt_re = .045
			var a := jun.group.position + Vector3(0, 11.0, 0)
			var c := boss.s.group.position
			jbolt.clear()
			jbolt.ribbon(a, c, 26, 12.0, 1.1, 4)
			jbolt.ribbon(a, c, 20, 18.0, .5, 2)
			jbolt.flush()
		jbolt.node.visible = randf() > .12
		jbolt.set_alpha(minf(1.0, (1.0 - jbolt_t / .9) * 2.2))
		if jbolt_t >= .9 or boss == null:
			jbolt_t = -1.0
			jbolt.node.visible = false
	var any := false
	if wave != null and sec.cur_wave == wave:
		for r: Robot in wave.spawned:
			if r.dead or r.gone:
				continue
			any = true
			if r.drone:
				continue
			if r.y < DECK - 10.0:      # off the ring: he is not coming back
				C.damage(r, 1e4, {"x": r.x, "z": r.z}, 0.0)
			elif dq != 0.0 and absf(r.y - DECK) < .5:      # the ring carries the guards as it carries you
				var dx := r.x - OX
				var dz := r.z - OZ
				var c := cos(dq)
				var s := sin(dq)
				r.x = OX + dx * c + dz * s
				r.z = OZ - dx * s + dz * c
				r.yaw += dq
	# the arcs from the emitter to whoever still feeds it
	teth_t -= dt
	if not live or not any or launched < 0:
		teth.node.visible = false
	elif teth_t <= 0.0:
		teth_t = .06
		var from: Vector3 = (ems[launched].cap_glow as Node3D).global_position + Vector3(0.0, 2.6, 0.0)
		teth.clear()
		for r: Robot in wave.spawned:
			if r.dead or r.gone or r.dev_passive:
				continue
			var to := Vector3(r.x, r.y + (.3 if r.drone else 1.4), r.z)
			if from.distance_to(to) < 70.0:
				teth.ribbon(from, to, 9, 1.1, .16)
		teth.flush()
		teth.node.visible = true
	if P == null or P.dead:
		return
	# the last piece of ring he stood on (never the lip of a gap)
	if seized and P.grounded and absf(P.y - DECK) < .3:
		var r := U.hyp(P.x - OX, P.z - OZ)
		if r > R0 + .5 and r < R1 - .5:
			var q := atan2(P.z - OZ, P.x - OX)
			var clear := true
			for G in gaps:
				if G.gone and absf(angle_difference(G.c - ring.rotation.y, q)) < GAP_H + .03:
					clear = false
			if clear:
				safe = Vector3(P.x, DECK, P.z)
				safe_ok = true
	if exit_on:
		_update_exit(dt, P, C)
	elif seized and live and safe_ok and P.y < DECK - 14.0:      # a fall into a gap: back where he stood (no 170 m wait for the magma)
		P.x = safe.x
		P.y = safe.y + .05
		P.z = safe.z
		P.vx = 0.0
		P.vy = 0.0
		P.vz = 0.0
		Game.rig.snap_to(P)
