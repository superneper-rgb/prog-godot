class_name Gadgets
extends Node3D
## How the arena gadgets look and sound (JS class Gadgets): Saw-Loop discs and their aiming guide, Bellows Beast rings, Moon Yoke stones, gravity wells, the Electranator's lightning. The simulation lives in Combat.
## Everything is pooled: instance lists written while a gadget is live, hidden when none is, and one ImmediateMesh for the thin lines. Looping voices come from Sfx.voice_start.

const PLAIN_ADD := preload("res://fx/plain_add.gdshader")
const PLAIN_ADD_DOUBLE := preload("res://fx/plain_add_double.gdshader")
const GLOW_SPRITE := preload("res://fx/glow_sprite.gdshader")
const WELL_POINTS := preload("res://fx/well_points.gdshader")
const BELL_W0 := 1.6            # JS BELL
const BELL_W1 := 3.6
const BELL_RANGE := 28.0
const ARC_RAD: Array[float] = [0.012, 0.034, 0.085]

class DiscState:
	var rot := 0.0
	var hist := PackedVector3Array()
	var v: Sfx.SpatialVoice = null

class Blast:
	var o := Vector3.ZERO
	var dir := Vector3.FORWARD
	var basis_ := Basis.IDENTITY
	var len_ := 0.0
	var t := 0.0

class RockState:
	var rx := 0.0
	var rz := 0.0
	var r := 0.3
	var parts: Array = []       # [offset, scale]

class WellState:
	var v: Sfx.SpatialVoice = null
	var pts: MultiMeshInstance3D = null

var fx: FX
var flail: FlailView            # the SCORPION FLAIL's ball and chain
var t := 0.0
var saws := {}
var rocks := {}
var wells := {}
var blasts: Array[Blast] = []
var charge: Sfx.SpatialVoice = null
var arc_v: Sfx.SpatialVoice = null
var arc_v2: Sfx.SpatialVoice = null
var _last := {}
var _lines: ImmediateMesh
var _lines_mi: MeshInstance3D
var _ring_mi: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _disc: FX.InstList
var _wave: FX.InstList
var _arc: FX.InstList
var _spr: FX.InstList
var _stone: FX.InstList
var _glow: FX.InstList
var _w_core: FX.InstList
var _w_ring: FX.InstList
var _well_pool: Array[MultiMeshInstance3D] = []
var _light: OmniLight3D
var _blast_light: OmniLight3D
var _arc_light: OmniLight3D
var _blast_energy := 0.0


func _init(p_fx: FX) -> void:
	fx = p_fx
	name = "Gadgets"


func _ready() -> void:
	flail = FlailView.new(fx)
	add_child(flail)
	_lines = ImmediateMesh.new()
	_lines_mi = MeshInstance3D.new()
	_lines_mi.mesh = _lines
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lines_mi.material_override = lm
	_lines_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines_mi.custom_aabb = AABB(Vector3(-20000, -20000, -20000), Vector3(40000, 40000, 40000))
	_lines_mi.visible = false
	add_child(_lines_mi)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.albedo_color = Color(fx._c(0xffd27a), 0.9)
	_ring_mi = MeshInstance3D.new()
	_ring_mi.mesh = FxMesh.ring(0.1, 0.17, 24)
	_ring_mi.material_override = _ring_mat
	_ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mi.visible = false
	add_child(_ring_mi)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.vertex_color_use_as_albedo = true
	disc_mat.roughness = 0.6
	_disc = FX.InstList.new(self, FxMesh.saw_disc(0.3, 16, fx._c(0xe8dcc4), fx._c(0xc27a45)), disc_mat, 16, "saw discs")
	var add_d := ShaderMaterial.new()
	add_d.shader = PLAIN_ADD_DOUBLE
	_wave = FX.InstList.new(self, FxMesh.torus_z(1.0, 0.045, 6, 44), add_d, 48, "bellows rings")
	var add_m := ShaderMaterial.new()
	add_m.shader = PLAIN_ADD
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_arc = FX.InstList.new(self, cyl, add_d, 360, "arc beam")
	var spr_mat := ShaderMaterial.new()
	spr_mat.shader = GLOW_SPRITE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_spr = FX.InstList.new(self, quad, spr_mat, 16, "arc joints")
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = fx._c_srgb(0x8a8f99)
	stone_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	stone_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	stone_mat.roughness = 1.0
	_stone = FX.InstList.new(self, FxMesh.icosahedron(1.0, 0), stone_mat, 80, "yoke stones")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 10
	_glow = FX.InstList.new(self, sphere, add_m, 32, "gadget glows")
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.vertex_color_use_as_albedo = true
	_w_core = FX.InstList.new(self, sphere, core_mat, 6, "well cores")
	_w_ring = FX.InstList.new(self, FxMesh.torus_z(1.0, 0.012, 6, 64), add_d, 18, "well rings")
	# the points circling each well: seeds live in the instances, the swirl in the shader
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE
	for i in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = dot
		mm.instance_count = 70
		for j in 70:
			mm.set_instance_custom_data(j, Color(randf(), randf() * 6.28, (randf() - 0.5) * 2.0, 0.0))
		mm.custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = WELL_POINTS
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_well_pool.append(mi)
	_light = _mk_light(0xa65cff, 16.0)
	_blast_light = _mk_light(0xff8a98, 18.0)
	_arc_light = _mk_light(0x58b8ff, 15.0)


