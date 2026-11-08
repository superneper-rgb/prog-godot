class_name FointGoonDress
extends RefCounted
## FOINT GOON dress (JS enemies/foint-goon-dress.js): the GOINT prison costumes worn by the same toads, built on the security body. Each costume = a recoloured base map (a tint shader on the toad's own 512 px texture: no new image) + PS2 pieces that ride the toad's bones:
##   goint_guard     a plain prison guard: light-blue duty shirt over navy trousers, black duty belt with a key ring and a baton, silver badge, name tag, chest radio, blue GOINT armband, a gun-mounted flashlight (beam cone + a real spot light; R.beam = the cone in world space for stealth checks) and the tall pointed GOINT helmet on the back of the head
##   goint_adjuster  GOINT GEAR XL pieces: blue suit, rimmed black shoulder pads, pale chest plate with the glowing hex core, ribbed belt, cuffs, thigh plates, a shield gauntlet, the helmet in blue, and the blue energy shield projected in front of him
## The pieces are built by the JS (skin-conformed there) and exported per bone by tools/export/goon_gear.expr.js; here they only ride their bones.

# The toad's skin is strongly saturated orange; cloth and armour are near-grey. Grey texels are re-tinted by brightness (dark tint -> light tint). Skin only shows on the head and hands, so saturated colour anywhere else on the body is a FOINT emblem (the orange F) or an LED: it is dyed flat to plain cloth (brightness `plain`). FOINT's grey prints on the security body sit in fixed places: texels inside those boxes (rest pose, |x| mirrored) are dyed flat too. Red LEDs can be swapped for another colour (led). split: dye by where the texel sits on the body (rest pose, model space) instead: shirt above the waist, trousers below, gloves and boots left dark.
const RECOLOUR := {
	"goint_guard": {"dark": Vector3(1, 1, 1), "light": Vector3(1, 1, 1), "lo": 0.05, "hi": 0.3, "lift": 0.0, "plain": 0.05, "split": {"waist": 0.745, "boot": 0.235, "hand": 0.83, "shirt": Vector3(0.33, 0.5, 0.72), "pants": Vector3(0.024, 0.034, 0.075)}},
	"goint_adjuster": {"dark": Vector3(0.55, 1.6, 6.2), "light": Vector3(0.95, 1.02, 1.16), "lo": 0.05, "hi": 0.28, "lift": 0.012, "plain": 0.05, "led": Vector3(0.12, 0.85, 1.1)},
}
const _CLOTH := {"dark": Vector3(1, 1, 1), "light": Vector3(1, 1, 1), "lo": 0.05, "hi": 0.3, "lift": 0.0, "plain": 0.15}      # (plain: FOINT's printed emblem dyed to the cloth's own tone)
# suits (VISITING HOURS: Fenn the claims adjuster, the undertakers) and the warden's shirtsleeves: the split dye, cloth only, no LEDs
const SUITS := {
	"goint_suit": {"waist": 0.745, "boot": 0.235, "hand": 0.83, "shirt": Vector3(0.2, 0.17, 0.13), "pants": Vector3(0.17, 0.145, 0.11)},
	"goint_undertaker": {"waist": 0.745, "boot": 0.235, "hand": 0.83, "shirt": Vector3(0.03, 0.03, 0.035), "pants": Vector3(0.025, 0.025, 0.03)},
	"goint_warden": {"waist": 0.745, "boot": 0.235, "hand": 0.83, "shirt": Vector3(0.72, 0.7, 0.62), "pants": Vector3(0.03, 0.04, 0.09)},
}
const BEAM_RANGE := 11.0
const BEAM_ANGLE := 0.36
const SHIELD_W := 0.96
const SHIELD_H := 1.2
const SHADER := "res://enemies/goon_recolour.gdshader"
const SHIELD_SHADER := "res://enemies/goon_shield.gdshader"
const BEAM_SHADER := "res://enemies/goon_beam.gdshader"


## A costume's pieces, loaded once.
class Kit:
	var pieces: Array[Dictionary] = []      # mesh, bone, follow, k, pivot, xf
	var badge: Variant = null               # Vector3: on the head bone
	var core := Vector3.ZERO                # in the chest bone's frame
	var core_n := Vector3.ZERO
	var back_depth := 0.0
	var mats: Array[Material] = []


static var _kits: Dictionary = {}
static var _beam_mesh: ArrayMesh = null
static var _beam_mat: ShaderMaterial = null
static var _shield_face: ArrayMesh = null
static var _shield_edge: ArrayMesh = null
static var _shield_face_mat: ShaderMaterial = null
static var _shield_edge_mat: ShaderMaterial = null


