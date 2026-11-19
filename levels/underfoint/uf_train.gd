class_name UfTrain
extends Node3D
## The last train out of UNDERFOINT: an armoured locomotive, its power car and the flatcar you ride on, with SERN's gun on the flatcar (levels/underfoint/uf_turret.gd).
## Restyled 2026-11-15 (user: "Make the train have more of a cyber future look like the aesthetic we have in the rest of the game"). Until then: an old tank-and-tender steam engine, a coal tender and a
## plank flatcar (2026-11-12). Now it is FOINT CITY's palette: near-black violet armour with a wet gloss, cyan light lines run along it, a white headlight bar across a wedge nose, amber power vents that
## breathe with its drive, a violet core under a dome on its roof, red markers at the corners. Built in code (boxes and cylinders, a few materials): it is seen from the car at 10-30 m, behind its own light.
## The flatcar stands still in the world (levels/underfoint/uf_chase.gd moves the route past it, levels/underfoint/uf_route.gd); the power car and the engine are set on the route ahead of it every
## frame, so on a bend they swing off to the side the way a real train's do. The wheels turn at the train's speed under skirts; the drive "beat" (chuff) pulses the vents and puffs heat out of the roof
## vents into the route's space (it streams back over you and is left behind); the headlight bar lights the line ahead.
## The flatcar is three 6 m sections behind a short footplate: every blow the Sigil lands tears the last one off (sections). Its decks are the only floor the ride has.
## Along the train, from the flatcar's middle (the route's s): flatcar -9..9, footplate 9..10.5, power car 11..17 (middle 14), engine 18..32 (middle 25).

const Y := UnderfointLevel.STATION_Y
const AT := UfRoute.HOME              # the flatcar's middle on the rails, where the train stands
const DECK := 1.2
const SEC := 6.0
const TENDER_AT := 14.0
const ENGINE_AT := 25.0
const SMALL_R := 0.45
const CYAN := Color(0.35, 0.92, 1.0)
const AMBER := Color(1.0, 0.55, 0.14)
const VIOLET := Color(0.62, 0.38, 1.0)

var blockers: Array[World.Solid] = []      # the engine's and power car's solids (for the run on foot only)
var lv: UnderfointLevel
var route: UfRoute
var engine := Node3D.new()
var tender := Node3D.new()                 # (the power car: "tender" kept, it is what the director calls it)
var sections: Array[Node3D] = []
var deck_solids: Array[World.Solid] = []
var tm: OutcastNpc = null             # the Ticket Man, driving from the operator's booth at the engine's back
var head_light: SpotLight3D
var fire_light: OmniLight3D           # the core's light on the roof (was the firebox's)
var tail_light: OmniLight3D
var bounce := 0.0                     # the director's jolt, metres: the train's own bodies jump with it
var chuff := 0.0                      # 0..1, set on each beat of the drive
var _mats := {}
var _wheels: Array = []               # [node, radius]
var _phi := 0.0
var _beat := 0
var _t := 0.0
var _vent_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D


func _init(p_lv: UnderfointLevel, p_route: UfRoute) -> void:
	lv = p_lv
	route = p_route
	name = "UfTrain"


