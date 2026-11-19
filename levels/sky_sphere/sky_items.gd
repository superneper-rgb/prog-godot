class_name SkyItems
extends Node3D
## The Overcurrent's pickups (user's pick, 2026-11-18: all five). Rows of item boxes across the deck give a craft one item after a short roulette,
## better ones the further back it is running:
##   SHOCK MINE     dropped behind; whoever runs over it loses its grip and gets kicked sideways
##   MAG HARPOON    latches onto the craft ahead, reels you in and slingshots you past (come in hot enough and it is a shunt)
##   RAM SHELL      a heavy plasma hull for a few seconds: anything it touches is slammed aside, walls cannot wreck you
##   GRAVITY PULSE  a ring that shoves every craft near you sideways, into the walls and off the edges
##   OVERCHARGE     the boost meter full, and one segment over it for a few seconds (it burns like any boost since 2026-11-19)
## Items only make crashes: what knocks a craft into a wall marks it (hit_by / hit_how), and sky_race.gd scores the takedown as ever.
## The rivals use them too (ai_use). Also the Hydro Thunder boost icons (user, 2026-11-18): blue ones top the boost meter up, red ones fill
## a lot of it and sit on the risky lines. Everything here dies with the level.

enum { NONE = -1, MINE, HARPOON, SHELL, PULSE, OVERCHARGE }
const NAMES: Array[String] = ["SHOCK MINE", "MAG HARPOON", "RAM SHELL", "GRAVITY PULSE", "OVERCHARGE"]
const COLORS: Array[Color] = [Color("ff4a3d"), Color("59e1ff"), Color("ff9a2e"), Color("b67dff"), Color("ffe45c")]
const BOX_BACK := 1.2          # seconds before a taken box is back (the pack runs close: longer and the middle of it found none)
const BOX_REACH := 2.4
const MINE_LIFE := 30.0
const MINE_REACH := 1.7
const MINES := 16
const SHELL_TIME := 4.0
const SHELL_MASS := 3.0
const OVER_TIME := 6.0
const PULSE_REACH := 18.0
const HARPOON_TIME := 2.2
const HARPOON_PULL := 72.0
const HARPOON_CLOSE := 42.0     # the reel stops pulling past this closing speed (fast enough to shunt the target)
const HARPOON_RANGE := 150.0
const ROULETTE := 1.0
const ICON_REACH := 2.6
const ICON_BACK := 5.0         # seconds before a taken icon is back
const ICON_BLUE := 0.35        # boost meter segments an icon gives (less since 2026-11-19: boost has to run out)
const ICON_RED := 1.1
# the odds of each item for the craft in front and for the one at the back (in between: a blend)
const ODDS_FRONT: Array[float] = [0.45, 0.05, 0.25, 0.2, 0.05]
const ODDS_BACK: Array[float] = [0.05, 0.3, 0.2, 0.15, 0.3]


class Box:
	var at := Transform3D.IDENTITY
	var back := 0.0        # seconds until it is there again (0: there)


class Mine:
	var pos := Vector3.ZERO
	var basis := Basis.IDENTITY
	var owner: SkyRace.Racer = null
	var life := 0.0
	var safe := 0.0        # the one who dropped it cannot set it off for this long
	var on := false


class Ring:
	var node: MeshInstance3D
	var age := 9.0


var race: SkyRace
var boxes: Array[Box] = []
var icons: Array[Box] = []
var _icon_red: Array[bool] = []
var _icon_mm: MultiMesh
var mines: Array[Mine] = []
var _rings: Array[Ring] = []
var _box_mm: MultiMesh
var _mine_mm: MultiMesh
var _tethers: Array[MeshInstance3D] = []
var _shells: Array[MeshInstance3D] = []
var _next_mine := 0