static func _kit(costume: String, B: FointGoonView.Body) -> Kit:
	if _kits.has(costume):
		return _kits[costume]
	var K := Kit.new()
	var sc: Node = (load("res://assets/objects/goon_dress_%s.glb" % costume) as PackedScene).instantiate()
	var look: Array[Node] = [sc]
	while look.size() > 0:
		var h: Node = look.pop_back()
		var hn := String((h.get_meta("extras", {}) as Dictionary).get("js_name", ""))
		if hn.begins_with("J_"):
			var bone: int = B.i[StringName(_bone_name(hn.substr(2)))]
			_walk(K, h, bone, -1, 0.0, Vector3.ZERO, Transform3D.IDENTITY, B)
		else:
			look.append_array(h.get_children())
	sc.free()
	K.core_n = (K.core_n - K.core).normalized() if K.core_n != Vector3.ZERO else Vector3.ZERO
	# how far the body (and anything it wears on its back) reaches behind him, at rest: what he lies on when dead
	var zmin := B.back_z
	for p: Dictionary in K.pieces:
		var m: Mesh = p.mesh
		var at: Transform3D = B.rest_m[p.bone] * (p.xf as Transform3D)
		for s in m.get_surface_count():
			var vs: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for i in range(0, vs.size(), 2):
				zmin = minf(zmin, (at * vs[i]).z)
	K.back_depth = -zmin
	# the body's own texture, recoloured; the eyes and mouth keep their colours
	var P: Dictionary = RECOLOUR[costume] if RECOLOUR.has(costume) else _CLOTH.merged({"split": SUITS[costume]})
	var sp: Dictionary = P.get("split", {"waist": 0.0, "boot": 0.0, "hand": 9.0, "shirt": Vector3.ONE, "pants": Vector3.ONE})
	var led: Variant = P.get("led")
	for s in B.mesh.get_surface_count():
		var src: Material = B.mats[s]
		if src.resource_name == "face":
			K.mats.append(src)
			continue
		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		m.set_shader_parameter(&"albedo_tex", (src as StandardMaterial3D).albedo_texture)
		m.set_shader_parameter(&"u_dark", P.dark)
		m.set_shader_parameter(&"u_light", P.light)
		m.set_shader_parameter(&"u_band", Vector4(P.lo, P.hi, P.lift, P.plain))
		var lv: Vector3 = led if led != null else Vector3.ZERO
		m.set_shader_parameter(&"u_led", Vector4(lv.x, lv.y, lv.z, 1.0 if led != null else 0.0))
		m.set_shader_parameter(&"u_split", Vector4(sp.waist, sp.boot, sp.hand, 1.0 if P.has("split") else 0.0))
		m.set_shader_parameter(&"u_shirt", sp.shirt)
		m.set_shader_parameter(&"u_pants", sp.pants)
		m.set_shader_parameter(&"u_print_a", PackedVector3Array([Vector3(0.0, 0.84, -9.0), Vector3(0.42, 1.0, -9.0)]))      # [|x|, y, z] min, max
		m.set_shader_parameter(&"u_print_b", PackedVector3Array([Vector3(0.3, 1.27, -0.16), Vector3(0.82, 1.42, 9.0)]))
		K.mats.append(m)
	_kits[costume] = K
	return K


static func _bone_name(key: String) -> String:
	var i := key.rfind("_")
	if i > 0 and (key.ends_with("_L") or key.ends_with("_R")):
		return key.substr(0, i) + "." + key.substr(i + 1)
	return key


static func _walk(K: Kit, n: Node, bone: int, follow: int, k: float, pivot: Vector3, xf: Transform3D, B: FointGoonView.Body) -> void:
	for c: Node in n.get_children():
		var nm := String((c.get_meta("extras", {}) as Dictionary).get("js_name", ""))
		var c3 := c as Node3D
		if nm == "P_badge":
			K.badge = c3.position
		elif nm == "P_core":
			K.core = c3.position
		elif nm == "P_coreN":
			K.core_n = c3.position
		elif nm.begins_with("Fo_"):      # Fo_<bone>__<follow>__<k x 1000>
			var parts := nm.substr(3).split("__")
			_walk(K, c, bone, B.i[StringName(_bone_name(parts[1]))], int(parts[2]) / 1000.0, c3.position, Transform3D.IDENTITY, B)
		else:
			if c is MeshInstance3D:
				K.pieces.append({"mesh": (c as MeshInstance3D).mesh, "bone": bone, "follow": follow, "k": k, "pivot": pivot, "xf": xf * c3.transform})
			if c3 != null:
				_walk(K, c, bone, follow, k, pivot, xf * c3.transform, B)