func _m(tag: String, c: Color, metal: float, rough: float, grime: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if grime:      # a faint wear in the object's own space (so it stays put as the engine swings): soot in the seams, a wet sheen on the flats
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.frequency = 0.05
		nz.fractal_octaves = 4
		var tx := NoiseTexture2D.new()
		tx.width = 128
		tx.height = 128
		tx.seamless = true
		tx.noise = nz
		tx.color_ramp = UfBuild._ramp(0.72, 1.0)
		tx.generate_mipmaps = true
		m.albedo_texture = tx
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_mats[tag] = m
	return m


func _glow(tag: String, c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	_mats[tag] = m
	return m


## Everything drawn here goes through a builder of its own with these materials (the level's builder is busy); the flatcar's floors go through the level's (they are solid)
func build(b: UfBuild) -> void:
	var tb := UfBuild.new(b.world)
	_m("armor", Color(0.055, 0.05, 0.08), 0.6, 0.3)          # FOINT's near-black violet, glossy
	_m("panel", Color(0.1, 0.1, 0.13), 0.75, 0.36)
	_m("dark", Color(0.022, 0.022, 0.028), 0.6, 0.5)
	_m("steel", Color(0.2, 0.2, 0.22), 0.9, 0.3)
	_m("deck", Color(0.11, 0.11, 0.125), 0.85, 0.42)
	var glass := StandardMaterial3D.new()      # the nose's windshield: dark, wet, a cyan cast from inside
	glass.albedo_color = Color(0.02, 0.05, 0.06)
	glass.metallic = 0.2
	glass.roughness = 0.08
	glass.emission_enabled = true
	glass.emission = Color(0.08, 0.35, 0.4)
	glass.emission_energy_multiplier = 0.6
	_mats["glass"] = glass
	_glow("cyan", CYAN, 3.2)
	_glow("white", Color(1.0, 0.96, 0.88), 7.0)
	_glow("red", Color(1.0, 0.07, 0.05), 4.0)
	_glow("screen", Color(0.3, 1.0, 0.5), 1.8)
	_glow("cell", Color(0.25, 0.8, 1.0), 1.3)      # the power car's cells (at the lines' 3.2 they bloomed white)
	_vent_mat = _glow("vent", AMBER, 2.0)
	_core_mat = _glow("core", VIOLET, 3.0)
	for k: String in _mats:
		tb.mats[k] = _mats[k]
	engine.name = "engine"
	tender.name = "tender"
	add_child(engine)
	add_child(tender)
	_engine(tb)
	_tender(tb)
	_flatcar(tb, b)
	place()


# ---- the engine (its own space: middle of it on the rails, +Z ahead, +X its left) ---------------------------------------------------------------------------------------------

func _engine(tb: UfBuild) -> void:
	var I := Basis.IDENTITY
	var up := Basis(Vector3.RIGHT, -PI * 0.5)      # a cylinder's axis turned from +Z to +Y
	# the frame and the skirts over the wheels, a cyan line along each skirt's foot
	tb.obox("dark", Transform3D(I, Vector3(0.0, 0.82, 0.0)), Vector3(1.32, 0.22, 6.9))
	for side: float in [-1.0, 1.0]:
		tb.obox("armor", Transform3D(I, Vector3(side * 1.42, 0.88, -0.2)), Vector3(0.05, 0.38, 6.4))
		tb.obox("cyan", Transform3D(I, Vector3(side * 1.475, 0.53, -0.2)), Vector3(0.012, 0.022, 6.2))
	# the body: from the operator's booth at the back to the nose, shoulders above, a spine along the roof
	tb.obox("armor", Transform3D(I, Vector3(0.0, 1.85, 0.65)), Vector3(1.45, 0.75, 5.05))
	tb.obox("panel", Transform3D(I, Vector3(0.0, 2.83, 0.3)), Vector3(1.26, 0.24, 4.6))
	tb.obox("armor", Transform3D(I, Vector3(0.0, 3.2, 0.0)), Vector3(0.82, 0.14, 4.0))
	tb.obox("armor", Transform3D(Basis(Vector3(0, 0, 1), 0.55), Vector3(1.32, 2.72, 0.3)), Vector3(0.05, 0.3, 4.6))      # the shoulders' chamfers
	tb.obox("armor", Transform3D(Basis(Vector3(0, 0, 1), -0.55), Vector3(-1.32, 2.72, 0.3)), Vector3(0.05, 0.3, 4.6))
	# panel seams, and the light lines along it
	for z: float in [-3.0, -1.2, 0.6, 2.4, 4.0]:
		for side: float in [-1.0, 1.0]:
			tb.obox("dark", Transform3D(I, Vector3(side * 1.462, 1.85, z)), Vector3(0.012, 0.72, 0.025))
	for side: float in [-1.0, 1.0]:
		tb.obox("cyan", Transform3D(I, Vector3(side * 1.468, 2.28, 0.65)), Vector3(0.012, 0.028, 4.95))
		tb.obox("cyan", Transform3D(I, Vector3(side * 1.27, 3.08, 0.3)), Vector3(0.012, 0.02, 4.5))
		tb.obox("red", Transform3D(I, Vector3(side * 1.36, 3.12, 4.85)), Vector3(0.08, 0.06, 0.08))      # the corner markers
		tb.obox("red", Transform3D(I, Vector3(side * 1.36, 3.12, -4.35)), Vector3(0.08, 0.06, 0.08))
		# the power vents: three slatted grilles a side, lit from inside, breathing with the drive
		for z: float in [-2.1, -0.3, 1.5]:
			tb.obox("vent", Transform3D(I, Vector3(side * 1.462, 1.6, z)), Vector3(0.008, 0.26, 0.55))
			for k in 4:
				tb.obox("dark", Transform3D(I, Vector3(side * 1.47, 1.42 + k * 0.12, z)), Vector3(0.012, 0.018, 0.56))
	# the nose: a wedge, a raked windshield in a frame, the headlight bar and its two clusters, red markers low
	tb.obox("armor", Transform3D(I, Vector3(0.0, 1.32, 6.35)), Vector3(1.44, 0.55, 0.85))
	tb.obox("armor", Transform3D(Basis(Vector3.RIGHT, 0.62), Vector3(0.0, 2.1, 6.02)), Vector3(1.42, 0.08, 0.95))      # the nose's top, sloping down to the front
	tb.obox("glass", Transform3D(Basis(Vector3.RIGHT, -0.85), Vector3(0.0, 2.55, 5.55)), Vector3(1.22, 0.55, 0.03))
	tb.obox("dark", Transform3D(Basis(Vector3.RIGHT, -0.85), Vector3(0.0, 2.55, 5.53)), Vector3(1.3, 0.62, 0.02))
	tb.obox("dark", Transform3D(I, Vector3(0.0, 1.45, 7.22)), Vector3(1.2, 0.1, 0.03))
	tb.obox("white", Transform3D(I, Vector3(0.0, 1.45, 7.25)), Vector3(1.05, 0.045, 0.02))
	for side: float in [-1.0, 1.0]:
		tb.obox("white", Transform3D(I, Vector3(side * 0.95, 1.12, 7.23)), Vector3(0.2, 0.09, 0.02))
		tb.obox("red", Transform3D(I, Vector3(side * 1.3, 0.92, 7.22)), Vector3(0.07, 0.05, 0.02))
	tb.obox("dark", Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0.0, 0.62, 7.35)), Vector3(1.3, 0.05, 0.4))      # the plough
	tb.obox("cyan", Transform3D(I, Vector3(0.0, 0.8, 7.2)), Vector3(1.1, 0.015, 0.015))
	# the core on its roof: a dome over a violet glow, two heat vents behind it
	tb.ocyl("dark", Transform3D(up, Vector3(0.0, 3.4, -1.6)), 0.75, 0.12, 20)
	tb.ocyl("core", Transform3D(up, Vector3(0.0, 3.56, -1.6)), 0.62, 0.05, 20)
	tb.ocyl("glass", Transform3D(up, Vector3(0.0, 3.72, -1.6)), 0.6, 0.12, 20, true, 1.0, 0.2, 0.35)
	for side: float in [-1.0, 1.0]:
		tb.obox("panel", Transform3D(I, Vector3(side * 0.5, 3.48, -3.2)), Vector3(0.24, 0.16, 0.42))
		tb.obox("vent", Transform3D(I, Vector3(side * 0.5, 3.645, -3.2)), Vector3(0.18, 0.01, 0.34))
	# the operator's booth at its back, open to the car: floor, walls, roof, the bulkhead with its screens (the Ticket Man rides here)
	tb.obox("dark", Transform3D(I, Vector3(0.0, 1.27, -5.55)), Vector3(1.45, 0.06, 1.15))
	for side: float in [-1.0, 1.0]:
		tb.obox("armor", Transform3D(I, Vector3(side * 1.42, 2.2, -5.5)), Vector3(0.05, 0.92, 1.1))
		tb.obox("cyan", Transform3D(I, Vector3(side * 1.475, 2.95, -5.5)), Vector3(0.012, 0.02, 1.05))
	tb.obox("armor", Transform3D(I, Vector3(0.0, 3.18, -5.45)), Vector3(1.52, 0.08, 1.25))
	tb.obox("panel", Transform3D(I, Vector3(0.0, 2.2, -4.42)), Vector3(1.4, 0.92, 0.04))
	tb.obox("screen", Transform3D(I, Vector3(0.55, 2.25, -4.46)), Vector3(0.32, 0.2, 0.01))
	tb.obox("vent", Transform3D(I, Vector3(-0.45, 2.15, -4.46)), Vector3(0.22, 0.12, 0.01))
	tb.obox("cyan", Transform3D(I, Vector3(0.0, 1.7, -4.46)), Vector3(1.0, 0.015, 0.01))
	tb.obox("dark", Transform3D(I, Vector3(0.0, 0.95, -6.85)), Vector3(1.3, 0.22, 0.12))
	tb.commit(engine)
	head_light = SpotLight3D.new()
	head_light.position = Vector3(0.0, 1.45, 7.45)
	head_light.rotation.y = PI      # (a spot shines down its -Z)
	head_light.light_color = Color("f2f6ff")
	head_light.light_energy = 9.0 * UnderfointLevel.GAIN
	head_light.spot_range = 75.0
	head_light.spot_angle = 26.0
	head_light.spot_attenuation = 1.1
	engine.add_child(head_light)
	fire_light = OmniLight3D.new()      # the core, over the roof
	fire_light.position = Vector3(0.0, 4.1, -1.6)
	fire_light.light_color = VIOLET
	fire_light.light_energy = 1.4 * UnderfointLevel.GAIN
	fire_light.omni_range = 7.0
	engine.add_child(fire_light)
	var booth := OmniLight3D.new()      # the booth's light, out of its open back over the power car and the footplate: the engine reads from the car
	booth.position = Vector3(0.0, 2.9, -5.9)
	booth.light_color = Color("bfeaff")
	booth.light_energy = 1.2 * UnderfointLevel.GAIN
	booth.omni_range = 12.0
	booth.omni_attenuation = 1.3
	engine.add_child(booth)
	# two bogies under the skirts, two axles each
	for z: float in [4.4, 3.2, -2.6, -3.8]:
		for side: float in [-1.0, 1.0]:
			_wheel(tb, engine, Vector3(side * 1.05, SMALL_R + 0.05, z), SMALL_R + 0.05)
	var tml := OutcastNpc.new("ticketman")
	add_child(tml)
	tm = tml
	lv._outcasts.append(tml)


