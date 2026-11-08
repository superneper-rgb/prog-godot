class_name ArmsDepot
extends Node3D
## The ARMS DEPOT vending machines (JS props/arms-depots.js): four cabinets from two rival brands, one guns / ammo and one armor machine each. The models come from the exporter (assets/objects/depot_<kind>.glb, tools/export/export.mjs object); this is their life: neon, screens, turntables, beacons. Built at the origin, feet on y = 0, facing +Z; the caller positions / rotates / scales it.
## They only stand in the DEV level, which has no tone mapping, so the JS's toneMapped:false colours go straight to the screen in both (export them with --level=dev).

const DEPOTS := [
	{"id": "foint-ammo", "name": "FOINT-O-MATIC", "note": "Foint guns + ammo: cheap rounds, street hardware", "brand": "foint", "size": [1.5, 2.95, 0.95]},
	{"id": "goint-ammo", "name": "GOINT ASSURED", "note": "Goint guns + ammo: premium, sold fully loaded", "brand": "goint", "size": [1.4, 2.9, 1.0]},
	{"id": "foint-armor", "name": "FOINT FLAK SHACK", "note": "Foint armor: resold suits, undercuts Goint", "brand": "foint", "size": [2.0, 2.55, 1.05]},
	{"id": "goint-armor", "name": "GOINT POLICY BOOTH", "note": "Goint armor: certified Goint suits", "brand": "goint", "size": [1.3, 2.85, 1.1]},
]

var kind := ""
var _n: Dictionary = {}      # JS part name -> node
var _m: Dictionary = {}      # JS part name -> its own material
var _off: StandardMaterial3D = null
var _on: StandardMaterial3D = null
var _bulbs: Array[MeshInstance3D] = []
var _bulb_off := -1


## one machine: update(time in seconds) animates it
static func build(p_kind: String) -> ArmsDepot:
	var path := "res://assets/objects/depot_%s.glb" % p_kind.replace("-", "_")
	if not ResourceLoader.exists(path):
		push_error("No arms depot \"%s\"" % p_kind)
		return null
	var o := ArmsDepot.new()
	o.kind = p_kind
	o.name = "arms-depot_" + p_kind
	var sc: Node3D = (load(path) as PackedScene).instantiate()
	o.add_child(sc)
	_index(sc, o._n)
	for nm: String in o._n:
		var mi := _mesh_of(o._n[nm])
		if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if mat != null:
				mat.resource_local_to_scene = false
				var own: StandardMaterial3D = mat.duplicate()      # (one machine's flicker must not reach a merged neighbour of the same colour)
				mi.material_override = own
				o._m[nm] = own
	if p_kind == "foint-ammo":
		o._on = o._m.get("dp_bulb0")
		o._off = o._on.duplicate() if o._on != null else null
		if o._off != null:
			o._off.albedo_color = Color.hex(0x553a20ff)
		for i in 14:
			var b := _mesh_of(o._n.get("dp_bulb%d" % i))
			if b != null:
				o._bulbs.append(b)
	return o


## parts the JS named (the exporter keeps them separate, and says their JS name in extras)
static func _index(n: Node, out: Dictionary) -> void:
	var x: Dictionary = n.get_meta("extras", {})
	if x.has("js_name"):
		out[String(x["js_name"])] = n
	for c: Node in n.get_children():
		_index(c, out)


static func _mesh_of(n: Variant) -> MeshInstance3D:
	if n == null:
		return null
	if n is MeshInstance3D:
		return n
	var f: Array[Node] = (n as Node).find_children("*", "MeshInstance3D", true, false)
	return f[0] if not f.is_empty() else null


## the JS's color.setScalar / setRGB (linear values) on a material
func _tint(nm: String, r: float, g: float = -1.0, b: float = -1.0) -> void:
	var mat: StandardMaterial3D = _m.get(nm)
	if mat == null:
		return
	var a := mat.albedo_color.a
	var c := Color(r, r if g < 0.0 else g, r if b < 0.0 else b).linear_to_srgb()
	c.a = a
	mat.albedo_color = c


func update_at(t: float) -> void:
	match kind:
		"foint-ammo":
			_foint_ammo(t)
		"goint-ammo":
			_goint_ammo(t)
		"foint-armor":
			_foint_armor(t)
		"goint-armor":
			_goint_armor(t)


func _foint_ammo(t: float) -> void:
	var tick: StandardMaterial3D = _m.get("dp_tick")
	if tick != null:
		tick.uv1_offset.x = fmod(t * 0.06, 1.0)
	var f := 0.45 if sin(t * 37.0) > 0.97 or fmod(t, 7.3) < 0.08 else 1.0      # tired neon: the odd stutter
	_tint("dp_sign", f)
	var off := int(floor(t * 6.0))
	if off != _bulb_off:      # chasing marquee bulbs
		_bulb_off = off
		for i in _bulbs.size():
			_bulbs[i].material_override = _off if (off + i) % 3 == 0 else _on
	_tint("dp_btn", 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 5.0)), 0.1, 0.1)
	for i in 3:
		_tint("dp_strip%d" % i, 1.0, 0.15 + 0.05 * sin(t * 3.0 + i), 0.15)
	_tint("dp_scr", 0.85 + 0.15 * sin(t * 60.0) * sin(t * 2.1))


func _goint_ammo(t: float) -> void:
	var a := t * 0.7
	if _n.has("dp_spin"):
		_n["dp_spin"].rotation.y = a
	if _n.has("dp_tt"):
		_n["dp_tt"].rotation.y = a
	_tint("dp_lamp", 1.0, 0.82 + 0.06 * sin(t * 1.3), 0.55)
	_tint("dp_scr", 0.88 + 0.12 * sin(t * 55.0) * sin(t * 1.7))
	_tint("dp_card", 0.3, 0.7 + 0.3 * sin(t * 4.0), 0.4)


func _foint_armor(t: float) -> void:
	if _n.has("dp_rot"):
		_n["dp_rot"].rotation.y = t * 4.2
	_tint("dp_scr", 0.85 + 0.15 * sin(t * 50.0) * sin(t * 1.3))
	_tint("dp_red", 0.7 + 0.3 * absf(sin(t * 2.2)), 0.12, 0.1)
	if _n.has("dp_padlock"):
		_n["dp_padlock"].rotation.z = 0.08 * sin(t * 0.9)
	var sign_m: StandardMaterial3D = _m.get("dp_sign")
	if sign_m != null:
		sign_m.emission_energy_multiplier = 0.2 if fmod(t, 5.1) < 0.12 else 1.0      # (the export folded the JS's 0.25 into the emission colour)


func _goint_armor(t: float) -> void:
	var holo: Node3D = _n.get("dp_holo")
	if holo != null:
		holo.rotation.y = t * 0.8
		if not has_meta(&"holo_y"):
			set_meta(&"holo_y", holo.position.y)
		holo.position.y = float(get_meta(&"holo_y")) + 0.015 * sin(t * 1.6)
	var op := 0.25 if fmod(t, 4.7) < 0.09 else 0.75 + 0.1 * sin(t * 9.0)
	for nm: String in ["dp_holop0", "dp_holop1"]:
		var hm: StandardMaterial3D = _m.get(nm)
		if hm != null:
			hm.albedo_color.a = op
	_tint("dp_scr", 0.88 + 0.12 * sin(t * 52.0) * sin(t * 1.9))
	for nm: String in ["dp_lamp0", "dp_lamp1"]:
		_tint(nm, 1.0, 0.65 + 0.1 * sin(t * 2.0), 0.25)
	if _n.has("dp_emitter"):
		_n["dp_emitter"].rotation.y = -t * 0.5