func _mk_light(hex: int, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = fx._c_srgb(hex)
	l.omni_range = range_m
	l.omni_attenuation = 2.0
	l.light_energy = 0.0
	l.visible = false
	l.add_to_group(FlashLights.GROUP)
	add_child(l)
	return l


func _set_light(l: OmniLight3D, intensity: float) -> void:
	if intensity <= 0.0:
		if l.visible:
			l.visible = false
		return
	l.visible = true
	l.light_energy = intensity / PI              # three.js point light candela -> Godot energy


## JS event(e, sfx, player): the sparks, shake and sound of a gadget event. Rapid repeats (a disc pinging between walls) are thinned out, not stacked.
func event(e: Dictionary, sfx: Sfx, _player: Player) -> void:
	var name_: String = str(e.t)
	var now_t := Time.get_ticks_msec()
	if now_t - int(_last.get(name_, 0)) < 70 and name_ != "yoke_launch" and name_ != "arc_zap":
		return
	_last[name_] = now_t
	var x: float = e.get("x", 0.0)
	var y: float = e.get("y", 0.0)
	var z: float = e.get("z", 0.0)
	var p := Vector3(x, y, z)
	match name_:
		"saw_bounce":
			_at(sfx, "sawPing", x, y, z, {"n": e.get("n", 1)})
			fx.sparks(p, 7, 4.5, Vector3(e.nx, e.ny, e.nz))
		"saw_slice":
			_at(sfx, "sawSlice", x, y, z)
			fx.sparks(p, 12 if e.get("kill", false) else 6, 3.5)
		"saw_clang":
			_at(sfx, "sawClang", x, y, z)
			fx.sparks(p, 12, 6.0, Vector3(e.nx, e.ny, e.nz))
			fx.shake = maxf(fx.shake, 0.12)
		"saw_return":
			_at(sfx, "sawTurn", x, y, z)
		"saw_catch":
			sfx.play("sawCatch")
			fx.shake = maxf(fx.shake, 0.08)
		"bellows_blast":
			_blast(e, sfx)
		"flail_swing", "flail_impact":
			flail.event(e, sfx, fx._wv())
		"yoke_start":
			sfx.play("yokeStart")
		"yoke_fizzle":
			sfx.play("yokeFizzle")
		"yoke_launch":
			fx.shake = maxf(fx.shake, 0.25 + 0.4 * float(e.get("ch", 0.0)))
		"yoke_impact":
			var ch: float = e.get("ch", 0.0)
			_at(sfx, "yokeImpact", x, y, z, {"k": 0.6 + ch})
			fx.dust(Vector3(x, y + 0.1, z), 10 + roundi(ch * 14.0), 3.0 + ch * 3.0)
			fx.sparks(p, 8, 5.0, Vector3.UP)
			fx.shake = maxf(fx.shake, 0.3 + 0.4 * ch)
		"arc_start":
			sfx.play("arcStart")
		"arc_stop":
			sfx.play("arcStop")
		"arc_burnout":
			sfx.play("arcBurn")
			fx.shake = maxf(fx.shake, 0.1)
		"arc_zap":
			var k: float = e.get("k", 0.0)
			fx.sparks(p, 4 if k < 0.0 else 3, 3.2, Vector3.UP)
			if k <= 0.0:
				_at(sfx, "arcZap", x, y, z)
			fx.shake = maxf(fx.shake, 0.04)
		"well_start":
			_at(sfx, "wellStart", x, y, z)
		"well_end":
			_at(sfx, "wellEnd", x, y, z)


func _at(sfx: Sfx, id: String, x: float, y: float, z: float, o: Dictionary = {}) -> void:
	var opts := {"range": 60.0}
	opts.merge(o, true)
	sfx.play_at(id, x, y, z, opts)


## JS _blast: Bellows Beast: spawn the ring train, flash, shake, and debris where the wave ends / at each enemy it hit.
func _blast(e: Dictionary, sfx: Sfx) -> void:
	var dir := Vector3(e.dx, e.dy, e.dz).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.999 else Vector3.RIGHT
	var x := up.cross(dir).normalized()
	var b := Blast.new()
	b.o = Vector3(e.x, e.y, e.z)
	b.dir = dir
	b.basis_ = Basis(x, dir.cross(x), dir)
	b.len_ = e.len
	blasts.append(b)
	_blast_light.position = b.o + Vector3(e.dx, e.dy, e.dz) * 1.5
	_blast_energy = 45.0
	fx.shake = maxf(fx.shake, 0.75)
	var end := Vector3(e.ex, e.ey, e.ez)
	var h: Array = e.get("hits", [])
	var i := 0
	while i + 2 < h.size():
		var hp := Vector3(h[i], h[i + 1], h[i + 2])
		fx.dust(hp, 8, 3.5)
		fx.sparks(hp, 6, 5.0, Vector3(e.dx, 0.4, e.dz))
		i += 3
	var wall: bool = e.get("wall", false)
	if wall:
		fx.dust(end, 22, 5.0)
		fx.sparks(end, 14, 6.0, Vector3(-float(e.dx), maxf(0.3, -float(e.dy)), -float(e.dz)))
	if wall or not h.is_empty():
		sfx.play_at("bellowsHit", end.x, end.y, end.z, {"range": 80.0, "k": 1.0 if wall else 0.7})


func _vol(x: float, y: float, z: float, cam: Vector3, k: float) -> float:
	return k / (1.0 + Vector3(cam.x - x, cam.y - y, cam.z - z).length() * 0.22)


## Hide the lightning and drop its voices (JS hideArc).
func hide_arc(hide_flail: bool = true) -> void:
	if hide_flail:
		flail.hide_view()
	_arc.finish()
	_spr.finish()
	_set_light(_arc_light, 0.0)
	if arc_v != null:
		Game.sfx.voice_kill(arc_v)
		arc_v = null
	if arc_v2 != null:
		Game.sfx.voice_kill(arc_v2)
		arc_v2 = null


## JS _arcSeg
func _arc_seg(p: Vector3, q: Vector3) -> void:
	var d := q - p
	var len_ := d.length()
	if len_ < 1e-4:
		return
	var y := d / len_
	var other := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var x := other.cross(y).normalized()
	var z := x.cross(y)
	var mid := p + d * 0.5
	for l in 3:
		var w: float = ARC_RAD[l] * ((0.7 + 0.6 * randf()) if l == 0 else 1.0)
		var col := Color(fx._c(0xeaffff), 1.0) if l == 0 else Color(fx._c(0x46b4ff), 0.45) if l == 1 else Color(fx._c(0x2a64ff), 0.16)
		_arc.add(Transform3D(Basis(x * w, y * len_, z * w), mid), col)


## JS _arcDraw: the lightning: jagged segments from the weapon's emitter through every zapped target, re-rolled every frame so it crackles.
func _arc_draw(combat: Variant) -> void:
	var A = combat.arc
	var w = combat.weapon
	if not (A.on and A.pts.size() > 1 and w != null and w.special == "arc"):
		if _arc.node.visible or _spr.node.visible or arc_v != null:
			hide_arc(false)
		return
	var pts: PackedVector3Array = A.pts.duplicate()
	var wv = fx._wv()
	if wv != null and wv.info != null:
		pts[0] = wv.muzzle_world()
	var links: Array = []
	for i in pts.size() - 1:
		links.append([pts[i], pts[i + 1], 0.13])
	if randf() < 0.6:                                    # a stray fork off the main bolt
		var k := randi() % (pts.size() - 1)
		var tt := 0.2 + randf() * 0.6
		var f0 := pts[k].lerp(pts[k + 1], tt)
		links.append([f0, f0 + Vector3((randf() - 0.5) * 1.6, (randf() - 0.3) * 1.2, (randf() - 0.5) * 1.6), 0.08])
	for link: Array in links:
		var a: Vector3 = link[0]
		var b: Vector3 = link[1]
		var L := a.distance_to(b)
		if L < 1e-3:
			continue
		var d := (b - a) / L
		var u := d.cross(Vector3.UP)
		if u.length_squared() < 1e-4:
			u = Vector3.RIGHT
		u = u.normalized()
		var v := d.cross(u)
		var N := maxi(2, mini(14, ceili(L / 0.45)))
		var amp: float = float(link[2]) + L * 0.012
		var p0 := a
		for k in range(1, N + 1):
			var p1 := b
			if k != N:
				var tk := float(k) / N
				var env := pow(sin(PI * tk), 0.6)
				p1 = a + d * (L * tk) + u * ((randf() - 0.5) * 2.0 * amp * env) + v * ((randf() - 0.5) * 2.0 * amp * env)
			_arc_seg(p0, p1)
			p0 = p1
	_arc.finish()
	var spr_col := Color(fx._c(0xbfe4ff), 1.0)
	for i in pts.size():
		var size := (0.45 if i == 0 else 1.1) * (0.75 + 0.5 * randf())
		_spr.add(Transform3D(Basis.from_scale(Vector3.ONE * size), pts[i]), spr_col)
	_spr.finish()
	_arc_light.position = pts[pts.size() - 1]
	_set_light(_arc_light, 14.0 + randf() * 14.0)
	var sfx: Sfx = Game.sfx
	if arc_v == null:
		arc_v = sfx.voice_start("loop.arc", 700.0)
		arc_v2 = sfx.voice_start("loop.arc2", 3200.0)
	sfx.voice_set(arc_v, "loop.arc", 56.0 + randf() * 12.0, 0.045 + 0.012 * A.hits.size())
	sfx.voice_set(arc_v2, "loop.arc2", 500.0 + randf() * 1800.0, 0.008 + 0.02 * randf())


## JS update(dt, combat, camera, player, wv)
func update_gadgets(dt: float, combat: Variant, camera: Camera3D, player: Player) -> void:
	t += dt
	if combat == null or camera == null or player == null:
		return
	var cam := camera.global_position
	var sfx: Sfx = Game.sfx
	_arc_draw(combat)
	if combat.flail != null:
		flail.update_view(dt, combat, camera, player, fx._wv(), sfx)
	# ---- aiming guide: path to the first surface, the first bounce, and where it goes next ----
	var sg = combat.saw_guide
	var show: bool = sg != null and not player.dead
	var want_lines: bool = show or not combat.saws.is_empty()
	if want_lines or _lines_mi.visible:
		_lines.clear_surfaces()
		_lines_mi.visible = want_lines
	if want_lines:
		_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	if show:
		var a: PackedVector3Array = sg.pts
		_line(a[0], a[1], Color(fx._c(0x55e0d0), 0.38))
		if a.size() > 2:
			_line(a[1], a[2], Color(fx._c(0xffd27a), 0.95))
		if sg.n != null:
			var n: Vector3 = sg.n
			var s := 1.0 + 0.15 * sin(t * 8.0)
			_ring_mat.albedo_color = Color(fx._c(0xffd27a), 0.9)
			_ring_mi.transform = Transform3D(_basis_y(n).scaled_local(Vector3(s, s, s)), a[1] + n * 0.03)
			_ring_mi.visible = true
		elif sg.target:
			_ring_mat.albedo_color = Color(fx._c(0xff6a5a), 0.9)
			_ring_mi.transform = Transform3D(_basis_y(camera.global_transform.basis.z), a[1])
			_ring_mi.visible = true
		else:
			_ring_mi.visible = false
	elif _ring_mi.visible:
		_ring_mi.visible = false
	# ---- discs ----
	var alive := {}
	for q in combat.saws:
		alive[q.id] = true
		var m: DiscState = saws.get(q.id)
		if m == null:
			m = DiscState.new()
			m.v = sfx.voice_start("loop.disc", 2600.0)
			saws[q.id] = m
		m.rot += dt * (30.0 + q.speed)
		var tilt := Basis.from_euler(Vector3(0.35 * sin(q.t * 3.0), 0.0, 0.35 * cos(q.t * 3.0)), EULER_ORDER_XYZ)
		var pos := Vector3(q.x, q.y, q.z)
		_disc.add(Transform3D(tilt * Basis(Vector3.UP, m.rot), pos), Color.WHITE)
		m.hist.insert(0, pos)
		if m.hist.size() > 16:
			m.hist.resize(16)
		var tc := Color(fx._c(0xffb070), 0.6)
		for i in m.hist.size() - 1:
			_line(m.hist[i], m.hist[i + 1], tc)
		sfx.voice_set(m.v, "loop.disc", 300.0 + q.speed * 9.0 + q.bounces * 40.0, _vol(q.x, q.y, q.z, cam, 0.03) * (1.2 if q.state == "return" else 1.0))
	_disc.finish()
	if want_lines:
		_lines.surface_end()
	for id: Variant in saws.keys():
		if not alive.has(id):
			sfx.voice_kill((saws[id] as DiscState).v)
			saws.erase(id)
	# ---- sonic blasts: ring train, expanding with the lane and fading toward its end ----
	_blast_energy *= exp(-10.0 * dt)
	if _blast_energy < 0.5:
		_blast_energy = 0.0
	_set_light(_blast_light, _blast_energy)
	for bi in range(blasts.size() - 1, -1, -1):
		var b := blasts[bi]
		b.t += dt
		var live := false
		for i in 6:
			var a := (b.t - i * 0.045) * 85.0
			if a < 0.0:
				live = true
				continue
			if a > b.len_ + 1.5:
				continue
			live = true
			var s := maxf(0.2, (BELL_W0 + (BELL_W1 - BELL_W0) * (a / BELL_RANGE)) * 0.95)
			var op := 0.8 * minf(1.0, a / 0.6) * pow(maxf(0.0, 1.0 - a / (b.len_ + 1.5)), 0.6)
			_wave.add(Transform3D(b.basis_.scaled_local(Vector3(s, s, s)), b.o + b.dir * a), Color(fx._c(0xffc2c8 if i % 2 == 1 else 0xff7f90), op))
		if not live:
			blasts.remove_at(bi)
	_wave.finish()
	# ---- thrown stones ----
	var glow_col := Color(fx._c(0xb36bff), 0.5)
	var seen := {}
	for q in combat.rocks:
		seen[q.id] = true
		var m: RockState = rocks.get(q.id)
		if m == null:
			m = RockState.new()
			m.r = 0.14 + 0.22 * q.ch
			for i in 5:
				m.parts.append([Vector3((randf() - 0.5) * m.r, (randf() - 0.5) * m.r, (randf() - 0.5) * m.r), m.r * (0.45 + (i % 3) * 0.2)])
			rocks[q.id] = m
		m.rx += dt * 6.0
		m.rz += dt * 4.0
		var rot := Basis.from_euler(Vector3(m.rx, 0.0, m.rz), EULER_ORDER_XYZ)
		var pos := Vector3(q.x, q.y, q.z)
		for part: Array in m.parts:
			var sc: float = part[1]
			_stone.add(Transform3D(rot.scaled_local(Vector3(sc, sc, sc)), pos + rot * (part[0] as Vector3)), Color.WHITE)
		_glow.add(Transform3D(Basis.from_scale(Vector3.ONE * (m.r * 1.5)), pos), glow_col)
	for id: Variant in rocks.keys():
		if not seen.has(id):
			rocks.erase(id)
	_stone.finish()
	# ---- gravity wells ----
	var light_k := 0.0
	var lp: Variant = null
	var seen_w := {}
	var ring_col := Color(fx._c(0xa65cff), 0.55)
	var core_col := Color(fx._c(0x1a0830), 1.0)
	var pool_i := 0
	for wl in combat.wells:
		seen_w[wl.id] = true
		var m: WellState = wells.get(wl.id)
		if m == null:
			m = WellState.new()
			m.v = sfx.voice_start("loop.well", 500.0)
			wells[wl.id] = m
		var env := minf(1.0, wl.t / 0.3) * minf(1.0, (wl.dur - wl.t) / 0.7)
		var es := maxf(0.01, env)
		var pos := Vector3(wl.x, wl.y, wl.z)
		_w_core.add(Transform3D(Basis.from_scale(Vector3.ONE * (0.45 * es)), pos), core_col)
		_glow.add(Transform3D(Basis.from_scale(Vector3.ONE * (0.7 * es * (1.0 + 0.12 * sin(t * 9.0)))), pos), glow_col)
		for i in 3:
			var k := fposmod(t * 0.35 + float(i) / 3.0, 1.0)
			var s := maxf(0.1, wl.r * (1.0 - k)) * es
			_w_ring.add(Transform3D(Basis.from_euler(Vector3(PI * 0.5 + (i - 1) * 0.12, 0.0, t * (0.6 + i * 0.3)), EULER_ORDER_XYZ).scaled_local(Vector3(s, s, s)), pos), ring_col)
		if pool_i < _well_pool.size():
			var pts := _well_pool[pool_i]
			pool_i += 1
			pts.visible = true
			pts.transform = Transform3D(Basis.from_scale(Vector3.ONE * es), pos)
			var pm: ShaderMaterial = pts.material_override
			pm.set_shader_parameter(&"t", t)
			pm.set_shader_parameter(&"r", wl.r)
		sfx.voice_set(m.v, "loop.well", 100.0 + 40.0 * env, _vol(wl.x, wl.y, wl.z, cam, 0.05) * env)
		var lk: float = env * (wl.ch * 0.5 + 0.6)
		if lk > light_k:
			light_k = lk
			lp = wl
	for i in range(pool_i, _well_pool.size()):
		_well_pool[i].visible = false
	for id: Variant in wells.keys():
		if not seen_w.has(id):
			sfx.voice_kill((wells[id] as WellState).v)
			wells.erase(id)
	_glow.finish()
	_w_core.finish()
	_w_ring.finish()
	if lp != null:
		_light.position = Vector3(lp.x, lp.y + 0.5, lp.z)
		_set_light(_light, 60.0 * light_k)
	else:
		_set_light(_light, 0.0)
	# ---- charge whine while the yoke gathers ----
	var Y = combat.yoke
	if Y.holding:
		if charge == null:
			charge = sfx.voice_start("loop.charge", 1800.0)
		sfx.voice_set(charge, "loop.charge", 80.0 + Y.charge * 420.0, 0.02 + 0.03 * Y.charge)
	elif charge != null:
		sfx.voice_kill(charge)
		charge = null


func _basis_y(n: Vector3) -> Basis:
	var y := n.normalized()
	var other := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var x := other.cross(y).normalized()
	return Basis(x, y, x.cross(y))


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_lines.surface_set_color(c)
	_lines.surface_add_vertex(a)
	_lines.surface_set_color(c)
	_lines.surface_add_vertex(b)


func clear() -> void:
	var sfx: Sfx = Game.sfx
	for id: Variant in saws.keys():
		sfx.voice_kill((saws[id] as DiscState).v)
	saws.clear()
	for id: Variant in wells.keys():
		sfx.voice_kill((wells[id] as WellState).v)
	wells.clear()
	rocks.clear()
	blasts.clear()
	if charge != null:
		sfx.voice_kill(charge)
		charge = null
	hide_arc(false)
	flail.clear()
	_lines.clear_surfaces()
	_lines_mi.visible = false
	_ring_mi.visible = false
	for w in _well_pool:
		w.visible = false
	_set_light(_light, 0.0)
	_set_light(_blast_light, 0.0)
	_blast_energy = 0.0
	_disc.finish()
	_wave.finish()
	_stone.finish()
	_glow.finish()
	_w_core.finish()
	_w_ring.finish()