## A wheel: tyre, a disc of spokes, the hub. Its own node so it turns.
func _wheel(tb: UfBuild, parent: Node3D, at: Vector3, r: float) -> void:
	var ax := Basis(Vector3.UP, PI * 0.5)      # the axis turned from +Z to +X
	tb.ocyl("steel", Transform3D(ax, Vector3.ZERO), r, 0.075, 16)
	tb.ocyl("dark", Transform3D(ax, Vector3.ZERO), r * 0.8, 0.085, 16, true, 0.8)
	tb.ocyl("cyan", Transform3D(ax, Vector3.ZERO), r * 0.2, 0.09, 8)
	var w := Node3D.new()
	w.position = at
	parent.add_child(w)
	tb.commit(w)
	_wheels.append([w, r])


# ---- the power car ---------------------------------------------------------------------------------------------------------------------------------------------------------

func _tender(tb: UfBuild) -> void:
	var I := Basis.IDENTITY
	tb.obox("dark", Transform3D(I, Vector3(0.0, 0.85, 0.0)), Vector3(1.3, 0.2, 2.95))
	tb.obox("armor", Transform3D(I, Vector3(0.0, 1.95, 0.05)), Vector3(1.45, 0.9, 2.75))
	tb.obox("panel", Transform3D(I, Vector3(0.0, 2.92, 0.05)), Vector3(1.3, 0.08, 2.6))
	for z: float in [-2.0, -1.2, -0.4, 0.4, 1.2, 2.0]:      # cooling fins across its roof
		tb.obox("dark", Transform3D(I, Vector3(0.0, 3.06, z)), Vector3(1.15, 0.07, 0.05))
	for side: float in [-1.0, 1.0]:      # the cells, glowing through their grilles, four a side
		for k in 4:
			var z := -1.95 + k * 1.3
			tb.obox("cell", Transform3D(I, Vector3(side * 1.462, 1.95, z)), Vector3(0.008, 0.42, 0.45))
			tb.obox("dark", Transform3D(I, Vector3(side * 1.47, 1.95, z)), Vector3(0.012, 0.44, 0.02))
			tb.obox("dark", Transform3D(I, Vector3(side * 1.47, 1.95, z)), Vector3(0.012, 0.02, 0.47))
		tb.obox("cyan", Transform3D(I, Vector3(side * 1.468, 2.62, 0.05)), Vector3(0.012, 0.025, 2.7))
		tb.obox("dark", Transform3D(I, Vector3(side * 1.42, 0.88, 0.0)), Vector3(0.05, 0.32, 2.8))
	tb.obox("red", Transform3D(I, Vector3(1.2, 3.1, -2.6)), Vector3(0.09, 0.07, 0.09))      # a red beacon on its back corner
	tb.obox("red", Transform3D(I, Vector3(-1.2, 3.1, -2.6)), Vector3(0.09, 0.07, 0.09))
	# its back, the face the car looks at: a door with a lit slit, hazard strips either side of it, a grille, two conduits, the coupling's housing
	tb.obox("panel", Transform3D(I, Vector3(0.0, 1.95, -2.83)), Vector3(0.48, 0.92, 0.05))
	tb.obox("dark", Transform3D(I, Vector3(0.0, 1.95, -2.86)), Vector3(0.42, 0.86, 0.02))
	tb.obox("cyan", Transform3D(I, Vector3(0.0, 2.45, -2.885)), Vector3(0.3, 0.035, 0.01))
	tb.obox("screen", Transform3D(I, Vector3(0.28, 1.7, -2.885)), Vector3(0.06, 0.04, 0.01))
	for side: float in [-1.0, 1.0]:
		tb.obox("vent", Transform3D(I, Vector3(side * 0.62, 1.95, -2.84)), Vector3(0.035, 0.85, 0.01))
		tb.obox("dark", Transform3D(I, Vector3(side * 1.05, 2.25, -2.85)), Vector3(0.28, 0.32, 0.03))      # a grille
		for k in 5:
			tb.obox("panel", Transform3D(I, Vector3(side * 1.05, 2.03 + k * 0.11, -2.87)), Vector3(0.26, 0.015, 0.01))
		tb.ocyl("steel", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(side * 0.95, 1.55, -2.88)), 0.06, 0.55, 8)      # conduits down to the frame
		tb.obox("armor", Transform3D(Basis(Vector3(0, 0, 1), side * -0.6), Vector3(side * 1.33, 2.86, 0.05)), Vector3(0.05, 0.22, 2.7))      # the roof's chamfers
	tb.obox("panel", Transform3D(I, Vector3(0.0, 1.0, -2.9)), Vector3(0.7, 0.18, 0.08))
	tb.obox("cyan", Transform3D(I, Vector3(0.0, 2.88, -2.84)), Vector3(1.2, 0.015, 0.01))
	tb.commit(tender)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 3.4, -2.6)
	lamp.light_color = Color("ff3a2a")
	lamp.light_energy = 0.5 * UnderfointLevel.GAIN
	lamp.omni_range = 6.0
	lamp.omni_attenuation = 1.6
	lamp.light_specular = 0.1
	tender.add_child(lamp)
	for z: float in [-2.0, -1.0, 1.0, 2.0]:
		for side: float in [-1.0, 1.0]:
			_wheel(tb, tender, Vector3(side * 1.0, SMALL_R, z), SMALL_R)


