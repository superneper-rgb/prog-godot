class_name DeckLook
extends RefCounted
## THE DECK, finished in Godot: the wet running surface (levels/shaders/deck_surface.gdshader) and its lamps as light (levels/shaders/deck_light.gdshader), the parapet lamps over
## the carriageway and the service lights under the slab that pool on the Underline. Where the lamps stand comes from the Deck's own numbers (JS deck-plan.js, city-deck.js
## lampRun and the underside ribs), so the light lands exactly under the lamps the export drew. Everything is made at level load and lives under the level.
## The JS stood a parapet lamp every 15 m, but restarted the count in every 46 m casting bay and ran all three roads into the Harbor corners, so the lamps bunched at the joints and
## piled up at the corners (user, 2026-11-11: "randomly placed in weird nonsensical patterns, some areas spammed"). One in two stays, about every 30 m and alternating sides along
## the whole road, none near a corner; the rest are cut: their masts, arms and heads fold away in the shaders that draw them (`cut`, levels/shaders/city_cut.gdshaderinc).

const GY := -10.0
const RISE := 15.0
const Y := GY + RISE                 # the deck's running surface
const HW := 7.2                      # the deck's half width
const HARBOR_Z := 180.0
const AVENUES := [-72.0, 72.0]       # Gleeman, Vox
const DESCENT_Z0 := 460.0
const SEG := 46.0                    # casting bay length
const LAMP := 15.0                   # the JS's parapet lamp spacing
const KEEP_GAP := 26.0               # the least distance between two lamps kept along a road (about every second one)
const CORNER := 14.0                 # no lamp this near the end of a road where it meets another at a Harbor corner
const COLD := Color(0.42, 0.7, 1.0)  # municipal plant: service lights (JS COLD)
const LAMP_TINTS := [Color(0.66, 0.5, 1.0), Color(1.0, 0.4, 0.56)]

var lamps: Array[Vector4] = []       # the parapet lamp heads that stay: xyz, tint index
var cut: Array[AABB] = []            # the pieces of the lamps that go: mast, arm, head (world boxes, a little larger than the piece)
var service: Array[Vector3] = []     # the service lights under the slab
var bays: Array = []                 # [route, a0, a1] per casting bay, in route order (levels/hub/deck_underside.gd hangs its detail on them)


## The routes as the JS lays them out (city-deck.js `routes`): a point `a` along a route, `off` across it.
static func _routes() -> Array:
	return [
		{"axis": "z", "c": AVENUES[0], "a0": HARBOR_Z + HW, "a1": DESCENT_Z0},
		{"axis": "z", "c": AVENUES[1], "a0": HARBOR_Z + HW, "a1": DESCENT_Z0},
		{"axis": "x", "c": HARBOR_Z, "a0": AVENUES[0] - HW, "a1": AVENUES[1] + HW},
	]


static func p_at(r: Dictionary, a: float, off: float) -> Vector2:
	return _p(r, a, off)


static func _p(r: Dictionary, a: float, off: float) -> Vector2:
	return Vector2(r.c + off, a) if r.axis == "z" else Vector2(a, r.c + off)


## JS lamp-zones.js lampArea: the tint of a lamp on the road whose centre line passes through (cx, cz)
static func lamp_area(cx: float, cz: float) -> int:
	if Vector2(cx, cz).distance_to(Vector2(0.0, 262.0)) < 66.0:
		return 1
	var col := 0
	var row := 0
	for c: float in [-72.0, 0.0, 72.0]:
		if cx + 0.01 >= c:
			col += 1
	for c: float in [236.0, 367.0, 451.0]:
		if cz + 0.01 >= c:
			row += 1
	return (col + row) & 1


## Is `a` along route `r` at a Harbor corner (where the avenues and the Harbor span run into each other)?
static func _at_corner(r: Dictionary, a: float) -> bool:
	if r.axis == "z":
		return a < HARBOR_Z + HW + CORNER
	for av: float in AVENUES:
		if absf(a - av) < HW + CORNER:
			return true
	return false


func _init() -> void:
	for r: Dictionary in _routes():
		var length: float = r.a1 - r.a0
		var n := maxi(1, roundi(length / SEG))
		var step := length / n
		var cands: Array = []      # [a, side] of every lamp the JS stood on this road
		for i in n:
			var a0: float = r.a0 + i * step
			var a1 := a0 + step
			bays.append([r, a0, a1])
			var k := 0
			var a := a0 + 4.0
			while a < a1 - 2.0:      # JS lampRun: alternating sides (restarting in every bay), the head on an arm over the carriageway
				cands.append([a, 1.0 if k % 2 == 1 else -1.0])
				a += LAMP
				k += 1
			a = a0 + 2.5
			while a < a1 - 1.0:      # the underside: a rib every 5 m, a service light on every third
				if roundi((a - a0) / 5.0) % 3 == 0:
					var p := _p(r, a, 0.0)
					service.append(Vector3(p.x, Y - 2.75, p.y))
				a += 5.0
		# keep one about every 30 m, alternating sides where the JS lets it, none at a corner
		var last_a := -1e9
		var last_s := 0.0
		for c: Array in cands:
			var a: float = c[0]
			var s: float = c[1]
			var gap := a - last_a
			if not _at_corner(r, a) and gap >= KEEP_GAP and (s != last_s or gap >= KEEP_GAP * 1.5):
				var h := _p(r, a, s * (HW - 1.05))
				var mid := _p(r, a, 0.0)
				lamps.append(Vector4(h.x, Y + 4.1, h.y, float(lamp_area(mid.x, mid.y))))
				last_a = a
				last_s = s
			else:
				_cut_lamp(r, a, s)