func build(owner_race: SkyRace) -> void:
	name = "Pickups"
	race = owner_race
	var course := race.course
	for row: Vector2i in course.item_rows:
		var p := course.paths[row.x]
		var fr := p.frames[row.y]
		var n := 2 if row.x != SkyCourse.MAIN else 5
		var w := minf(p.wl[row.y], p.wr[row.y]) - 1.8
		for k in n:
			var b := Box.new()
			b.at = Transform3D(fr.basis, fr * Vector3(lerpf(-w, w, float(k) / float(n - 1)), 1.2, 0.0))
			boxes.append(b)
	for c: SkyCourse.Icon in course.icons:
		var fr := course.frame(c.path, c.i)
		var b := Box.new()
		b.at = Transform3D(fr.basis, fr * Vector3(c.u, 1.5, 0.0))
		icons.append(b)
		_icon_red.append(c.red)
	var hexa := CylinderMesh.new()
	hexa.top_radius = 0.95
	hexa.bottom_radius = 0.95
	hexa.height = 0.22
	hexa.radial_segments = 6
	hexa.rings = 1
	var icon_mat := _material(preload("res://levels/sky_sphere/sky_boost_icon.gdshader"))
	_icon_mm = _batch(hexa, icon_mat, maxi(1, icons.size()), true)
	for i in icons.size():
		_icon_mm.set_instance_color(i, Color("ff2a1a") if _icon_red[i] else Color("3aa8ff"))
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.25
	_box_mm = _batch(box, _material(preload("res://levels/sky_sphere/sky_item_box.gdshader")), boxes.size())
	var disc := SphereMesh.new()
	disc.radius = 0.6
	disc.height = 0.36
	disc.radial_segments = 12
	disc.rings = 4
	_mine_mm = _batch(disc, _material(preload("res://levels/sky_sphere/sky_mine.gdshader")), MINES)
	for i in MINES:
		var m := Mine.new()
		mines.append(m)
	var glow := preload("res://levels/sky_sphere/sky_item_glow.gdshader")
	var beam := BoxMesh.new()
	beam.size = Vector3.ONE
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	for r: SkyRace.Racer in race.racers:
		var tether := MeshInstance3D.new()
		tether.mesh = beam
		tether.material_override = _material(glow, COLORS[HARPOON], 2.4)
		tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tether.top_level = true
		tether.hide()
		add_child(tether)
		_tethers.append(tether)
		var shell := MeshInstance3D.new()
		shell.mesh = ball
		shell.material_override = _material(glow, COLORS[SHELL], 1.5)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.scale = Vector3(r.car.half.x * 1.55, 1.25, r.car.half.z * 1.25)
		shell.position = Vector3.UP * 0.55
		shell.hide()
		r.model.root.add_child(shell)
		_shells.append(shell)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var ring_mat := _material(preload("res://levels/sky_sphere/sky_item_ring.gdshader"), COLORS[PULSE], 2.0)
	for i in 4:
		var ring := Ring.new()
		ring.node = MeshInstance3D.new()
		ring.node.mesh = plane
		ring.node.material_override = ring_mat
		ring.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.node.hide()
		add_child(ring.node)
		_rings.append(ring)
	reset()


func reset() -> void:
	for i in boxes.size():
		boxes[i].back = 0.0
		_box_mm.set_instance_transform(i, boxes[i].at)
	for i in icons.size():
		icons[i].back = 0.0
		_icon_mm.set_instance_transform(i, _icon_pose(icons[i].at))
	for i in mines.size():
		mines[i].on = false
		_mine_mm.set_instance_transform(i, _hidden())
	for k in race.racers.size():
		var r := race.racers[k]
		r.item = NONE
		r.item_next = NONE
		r.roulette = 0.0
		r.item_t = 0.0
		r.shell = 0.0
		r.harpoon = 0.0
		r.harpoon_to = null
		r.over = 0.0
		r.car.mass = r.base_mass
		_tethers[k].hide()
		_shells[k].hide()
	for ring: Ring in _rings:
		ring.age = 9.0
		ring.node.hide()


func tick(dt: float) -> void:
	_boxes(dt)
	_icons(dt)
	_mines(dt)
	for k in race.racers.size():
		var r := race.racers[k]
		if r.roulette > 0.0:
			r.roulette -= dt
			if r.roulette <= 0.0:
				r.item = r.item_next
				r.item_next = NONE
				r.item_t = 0.0
				if r == race.player_racer():
					race.cue(SkyDriveFx.Cue.ITEM)
		if r.item != NONE:
			r.item_t += dt
			if r.brain != null and race.racing() and not r.car.wrecked:
				_ai_use(r)
		_harpoon(r, k, dt)
		if r.shell > 0.0:
			r.shell -= dt
			if r.shell <= 0.0 or r.car.wrecked:
				r.shell = 0.0
				r.car.mass = r.base_mass
		_shells[k].visible = r.shell > 0.0 and (r.shell > 0.8 or fmod(r.shell * 10.0, 1.0) > 0.4)
		if r.over > 0.0:
			r.over -= dt
			if r.over <= 0.0:
				r.over = 0.0
				r.meter = minf(r.meter, r.meter_max)
	for ring: Ring in _rings:
		if ring.age < 0.6:
			ring.age += dt
			var k := ring.age / 0.5
			ring.node.scale = Vector3.ONE * (1.0 + PULSE_REACH * smoothstep(0.0, 1.0, k))
			ring.node.set_instance_shader_parameter(&"fade", clampf(1.0 - k, 0.0, 1.0))
			ring.node.visible = ring.age < 0.5