# ---- the flatcar (in the world, still) ---------------------------------------------------------------------------------------------------------------------------------------

func _flatcar(tb: UfBuild, b: UfBuild) -> void:
	var w := lv.world
	var x := AT.x
	for k: String in ["deck", "armor", "dark", "steel", "red"]:      # the level's builder draws the solid floors: it gets the train's materials under its own names
		b.mats["t_" + k] = _mats[k]
	var near := (_mats["cyan"] as StandardMaterial3D).duplicate() as StandardMaterial3D      # (the car's own lines are a metre from the camera: at the engine's 3.2 they bloomed to white bars)
	near.emission_energy_multiplier = 0.9
	b.mats["t_cyan"] = near
	# the footplate between the flatcar and the power car, and what stands in the way ahead of it (the power car's and the engine's bulk: nobody walks onto those)
	b.box("t_deck", x - 1.7, x + 1.7, Y + 1.0, Y + DECK, AT.z + 9.0, AT.z + 10.5)
	b.box("t_dark", x - 1.7, x + 1.7, Y + 0.7, Y + 1.0, AT.z + 9.0, AT.z + 10.5, false)
	# (kept: the chase takes these two away for the ride. You cannot leave the car then, and standing they stopped every shot at the Sigil when it is on the line ahead.)
	blockers.append(w.add({"kind": "box", "cx": x, "cz": AT.z + 14.0, "hx": 1.5, "hz": 3.4, "bottom": Y, "top": Y + 3.0, "tag": "tender", "no_cam": true}))
	blockers.append(w.add({"kind": "box", "cx": x, "cz": AT.z + 25.0, "hx": 1.6, "hz": 7.0, "bottom": Y, "top": Y + 4.6, "tag": "engine", "no_cam": true}))
	var fp := Node3D.new()
	fp.name = "footplate"
	add_child(fp)
	b.commit(fp)
	for k in 3:      # k 0 the front section .. 2 the tail
		var z0 := AT.z + 3.0 - k * SEC
		deck_solids.append(b.box("t_deck", x - 1.7, x + 1.7, Y + 1.0, Y + DECK, z0, z0 + SEC))
		b.box("t_armor", x - 1.74, x - 1.5, Y + 0.6, Y + 1.12, z0 + 0.05, z0 + SEC - 0.05, false)      # the side beams, armoured
		b.box("t_armor", x + 1.5, x + 1.74, Y + 0.6, Y + 1.12, z0 + 0.05, z0 + SEC - 0.05, false)
		b.box("t_cyan", x - 1.755, x - 1.74, Y + 0.85, Y + 0.88, z0 + 0.1, z0 + SEC - 0.1, false)      # a light line along each
		b.box("t_cyan", x + 1.74, x + 1.755, Y + 0.85, Y + 0.88, z0 + 0.1, z0 + SEC - 0.1, false)
		b.box("t_dark", x - 1.3, x + 1.3, Y + 0.6, Y + 0.75, z0 + 1.6, z0 + 4.4, false)      # the truck's bolster
		for q: float in [1.5, 3.0, 4.5]:      # floor plate seams
			b.box("t_dark", x - 1.68, x + 1.68, Y + DECK, Y + DECK + 0.006, z0 + q - 0.02, z0 + q + 0.02, false)
		for side: float in [-1.0, 1.0]:      # the rail: posts, a mid rail, a top rail with a cyan line on it
			for q: float in [0.3, 3.0, 5.7]:
				b.box("t_steel", x + side * 1.62 - 0.045, x + side * 1.62 + 0.045, Y + DECK, Y + 2.1, z0 + q - 0.045, z0 + q + 0.045, false)
			b.box("t_dark", x + side * 1.62 - 0.035, x + side * 1.62 + 0.035, Y + 2.02, Y + 2.1, z0 + 0.3, z0 + 5.7, false)
			b.box("t_cyan", x + side * 1.62 - 0.012, x + side * 1.62 + 0.012, Y + 2.1, Y + 2.115, z0 + 0.32, z0 + 5.68, false)
			b.box("t_dark", x + side * 1.62 - 0.02, x + side * 1.62 + 0.02, Y + 1.55, Y + 1.59, z0 + 0.3, z0 + 5.7, false)
		if k == 2:      # the tail: buffers, the coupling, a step up, a red light bar across it
			for side: float in [-1.0, 1.0]:
				b.box("t_steel", x + side * 1.0 - 0.18, x + side * 1.0 + 0.18, Y + 0.85, Y + 1.15, z0 - 0.45, z0, false)
				b.box("t_dark", x + side * 1.0 - 0.3, x + side * 1.0 + 0.3, Y + 0.72, Y + 1.28, z0 - 0.55, z0 - 0.45, false)
			b.box("t_armor", x - 1.7, x + 1.7, Y + 0.65, Y + 1.0, z0 - 0.15, z0, false)
			b.box("t_red", x - 1.3, x + 1.3, Y + 0.9, Y + 0.95, z0 - 0.17, z0 - 0.15, false)
			b.box("t_deck", x - 0.5, x + 0.5, Y + 0.45, Y + 0.55, z0 - 0.7, z0 - 0.1)      # the step (solid: you climb on by it)
			b.box("t_dark", x - 0.5, x + 0.5, Y + 0.0, Y + 0.45, z0 - 0.45, z0 - 0.35, false)
		var sn := Node3D.new()
		sn.name = "section%d" % k
		add_child(sn)
		b.commit(sn)
		sections.append(sn)
		for zz: float in [z0 + 2.3, z0 + 3.7]:      # the truck's wheels, which turn
			for side: float in [-1.0, 1.0]:
				_wheel(tb, sn, Vector3(x + side * 0.9, Y + SMALL_R, zz), SMALL_R)
		if k == 2:
			# (2026-11-15: was 1.2 x GAIN, 9 m, at lamp height a metre behind the car: it lit Prog red-pink from behind and blew him out whenever he turned to the camera. Now it is low, behind the
			# buffers, falls off fast and has no highlight: it reds the coupling, the buffers and the track running away under you, not the man on the deck.)
			tail_light = OmniLight3D.new()
			tail_light.position = Vector3(x + 0.9, Y + 0.6, z0 - 1.5)
			tail_light.light_color = Color("ff2a1a")
			tail_light.light_energy = 0.5 * UnderfointLevel.GAIN
			tail_light.light_specular = 0.0
			tail_light.omni_range = 5.5
			tail_light.omni_attenuation = 2.2
			sn.add_child(tail_light)
	lv.district.prop("old_military_crate", x - 1.1, Y + DECK, AT.z + 8.2, 0.4, 1.0)      # what SERN left on it: the rounds you are firing


