class_name VehicleDamage
extends RefCounted
## Vehicle damage (JS vehicles/damage.js): hit points, dents, smoke and fire stages, cracked glass, the burnt wreck and the explosion's look. vehicles.gd owns the physics and decides who gets hurt.
##   Health: v.hp of v.max_hp. Stages by the share left: below 0.6 white steam from the bonnet, 0.35 grey smoke and the engine loses power, 0.15 black smoke and misfires, at 0 the engine bay is on fire and a fuse runs (a single huge hit blows it up at once; a crash never does), then the vehicle explodes. Like GTA's: the smoke is the health bar, the fire is the warning to get out.
##   Dents: an impact pushes the body in around the contact, one displacement field in the chassis' frame applied to every body mesh alike, so paint, trim, glass and the door move together. Each vertex's total dent is capped so the cabin and the driver are never crushed into.
##   The wreck: charred paint and trim, glass gone, lamps out, flat tyres (v.sag), a long burn that dies down to smoke.

const FUSE := 9.0      # (seconds of fire after damage wore it down: long enough to see it, think and bail out or drive it clear)
const MAX_DENT := 0.17
const STAGE_STEAM := 0.6
const STAGE_SMOKE := 0.35
const STAGE_BLACK := 0.15

var _burnt: StandardMaterial3D
var _burnt_v: StandardMaterial3D
var _cracked: StandardMaterial3D


func _init() -> void:
	_burnt_v = StandardMaterial3D.new()
	_burnt_v.albedo_color = MsKit.srgb(0x2b2622)
	_burnt_v.vertex_color_use_as_albedo = true
	_burnt_v.roughness = 0.85
	_burnt = StandardMaterial3D.new()
	_burnt.albedo_color = MsKit.srgb(0x1c1916)
	_burnt.roughness = 1.0
	_cracked = StandardMaterial3D.new()
	_cracked.albedo_color = Color(MsKit.srgb(0xb8c4cc), 0.62)
	_cracked.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cracked.roughness = 0.3


static func _active_mat(mi: MeshInstance3D) -> Material:
	return mi.material_override if mi.material_override != null else mi.get_active_material(0)


static func _is_add(m: Material) -> bool:
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD
	return m is ShaderMaterial


static func _is_glass(m: Material) -> bool:
	if not m is StandardMaterial3D:
		return false
	var s := m as StandardMaterial3D
	return s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and s.albedo_color.a < 0.7 and s.blend_mode != BaseMaterial3D.BLEND_MODE_ADD


## the meshes that make up the body (under the chassis; wheels hang from the root)
func _body_meshes(v: Variant) -> Array:
	if not v.body_cache.is_empty():
		return v.body_cache
	var out: Array = []
	var walk: Array[Node] = [v.model.chassis]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and not _is_add(_active_mat(n)):
			out.append(n)
	v.body_cache = out
	return out


func init(v: Variant) -> void:
	v.max_hp = v.h.hp
	v.hp = v.max_hp
	v.fire = 0.0
	v.fuse = 0.0
	v.wrecked = false
	v.burn_t = 0.0
	v.sag = 0.0
	v.puff_t = 0.0
	v.pop_t = 0.0
	v.dents = 0


## share of health left, 0..1
func share(v: Variant) -> float:
	return clampf(v.hp / v.max_hp, 0.0, 1.0)


## engine power the damage leaves (1 = healthy): weaker in black smoke, sputtering once it burns
func power(v: Variant, t: float) -> float:
	if v.wrecked:
		return 0.0
	if v.fire > 0.0:
		return 0.55 if v.fire < 4.0 else 0.28
	var s := share(v)
	if s > STAGE_SMOKE:
		return 1.0
	var miss := 0.5 if s < STAGE_BLACK and sin(t * 23.0 + sin(t * 7.3) * 3.0) > 0.86 else 1.0      # misfires: the power dips in short stutters
	return (0.68 if s < STAGE_BLACK else 0.86) * miss


## take damage; returns true when this hit set it alight. big: the hit alone was huge: no fuse, it goes up at once. crash: a collision, which only ever starts the fire
func hurt(v: Variant, amount: float, big: bool = false, crash: bool = false) -> bool:
	if v.wrecked or not (amount > 0.0):
		return false
	v.hp -= amount
	if v.hp <= 0.0 and v.fire <= 0.0:
		v.hp = 0.0
		v.fire = 1e-3
		v.fuse = 0.0 if big or (not crash and amount > v.max_hp * 0.6) else FUSE
		return true
	if v.fire > 0.0 and big:      # already burning and hit hard again: it goes now
		v.fuse = 0.0
	return false