## The craft lost what it was holding (a wreck).
func drop(r: SkyRace.Racer) -> void:
	r.item = NONE
	r.item_next = NONE
	r.roulette = 0.0
	r.harpoon = 0.0
	r.harpoon_to = null


func use(r: SkyRace.Racer) -> void:
	if r.item == NONE or r.roulette > 0.0 or r.car.wrecked:
		return
	var is_me := r == race.player_racer()
	race.item_log.append("%.1fs %s %s" % [race.race_time(), r.title, NAMES[r.item]])
	match r.item:
		MINE:
			_drop_mine(r)
			race.cue_near(SkyDriveFx.Cue.DROP, r.car.pos)
		HARPOON:
			var target := _ahead(r)
			if target == null:
				if is_me:
					race.pop("NO LOCK")
				return
			r.harpoon = HARPOON_TIME
			r.harpoon_to = target
			race.cue_near(SkyDriveFx.Cue.HARPOON, r.car.pos)
			if target == race.player_racer():
				race.pop("HARPOONED", "BY " + r.title)
		SHELL:
			r.shell = SHELL_TIME
			r.car.mass = r.base_mass * SHELL_MASS
			race.cue_near(SkyDriveFx.Cue.SHELL, r.car.pos)
			if is_me:
				race.pop("RAM SHELL", "", true)
		PULSE:
			_pulse(r)
		OVERCHARGE:
			r.over = OVER_TIME
			r.meter = r.meter_max + 1.0
			race.cue_near(SkyDriveFx.Cue.BOOST, r.car.pos)
			if is_me:
				race.pop("OVERCHARGE", "", true)
	r.item = NONE


# ----------------------------------------------------------------- boxes ----

func _boxes(dt: float) -> void:
	for i in boxes.size():
		var b := boxes[i]
		if b.back > 0.0:
			b.back -= dt
			if b.back <= 0.0:
				_box_mm.set_instance_transform(i, b.at)
			continue
		for r: SkyRace.Racer in race.racers:
			if r.car.wrecked or r.ghost > 0.0:
				continue
			if r.car.pos.distance_squared_to(b.at.origin) > BOX_REACH * BOX_REACH:
				continue
			b.back = BOX_BACK
			_box_mm.set_instance_transform(i, _hidden())
			Game.fx.sparks(b.at.origin, 8, 6.0, null, 0xd8f6ff)
			if r.item == NONE and r.roulette <= 0.0:
				r.item_next = _roll(r)
				r.roulette = ROULETTE if r == race.player_racer() else 0.6
				if r == race.player_racer():
					race.cue(SkyDriveFx.Cue.TICK)
			break


## The boost icons: whoever reaches one takes its boost (the icon stands on its edge, turned to face down the road).
func _icons(dt: float) -> void:
	for i in icons.size():
		var b := icons[i]
		if b.back > 0.0:
			b.back -= dt
			if b.back <= 0.0:
				_icon_mm.set_instance_transform(i, _icon_pose(b.at))
			continue
		for r: SkyRace.Racer in race.racers:
			if r.car.wrecked or r.ghost > 0.0:
				continue
			if r.car.pos.distance_squared_to(b.at.origin) > ICON_REACH * ICON_REACH:
				continue
			b.back = ICON_BACK
			_icon_mm.set_instance_transform(i, _hidden())
			race.boost_icon(r, ICON_RED if _icon_red[i] else ICON_BLUE, _icon_red[i])
			Game.fx.sparks(b.at.origin, 10, 7.0, null, 0xff5030 if _icon_red[i] else 0x60b8ff)
			break


static func _icon_pose(at: Transform3D) -> Transform3D:
	return Transform3D(at.basis * Basis(Vector3.RIGHT, PI * 0.5), at.origin)