## Returns null for the plain FOINT costumes.
static func dress(view: FointGoonView) -> FointGoonDress:
	var costume := view.R.costume
	if not RECOLOUR.has(costume) and not SUITS.has(costume):
		return null
	return FointGoonDress.new(view, costume)


var view: FointGoonView
var R: FointGoon
var kit: Kit
var costume := ""
var back_depth := 0.0
var still: Array[Dictionary] = []      # node, bone, xf
var moving: Array[Dictionary] = []     # node, bone, follow, k, pivot
var t := randf() * 10.0
var badge: MeshInstance3D = null
# the flashlight
var torch_origin: Node3D = null
var spot: SpotLight3D = null
var flare: MeshInstance3D = null
# the shield
var shield: Node3D = null
var face_mi: MeshInstance3D = null
var edge_mi: MeshInstance3D = null
var shield_up := 0.0
var flick := 0.0
var flash_ := 0.0
var hits := 0
var breaks := 0
var ups := 0


func _init(v: FointGoonView, c: String) -> void:
	view = v
	R = v.R
	costume = c
	kit = FointGoonDress._kit(c, v.B)
	back_depth = kit.back_depth
	for s in kit.mats.size():
		v.mesh_i.set_surface_override_material(s, kit.mats[s])
	for p: Dictionary in kit.pieces:
		var mi := MeshInstance3D.new()
		mi.mesh = p.mesh
		v.holder.add_child(mi)
		if int(p.follow) >= 0:
			moving.append({"node": mi, "bone": p.bone, "follow": p.follow, "k": p.k, "pivot": p.pivot, "xf": p.xf})
		else:
			still.append({"node": mi, "bone": p.bone, "xf": p.xf})
	if kit.badge != null:      # the badge light's glow, on the head bone
		badge = FxBeam.dot(0x6af0ff)
	if c == "goint_guard" and R.flashlight:
		_build_flashlight()
	elif v.gun.torch != null:
		v.gun.torch.visible = false
	if c == "goint_adjuster":
		_build_shield()
		hits = R.shield_hits
		breaks = R.shield_breaks
		ups = R.shield_ups


func dispose() -> void:
	if badge != null and is_instance_valid(badge):
		badge.queue_free()
	if flare != null and is_instance_valid(flare):
		flare.queue_free()