# ---- every frame ------------------------------------------------------------------------------------------------------------------------------------------------------------

## The power car and the engine on the route ahead (they swing off on a bend); the Ticket Man in the booth at the engine's back
func place() -> void:
	tender.transform = route.world_xf(route.s + TENDER_AT, 0.0, bounce * 0.6)
	engine.transform = route.world_xf(route.s + ENGINE_AT, 0.0, bounce * 0.5)
	if tm != null:
		var at := engine.transform * Vector3(0.45, 1.3, -5.3)
		var fwd := engine.transform.basis.z
		tm.place(at.x, at.y, at.z, atan2(-fwd.x, -fwd.z) + 0.35)


func update(dt: float, v: float) -> void:
	_t += dt
	place()
	_phi += v / SMALL_R * dt
	for q: Array in _wheels:
		(q[0] as Node3D).rotation.x = _phi * SMALL_R / float(q[1])
	# the drive's beat: the vents breathe, the core pulses, heat goes up out of the roof vents into the route's space
	var beat := int(_phi / (PI * 0.5))
	chuff = maxf(0.0, chuff - dt * 4.0)
	if beat != _beat and v > 0.5:
		_beat = beat
		chuff = 1.0
		var inv := route.transform.affine_inverse()
		for side: float in [-1.0, 1.0]:
			var vent := inv * (engine.transform * Vector3(side * 0.5, 3.75, -3.2))
			route.smoke(vent, inv.basis * (engine.transform.basis * Vector3(side * 0.5, 2.5, 0.0)), 0.4, 1.8, 0.9, Color(0.4, 0.44, 0.52, 0.13))
		if randf() < 0.25:      # a spit of sparks off the core now and then
			var core := inv * (engine.transform * Vector3(0.0, 3.8, -1.6))
			for k in 3:
				route.fire(core, inv.basis * Vector3(randf_range(-2.0, 2.0), randf_range(3.0, 6.0), randf_range(-2.0, 2.0)), 0.07, 0.0, randf_range(0.3, 0.6), Color(0.7, 0.45, 1.0) * 2.0)
	_vent_mat.emission_energy_multiplier = 1.6 + 2.4 * chuff + 0.3 * clampf(v / 30.0, 0.0, 1.0)
	_core_mat.emission_energy_multiplier = 2.6 + 1.6 * chuff + 0.4 * sin(_t * 7.0)
	head_light.light_energy = (9.0 + sin(_t * 31.0) * 0.3) * UnderfointLevel.GAIN
	fire_light.light_energy = (1.2 + 0.8 * chuff) * UnderfointLevel.GAIN
	for k in sections.size():
		if sections[k].visible and sections[k].get_meta(&"torn", -1.0) < 0.0:
			sections[k].position.y = bounce * (0.35 + 0.2 * k)