## A fair draw for where the craft is running: the leader mostly gets mines and shells, the back of the field harpoons and overcharges.
func _roll(r: SkyRace.Racer) -> int:
	var n := race.racers.size()
	var back := clampf(float(r.rank - 1) / float(maxi(1, n - 1)), 0.0, 1.0)
	var total := 0.0
	var odds: Array[float] = []
	for i in NAMES.size():
		var o := lerpf(ODDS_FRONT[i], ODDS_BACK[i], back)
		odds.append(o)
		total += o
	var pick := randf() * total
	for i in odds.size():
		pick -= odds[i]
		if pick <= 0.0:
			return i
	return OVERCHARGE


# ----------------------------------------------------------------- mines ----

func _drop_mine(r: SkyRace.Racer) -> void:
	var course := race.course
	var car := r.car
	var at := car.pos - car.basis.z * (car.half.z + 1.6)
	var i := course.locate(car.path, car.index, at, 10, 3)
	var local := course.q_local
	if not course.on_deck(car.path, i, local):
		return      # (dropped over a gap: it falls away)
	var fr := course.frame(car.path, i)
	var m := mines[_next_mine]
	m.on = true
	m.pos = fr * Vector3(local.x, 0.3, local.z)
	m.basis = fr.basis
	m.owner = r
	m.life = MINE_LIFE
	m.safe = 1.2
	_mine_mm.set_instance_transform(_next_mine, Transform3D(m.basis, m.pos))
	_next_mine = (_next_mine + 1) % MINES


func _mines(dt: float) -> void:
	for i in mines.size():
		var m := mines[i]
		if not m.on:
			continue
		m.life -= dt
		m.safe -= dt
		if m.life <= 0.0:
			m.on = false
			_mine_mm.set_instance_transform(i, _hidden())
			continue
		for o: SkyRace.Racer in race.everyone:
			if o.car.wrecked or o.ghost > 0.0 or (o == m.owner and m.safe > 0.0):
				continue
			var reach := MINE_REACH + o.car.half.x * 0.6
			if o.car.pos.distance_squared_to(m.pos) > reach * reach:
				continue
			m.on = false
			_mine_mm.set_instance_transform(i, _hidden())
			Game.fx.explosion(m.pos, 1.2)
			Game.fx.sparks(m.pos, 16, 9.0, m.basis.y, 0xff6050)
			race.cue_near(SkyDriveFx.Cue.ZAP, m.pos)
			_shock(o, m.owner, "MINE", 1.0)
			if o == race.player_racer():
				race.pop("SHOCK MINE", "")
			break


## A craft knocked off its line by an item: grip gone for a moment, kicked up and round, and marked so a wall or the drop counts for the one who did it.
func _shock(o: SkyRace.Racer, by: SkyRace.Racer, how: String, strength: float) -> void:
	var car := o.car
	var up := car.road.basis.y
	car.stagger = maxf(car.stagger, 0.6 + 0.5 * strength)
	car.vel *= 1.0 - 0.18 * strength
	car.vel += up * (3.0 + 2.0 * strength)
	car.spin += up * (randf_range(-1.0, 1.0) * 3.0 * strength)
	if by != null and by != o:
		o.hit_by = by
		o.hit_t = race.race_time()
		o.hit_how = how


# --------------------------------------------------------------- harpoon ----

## The nearest rival ahead on the lap within reach, or null.
func _ahead(r: SkyRace.Racer) -> SkyRace.Racer:
	var best: SkyRace.Racer = null
	var gap_best := HARPOON_RANGE
	for o: SkyRace.Racer in race.racers:
		if o == r or o.car.wrecked or o.ghost > 0.0:
			continue
		var gap := o.progress - r.progress
		if gap > 6.0 and gap < gap_best:
			gap_best = gap
			best = o
	return best