## The pieces of one JS lamp (city-deck.js lampRun): the mast on the parapet, the arm over the carriageway, the lit head under the arm.
func _cut_lamp(r: Dictionary, a: float, s: float) -> void:
	var m := _p(r, a, s * (HW - 0.3))
	var h := _p(r, a, s * (HW - 1.05))
	var z: bool = r.axis == "z"
	var pad := Vector3(0.06, 0.06, 0.06)
	for b: Array in [[Vector3(m.x, Y + 2.6, m.y), Vector3(0.22, 3.4, 0.22)], [Vector3(h.x, Y + 4.3, h.y), Vector3(1.7, 0.2, 0.5) if z else Vector3(0.5, 0.2, 1.7)],
			[Vector3(h.x, Y + 4.1, h.y), Vector3(1.3, 0.16, 0.42) if z else Vector3(0.42, 0.16, 1.3)]]:
		var size: Vector3 = b[1] + pad
		cut.append(AABB(b[0] - size * 0.5, size))


## The cut boxes as shader uniforms (levels/shaders/city_cut.gdshaderinc).
func set_cut(m: ShaderMaterial) -> void:
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	var all := AABB()
	for i in cut.size():
		lo.append(cut[i].position)
		hi.append(cut[i].end)
		all = cut[i] if i == 0 else all.merge(cut[i])
	lo.resize(128)
	hi.resize(128)
	m.set_shader_parameter(&"cut_lo", lo)
	m.set_shader_parameter(&"cut_hi", hi)
	m.set_shader_parameter(&"cut_n", mini(cut.size(), 128))
	m.set_shader_parameter(&"cut_all_lo", all.position)
	m.set_shader_parameter(&"cut_all_hi", all.end)
	if cut.size() > 128:
		push_warning("DeckLook: %d lamp pieces to cut, the shaders take 128" % cut.size())


## Dress the exported Deck: `surface` is the DeckSurface node, `parent` the node the lights go under.
func build(surface: Node, parent: Node3D) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://levels/shaders/deck_surface.gdshader")
	var arr := PackedVector4Array()
	arr.resize(64)
	for i in mini(lamps.size(), 64):
		arr[i] = lamps[i]
	sm.set_shader_parameter(&"lamps", arr)
	sm.set_shader_parameter(&"lamp_n", mini(lamps.size(), 64))
	if lamps.size() > 64:
		push_warning("DeckLook: %d lamps, the surface reflects the first 64" % lamps.size())
	var meshes: Array = surface.find_children("*", "MeshInstance3D", true, false)
	if surface is MeshInstance3D:
		meshes.append(surface)
	for mi: MeshInstance3D in meshes:
		mi.material_override = sm

	# the service lights: from UPLIFT above the lamp (its spill on the ribs, stringers and conduit around it) down to the street; the box's half width is the pool at the bottom
	var svc: Array = []
	for p: Vector3 in service:
		var top := p.y + UPLIFT
		var bottom := GY - 0.4
		svc.append([Transform3D(Basis.from_scale(Vector3(14.0, top - bottom, 14.0)), Vector3(p.x, (top + bottom) * 0.5, p.z)), Color(COLD.r, COLD.g, COLD.b, 2.6)])
	_lights(parent, "DeckLights", svc, UPLIFT)
	# the parapet lamps: from the head down to the deck, not through it
	var heads: Array = []
	for l: Vector4 in lamps:
		var top := l.y + 0.05
		var bottom := Y - 0.3
		var t: Color = LAMP_TINTS[int(l.w)]
		heads.append([Transform3D(Basis.from_scale(Vector3(10.0, top - bottom, 10.0)), Vector3(l.x, (top + bottom) * 0.5, l.z)), Color(t.r, t.g, t.b, 0.55)])
	_lights(parent, "DeckLampLights", heads, 0.05)


const UPLIFT := 1.3      # how far a service light's box reaches above the lamp (deck_light.gdshader `uplift`)


func _lights(parent: Node3D, nm: String, items: Array, uplift: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var lm := ShaderMaterial.new()
	lm.shader = load("res://levels/shaders/deck_light.gdshader")
	lm.set_shader_parameter(&"uplift", uplift)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = lm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