## push the body in around a contact. point: world, dir: world (into the car), depth (m)
func dent(v: Variant, point: Vector3, dir: Vector3, depth: float) -> void:
	if depth < 0.012 or v.wrecked:
		return
	var ch: Node3D = v.model.chassis
	var ci := ch.global_transform.affine_inverse()
	var P := ci * point
	var D := (ci.basis * dir).normalized()
	D.y *= 0.3
	D = D.normalized()
	var R := clampf(0.45 + depth * 2.6, 0.5, 1.1)
	for mesh: MeshInstance3D in _body_meshes(v):
		var mt := ci * mesh.global_transform      # the mesh's frame relative to the chassis (the door's hinge turn)
		var mti := mt.affine_inverse()
		var aabb := mesh.get_aabb()
		var c := mt * aabb.get_center()
		if c.distance_to(P) > aabb.size.length() * 0.5 + R:
			continue
		if not mesh.has_meta("dent"):      # first dent: its own copy of the geometry (the type's is shared)
			var am := ArrayMesh.new()
			var st: Array = []
			for s in mesh.mesh.get_surface_count():
				var arr: Array = mesh.mesh.surface_get_arrays(s)
				var orig: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var off := PackedVector3Array()
				off.resize(orig.size())
				st.append({"arr": arr, "orig": orig.duplicate(), "off": off, "mat": mesh.get_active_material(s)})
			mesh.set_meta("dent", st)
			mesh.mesh = am
			for s in st.size():
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st[s].arr)
				am.surface_set_material(s, st[s].mat)
		var dst: Array = mesh.get_meta("dent")
		var moved := false
		var am2 := mesh.mesh as ArrayMesh
		for s in dst.size():
			var e: Dictionary = dst[s]
			var o: PackedVector3Array = e.orig
			var off: PackedVector3Array = e.off
			var cur: PackedVector3Array = e.arr[Mesh.ARRAY_VERTEX]
			var smoved := false
			for i in o.size():
				var q := mt * o[i]      # rest position, chassis space
				var ov := off[i]
				var dx := q.x + ov.x - P.x
				var dy := (q.y + ov.y - P.y) * 1.4
				var dz := q.z + ov.z - P.z
				var dd := sqrt(dx * dx + dy * dy + dz * dz)
				if dd >= R:
					continue
				var w := pow(1.0 - dd / R, 2.0) * depth
				var crumple := 0.75 + 0.5 * sin(q.x * 23.1 + q.y * 17.3 + q.z * 29.7)      # (a little noise: metal folds, it does not scoop)
				var nv := ov + D * (w * crumple) + Vector3(0.0, -w * 0.12, 0.0)
				if nv.length() > MAX_DENT:
					nv = nv.normalized() * MAX_DENT
				off[i] = nv
				cur[i] = mti * (q + nv)
				smoved = true
			if smoved:
				e.off = off
				e.arr[Mesh.ARRAY_VERTEX] = cur
				moved = true
		if moved:
			am2.clear_surfaces()
			for s in dst.size():
				am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dst[s].arr)
				am2.surface_set_material(s, dst[s].mat)
			if depth > 0.06 and _is_glass(_active_mat(mesh)):
				_crack(mesh)
	v.dents += 1


func _crack(mesh: MeshInstance3D) -> void:
	if mesh.has_meta("cracked"):
		return
	mesh.set_meta("cracked", true)
	mesh.material_override = _cracked


## where smoke and fire come out: the engine bay (the front, or the back of a rear-engined type), world space
func bay(v: Variant) -> Vector3:
	var m: Variant = v.model
	var z: float = m.axle_f * 0.85 + 0.2 if v.spec.get("engine_at", 1.0) > 0.0 else m.axle_r * 0.85 - 0.2
	return (m.chassis as Node3D).global_transform * Vector3(0.0, m.height * 0.62, z)


func _at(v: Variant, id: String, o: Dictionary) -> void:
	if Game.sfx != null:
		Game.sfx.play_at(id, v.x, v.y + 0.8, v.z, o)


## every frame: smoke by stage, fire and its fuse (returns true when it is time to explode), the wreck's burn
func tick(v: Variant, dt: float, _t: float) -> bool:
	if v.max_hp == 0.0 or (v.hp >= v.max_hp and not v.wrecked):
		return false
	var s := share(v)
	var pt := bay(v)
	var moving := minf(1.0, v.speed / 12.0)
	v.puff_t -= dt
	if v.wrecked:
		v.burn_t += dt
		var burn := clampf(1.0 - (v.burn_t - 9.0) / 8.0, 0.0, 1.0)
		var smoke := clampf(1.0 - (v.burn_t - 22.0) / 14.0, 0.0, 1.0)
		if v.puff_t <= 0.0 and smoke > 0.0:
			v.puff_t = 0.05
			var q := pt - Vector3(0.0, 0.25, 0.0)
			if burn > 0.0:
				_flame(q, 0.7 * burn + 0.3, 1.6)
			if randf() < 0.55 * smoke:
				_puff(q, 0x141312, 0.55 + randf() * 0.4, 2.8, 2.2, 1.0)
		return false
	if v.fire > 0.0:
		v.fire += dt
		v.fuse -= dt
		var k := clampf(v.fire / 5.0, 0.25, 1.0)
		if v.puff_t <= 0.0:
			v.puff_t = 0.035
			_flame(pt, k, 1.0)
			if randf() < 0.6:
				_puff(pt, 0x101010, 0.45 + 0.4 * k, 2.4, 1.8, 1.0 - moving * 0.5)
		v.pop_t -= dt
		if v.pop_t <= 0.0:
			v.pop_t = clampf(v.fuse * 0.22, 0.12, 0.7)
			_at(v, "vehPop", {"range": 45.0, "k": 1.0 - clampf(v.fuse / FUSE, 0.0, 1.0)})
			if randf() < 0.5:
				Game.fx.sparks(pt, 4, 3.2, null, 0xffa040)
		return v.fuse <= 0.0
	if s < STAGE_STEAM and v.puff_t <= 0.0:
		if s < STAGE_BLACK:
			v.puff_t = 0.06
			_puff(pt, 0x121212, 0.38 + randf() * 0.2, 1.9, 1.6, 1.0)
		elif s < STAGE_SMOKE:
			v.puff_t = 0.09
			_puff(pt, 0x4a4a4e, 0.3 + randf() * 0.15, 1.5, 1.4, 1.0)
		else:
			v.puff_t = 0.22
			_puff(pt, 0xd4dce2, 0.22, 0.9, 1.2, 0.7, true)
	return false