## the beam: an open cone along +Z, bright at the lens, black (= nothing, additive) at the far end
static func _beam() -> ArrayMesh:
	if _beam_mesh != null:
		return _beam_mesh
	var segs := 16
	var rows := 6
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	for j in rows + 1:
		var z := float(j) / rows
		var r := lerpf(0.03, 1.0, z)
		var k := pow(1.0 - z, 1.6)
		for i in segs + 1:
			var a := float(i) / segs * TAU
			v.append(Vector3(cos(a) * r, sin(a) * r, z))
			cl.append(Color(k, k, k))
	for j in rows:
		for i in segs:
			var a := j * (segs + 1) + i
			idx.append_array(PackedInt32Array([a, a + 1, a + segs + 1, a + 1, a + segs + 2, a + segs + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = idx
	_beam_mesh = ArrayMesh.new()
	_beam_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load(BEAM_SHADER)
	return _beam_mesh


func _build_flashlight() -> void:
	var kind := R.gun
	var y := -0.025 if kind == "smg" else -0.02
	var z := 0.2 if kind == "smg" else 0.09
	torch_origin = Node3D.new()
	torch_origin.position = Vector3(0.0, y, z + 0.09)
	view.gun.g.add_child(torch_origin)
	var tr := tan(BEAM_ANGLE) * BEAM_RANGE * 0.8
	var bm := FointGoonDress._beam()
	var cone := MeshInstance3D.new()
	cone.mesh = bm
	cone.material_override = _beam_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.scale = Vector3(tr, tr, BEAM_RANGE * 0.8)
	cone.set_instance_shader_parameter(&"opacity", 0.055)
	torch_origin.add_child(cone)
	var core := MeshInstance3D.new()
	core.mesh = bm
	core.material_override = _beam_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3(tr * 0.45, tr * 0.45, BEAM_RANGE * 0.55)
	core.set_instance_shader_parameter(&"opacity", 0.06)
	torch_origin.add_child(core)
	spot = SpotLight3D.new()
	spot.light_color = Color.hex(0xfff0d0ff)
	spot.light_energy = 6.0 / PI
	spot.spot_range = BEAM_RANGE * 1.3
	spot.spot_attenuation = 1.6
	spot.spot_angle = rad_to_deg(BEAM_ANGLE)
	spot.spot_angle_attenuation = ExportedLevel.spot_k(0.45)
	spot.rotation.y = PI       # a Godot spot shines along -Z
	torch_origin.add_child(spot)
	flare = FxBeam.dot(0xfff2d0)


func _build_shield() -> void:
	if _shield_face == null:
		var curve := 1.3
		var nx := 10
		var ny := 6
		var pos := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var idx := PackedInt32Array()
		for j in ny + 1:
			for i in nx + 1:
				var u := float(i) / nx
				var w := float(j) / ny
				var a := (u - 0.5) * SHIELD_W / curve
				pos.append(Vector3(sin(a) * curve, (w - 0.5) * SHIELD_H, (cos(a) - 1.0) * curve))
				uv.append(Vector2(u * 2.2, w * 2.7))
				uv2.append(Vector2(u, w))      # a flat edge frame (the repeated hex texture would tile): a second, unrepeated copy of the face draws the bright border
		for j in ny:
			for i in nx:
				var a := j * (nx + 1) + i
				idx.append_array(PackedInt32Array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]))
		for q in 2:
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = pos
			arr[Mesh.ARRAY_TEX_UV] = uv if q == 0 else uv2
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			if q == 0:
				_shield_face = m
			else:
				_shield_edge = m
		var tex: Texture2D = load("res://assets/objects/goon_hex.png")
		_shield_face_mat = ShaderMaterial.new()
		_shield_face_mat.shader = load(SHIELD_SHADER)
		_shield_face_mat.set_shader_parameter(&"hex", tex)
		_shield_edge_mat = ShaderMaterial.new()
		_shield_edge_mat.shader = load(SHIELD_SHADER)
		_shield_edge_mat.set_shader_parameter(&"hex", tex)
		_shield_edge_mat.set_shader_parameter(&"edge", true)
	shield = Node3D.new()
	view.holder.add_child(shield)
	for q in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _shield_face if q == 0 else _shield_edge
		mi.material_override = _shield_face_mat if q == 0 else _shield_edge_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4.0
		shield.add_child(mi)
		if q == 0:
			face_mi = mi
		else:
			edge_mi = mi
	var fc := RigidBatch.lin(0x5fb4ff)
	edge_mi.set_instance_shader_parameter(&"tint", Vector3(fc.r, fc.g, fc.b))


func update(dt: float, fx: Variant, dead: bool) -> void:
	t += dt
	for p: Dictionary in still:
		var b: int = p.bone
		(p.node as Node3D).transform = Transform3D(Basis(view.mq(b)), view.mp(b)) * (p.xf as Transform3D)
	var B := view.B
	for f: Dictionary in moving:      # a piece between two bones: the share k of how far the arm turned against the chest
		var b: int = f.bone
		var fo: int = f.follow
		var q1 := view.mq(b).inverse() * view.mq(fo)
		var q3 := (B.rest_mq[b].inverse() * B.rest_mq[fo]).inverse()
		var qq := Quaternion.IDENTITY.slerp((q1 * q3).normalized(), float(f.k))
		(f.node as Node3D).transform = Transform3D(Basis(view.mq(b)), view.mp(b)) * Transform3D(Basis(qq), f.pivot) * (f.xf as Transform3D)
	if badge != null:
		var at: Vector3 = view.mw * (Transform3D(Basis(view.mq(view.i_head)), view.mp(view.i_head)) * (kit.badge as Vector3))
		FxBeam.place_dot(badge, at, 0.13, 0.15 if dead else 0.55 + (0.3 if sin(t * 3.1) > 0.6 else 0.0))
	if torch_origin != null:      # beam data for stealth: where the cone starts, its axis, its half-angle and reach
		var on := not dead or view.death_t < 2.5
		torch_origin.visible = on
		var gx := view.mw * view.gun.g.transform if view.drop_gun == null else view.gun.g.global_transform
		var p := gx * torch_origin.position
		var n := (gx.basis * Vector3(0.0, 0.0, 1.0)).normalized()
		R.beam = {"on": on and not dead, "x": p.x, "y": p.y, "z": p.z, "dx": n.x, "dy": n.y, "dz": n.z, "angle": BEAM_ANGLE, "range": BEAM_RANGE}
		if on:
			FxBeam.place_dot(flare, p, 0.18, 0.7 + randf() * 0.1)
		else:
			flare.visible = false
	if shield != null:
		_shield_update(dt, fx, dead)


## the energy shield: posed in front of the gauntlet (view.shield_pose_*), raised while he fights, flashes per absorbed hit, flickers out on overload, grows back when it recovers; writes R.shield_geo (world rectangle the AI tests shots against) and R.core_at (the hex core)
func _shield_update(dt: float, fx: Variant, dead: bool) -> void:
	var want := 1.0 if not dead and R.shield_down_t <= 0.0 and R.state != &"idle" and R.state != &"return" and not R.dev_passive else 0.0
	shield_up += (want - shield_up) * (1.0 - exp(-(7.0 if want != 0.0 else 12.0) * dt))
	# sounds and sparks on the AI's counters
	var mid := view.mw * shield.position
	if R.shield_hits != hits:
		hits = R.shield_hits
		flash_ = 1.0
		_at("shieldHit")
		if fx != null and R.shield_hit_at != null:
			var h: Dictionary = R.shield_hit_at
			fx.sparks(Vector3(h.x, h.y, h.z), 5, 2.6, Vector3(h.nx, h.ny, h.nz), 0x6ab8ff)
	if R.shield_breaks != breaks:
		breaks = R.shield_breaks
		flick = 0.7
		_at("shieldBreak")
		if fx != null:
			fx.sparks(mid, 36, 5.5, null, 0x4db8ff)
			fx.sparks(mid, 10, 4.0, null, 0xffffff)
	if R.shield_ups != ups:
		ups = R.shield_ups
		shield_up = 0.05
		_at("shieldUp")
	flash_ = maxf(0.0, flash_ - dt * 6.0)
	flick = maxf(0.0, flick - dt)
	# pose: anchored ahead of the gauntlet (the view says where the hand is and how far open the guard is)
	if not view.has_shield_pose:
		shield.visible = false
		R.shield_geo = null
		return
	var grow := (1.0 if randf() < 0.5 else 0.2) if flick > 0.0 else shield_up
	shield.visible = grow > 0.03 or flick > 0.0
	R.shield_geo = null
	var sc := Vector3(lerpf(0.5, 1.0, grow), maxf(0.02, grow), 1.0)
	shield.transform = Transform3D(Basis(view.shield_pose_q).scaled_local(sc), view.shield_pose_p)
	var charge := clampf(R.shield / R.shield_max, 0.0, 1.0) if R.shield_max != 0.0 else 1.0
	var fl := randf() if flick > 0.0 else 1.0
	face_mi.set_instance_shader_parameter(&"opacity", (0.32 + 0.25 * charge + 0.5 * flash_) * fl * grow * (0.92 + 0.08 * sin(t * 23.0)))
	edge_mi.set_instance_shader_parameter(&"opacity", (0.3 + 0.2 * charge + 0.6 * flash_) * fl * grow)
	var fc := RigidBatch.lin(0x7f6dff if charge < 0.3 else 0x3d8dff)      # nearly spent: it goes violet
	face_mi.set_instance_shader_parameter(&"tint", Vector3(fc.r, fc.g, fc.b))
	face_mi.set_instance_shader_parameter(&"scroll", fposmod(t * 0.12, 1.0))
	if flick > 0.0 and fx != null and randf() < dt * 30.0:
		fx.sparks(mid + Vector3(0.0, (randf() - 0.5) * 0.8, 0.0), 3, 3.0, null, 0x7fc8ff)
	# the world rectangle the AI tests shots against: only while it is up for real
	if not dead and shield_up > 0.6 and R.shield_down_t <= 0.0:
		var wb := view.mw.basis * Basis(view.shield_pose_q)
		R.shield_geo = {"c": mid, "n": wb * Vector3(0.0, 0.0, 1.0), "u": wb * Vector3(1.0, 0.0, 0.0), "v": wb * Vector3(0.0, 1.0, 0.0), "hw": SHIELD_W / 2.0 * sc.x, "hh": SHIELD_H / 2.0 * sc.y}
	var cx := Transform3D(Basis(view.mq(view.i_chest)), view.mp(view.i_chest))
	var wc := view.mw * cx
	R.core_at = {"c": wc * kit.core, "n": (wc.basis * kit.core_n).normalized()}


func _at(id: String) -> void:
	if Game.sfx != null:
		Game.sfx.play_at(id, R.x, R.y + 1.0, R.z, {"hi": true})