func _harpoon(r: SkyRace.Racer, k: int, dt: float) -> void:
	var tether := _tethers[k]
	if r.harpoon <= 0.0 or r.harpoon_to == null:
		tether.hide()
		return
	var t := r.harpoon_to
	if r.car.wrecked or t.car.wrecked or t.ghost > 0.0:
		r.harpoon = 0.0
		r.harpoon_to = null
		tether.hide()
		return
	var a := r.car.pos + r.car.basis.y * 0.4
	var b := t.car.pos + t.car.basis.y * 0.4
	var d := t.car.pos - r.car.pos
	var dist := d.length()
	r.harpoon -= dt
	if dist < 9.0 or r.harpoon <= 0.0:
		# let go and slingshot past
		r.car.turbo = maxf(r.car.turbo, 1.3 if dist < 9.0 else 0.8)
		t.hit_by = r
		t.hit_t = race.race_time()
		t.hit_how = "HARPOON"
		r.harpoon = 0.0
		r.harpoon_to = null
		tether.hide()
		if r == race.player_racer():
			race.pop("SLINGSHOT", "", true)
			race.cue(SkyDriveFx.Cue.BOOST)
		return
	var dir := d / dist
	if (r.car.vel - t.car.vel).dot(dir) < HARPOON_CLOSE:
		r.car.vel += dir * (HARPOON_PULL * dt)
	r.car.turbo = maxf(r.car.turbo, 0.2)
	tether.global_transform = SkyGeometry.beam(a, b, 0.14, 0.14)
	tether.show()


# ----------------------------------------------------------------- pulse ----

func _pulse(r: SkyRace.Racer) -> void:
	var centre := r.car.pos
	var up := r.car.road.basis.y
	for ring: Ring in _rings:
		if ring.age >= 0.5:
			ring.age = 0.0
			ring.node.global_transform = Transform3D(r.car.road.basis, centre - up * 0.3)
			ring.node.scale = Vector3.ONE
			ring.node.show()
			break
	race.cue_near(SkyDriveFx.Cue.ZAP, centre)
	Game.fx.sparks(centre, 20, 12.0, up, 0xc89bff)
	var hit := 0
	for o: SkyRace.Racer in race.everyone:
		if o == r or o.car.wrecked or o.ghost > 0.0:
			continue
		var d := o.car.pos - centre
		var dist := d.length()
		if dist > PULSE_REACH:
			continue
		var flat := d - up * d.dot(up)
		if flat.length() < 0.1:
			flat = r.car.basis.x
		var k := 1.0 - dist / PULSE_REACH
		o.car.vel += flat.normalized() * (10.0 + 22.0 * k) + up * (2.0 + 3.0 * k)
		_shock(o, r, "PULSE", 0.4 + 0.6 * k)
		hit += 1
		if o == race.player_racer():
			race.pop("PULSED", "BY " + r.title)
	if r == race.player_racer():
		race.pop("GRAVITY PULSE", "%d HIT" % hit if hit > 0 else "", true)


# -------------------------------------------------------------------- AI ----

## When a rival lets its item go: when it would do some harm, or when it has held it long enough.
func _ai_use(r: SkyRace.Racer) -> void:
	if r.item_t < 0.8 or race.race_time() < 6.0:      # (not off the grid: the whole field went into the walls of the first dive)
		return
	var car := r.car
	match r.item:
		MINE:
			if r.item_t > 9.0 or _someone(r, -32.0, -4.0, 4.0):
				use(r)
		HARPOON:
			var t := _ahead(r)
			if t != null and (t.progress - r.progress > 18.0 or r.item_t > 10.0):
				use(r)
		SHELL:
			if r.item_t > 10.0 or _someone(r, -6.0, 10.0, 5.0):
				use(r)
		PULSE:
			if r.item_t > 12.0 or _someone(r, -10.0, 10.0, 9.0):
				use(r)
		OVERCHARGE:
			var p := race.course.paths[car.path]
			if r.item_t > 8.0 or (p.pace[p.wrap(car.index + 30)] > 80.0 and p.pace[p.wrap(car.index + 12)] > 80.0):
				use(r)


## Is any other craft between `back` and `ahead` metres along this one's nose, and within `side` across it?
func _someone(r: SkyRace.Racer, back: float, ahead: float, side: float) -> bool:
	for o: SkyRace.Racer in race.everyone:
		if o == r or o.car.wrecked:
			continue
		var rel := o.car.pos - r.car.pos
		var z := rel.dot(r.car.basis.z)
		if z > back and z < ahead and absf(rel.dot(r.car.basis.x)) < side:
			return true
	return false


# ----------------------------------------------------------------- looks ----

func _batch(mesh: Mesh, material: Material, count: int, colours: bool = false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colours
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 400.0
	add_child(node)
	return mm


func _material(shader: Shader, colour: Color = Color.WHITE, power: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"tint", colour)
	m.set_shader_parameter(&"power", power)
	return m


static func _hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0.0, -500.0, 0.0))