func _puff(p: Vector3, color: int, size: float, life: float, rise: float, alpha: float = 1.0, steam: bool = false) -> void:
	var fx: Variant = Game.fx
	var vel := Vector3((randf() - 0.5) * 0.7, rise * (0.7 + randf() * 0.5), (randf() - 0.5) * 0.7)
	var c: Color = fx._c(color)
	fx._spawn(fx._p_steam if steam else fx._p_smoke, p, vel, life * (0.8 + randf() * 0.4), size, 1.1, -0.25, c, (0.4 if steam else 0.55) * alpha)


func _flame(p: Vector3, k: float, spread: float) -> void:
	var fx: Variant = Game.fx
	for i in 2:
		var hot := randf() < 0.12
		var c: Color = fx._c_core if hot else Color.from_hsv(0.02 + randf() * 0.06, 1.0, 0.72 + randf() * 0.2)      # (additive: overlapping licks add up, so each stays a deep orange or the fire burns out to white)
		var q := Vector3(p.x + (randf() - 0.5) * 0.9 * spread, p.y + randf() * 0.15, p.z + (randf() - 0.5) * 0.9 * spread)
		var vel := Vector3((randf() - 0.5) * 0.6, 1.6 + randf() * 2.2 * k, (randf() - 0.5) * 0.6)
		fx._spawn(fx._p_fire, q, vel, 0.3 + randf() * 0.35 * k, (0.16 + randf() * 0.22) * (0.6 + k * 0.6), -0.9, -1.2, c)


## the vehicle is now a wreck: charred, glass gone, lamps out, tyres burnt flat
func wreck(v: Variant) -> void:
	v.wrecked = true
	v.fire = 0.0
	v.burn_t = 0.0
	v.sag = 0.13
	v.hp = 0.0
	for mesh: MeshInstance3D in _body_meshes(v):
		var m := _active_mat(mesh)
		if _is_glass(m) or mesh.has_meta("cracked"):
			mesh.visible = false
			continue
		mesh.material_override = _burnt_v if m is StandardMaterial3D and (m as StandardMaterial3D).vertex_color_use_as_albedo else _burnt
	var walk: Array[Node] = [v.model.root]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D and _is_add(_active_mat(n)):
			(n as Node3D).visible = false
	for w: Variant in v.model.wheels:
		var wk: Array[Node] = [w.spin]
		while not wk.is_empty():
			var n: Node = wk.pop_back()
			wk.append_array(n.get_children())
			if n is MeshInstance3D:
				(n as MeshInstance3D).material_override = _burnt
	if v.model.set_lights.is_valid():
		v.model.set_lights.call(false)


## the blast's look and sound: two fireballs, a column of black smoke, debris, sparks, the flash
func blast_fx(v: Variant) -> void:
	var fx: Variant = Game.fx
	var p := Vector3(v.x, v.y + 1.0, v.z)
	fx.explosion(p, 4.6)
	fx.explosion(p + Vector3(0.0, 1.3, 0.0), 3.2)
	for i in 26:      # debris thrown by the blast
		var a := randf() * TAU
		var sp := 5.0 + randf() * 9.0
		var vel := Vector3(cos(a) * sp, 5.0 + randf() * 8.0, sin(a) * sp)
		var c: Color = fx._c(0x15161a if randf() < 0.5 else 0x3a2c22)
		fx._spawn(fx._p_smoke, p, vel, 1.2 + randf() * 0.9, 0.08 + randf() * 0.18, 0.0, 16.0, c, 1.0)
	fx.sparks(p, 30, 9.0, null, 0xffb050)
	fx.dust(Vector3(v.x, v.y + 0.1, v.z), 18, 5.0)
	for i in 16:
		_puff(p, 0x0d0d0d, 0.9 + randf() * 0.8, 2.6, 3.5, 1.0)
	_at(v, "explode", {"range": 110.0})
