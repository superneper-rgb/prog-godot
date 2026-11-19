class_name MsGodmother
extends RefCounted
## THE GODMOTHER, the boss you do not kill (JS levels/mothership/godmother.js). Six metres of gray matriarch in a quilted plum silk bathrobe with a pink marabou boa, pearls, curlers and rhinestone cat-eye glasses, sat in a tufted crimson wingback on a little gold saucer of her own.
## A three-eyed lavender Persian sleeps on her lap. You are not trying to kill her: you are trying to make her RESPECT you. The bar fills: hits on her hide barely count (x0.12); hits while she is DOWN, DIZZY, or while her head glows count in full. At 100 % she raises one huge hand ("Enough.") and the fight is over.
##   PHASE 1  THE MATRIARCH    she drifts round the room. PSI BLASTS (the palm glows purple 0.8 s, then a fan of five plasma bolts), the GRAVITY BOMB (a black hole wells up over her head; an amber ring marks where it lands 1.3 s later: a GRAVITY WELL for 4.5 s), THE CALL (a psychic finger-snap: two probe butlers ride up the Spine Beam's shaft). Three anti-grav EMITTERS glow under her chair: shoot all three and she is DOWN for 6 s.
##   PHASE 2  THE FAMILY FLOOR (35 %) she tears the floor up: sixteen tiles float over the PIT. The SWEEP: a giant red beam turns round the room once, low: stand on a HIGH tile; her head glows gold (a halo spins over it) while she channels it. Shots on the glowing head count in full and crack her FOCUS: crack it and the beam dies and she is DIZZY. BUTTON MEN ride the Spine Beam up (cloaked).
##   PHASE 3  THE HOUSE        (70 %) the floor comes back and the whole room TURNS. The SLAM: two golden shockwave rings (jump them); then she is DIZZY for 3.5 s. A tommy-gun gray and a Consigliere come up the beam.
## Every move is telegraphed by pose, face, colour and sound; nothing hits you from off screen; a hit gives you a moment of mercy. Each hit on her makes her flinch.

const MODEL := "res://assets/npcs/godmother/model.glb"
const PF := 44.0
const ARENA := 21.0
const RESPECT := 2600.0
const ARMOUR := 0.12
const PHASE2 := 0.35
const PHASE3 := 0.7
const DOWN_T := 6.0
const DIZZY_T := 3.5
const BOLT_N := 5
const BOLT_SPREAD := 0.55
const BOLT_SPEED := 15.0
const BOLT_DMG := 7.0
const WELL_DMG := 14.0
const WELL_R := 2.6
const WELL_T := 4.5
const WELL_PULL := 2.6
const SWEEP_SPEED := 1.0
const SWEEP_DMG := 14.0
const SLAM_SPEED := 10.0
const SLAM_DMG := 16.0
const PIT_DPS := 12.0
const HEAD_HOT := 1.6      # her glowing head while she channels the sweep (the JS 1.15 read as no extra damage at all: 2026-11-15)
const FOCUS := 260.0       # raw damage on the glowing head during one sweep that breaks her focus: the beam dies and she is DIZZY (new 2026-11-15: the glow had no payoff you could see)
const EMIT_HP := 70.0
const MERCY := 0.8
const BIG := 1e6
const LOOP := {1: ["blasts", "blasts", "bomb", "blasts", "call"], 2: ["sweep", "blasts", "bm", "sweep", "blasts", "bomb"], 3: ["slam", "blasts", "bomb", "slam", "blasts", "call"]}


class Spr:
	var x := 0.0
	var v := 0.0


class Arm:
	var sh: Node3D
	var el: Node3D
	var hand: Node3D
	var glow: MeshInstance3D
	var f: Array = []
	var t: Array = []


class Emitter:
	var mesh: Node3D
	var halo: MeshInstance3D
	var a := 0.0
	var shell: MeshInstance3D
	var r1: Node3D
	var r2: Node3D
	var cage: Node3D
	var beam: MeshInstance3D


class Bolt:
	var m: Node3D
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var t := 0.0


class Well:
	var m: Node3D
	var disc: MeshInstance3D
	var edge: MeshInstance3D
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var t := 0.0
	var tick := 0.0


class ShockRing:
	var m: MeshInstance3D
	var r := 2.6
	var delay := 0.0
	var hit := false


## JS `W`: this frame's target pose
class PoseT:
	var lean := 0.05
	var twist := 0.0
	var roll := 0.0
	var hx := -0.04
	var hy := 0.0
	var hz := 0.0
	var sh_lx := 0.0
	var sh_lz := -0.12
	var sh_ly := 0.15
	var el_lx := 0.0
	var h_lx := 0.35
	var h_ly := 0.0
	var h_lz := 0.0
	var f_l := 0.25
	var t_l := 0.2
	var sh_rx := -0.5
	var sh_rz := -0.2
	var sh_ry := -0.25
	var el_rx := -1.75
	var h_rx := 0.1
	var h_ry := 0.5
	var h_rz := 0.0
	var f_r: Array = [0.7, 0.75, 0.0]
	var t_r := 0.6
	var jaw := 0.0
	var lid_l := 0.32
	var lid_r := 0.36
	var b_ly := 0.03
	var b_ry := 0.0
	var b_lz := -0.12
	var b_rz := 0.12
	var gz := 0.0
	var gy := 0.0
	var glow_l := 0.0
	var glow_r := 0.0
	var cat_up := 0.0
	var cat_puff := 0.0
	var cat_away := 0.0
	var shin_l := 0.0
	var shin_r := 0.0
	var point_l := false


var L: MothershipLevel
var mode := "off"
var phase := 1
var respect := 0.0
var x := 0.0
var y := PF + 2.2
var z := 12.0
var yaw := PI
var mv := ""
var mt := 0.0
var idx := 0
var gap := 1.5
var down_t := 0.0
var dizzy_t := 0.0
var channel := 0.0
var orbit_a := 0.0
var mercy := 0.0
var tiles_up_ := 0
var spin_a := 0.0
var sweep_a := 0.0
var intro_t := 0.0
var enough_t := 0.0
var talk := false
var look_x: Variant = null
var look_z: Variant = null
var foes: Array = []
var hit := 0.0
var label := ""
var say_t := 0.0
var flinch := 0.0
var shot := 0
var first := false
var reinf := 0
var shake_ := false
var bomb_t := [0.0, 0.0]
var bomb_from := Vector3.ZERO
var call_t: Variant = null
var cine_puff := 0
var squash := 0.0
var flash := 0.0
var cup_in := 1.0
var hissed := false
var focus := 0.0
var sweeps := 0
var halo_hit := 0.0

var g: Node3D
var model: Node3D
var _base_mats: Array[StandardMaterial3D] = []
var flash_mats: Array = []
var bm_a: StandardMaterial3D = null
var bm_b: StandardMaterial3D = null
var throne: Node3D
var body: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var jaw: Node3D
var mouth: Node3D
var glasses: Node3D
var curlers: Node3D
var cat: Node3D
var cat_head: Node3D
var cat_tail: Node3D
var lid_l: Node3D
var lid_r: Node3D
var brow_l: Node3D
var brow_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var arm_l: Arm
var arm_r: Arm
var emitters: Array[Emitter] = []
var held_cup: Node3D
var bomb: Node3D
var bomb_shell: MeshInstance3D
var bomb_rings: Array[Node3D] = []
var bomb_glow: MeshInstance3D
var call_ring: MeshInstance3D
var head_glow: MeshInstance3D
var halo: MeshInstance3D
var spirals: Array[MeshInstance3D] = []
var stars: Node3D
var t_body: Target
var t_head: Target
var t_emit: Array[Target] = []
var all_t: Array[Target] = []
var solid: World.Solid
var combat: Combat = null
var bolts: Array[Bolt] = []
var wells: Array[Well] = []
var rings: Array[ShockRing] = []
var bolt_pool: Array[Node3D] = []
var bomb_ring: MeshInstance3D
var sweep: Node3D
var sweep_m: MeshInstance3D
var sweep_light: OmniLight3D
var beam_grip: MeshInstance3D
var _well_disc: ArrayMesh
var _well_edge: TorusMesh
var _ring_mesh: TorusMesh
var SPR: Dictionary = {}
var rest_r: Dictionary = {}
var rest_p: Dictionary = {}
var rest_q: Dictionary = {}
var blink_t := 2.5
var blink := 0.0
var sip_t := 4.0
var sip := -1.0
var tap_t := 6.0
var tap := -1.0
var cat_home := Vector3.ZERO


func N(nm: String) -> Node3D:
	var n := model.find_child(nm, true, false) as Node3D
	if n == null:
		push_warning("GODMOTHER: no node " + nm)
	return n


func _init(level: MothershipLevel, root: Node3D) -> void:
	L = level
	g = Node3D.new()
	g.name = "THE GODMOTHER"
	root.add_child(g)
	g.visible = false
	var ps: PackedScene = load(MODEL)
	model = ps.instantiate()
	g.add_child(model)
	throne = N("gm_throne")
	body = N("gm_body")
	chest = N("gm_chest")
	neck = N("gm_neck")
	head = N("gm_head")
	jaw = N("gm_jaw")
	mouth = N("gm_mouth")
	glasses = N("gm_glasses")
	curlers = N("gm_curlers")
	cat = N("gm_cat")
	cat_head = N("gm_cathead")
	cat_tail = N("gm_cattail")
	lid_l = N("gm_lidL")
	lid_r = N("gm_lidR")
	brow_l = N("gm_browL")
	brow_r = N("gm_browR")
	eye_l = N("gm_eyeL")
	eye_r = N("gm_eyeR")
	shin_l = N("gm_shinL")
	shin_r = N("gm_shinR")
	var cup_node := N("gm_cup")
	# rest transforms: every pose below is an offset from these
	var walk: Array[Node] = [model]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is Node3D:
			rest_r[n] = (n as Node3D).rotation
			rest_p[n] = (n as Node3D).position
			rest_q[n] = (n as Node3D).quaternion
	_materials()
	for side: String in ["L", "R"]:
		var A := Arm.new()
		A.hand = N("gm_hand" + side)
		A.glow = MsKit.sprite(A.hand, 0xc070ff, 0.0, 2.2)
		A.glow.position = Vector3(0.0, -0.35, 0.0)
		A.sh = N("gm_sh" + side)
		A.el = N("gm_el" + side)
		for i in 3:
			A.f.append([N("gm_f" + side + str(i) + "a"), N("gm_f" + side + str(i) + "b")])
		A.t = [N("gm_t" + side + "a"), N("gm_t" + side + "b")]
		if side == "L":
			arm_l = A
		else:
			arm_r = A
	# the emitters under the saucer (the phase-1 weak points): a white-hot core in a pulsing glass shell, two crossed gimbal rings, a cage of gold prongs, and a column of anti-grav light falling to the floor
	var gold := MsKit.std(0xd6a23a, 0.3, 0.8)
	var core_m := MsKit.flat(0xeafff4)
	for i in 3:
		var E := Emitter.new()
		var a := float(i) / 3.0 * TAU + PI / 6.0
		E.a = a
		var e := MsKit.part(throne, MsKit.sphere(0.3, 12, 8), core_m, Vector3(sin(a) * 1.8, -0.15, cos(a) * 1.8), false)
		E.mesh = e
		E.shell = MsKit.glow(e, MsKit.sphere(0.46, 16, 12), 0, 0x7affc0, 0.38)
		E.r1 = MsKit.glow(e, MsKit.torus(0.62, 0.035, 36, 6), 0, 0x9affd8, 0.85)
		E.r2 = MsKit.glow(e, MsKit.torus(0.76, 0.03, 36, 6), 0, 0x9affd8, 0.85)
		E.cage = Node3D.new()
		e.add_child(E.cage)
		for k in 4:
			var ka := k * 1.571
			var p := MsKit.part(E.cage, MsKit.cyl(0.0, 0.07, 0.34, 6), gold, Vector3(sin(ka) * 0.5, 0.52, cos(ka) * 0.5))
			p.rotation = Vector3(cos(ka) * 0.5, 0.0, -sin(ka) * 0.5)
		E.beam = MsKit.glow(e, MsKit.cyl(0.08, 0.5, 5.0, 14, true), 0, 0x7affc0, 0.16)
		E.beam.position.y = -2.9
		E.halo = MsKit.sprite(e, 0x7affc0, 0.6, 2.2)
		emitters.append(E)
	# the teacup in her right hand (kept level whatever the hand does: her tea is not a weapon, she would never), and the GRAVITY BOMB: a little black hole she wells up over her head
	if cup_node != null:
		held_cup = cup_node.duplicate()
		cup_node.free()
		held_cup.position = Vector3.ZERO
		held_cup.scale = Vector3.ONE * 1.1
		arm_r.hand.add_child(held_cup)
	bomb = Node3D.new()
	bomb.visible = false
	root.add_child(bomb)
	MsKit.part(bomb, MsKit.sphere(0.55, 20, 14), MsKit.flat(0x07000d), Vector3.ZERO, false)
	bomb_shell = MsKit.glow(bomb, MsKit.sphere(0.85, 20, 14), 0, 0xb050ff, 0.32)
	for i in 2:
		var r := MsKit.glow(bomb, MsKit.torus(1.15 + i * 0.25, 0.05, 48, 6), 0, 0xff5ad0 if i == 0 else 0x8a6aff, 0.85)
		r.rotation = Vector3(1.2 + i * 0.5 - PI / 2.0, 0.0, i * 0.7)
		bomb_rings.append(r)
	bomb_glow = MsKit.sprite(bomb, 0xb050ff, 0.8, 3.4)
	# THE CALL: a psychic ring that goes out from her head when she snaps her fingers
	call_ring = MsKit.glow(root, MsKit.torus(1.0, 0.06, 64, 6), 0, 0x7affc0, 0.0)
	head_glow = MsKit.sprite(head, 0xffd060, 0.0, 5.5)
	head_glow.position.y = 1.4
	# the sweep's tell: a gold halo turns over her head while she channels (shoot inside it); it shudders as her focus cracks
	halo = MsKit.glow(head, MsKit.torus(1.7, 0.11, 56, 6), 0, 0xffd060, 0.0)
	halo.position.y = 2.3
	# DIZZY: spiral eyes (in front of each eye, spinning) and a ring of little gold stars round her curlers
	var pts := PackedVector3Array()
	for i in 81:
		var a := float(i) / 80.0 * PI * 6.0
		var r := 0.03 + float(i) / 80.0 * 0.26
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	var spiral_g := MsKit.tube(pts, 0.022)
	var spiral_m := MsKit.flat(0xfff070)
	for e: Node3D in [eye_l, eye_r]:
		var m := MsKit.part(e, spiral_g, spiral_m, Vector3(0.0, 0.0, 0.3), false)
		m.visible = false
		spirals.append(m)
	stars = Node3D.new()
	head.add_child(stars)
	stars.position.y = 3.0
	var star_g := MsKit.star(0.12, 0.28, 0.08)
	var star_m := MsKit.flat(0xffe060)
	for i in 5:
		MsKit.part(stars, star_g, star_m, Vector3.ZERO, false)
	stars.visible = false
	# ---- the hit targets (cylinders the game's guns hit) and her collider
	t_body = Target.new(9100, 0.0, 0.0, PF, {"r": 2.3, "h": 6.2, "max": BIG, "hp": BIG, "boss": true})
	t_head = Target.new(9101, 0.0, 0.0, PF, {"r": 1.4, "h": 3.2, "max": BIG, "hp": BIG, "boss": true})      # (neck to the top of the curlers and the halo)
	for i in 3:
		t_emit.append(Target.new(9102 + i, 0.0, 0.0, PF, {"r": 0.75, "h": 1.1, "max": EMIT_HP, "hp": EMIT_HP}))
	all_t = [t_body, t_head]
	all_t.append_array(t_emit)
	solid = L.solid_id("ms_gm")
	solid.set_off(true)
	# ---- projectiles, gravity wells, the sweep beam, the shock rings
	# a PSI BLAST: a white-hot plasma bolt (a stretched core in a violet sheath) dragging a fading tail of light, a halo round its head
	var core_b := MsKit.flat(0xfff4ff)
	var core_g := MsKit.sphere(0.16, 10, 8)
	var sheath_g := MsKit.sphere(0.3, 12, 8)
	var tail_g := MsKit.cone_z(0.26, 0.0, 2.4, 10)
	for i in 12:
		var c := Node3D.new()
		var a := MsKit.part(c, core_g, core_b, Vector3.ZERO, false)
		a.scale = Vector3(1.0, 1.0, 2.6)
		var b := MsKit.glow(c, sheath_g, 0, 0xb050ff, 0.55)
		b.scale = Vector3(1.0, 1.0, 2.2)
		var tl := MsKit.glow(c, tail_g, 0, 0xd070ff, 0.4)
		tl.position.z = -0.2
		tl.rotation.y = PI
		MsKit.sprite(c, 0xc070ff, 0.8, 1.6)
		c.visible = false
		root.add_child(c)
		bolt_pool.append(c)
	bomb_ring = MsKit.glow(root, MsKit.ring(WELL_R - 0.2, WELL_R, 32), 0, 0xffb040, 0.8)
	bomb_ring.visible = false
	_well_disc = MsKit.disc(WELL_R, 32)
	_well_edge = MsKit.torus(WELL_R, 0.07, 48, 5)
	sweep = Node3D.new()
	sweep.visible = false
	root.add_child(sweep)
	sweep_m = MsKit.glow(sweep, MsKit.box(1.0, 2.4, 1.0), 0, 0xff2a2a, 0.55)
	sweep_m.position = Vector3(0.5, 1.2, 0.0)
	sweep_light = MsKit.light(root, 0xff3030, 0.0, 18.0)
	_ring_mesh = MsKit.torus(1.0, 0.35, 64, 6)
	beam_grip = MsKit.glow(root, MsKit.cyl(2.4, 2.4, 14.0, 20, true), 0, 0xffffff, 0.0)
	beam_grip.position = Vector3(0.0, PF + 7.0, 0.0)
	SPR["jaw"] = Spr.new()


## the paint carries its own light (baked AO + a top light): let it glow a little through the penthouse's dim red light, PS2 style. The bulbs chase in two sets. (Each gets its own copy: the imported file's materials are shared with the next visit.)
func _materials() -> void:
	var copies: Dictionary = {}
	var walk: Array[Node] = [model]
	var bulbs_a := N("gm_bulbsA")
	var bulbs_b := N("gm_bulbsB")
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		mi.extra_cull_margin = 8.0
		var in_b := bulbs_b != null and bulbs_b.is_ancestor_of(mi) or mi == bulbs_b
		var in_a := bulbs_a != null and bulbs_a.is_ancestor_of(mi) or mi == bulbs_a
		for s in mi.mesh.get_surface_count():
			var m0 := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m0 == null:
				continue
			var key: Variant = [m0, in_b]
			var c: StandardMaterial3D = copies.get(key)
			if c == null:
				c = m0.duplicate() as StandardMaterial3D
				copies[key] = c
				if c.albedo_texture != null:
					c.emission_enabled = true
					c.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY      # (three.js multiplies emissive by its map; Godot adds unless told)
					c.emission_texture = c.albedo_texture
					c.emission = Color.WHITE
					c.emission_energy_multiplier = 0.32
				elif not c.emission_enabled or c.emission.get_luminance() == 0.0:
					c.emission_enabled = true
					c.emission = c.albedo_color * 0.3
					c.emission_energy_multiplier = 1.0
				c.set_meta("e0", c.emission)
				c.set_meta("i0", c.emission_energy_multiplier)
				if m0.resource_name == "gm_lens":
					c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					c.albedo_color.a = 0.28
					c.render_priority = 2
			mi.set_surface_override_material(s, c)
			if in_a:
				bm_a = c
			if in_b:
				bm_b = c
			# her materials (for the hit flash): everything under gm_body, skipping the glowing bits
			if (body == null or body.is_ancestor_of(mi)) and not m0.resource_name.contains("shine") and not m0.resource_name.contains("gem") and not m0.resource_name.contains("cateye") and not m0.resource_name.contains("lens") and not flash_mats.has(c):
				flash_mats.append(c)


func _register(C: Combat) -> void:
	combat = C
	if C == null:
		return
	for t: Target in all_t:
		if not C.targets.has(t):
			C.targets.append(t)


func unregister() -> void:
	if combat == null:
		return
	for t: Target in all_t:
		combat.targets.erase(t)


# ---------------------------------------------------------------------------------------------- lifecycle
func reset() -> void:
	reinf = 0
	foes = []
	shake_ = false
	talk = false
	mode = "off"
	phase = 1
	respect = 0.0
	x = 0.0
	y = PF + 2.2
	z = 12.0
	yaw = PI
	mv = ""
	mt = 0.0
	idx = 0
	gap = 1.5
	down_t = 0.0
	dizzy_t = 0.0
	channel = 0.0
	orbit_a = 0.0
	mercy = 0.0
	tiles_up_ = 0
	spin_a = 0.0
	sweep_a = 0.0
	intro_t = 0.0
	enough_t = 0.0
	label = ""
	say_t = 0.0
	flinch = 0.0
	focus = 0.0
	sweeps = 0
	halo_hit = 0.0
	for t: Target in all_t:
		t.hp = t.max
		t.dead = false
	for e: Emitter in emitters:
		e.mesh.visible = true
	_clear_bolts()
	_clear_wells()
	_clear_rings()
	sweep.visible = false
	sweep_light.light_energy = 0.0
	bomb.visible = false
	bomb_ring.visible = false
	MsKit.opa(call_ring, 0.0)
	stars.visible = false
	MsKit.opa(beam_grip, 0.0)
	_tiles_home(true)
	unregister()
	g.visible = false
	solid.set_off(true)


func _clear_bolts() -> void:
	for c: Bolt in bolts:
		c.m.visible = false
	bolts.clear()


func _clear_wells() -> void:
	for w: Well in wells:
		w.m.queue_free()
	wells.clear()


func _clear_rings() -> void:
	for r: ShockRing in rings:
		r.m.queue_free()
	rings.clear()


## the player stepped off the Spine Beam into her room: she turns round in her chair
func intro() -> void:
	if mode != "off":
		return
	mode = "intro"
	intro_t = 0.0
	g.visible = true
	x = 0.0
	z = 13.0
	y = PF + 2.2
	yaw = 0.0


func _tiles_home(instant: bool) -> void:
	L.act2.tile_floor.set_off(false)
	for tl: MsAct2.Tile in L.act2.tiles:
		tl.want = 0.0
		if instant:
			tl.lift = 0.0
			tl.g.position = tl.home
		tl.set_off(true)
	tiles_up_ = 0


func _tiles_up() -> void:
	L.act2.tile_floor.set_off(true)
	tiles_up_ = 1
	var heights := [0.6, 2.4, 4.2, 1.4, 3.4, 5.2, 0.9, 2.9]
	var tiles: Array = L.act2.tiles
	for i in tiles.size():
		var tl: MsAct2.Tile = tiles[i]
		tl.want = heights[(i * 5 + tl.ring * 3) % 8]
		tl.set_off(false)


# ---------------------------------------------------------------------------------------------- the fight
func _respect_gain(d: float, mult: float) -> void:
	if d <= 0.0:
		return
	var cap := PHASE2 if phase == 1 else (PHASE3 if phase == 2 else 1.0)
	respect = minf(cap, respect + d * mult / RESPECT)
	hit = 1.0
	flinch = maxf(flinch, minf(1.0, 0.35 + d * mult / 40.0))


func _begin(m: String) -> void:      # first: the move's first frame (its set-up runs once)
	mv = m
	mt = 0.0
	shot = 0
	first = true


func _next_move() -> void:
	var list: Array = LOOP[phase]
	idx = (idx + 1) % list.size()
	_begin(list[idx])


static func wrap_a(a: float) -> float:
	return atan2(sin(a), cos(a))


func _line(key: String, text: String) -> void:
	say_t = minf(2.6, 0.8 + text.length() * 0.045)
	L.guests.say("THE GODMOTHER", text, x, y + 6.0, z, 0.45, key)


func _shake(k: float) -> void:
	if Game.fx != null:
		Game.fx.shake = maxf(Game.fx.shake, k)


func _sparks(p: Vector3, n: int, sp: float, nrm: Variant, col: int) -> void:
	if Game.fx != null:
		Game.fx.sparks(p, n, sp, nrm, col)


func _cue(f0: float, f1: float, d: float, gain: float = 0.15, type: StringName = &"sine") -> void:
	MsSound.tone(d, f0, f1, gain, type, 0.5)


func _thud(gain: float = 0.8) -> void:
	MsSound.play([["noise", 0.0, {"type": &"lowpass", "f0": 600.0, "f1": 80.0, "gain": gain, "dur": 0.5}], ["tone", 0.0, {"type": &"sine", "f0": 90.0, "f1": 30.0, "gain": gain * 1.2, "dur": 0.6}]], 0.5)


func _snap() -> void:      # a finger-snap, then a psychic warble
	MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 2600.0, "q": 2.0, "gain": 0.5, "dur": 0.04}], ["tone", 0.03, {"type": &"sine", "f0": 180.0, "f1": 1400.0, "gain": 0.07, "dur": 0.9}], ["tone", 0.03, {"type": &"triangle", "f0": 186.0, "f1": 1430.0, "gain": 0.05, "dur": 0.9}]], 0.6)


func _zap(f0: float = 1800.0, f1: float = 300.0) -> void:
	MsSound.tone(0.22, f0, f1, 0.09, &"square", 0.35)


func _woom() -> void:
	MsSound.play([["tone", 0.0, {"type": &"sine", "f0": 55.0, "f1": 30.0, "gain": 0.5, "dur": 1.2}], ["tone", 0.0, {"type": &"sawtooth", "f0": 400.0, "f1": 90.0, "gain": 0.08, "dur": 1.2}], ["noise", 0.0, {"type": &"lowpass", "f0": 500.0, "f1": 60.0, "gain": 0.4, "dur": 0.9}]], 0.55)


func _hiss() -> void:
	MsSound.noise(0.45, &"highpass", 3000.0, 5000.0, 0.12)


func _slurp() -> void:
	MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 900.0, "f1": 2200.0, "q": 3.0, "gain": 0.07, "dur": 0.32}], ["tone", 0.3, {"type": &"sine", "f0": 300.0, "f1": 220.0, "gain": 0.05, "dur": 0.12}]], 0.4)


## (Combat.update rewrites a live target's x / z from bx / bz + knockback every frame: move the anchors, not just x / z)
func _place_t(tg: Target, px: float, pz: float) -> void:
	tg.x = px
	tg.bx = px
	tg.z = pz
	tg.bz = pz
	tg.kx = 0.0
	tg.kz = 0.0


func update(dt: float, P: Player, C: Combat, t: float) -> void:
	if mode == "off":
		return
	_register(C)
	mercy = maxf(0.0, mercy - dt)
	hit = maxf(0.0, hit - dt * 3.0)
	say_t = maxf(0.0, say_t - dt)
	# ---- damage in: every target's lost hp, weighted
	var stunned := down_t > 0.0 or dizzy_t > 0.0
	_respect_gain(BIG - t_body.hp, 1.0 if stunned else ARMOUR)
	t_body.hp = BIG
	t_body.dead = false
	var hd := BIG - t_head.hp
	var hot := channel > 0.0 and not stunned
	_respect_gain(hd, 1.15 if stunned else (HEAD_HOT if hot else ARMOUR * 1.5))
	t_head.hp = BIG
	t_head.dead = false
	if hot and hd > 0.0 and mode == "fight":      # a shot into the glow: gold sparks, a bright tink, the halo jumps; enough of them and her focus breaks
		focus += hd
		halo_hit = 1.0
		_sparks(head.global_position + Vector3(0.0, 1.6, 0.0), 10, 5.0, null, 0xffd060)
		_cue(1500.0, 2600.0, 0.08, 0.06, &"square")
		if focus >= FOCUS and mv == "sweep":
			_break_focus()
	if mode == "fight" and phase == 1 and down_t <= 0.0 and mv != "raise":      # (the raise ends phase 1: broken emitters stay broken)
		var all_dead := true
		for i in 3:
			var te := t_emit[i]
			if te.dead and emitters[i].mesh.visible:
				emitters[i].mesh.visible = false
				_thud(0.4)
				flinch = 1.0
				_sparks(emitters[i].mesh.global_position, 24, 6.0, null, 0x7affc0)
			if not te.dead:
				all_dead = false
		if all_dead:
			down_t = DOWN_T
			_begin("down")
			_thud(1.0)
			_shake(0.6)
			_line("pain", "My CHAIR! ...Do you know what this chair COST?")
	if mode == "intro":
		intro_t += dt
		yaw += (atan2(P.x - x, P.z - z) - yaw) * minf(1.0, dt * 2.0)
		if intro_t > 0.4 and intro_t - dt <= 0.4:
			_line("alert", "So. You're the one who ruined my daughter's wedding.")
		if intro_t > 3.6 and intro_t - dt <= 3.6:
			_line("alert", "Nobody walks into my house uninvited. ...Sit DOWN.")
		if intro_t > 6.0:
			mode = "fight"
			phase = 1
			idx = -1
			for te: Target in t_emit:
				te.hp = te.max
				te.dead = false
			_next_move()
	elif mode == "fight":
		_fight(dt, P, C, t)
	elif mode == "enough":
		enough_t += dt
		y += (PF + 0.6 - y) * minf(1.0, dt * 1.5)
		x += (0.0 - x) * minf(1.0, dt)
		z += (14.0 - z) * minf(1.0, dt)
		yaw += (atan2(P.x - x, P.z - z) - yaw) * minf(1.0, dt * 2.0)
	# ---- moving pieces
	_tiles_step(dt, P, t)
	_bolts_step(dt, P, C)
	_wells_step(dt, P, C, t)
	_rings_step(dt, P, C)
	_call_step(dt)
	# ---- placement + pose
	g.position = Vector3(x, y, z)
	g.rotation.y = yaw
	_pose(dt, t, P)
	var low := y < PF + 3.5 and mode != "off"
	var off := not low or mode == "tamed"
	if off != solid.off:
		solid.set_off(off)
	if not off:      # starts above the emitters, or it eats the shots meant for them
		solid.place(x, z, 0.0, 2.0, 2.0)
		solid.set_span(y + 0.55, y + 3.0, y + 3.0)
	if not off and P != null and U.hyp(P.x - x, P.z - z) < 2.0 + 0.36 and P.y < solid.top:
		var d := U.hyp(P.x - x, P.z - z)
		if d == 0.0:
			d = 1.0
		P.x = x + (P.x - x) / d * 2.4
		P.z = z + (P.z - z) / d * 2.4
	_place_t(t_body, x, z)
	t_body.y = y + 0.4
	var hp := head.global_position
	# her body's cylinder stops at her neck (2026-11-15): 6.2 m tall and wider than the head's, it swallowed all but the top of her curlers, so a shot at her glowing head never reached it.
	# While she channels, the glowing head is the weak point and a generous one: down to her shoulders and wider (from a tile below her, a shot at the halo would otherwise clip her shoulders first).
	var glowing := channel > 0.0
	var neck_y := hp.y - (1.2 if glowing else 0.0)
	t_body.h = clampf(neck_y - t_body.y, 2.0, 6.2)
	_place_t(t_head, hp.x, hp.z)
	t_head.y = neck_y
	t_head.h = 4.4 if glowing else 3.2
	t_head.r = 2.1 if glowing else 1.4
	for i in 3:
		var te := t_emit[i]
		var p := emitters[i].mesh.global_position
		_place_t(te, p.x, p.z)
		te.y = p.y - 0.75
		if not emitters[i].mesh.visible or phase > 1 or mode != "fight":      # only phase 1's weak points
			te.dead = true
		if te.dead:      # (a broken emitter regrows only when her DOWN ends: Combat's own 4 s respawn would bring back an invisible one that still eats shots)
			te.respawn_t = 1e9


func _fight(dt: float, P: Player, C: Combat, t: float) -> void:
	var ph := phase
	# phase gates (each crossing is a set piece of its own)
	if ph == 1 and respect >= PHASE2 and mv != "raise":
		down_t = 0.0
		_begin("raise")
		_line("alert", "Fine. You wanna play rough? Let's redecorate.")
	if ph == 2 and respect >= PHASE3 and mv != "house":
		_begin("house")
		_line("alert", "This is MY house. And my house... does what I SAY.")
	if ph == 3 and respect >= 0.999:
		_enough()
		return
	mt += dt
	down_t = maxf(0.0, down_t - dt)
	dizzy_t = maxf(0.0, dizzy_t - dt)
	channel = maxf(0.0, channel - dt)
	# where she floats
	var hold := mv == "down" or mv == "slam" or mv == "raise" or mv == "house" or (mv == "dizzy" and ph == 2)      # (her focus broken in phase 2, she stops drifting and sags to the high tiles)
	if not hold:
		orbit_a += dt * (0.12 if ph == 2 else 0.18)
		var R := 5.0 if ph == 2 else 10.5
		var ty := PF + 6.5 if ph == 2 else PF + 2.4
		x += (sin(orbit_a) * R - x) * minf(1.0, dt * 0.8)
		z += (cos(orbit_a) * R - z) * minf(1.0, dt * 0.8)
		y += (ty + sin(t * 1.3) * 0.25 - y) * minf(1.0, dt * 1.5)
	if mv != "down" and mv != "slam":      # she turns to face you (2 rad/s)
		yaw += clampf(wrap_a(atan2(P.x - x, P.z - z) - yaw), -dt * 2.0, dt * 2.0)
	# the room turns in phase 3 (and carries you)
	if ph == 3:
		var w := 0.12
		spin_a += w * dt
		_spin_floor(w * dt, P)
	var m := mt
	var cur := mv
	match cur:
		"blasts":
			var wind := 0.6 if ph == 3 else 0.8
			if m < wind:
				label = "PSI BLASTS"
				if first:
					_cue(400.0, 1400.0, wind, 0.08, &"triangle")
			elif shot == 0:
				shot = 1
				var hand := arm_r.hand.global_position
				var base := atan2(P.x - hand.x, P.z - hand.z)
				var n := BOLT_N + (2 if ph == 3 else 0)
				for i in n:
					var a := base + (float(i) / (n - 1) - 0.5) * BOLT_SPREAD * 2.0
					var dy := (P.y + 1.1 - hand.y) / maxf(4.0, U.hyp(P.x - hand.x, P.z - hand.z))
					_throw_bolt(hand, sin(a), dy, cos(a))
				_zap(2200.0, 500.0)
				_cue(900.0, 300.0, 0.25, 0.1, &"sawtooth")
			elif m > wind + 0.7:
				gap = 0.9 if ph == 3 else 1.3
				_begin("gap")
		"bomb":
			# a black hole wells up over her raised hand, then she lobs it where you stand (the amber ring): it lands as a GRAVITY WELL
			if first:
				bomb_t = [P.x, P.z]
				bomb_ring.visible = true
				bomb_ring.position = Vector3(P.x, (P.y if P.y > PF - 0.5 else PF) + 0.05, P.z)
				label = "GRAVITY BOMB"
				_cue(90.0, 420.0, 1.2, 0.12, &"sawtooth")
				bomb_from = arm_l.hand.global_position
				bomb.visible = true
				bomb.scale = Vector3.ONE * 0.01
			var lead := 1.3
			MsKit.opa(bomb_ring, 0.5 + 0.4 * sin(t * 16.0))
			bomb_ring.scale = Vector3.ONE * (1.0 + 0.2 * maxf(0.0, 1.0 - m / lead))
			var top := Vector3(x, y + 8.2 + sin(m * 6.0) * 0.2, z)
			for i in 2:
				bomb_rings[i].rotation.z += dt * (-5.0 if i == 1 else 7.0)
			bomb_shell.scale = Vector3.ONE * (1.0 + 0.08 * sin(t * 22.0))
			MsKit.opa(bomb_glow, 0.6 + 0.3 * sin(t * 13.0))
			if m < lead:      # it grows out of her palm and hangs over her head
				var u := minf(1.0, m / 0.6)
				var e := u * u * (3.0 - 2.0 * u)
				bomb.position = bomb_from.lerp(top, e)
				bomb.scale = Vector3.ONE * maxf(0.01, e) * 1.3
			elif m < lead + 1.0:
				var u := m - lead
				bomb.position = Vector3(x + (float(bomb_t[0]) - x) * u, y + 8.2 + sin(u * PI) * 4.0 - u * (y + 8.2 - bomb_ring.position.y), z + (float(bomb_t[1]) - z) * u)
				bomb.scale = Vector3.ONE * 1.3
			else:
				bomb.visible = false
				bomb_ring.visible = false
				_add_well(bomb_t[0], bomb_ring.position.y, bomb_t[1])
				_woom()
				_shake(0.3)
				var q := Vector3(bomb_t[0], bomb_ring.position.y + 0.3, bomb_t[1])
				_sparks(q, 30, 7.0, Vector3.UP, 0xc070ff)
				_sparks(q, 14, 4.0, null, 0xffffff)
				gap = 1.0
				_begin("gap")
		"call":
			# a psychic finger-snap: a ring of thought goes out from her head, and the family comes up the Spine Beam's shaft through the hole in her floor
			if first:
				label = "THE CALL"
				_line("shoot", "Boys! BOYS! Get in here!" if ph == 3 else "Jeeves! Show our guest the door!")
			if m > 0.55 and m - dt <= 0.55:
				_snap()
				call_ring.position = head.global_position
				call_t = 0.0
			if m > 0.8 and shot == 0:
				shot = 1
				var alive := 0
				for r: Variant in foes:
					if is_instance_valid(r) and not r.dead:
						alive += 1
				if alive < 3:
					for i in 2:
						var a := randf() * TAU
						foes.append(L.bo.spawn([sin(a) * 15.0, PF + 2.5, cos(a) * 15.0], {"kind": "butler", "from": [[0.0, PF - 9.0, 0.0, "air"], [0.0, PF + 2.5, 0.0, "air"]], "delay": 0.4 + i * 0.9}))
				if ph == 3 and reinf == 0:
					reinf = 1
					foes.append(L.bo.spawn([-14.0, PF, 8.0], {"kind": "tommygun", "from": [[0.0, PF - 9.0, 0.0, "air"], [0.0, PF + 0.2, 0.0, "air"], [-3.5, PF, 2.0]], "delay": 0.2}))
					foes.append(L.bo.spawn([14.0, PF + 3.0, 8.0], {"kind": "consigliere", "from": [[0.0, PF - 9.0, 0.0, "air"], [0.0, PF + 2.5, 0.0, "air"]], "delay": 1.6}))
			if m > 1.6:
				gap = 1.0
				_begin("gap")
		"bm":
			if first:
				label = "BUTTON MEN"
				_line("shoot", "I got a couple of friends who'd love to meet you.")
			if m > 0.6 and shot == 0:      # up the Spine Beam as a shimmer, then a hop onto the high tiles
				shot = 1
				var hi: Array = []
				var spots: Array = []
				for tl: MsAct2.Tile in L.act2.tiles:
					if tl.want > 3.0 and hi.size() < 2:
						hi.append(tl)
					if tl.want > 2.5:
						spots.append([tl.g.position.x, PF + tl.want, tl.g.position.z])
				for i in hi.size():
					var tl: MsAct2.Tile = hi[i]
					var tp := tl.g.position
					var r: Robot = L.bo.spawn([tp.x, tp.y + 0.1, tp.z], {"kind": "buttonman", "from": [[0.0, PF - 9.0, 0.0, "air"], [0.0, PF + 1.0, 0.0, "air"], [tp.x * 0.5, tp.y + 1.6, tp.z * 0.5, "air"]], "cloak": true, "delay": i * 0.8})
					if r != null:
						if r is ButtonMan:
							(r as ButtonMan).spots = spots
						foes.append(r)
			if m > 1.4:
				gap = 1.2
				_begin("gap")
		"sweep":
			var warn := 1.1
			var T1 := TAU / SWEEP_SPEED
			label = "SWEEP: GET HIGH, SHOOT HER HEAD"
			channel = 0.3
			if first:
				sweep_a = atan2(P.x, P.z) + PI * 0.6
				focus = 0.0
				sweeps += 1
				if sweeps == 1:
					_line("alert", "Don't you DARE interrupt me while I'm concentrating.")
				elif sweeps % 2 == 1:
					_line("shoot", "Hold STILL, sweetheart.")
				_cue(200.0, 900.0, warn, 0.1, &"sawtooth")
				_hiss()
			var a := sweep_a if m < warn else sweep_a + (m - warn) * SWEEP_SPEED
			var live := m >= warn
			sweep.visible = true
			sweep.position = Vector3(0.0, PF - 0.4, 0.0)
			sweep.rotation.y = a - PI / 2.0
			sweep.scale = Vector3(ARENA, 1.0 if live else 0.3, 0.7 if live else 0.25)
			MsKit.opa(sweep_m, 0.6 if live else 0.25 + 0.2 * sin(t * 30.0))
			sweep_light.position = Vector3(sin(a) * 10.0, PF + 1.0, cos(a) * 10.0)
			sweep_light.light_energy = (9.0 if live else 3.0) / PI
			if live and mercy <= 0.0:
				var pa := atan2(P.x, P.z)
				var dr := absf(wrap_a(pa - a)) * U.hyp(P.x, P.z)
				if dr < 0.9 and P.y < PF + 2.3 and U.hyp(P.x, P.z) > 2.5:
					_hit_player(P, C, SWEEP_DMG, 0.0, 0.0, 6.0)
			if m >= warn + T1:
				sweep.visible = false
				sweep_light.light_energy = 0.0
				gap = 1.0
				_begin("gap")
		"slam":
			label = "THE SLAM: JUMP THE RINGS"
			var grab := 1.4
			var lift := 1.2
			x += (0.0 - x) * minf(1.0, dt * 2.5)
			z += (3.2 - z) * minf(1.0, dt * 2.5)
			if m < grab:
				y += (PF + 4.0 - y) * minf(1.0, dt * 3.0)
				MsKit.opa(beam_grip, m / grab * 0.5)
				if first:
					_cue(150.0, 500.0, grab + lift, 0.1, &"sawtooth")
					_hiss()
			elif m < grab + lift:
				y += (PF + 9.0 - y) * minf(1.0, dt * 3.0)
				MsKit.opa(beam_grip, 0.5 + 0.3 * sin(t * 30.0))
			elif shot == 0:
				shot = 1
				y = PF + 1.0
				squash = 1.0
				_thud(1.4)
				_shake(0.9)
				MsKit.opa(beam_grip, 0.0)
				for i in 2:
					_add_ring(i * 0.75)
				_sparks(Vector3(x, PF + 0.4, z), 40, 9.0, Vector3.UP, 0xffd060)
			elif m > grab + lift + 0.3:
				dizzy_t = DIZZY_T
				_begin("dizzy")
				_line("pain", "Ohhh... my curlers...")
		"dizzy":
			label = "DIZZY: NOW!"
			y += ((PF + 3.4 if ph == 2 else PF + 1.2) - y) * minf(1.0, dt * 2.0)      # (phase 2: down to the high tiles, not into the pit)
			if dizzy_t <= 0.0:
				gap = 0.8
				_begin("gap")
		"down":
			label = "SHE'S DOWN: NOW!"
			y += (PF + 0.6 - y) * minf(1.0, dt * 6.0)
			if first:
				squash = 1.0
			if down_t <= 0.0:
				for te: Target in t_emit:
					te.hp = te.max
					te.dead = false
				for e: Emitter in emitters:
					e.mesh.visible = true
				_cue(300.0, 900.0, 0.6, 0.1)
				gap = 1.2
				_begin("gap")
		"raise":
			label = "SHE'S RAISING THE FLOOR"
			y += (PF + 6.5 - y) * minf(1.0, dt * 1.5)
			if first:
				_thud(1.0)
				_shake(0.7)
				_tiles_up()
				for e: Emitter in emitters:      # her chair's emitters are done with: phase 2 has none to shoot, so none should glow
					e.mesh.visible = false
			if m > 2.6:
				phase = 2
				idx = -1
				gap = 0.6
				_begin("gap")
		"house":
			label = "THE HOUSE IS TURNING"
			if first:
				_tiles_home(false)
				_thud(1.0)
				_shake(0.7)
			if m > 2.6:
				phase = 3
				idx = -1
				gap = 0.6
				_begin("gap")
		"gap":
			if label.ends_with("NOW!"):
				label = ""
			if m > gap:
				_next_move()
	if mv == cur:      # (a move that just began another keeps the new one's first frame)
		first = false
	# the pit (phase 2): burns, and throws you back up
	if not P.dead and tiles_up_ != 0 and P.y < PF - 1.5 and P.grounded and mercy <= 0.0:
		_hit_player(P, C, PIT_DPS * 0.5, P.x, P.z, 0.0)
		P.vy = 11.0
		P.grounded = false
		L.toast("THE PIT BURNS: CLIMB OUT")      # (its burn bounces you up to grab a ledge: the pedestal's edge or a low tile; or walk in under the pedestal to the Spine Beam)


## her focus breaks (enough shots on her glowing head during one sweep): the beam dies, she clutches her curlers and is DIZZY, every hit counting in full
func _break_focus() -> void:
	focus = 0.0
	channel = 0.0
	sweep.visible = false
	sweep_light.light_energy = 0.0
	dizzy_t = DIZZY_T
	_begin("dizzy")
	_thud(1.0)
	_shake(0.5)
	_sparks(head.global_position + Vector3(0.0, 1.6, 0.0), 40, 9.0, null, 0xffd060)
	_sparks(head.global_position + Vector3(0.0, 1.6, 0.0), 16, 5.0, null, 0xffffff)
	MsSound.play([["noise", 0.0, {"type": &"highpass", "f0": 2500.0, "f1": 6000.0, "gain": 0.25, "dur": 0.35}], ["tone", 0.0, {"type": &"triangle", "f0": 1800.0, "f1": 200.0, "gain": 0.12, "dur": 0.7}]], 0.6)      # the halo shatters
	_line("pain", "My HEAD! ...You broke my CONCENTRATION!")


func _hit_player(P: Player, C: Combat, dmg: float, sx: float, sz: float, push: float) -> void:
	if mercy > 0.0 or C == null:
		return
	mercy = MERCY
	if C.hurt_player(P, dmg, sx if sx != 0.0 else x, sz if sz != 0.0 else z, "bolt") and push != 0.0:
		var d := U.hyp(P.x, P.z)
		if d == 0.0:
			d = 1.0
		P.ix += P.x / d * push
		P.iz += P.z / d * push
		P.vy = maxf(P.vy, 5.0)
		P.grounded = false


func _enough() -> void:
	mode = "enough"
	mv = ""
	label = "TRUCE?"
	respect = 1.0
	sweep.visible = false
	sweep_light.light_energy = 0.0
	bomb.visible = false
	bomb_ring.visible = false
	MsKit.opa(beam_grip, 0.0)
	_clear_bolts()
	_clear_wells()
	_clear_rings()
	_tiles_home(false)
	for r: Variant in foes:
		if r != null and not r.dead:
			Game.despawn_enemy(r)
	foes = []
	unregister()
	_line("alert", "ENOUGH.")
	_thud(0.6)


# ---------------------------------------------------------------------------------------------- pieces
func _throw_bolt(from: Vector3, dx: float, dy: float, dz: float) -> void:
	var m: Node3D = null
	for c: Node3D in bolt_pool:
		if not c.visible:
			m = c
			break
	if m == null:
		return
	m.visible = true
	m.position = from
	var l := sqrt(dx * dx + dy * dy + dz * dz)
	if l == 0.0:
		l = 1.0
	var sp := BOLT_SPEED * (1.15 if phase == 3 else 1.0)
	var b := Bolt.new()
	b.m = m
	b.x = from.x
	b.y = from.y
	b.z = from.z
	b.vx = dx / l * sp
	b.vy = dy / l * sp
	b.vz = dz / l * sp
	bolts.append(b)


func _bolts_step(dt: float, P: Player, C: Combat) -> void:
	var i := bolts.size() - 1
	while i >= 0:
		var c: Bolt = bolts[i]
		c.t += dt
		c.x += c.vx * dt
		c.y += c.vy * dt
		c.z += c.vz * dt
		c.m.position = Vector3(c.x, c.y, c.z)
		c.m.look_at(Vector3(c.x + c.vx, c.y + c.vy, c.z + c.vz), Vector3.UP, true)      # nose first, crackling
		c.m.scale = Vector3.ONE * (1.0 + 0.12 * sin(c.t * 40.0))
		var dead := c.t > 4.0 or U.hyp(c.x, c.z) > ARENA + 0.5 or c.y < PF - 3.0
		if not dead and P != null and not P.dead and U.hyp(P.x - c.x, P.z - c.z) < 0.8 and c.y > P.y and c.y < P.y + 1.9:
			_hit_player(P, C, BOLT_DMG, c.x, c.z, 0.0)
			dead = true
		if dead:
			c.m.visible = false
			bolts.remove_at(i)
			_sparks(Vector3(c.x, c.y, c.z), 12, 4.0, null, 0xc070ff)
			_sparks(Vector3(c.x, c.y, c.z), 6, 3.0, null, 0x7affc0)
		i -= 1


func _add_well(wx: float, wy: float, wz: float) -> void:
	var w := Well.new()
	var gw := Node3D.new()
	gw.position = Vector3(wx, wy + 0.04, wz)
	bomb.get_parent().add_child(gw)
	w.m = gw
	w.disc = MsKit.glow(gw, _well_disc, 6, 0xb050ff, 0.0)
	w.edge = MsKit.glow(gw, _well_edge, 0, 0xff5ad0, 0.0)
	w.x = wx
	w.y = wy
	w.z = wz
	wells.append(w)


func _wells_step(dt: float, P: Player, C: Combat, t: float) -> void:
	var i := wells.size() - 1
	while i >= 0:
		var w: Well = wells[i]
		w.t += dt
		w.tick -= dt
		var k := minf(1.0, w.t / 0.25) * minf(1.0, (WELL_T - w.t) / 0.6)
		w.disc.rotation.y -= dt * 3.2
		MsKit.opa(w.disc, maxf(0.0, 0.85 * k))
		MsKit.opa(w.edge, maxf(0.0, 0.7 * k))
		w.edge.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 14.0))
		if P != null and not P.dead and absf(P.y - w.y) < 1.2:
			var dx := w.x - P.x
			var dz := w.z - P.z
			var d := U.hyp(dx, dz)
			if d < WELL_R + 1.0 and d > 0.15 and k > 0.3:      # it drags you in (you can run out of it)
				var pull := WELL_PULL * (1.4 - d / (WELL_R + 1.0)) * 9.0 * dt
				P.ix += dx / d * pull
				P.iz += dz / d * pull
			if d < WELL_R * 0.6 and w.tick <= 0.0 and C != null:      # the white-hot eye burns
				w.tick = 0.45
				C.hurt_player(P, WELL_DMG * 0.45, w.x, w.z, "bolt")
		if w.t > WELL_T:
			w.m.queue_free()
			wells.remove_at(i)
		i -= 1


func _call_step(dt: float) -> void:      # the psychic ring of THE CALL spreads out and fades
	if call_t == null:
		MsKit.opa(call_ring, 0.0)
		return
	call_t = float(call_t) + dt
	var u: float = float(call_t) / 0.9
	call_ring.scale = Vector3.ONE * (1.0 + u * 22.0)
	MsKit.opa(call_ring, maxf(0.0, 0.9 * (1.0 - u)))
	if u >= 1.0:
		call_t = null


func _add_ring(delay: float) -> void:
	var r := ShockRing.new()
	r.m = MsKit.glow(bomb.get_parent(), _ring_mesh, 0, 0xffd060, 0.85)
	r.m.position = Vector3(0.0, PF + 0.4, 0.0)
	r.m.visible = false
	r.delay = delay
	rings.append(r)


func _rings_step(dt: float, P: Player, C: Combat) -> void:
	var i := rings.size() - 1
	while i >= 0:
		var R: ShockRing = rings[i]
		if R.delay > 0.0:
			R.delay -= dt
			i -= 1
			continue
		R.m.visible = true
		R.r += SLAM_SPEED * dt
		R.m.scale = Vector3(R.r, 1.0, R.r)
		if P != null and not P.dead and not R.hit and absf(U.hyp(P.x, P.z) - R.r) < 0.7 and P.y < PF + 0.9:
			R.hit = true
			_hit_player(P, C, SLAM_DMG, 0.0, 0.0, 7.0)
		if R.r > ARENA:
			R.m.queue_free()
			rings.remove_at(i)
		i -= 1


func _spin_floor(da: float, P: Player) -> void:      # phase 3: the floor (tiles + inner disc) turns; you turn with it
	for tl: MsAct2.Tile in L.act2.tiles:
		var a := atan2(tl.home.x, tl.home.z) + da
		var r := U.hyp(tl.home.x, tl.home.z)
		tl.home.x = sin(a) * r
		tl.home.z = cos(a) * r
		tl.g.position.x = tl.home.x
		tl.g.position.z = tl.home.z
		tl.g.rotation.y += da
	if P != null and P.grounded and absf(P.y - PF) < 0.15 and U.hyp(P.x, P.z) < MsArena.LEDGE_R:      # (the gift ledge round the wall stays put)
		var a := atan2(P.x, P.z) + da
		var r := U.hyp(P.x, P.z)
		P.x = sin(a) * r
		P.z = cos(a) * r
		P.yaw += da


func _tiles_step(dt: float, P: Player, t: float) -> void:
	for tl: MsAct2.Tile in L.act2.tiles:
		var want := tl.want + (sin(t * 0.9 + tl.k * 1.7 + tl.ring) * 0.35 if tl.want > 0.0 else 0.0)
		var prev := tl.lift
		tl.lift += (want - tl.lift) * minf(1.0, dt * (1.4 if tl.want > 0.0 else 3.0))
		tl.g.position.y = PF + tl.lift
		tl.move(tl.g.position.x, tl.g.position.z, PF + tl.lift)
		tl.emission(0.15 if tl.want > 0.0 else 0.0, 0.03 if tl.want > 0.0 else 0.0, 0.08 if tl.want > 0.0 else 0.0)
		if P != null and not tl.off_ and P.grounded and absf(P.y - (PF + prev)) < 0.2 and tl.top_at(P.x, P.z) != null:      # standing on a tile: it carries you up and down
			P.y = PF + tl.lift


# ---------------------------------------------------------------------------------------------- pose: what the model shows
## Every joint channel is a damped spring towards this frame's target (a little overshoot = follow-through); the targets come from her state below.
func _spr(key: String, target: float, dt: float, k: float = 110.0, d: float = 15.0) -> float:
	var c: Spr = SPR.get(key)
	if c == null:
		c = Spr.new()
		c.x = target
		SPR[key] = c
	var n := maxi(1, ceili(dt / 0.012))
	var h := dt / n
	for i in n:
		c.v += ((target - c.x) * k - c.v * d) * h
		c.x += c.v * h
	return c.x


func _kick(key: String, v: float) -> void:
	var c: Spr = SPR.get(key)
	if c != null:
		c.v += v


static func _sm(a: float, b: float, v: float) -> float:
	var u := clampf((v - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _pose(dt_in: float, t: float, P: Player) -> void:
	var dt := minf(dt_in, 0.1)
	var m := mt
	var down := mv == "down"
	var dizzy := mv == "dizzy" or dizzy_t > 0.0
	var busy := mode == "fight" and mv != "gap" and mv != "bm"      # (an attack is on: no sipping, no stroking the cat)
	# ---- the target pose (defaults: the idle: tea in the right hand, stroking the cat with the left, a smug face)
	var W := PoseT.new()
	W.hz = 0.05 * sin(t * 0.45)
	W.sh_lx = -0.62 + 0.1 * sin(t * 1.8)
	W.el_lx = -1.0 + 0.2 * sin(t * 1.8 + 0.7)
	W.h_lz = 0.15 * sin(t * 1.8 + 1.2)
	# look at the player (head yaw / pitch, inside the chair's frame)
	var look := 0.0
	var look_p := 0.0
	if P != null:
		look = clampf(wrap_a(atan2(P.x - x, P.z - z) - yaw), -0.6, 0.6)
		look_p = clampf(-atan2(P.y + 1.0 - (y + 6.0), U.hyp(P.x - x, P.z - z)) * 0.6, -0.25, 0.35)
	if look_x != null and (mode == "tamed" or mode == "enough"):
		look = clampf(wrap_a(atan2(float(look_x) - x, float(look_z) - z) - yaw), -0.6, 0.6)
	W.hy = look * 0.8
	W.hx += look_p
	# the sip (idle only): cup up to the lips, head back, eyes shut in bliss, pinky out
	sip_t -= dt
	if sip_t <= 0.0 and sip < 0.0 and not busy and not talk:
		sip = 0.0
		sip_t = 5.0 + randf() * 3.0
	if sip >= 0.0:
		if sip < 0.75 and sip + dt >= 0.75:
			_slurp()
		sip += dt
		var u := _sm(0.0, 0.5, sip) * (1.0 - _sm(1.5, 2.0, sip))
		W.sh_rx = -0.5 - 0.65 * u
		W.sh_rz = -0.2 + 0.18 * u
		W.el_rx = -1.75 - 0.55 * u
		W.h_rx = 0.1 - 0.3 * u
		W.hx -= 0.18 * u
		W.lid_l = 0.32 + 0.6 * u
		W.lid_r = W.lid_l
		W.b_ly = 0.05 * u
		W.b_ry = W.b_ly
		if sip > 2.0 or busy:
			sip = -1.0
	# the foot: an impatient tap now and then
	tap_t -= dt
	if tap_t <= 0.0 and tap < 0.0:
		tap = 0.0
		tap_t = 7.0 + randf() * 5.0
	if tap >= 0.0:
		tap += dt
		W.shin_l = -0.22 * maxf(0.0, sin(tap * 14.0))
		if tap > 1.3:
			tap = -1.0
	# talking (any line she says, and the truce conversation)
	if say_t > 0.0 or talk:
		W.jaw = 0.25 + 0.3 * absf(sin(t * 12.5)) * absf(sin(t * 4.1 + 1.0))
	# ---- the moves
	if mode == "intro" and intro_t > 3.4:
		var u := _sm(3.4, 3.8, intro_t)
		W.sh_lx = -1.55 * u + W.sh_lx * (1.0 - u)
		W.sh_lz = -0.05
		W.sh_ly = 0.0
		W.el_lx = -0.15
		W.h_lx = -0.1
		W.f_l = 1.0
		W.t_l = 1.0
		W.point_l = true
		W.lean = 0.14
		W.lid_l = 0.48
		W.lid_r = 0.48
		W.b_lz = 0.22
		W.b_rz = -0.22
		W.b_ly = -0.03
		W.b_ry = -0.03
		W.cat_up = 1.0
	if mv == "blasts":
		var wind := 0.6 if phase == 3 else 0.8
		var w := _sm(0.0, wind * 0.7, m)
		if shot == 0:
			W.sh_rx = -0.5 + 0.9 * w
			W.sh_rz = -0.2 - 0.75 * w
			W.sh_ry = -0.25 - 0.4 * w
			W.el_rx = -1.75 + 0.35 * w
			W.h_rx = -0.4 * w
			W.glow_r = w
			W.lean = 0.05 - 0.12 * w
			W.twist = -0.22 * w
			W.f_r = [0.0, 0.0, 0.0]
			W.t_r = 0.0
			W.hy = look * 0.4
		else:
			var f := _sm(0.0, 0.12, m - wind) * (1.0 - 0.6 * _sm(0.3, 0.7, m - wind))
			W.sh_rx = -1.45 * f + -0.5 * (1.0 - f)
			W.sh_rz = -0.15
			W.sh_ry = 0.1
			W.el_rx = -0.25 * f - 1.75 * (1.0 - f)
			W.h_rx = 0.3 * f
			W.lean = 0.2 * f
			W.twist = 0.18 * f
			W.jaw = maxf(W.jaw, 0.65 * f)
			W.f_r = [0.0, 0.0, 0.0]
			W.t_r = 0.0
			W.glow_r = 0.5 * (1.0 - f)
		W.lid_l = 0.5
		W.lid_r = 0.5
		W.b_lz = 0.28
		W.b_rz = -0.28
		W.b_ly = -0.04
		W.b_ry = -0.04
		W.cat_up = 1.0
	if mv == "bomb":      # palm up over her head while the black hole wells up in it, then the lob
		var lead := 1.3
		var u := _sm(0.0, 0.35, m)
		var thr := _sm(lead - 0.1, lead + 0.15, m) * (1.0 - _sm(lead + 0.8, lead + 1.3, m))
		W.sh_lx = -2.55 * u * (1.0 - thr) - 1.3 * thr
		W.sh_lz = 0.3 * u
		W.sh_ly = 0.2
		W.el_lx = -0.25
		W.h_lx = -0.5 * u
		W.h_lz = 0.0
		W.f_l = 0.15 * u
		W.t_l = 0.0
		W.glow_l = u * (1.0 - thr)
		W.hx = -0.32 * u * (1.0 - thr) + W.hx * thr
		W.hy = look * (0.3 + 0.7 * thr)
		W.jaw = maxf(W.jaw, 0.4 * u)
		W.lid_l = 0.15
		W.lid_r = 0.15
		W.b_ly = 0.09
		W.b_ry = 0.09
		W.b_lz = -0.1
		W.b_rz = 0.1
		W.lean = -0.06 * u + 0.18 * thr
		W.cat_up = 1.0
	if mv == "call":      # hand up, fingers pressed... SNAP (at 0.55 s); her eyes and hand glow with the thought
		var u := _sm(0.0, 0.25, m) * (1.0 - _sm(1.3, 1.6, m))
		var sn := 1.0 - _sm(0.55, 0.9, m) if m > 0.55 else 0.0
		W.sh_lx = -2.1 * u + W.sh_lx * (1.0 - u)
		W.sh_lz = 0.45 * u
		W.el_lx = -0.7 * u + W.el_lx * (1.0 - u)
		W.h_lx = 0.2 + 0.35 * sn
		W.h_lz = 0.25 * sn
		W.f_l = 0.6 if m < 0.55 else 0.15
		W.t_l = 0.9 if m < 0.55 else 0.2
		W.glow_l = u
		W.hy = look * 0.3 + 0.35 * u
		W.jaw = maxf(W.jaw, 0.35 * u)
		W.lid_l = 0.6 if m < 0.55 else 0.15
		W.lid_r = W.lid_l
		W.b_ly = 0.07
		W.b_ry = 0.07
		W.cat_up = 1.0
	if mv == "sweep" or channel > 0.0:
		var u := _sm(0.0, 0.6, m if mv == "sweep" else 1.0)
		W.sh_lx = -2.65 * u
		W.sh_rx = -2.65 * u
		W.sh_lz = 0.55 * u
		W.sh_rz = -0.55 * u
		W.sh_ly = 0.0
		W.sh_ry = 0.0
		W.el_lx = -0.2
		W.el_rx = -0.2
		W.h_lx = -0.4
		W.h_rx = -0.4
		W.h_lz = 0.0
		W.h_rz = 0.0
		W.f_l = 0.0
		W.f_r = [0.0, 0.0, 0.0]
		W.t_l = 0.0
		W.t_r = 0.0
		W.glow_l = 1.0
		W.glow_r = 1.0
		W.hx = -0.28 * u
		W.lid_l = 1.0
		W.lid_r = 1.0
		W.jaw = 0.18 + 0.1 * sin(t * 7.0)
		W.b_ly = 0.06
		W.b_ry = 0.06
		W.b_lz = 0.08
		W.b_rz = -0.08
		W.lean = -0.1 * u
		W.cat_puff = 1.0
		W.cat_up = 1.0
	if mv == "slam":
		var grab := 1.4
		var lift := 1.2
		var gr := _sm(0.0, 0.5, m)
		var did := shot != 0
		var up := _sm(grab, grab + lift * 0.8, m)
		W.sh_lx = -0.75 if did else -3.0 * gr
		W.sh_rx = W.sh_lx
		W.sh_lz = 0.5 if did else 0.18
		W.sh_rz = -0.5 if did else -0.18
		W.sh_ly = 0.0
		W.sh_ry = 0.0
		W.el_lx = -0.2 if did else -0.35 + 0.25 * up
		W.el_rx = W.el_lx
		W.h_lx = 0.0
		W.h_rx = 0.0
		W.h_lz = 0.0
		W.h_rz = 0.0
		W.f_l = 1.0      # fists round the beam
		W.f_r = [1.0, 1.0, 1.0]
		W.t_l = 1.0
		W.t_r = 1.0
		W.lean = 0.5 if did else -0.15 * up
		W.hx = 0.25 if did else -0.3 * gr
		W.jaw = 0.7 if did else 0.05
		W.lid_l = 0.75 if did else 0.5
		W.lid_r = W.lid_l
		W.b_lz = 0.32
		W.b_rz = -0.32
		W.b_ly = -0.05
		W.b_ry = -0.05
		W.cat_puff = 1.0
		W.cat_up = 1.0
	if down:
		W.lean = 0.42
		W.roll = 0.22
		W.twist = 0.1
		W.hx = 0.32
		W.hz = 0.3 + 0.05 * sin(t * 2.0)
		W.hy = 0.15
		W.sh_lx = 0.12
		W.sh_lz = 0.42
		W.sh_ly = 0.0
		W.el_lx = -0.25
		W.sh_rx = 0.12
		W.sh_rz = -0.42
		W.sh_ry = 0.0
		W.el_rx = -0.25
		W.h_lx = 0.3
		W.h_rx = 0.3
		W.h_lz = 0.0
		W.h_rz = 0.0
		W.f_l = 0.35
		W.f_r = [0.35, 0.35, 0.35]
		W.t_l = 0.3
		W.t_r = 0.3
		W.jaw = 0.55 + 0.1 * sin(t * 3.0)
		W.lid_l = 0.55
		W.lid_r = 0.7
		W.b_ly = 0.08
		W.b_ry = 0.08
		W.b_lz = -0.25
		W.b_rz = 0.25
		W.gz = 0.38
		W.gy = -0.22
		W.cat_away = 1.0
		W.cat_puff = 1.0
		W.shin_l = 0.3
		W.shin_r = -0.15
	if dizzy and not down:
		W.hz = 0.28 * sin(t * 4.2)
		W.hx = 0.12 + 0.18 * cos(t * 4.2)
		W.hy = 0.2 * sin(t * 2.1)
		W.lean = 0.2
		W.roll = 0.1 * sin(t * 2.1)
		W.sh_lx = -0.3 + 0.25 * sin(t * 3.0)
		W.sh_lz = 0.35
		W.sh_rx = -0.3 + 0.25 * sin(t * 3.0 + 2.0)
		W.sh_rz = -0.35
		W.el_lx = -0.4
		W.el_rx = -0.4
		W.f_l = 0.3
		W.f_r = [0.3, 0.3, 0.3]
		W.jaw = 0.45
		W.lid_l = 0.2 + 0.3 * sin(t * 5.0)
		W.lid_r = 0.2 - 0.3 * sin(t * 5.0)
		W.b_lz = -0.2
		W.b_rz = 0.25
		W.gz = 0.2 * sin(t * 4.2)
		W.gy = -0.1
		W.cat_away = 1.0
	if mv == "raise" or mv == "house":
		var u := _sm(0.0, 0.6, m) * (1.0 - _sm(2.0, 2.6, m))
		W.sh_lx = -1.9 * u
		W.sh_rx = -1.9 * u
		W.sh_lz = 0.75 * u
		W.sh_rz = -0.75 * u
		W.el_lx = -0.5 * u
		W.el_rx = -0.5 * u
		W.h_lx = -0.8 * u
		W.h_rx = -0.8 * u
		W.f_l = 0.0
		W.f_r = [0.0, 0.0, 0.0]
		W.glow_l = u
		W.glow_r = u
		W.hx = -0.15 * u
		W.jaw = maxf(W.jaw, 0.5 * u)
		W.lid_l = 0.45
		W.lid_r = 0.45
		W.b_lz = 0.3
		W.b_rz = -0.3
		W.cat_puff = 1.0
		W.cat_up = 1.0
	if mode == "enough" or mode == "tamed":
		if mode == "enough" or not shake_:
			var u := _sm(0.0, 0.5, enough_t) if mode == "enough" else 0.0
			if u > 0.0:
				W.sh_rx = -2.15 * u - 0.5 * (1.0 - u)
				W.sh_rz = -0.25
				W.sh_ry = 0.3
				W.el_rx = -0.55 * u - 1.75 * (1.0 - u)
				W.h_rx = -0.9 * u
				W.h_ry = -1.2 * u
				W.f_r = [0.0, 0.0, 0.0]
				W.t_r = 0.1
				W.lid_l = 0.38
				W.lid_r = 0.38
				W.b_lz = 0.05
				W.b_rz = -0.05
				W.b_ly = 0.0
				W.b_ry = 0.0
		if shake_:
			W.sh_rx = -1.25 + 0.14 * sin(t * 9.0)
			W.sh_rz = -0.05
			W.sh_ry = 0.2
			W.el_rx = -0.25
			W.h_rx = 0.0
			W.h_ry = -1.4
			W.f_r = [0.55, 0.55, 0.55]
			W.t_r = 0.5
			W.lean = 0.25
			W.lid_l = 0.3
			W.lid_r = 0.3
	if cine_puff != 0:      # the truce cutscene: the cat has opinions
		W.cat_puff = 1.0
		W.cat_up = 1.0
	# blinks (not while the lids are already shut)
	blink_t -= dt
	if blink_t <= 0.0:
		blink = 0.16
		blink_t = 2.2 + randf() * 3.5
	blink = maxf(0.0, blink - dt)
	if blink > 0.0 and not dizzy:
		W.lid_l = 1.0
		W.lid_r = 1.0
	# a hit: she flinches (head snaps back, lids squeeze, glasses jump) and flashes white
	if flinch > 0.0:
		_kick("hx", -2.2 * flinch)
		_kick("lean", -1.2 * flinch)
		_kick("gy", 1.6 * flinch)
		_kick("gz", (randf() - 0.5) * 3.0 * flinch)
		flash = maxf(flash, flinch)
		flinch = 0.0
	flash = maxf(0.0, flash - dt * 5.0)
	if flash > 0.02 and blink <= 0.0:
		W.lid_l = maxf(W.lid_l, 0.75)
		W.lid_r = maxf(W.lid_r, 0.75)
		W.b_ly = 0.08
		W.b_ry = 0.08
	var fl := minf(1.0, flash)
	for mat: StandardMaterial3D in flash_mats:
		mat.emission = (mat.get_meta("e0") as Color).lerp(Color.WHITE, fl * 0.7)
		mat.emission_energy_multiplier = float(mat.get_meta("i0")) + fl * 0.9
	# ---- apply (springs)
	var cr: Vector3 = rest_r[chest]
	chest.rotation = Vector3(cr.x + _spr("lean", W.lean, dt), cr.y + _spr("twist", W.twist, dt, 80.0, 13.0), cr.z + _spr("roll", W.roll, dt, 60.0, 11.0))
	var br := 1.0 + 0.012 * sin(t * 1.7) + (0.02 * sin(t * 9.0) if channel > 0.0 else 0.0)
	chest.scale = Vector3(br, 1.0 + (br - 1.0) * 0.6, br)
	head.rotation = Vector3(_spr("hx", W.hx, dt, 90.0, 12.0), _spr("hy", W.hy, dt, 60.0, 11.0), _spr("hz", W.hz, dt, 70.0, 11.0))
	neck.rotation.x = head.rotation.x * 0.25
	jaw.rotation.x = _spr("jaw", W.jaw, dt, 260.0, 20.0) * 0.42
	var jx := maxf(0.0, (SPR["jaw"] as Spr).x)
	mouth.scale = Vector3(1.0 - jx * 0.25, 0.15 + jx * 1.6, mouth.scale.z)
	# (about the lid's own tilted axis)
	lid_l.quaternion = (rest_q[lid_l] as Quaternion) * Quaternion(Vector3.RIGHT, -0.28 + _spr("lidL", W.lid_l, dt, 300.0, 24.0) * 1.5)
	lid_r.quaternion = (rest_q[lid_r] as Quaternion) * Quaternion(Vector3.RIGHT, -0.28 + _spr("lidR", W.lid_r, dt, 300.0, 24.0) * 1.5)
	brow_l.position.y = (rest_p[brow_l] as Vector3).y + _spr("byL", W.b_ly, dt, 160.0, 16.0)
	brow_r.position.y = (rest_p[brow_r] as Vector3).y + _spr("byR", W.b_ry, dt, 160.0, 16.0)
	brow_l.rotation.z = _spr("bzL", W.b_lz, dt, 160.0, 16.0)
	brow_r.rotation.z = _spr("bzR", W.b_rz, dt, 160.0, 16.0)
	spirals[0].visible = dizzy
	spirals[1].visible = dizzy
	spirals[0].rotation.z = -t * 8.0
	spirals[1].rotation.z = t * 8.0
	# arms: shoulder (x forward/back, z out/in, y twist), elbow, wrist; then the fingers curl
	_arm(arm_l, "L", 1.0, W.sh_lx, W.sh_ly, W.sh_lz, W.el_lx, W.h_lx, W.h_ly, W.h_lz, [0.0 if W.point_l else W.f_l, W.f_l, W.f_l], W.t_l, W.glow_l, dt)
	_arm(arm_r, "R", -1.0, W.sh_rx, W.sh_ry, W.sh_rz, W.el_rx, W.h_rx, W.h_ry, W.h_rz, W.f_r, W.t_r, W.glow_r, dt)
	shin_l.rotation.x = _spr("shinL", W.shin_l, dt, 200.0, 14.0)
	shin_r.rotation.x = _spr("shinR", W.shin_r, dt, 200.0, 14.0)
	glasses.rotation.z = _spr("gz", W.gz, dt, 120.0, 9.0)
	glasses.position.y = (rest_p[glasses] as Vector3).y + _spr("gy", W.gy, dt, 140.0, 10.0) * 0.25
	# curlers jiggle with the head's motion
	var hz_v := absf((SPR["hz"] as Spr).v)
	var i := 0
	for c: Node in curlers.get_children():
		if c is Node3D and rest_r.has(c):
			var R: Vector3 = rest_r[c]
			(c as Node3D).rotation = Vector3(R.x + sin(t * 5.3 + i) * 0.02 * (1.0 + hz_v), R.y, R.z + sin(t * 4.1 + i * 2) * 0.03)
		i += 1
	# the teacup stays level in her right hand (set down while that hand is busy)
	var hand_free := mv == "blasts" or mv == "sweep" or mv == "slam" or mv == "raise" or mv == "house" or mv == "down" or mode == "enough" or (mode == "tamed" and shake_)
	cup_in = clampf(cup_in + (-dt * 6.0 if hand_free else dt * 3.0), 0.0, 1.0)
	if held_cup != null:
		held_cup.visible = cup_in > 0.02
		held_cup.position = Vector3(0.24, -0.62, 0.12)
		held_cup.quaternion = arm_r.hand.global_transform.basis.get_rotation_quaternion().inverse() * Quaternion(Vector3.UP, yaw)
		held_cup.scale = Vector3.ONE * maxf(0.001, 1.1 * cup_in)
	# the cat: asleep and breathing; head up when something's coming; puffed before the big moves; it bolts to the chair's crest when she goes DOWN
	var up := _spr("catUp", maxf(W.cat_up, W.cat_puff), dt, 60.0, 10.0)
	var puff := _spr("catPuff", W.cat_puff, dt, 80.0, 10.0)
	var away := _spr("catAway", W.cat_away, dt, 30.0, 9.0)
	if cat_home == Vector3.ZERO:
		cat_home = rest_p[cat]
	var hop := sin(clampf(away, 0.0, 1.0) * PI) * 1.4
	cat.position = Vector3(cat_home.x + 0.75 * away, cat_home.y + 4.35 * away + hop, cat_home.z - 2.95 * away)
	cat.rotation.y = PI * 0.85 * away
	var cb := 1.0 + 0.035 * sin(t * 1.4) * (1.0 - up)
	cat.scale = Vector3(cb + puff * 0.18, cb + puff * 0.25, cb + puff * 0.18)
	cat_head.rotation = Vector3(-0.45 * up + 0.08 * sin(t * 0.7) * (1.0 - up), look * 0.5 * up + 0.2 * sin(t * 0.3) * (1.0 - up), 0.25 * (1.0 - up))
	cat_tail.rotation = Vector3(0.0, 0.35 * sin(t * (1.2 + puff * 6.0)), puff * 0.4)
	if puff > 0.5 and not hissed:
		hissed = true
		_hiss()
	if puff < 0.2:
		hissed = false
	# the throne: bob, a tilt when she's DOWN, a wobble when DIZZY, and a squash on the slam / the crash
	if squash != 0.0:
		_kick("sq", -6.0 * squash)
		squash = 0.0
	var sq := _spr("sq", 0.0, dt, 180.0, 9.0)
	throne.position.y = sin(t * 1.4) * 0.06 + sq * 0.4
	throne.scale = Vector3(1.0 - sq * 0.25, 1.0 + sq * 0.5, 1.0 - sq * 0.25)
	throne.rotation.z = _spr("tz", 0.12 if down else (sin(t * 4.0) * 0.08 if dizzy else 0.0), dt, 60.0, 8.0)
	# the marquee: the bulbs chase (faster while she channels); they sputter when the chair is down
	var ch := 14.0 if channel > 0.0 else 5.0
	var on := sin(t * ch) > 0.0
	var spt := (0.1 if randf() < 0.5 else 1.0) if down else 1.0
	if bm_a != null:
		bm_a.emission_energy_multiplier = (1.6 if on else 0.35) * spt
	if bm_b != null:
		bm_b.emission_energy_multiplier = (0.35 if on else 1.6) * spt
	halo_hit = maxf(0.0, halo_hit - dt * 4.0)
	MsKit.opa(head_glow, 0.45 + 0.25 * sin(t * 12.0) + 0.5 * halo_hit if channel > 0.0 else (0.2 if dizzy_t > 0.0 or down_t > 0.0 else 0.0))
	var crack := clampf(focus / FOCUS, 0.0, 1.0)
	halo.visible = channel > 0.0
	if halo.visible:      # the halo turns, jumps on every hit, and shudders harder the closer her focus is to breaking
		MsKit.opa(halo, 0.7 + 0.2 * sin(t * 10.0) + 0.3 * halo_hit)
		MsKit.tint(halo, MsKit.lin(0xffd060).lerp(Color(1.0, 0.35, 0.25), crack * 0.8).lerp(Color.WHITE, halo_hit * 0.7))
		halo.rotation = Vector3(sin(t * 23.0) * 0.18 * crack, t * 3.0, cos(t * 19.0) * 0.18 * crack)
		halo.scale = Vector3.ONE * (1.0 + 0.25 * halo_hit + 0.05 * sin(t * 6.0))
	stars.visible = dizzy_t > 0.0 or down_t > 0.0
	if stars.visible:
		var si := 0
		for s: Node3D in stars.get_children():
			var a := t * 3.0 + si * 1.256
			s.position = Vector3(sin(a) * 1.5, sin(t * 5.0 + si) * 0.2, cos(a) * 1.5)
			s.rotation = Vector3(0.0, t * 4.0, 0.0)
			si += 1
	for k in 3:
		var e: Emitter = emitters[k]
		if not e.mesh.visible:
			continue
		var pu := sin(t * 8.0 + e.a)
		var hurt := 1.0 - minf(1.0, t_emit[k].hp / EMIT_HP)      # the more it is shot, the faster and angrier it runs
		MsKit.tint(e.halo, Color(0.48 + hurt * 0.52, 1.0 - hurt * 0.45, 0.75 - hurt * 0.5).srgb_to_linear(), 0.4 + 0.3 * pu)
		e.shell.scale = Vector3.ONE * (1.0 + 0.1 * pu + hurt * 0.1)
		MsKit.opa(e.shell, 0.3 + 0.12 * pu)
		e.r1.rotation = Vector3(t * (2.2 + hurt * 4.0), t * 1.3, 0.0)
		e.r2.rotation = Vector3(t * -1.1, t * (2.8 + hurt * 4.0), 1.1)
		e.cage.rotation.y = -t * 1.5
		MsKit.opa(e.beam, 0.12 + 0.07 * sin(t * 11.0 + e.a))
		e.beam.scale = Vector3(1.0 + 0.12 * pu, 1.0, 1.0 + 0.12 * pu)


func _arm(A: Arm, s: String, sg: float, shx: float, shy: float, shz: float, elx: float, hx: float, hy: float, hz: float, curls: Array, thumb: float, glow_: float, dt: float) -> void:
	A.sh.rotation = Vector3(_spr("shx" + s, shx, dt, 120.0, 15.0), _spr("shy" + s, shy, dt, 90.0, 14.0), _spr("shz" + s, shz, dt, 120.0, 15.0))
	A.el.rotation.x = _spr("el" + s, elx, dt, 140.0, 15.0)
	A.hand.rotation = Vector3(_spr("hx" + s, hx, dt, 150.0, 16.0), _spr("hy" + s, hy, dt, 120.0, 15.0), _spr("hz" + s, hz, dt, 220.0, 18.0))
	for i in 3:
		var c := _spr("f" + s + str(i), curls[i], dt, 200.0, 18.0)
		var pair: Array = A.f[i]
		if pair[0] != null:
			(pair[0] as Node3D).rotation.z = -sg * c * 1.2
		if pair[1] != null:
			(pair[1] as Node3D).rotation.z = -sg * c * 1.4
	var tc := _spr("t" + s, thumb, dt, 200.0, 18.0)
	(A.t[0] as Node3D).rotation = Vector3(-tc * 0.3, 0.0, -sg * tc * 0.7)
	(A.t[1] as Node3D).rotation.z = -sg * tc * 0.9
	MsKit.opa(A.glow, _spr("glow" + s, glow_, dt, 60.0, 12.0) * 0.9)


func get_bar() -> Variant:
	if mode == "off":
		return null
	var lab := "RESPECT"
	if mode == "enough" or mode == "tamed":
		lab = "TRUCE?"
	elif mode != "intro" and label != "":
		lab = "RESPECT  ·  " + label
	return {"name": "THE GODMOTHER", "f": respect, "label": lab, "hot": down_t > 0.0 or dizzy_t > 0.0 or channel > 0.0}


func tame() -> void:
	mode = "tamed"
	label = "TRUCE"


## after the truce: she sits at the north side of the room, calm (the ending)
func place_tamed() -> void:
	reset()
	mode = "tamed"
	g.visible = true
	x = 0.0
	z = 14.0
	y = PF + 0.6
	yaw = PI
	respect = 1.0


## a retry mid-fight starts at the phase you had reached (its respect, its floor) instead of from the top
func resume(ph: int) -> void:
	reset()
	g.visible = true
	mode = "fight"
	phase = ph
	respect = [0.0, 0.0, PHASE2, PHASE3][ph]
	idx = -1
	y = PF + 6.5 if ph == 2 else PF + 2.4
	if ph == 2:
		_tiles_up()
	for e: Emitter in emitters:
		e.mesh.visible = ph == 1
	for te: Target in t_emit:
		te.hp = te.max
		te.dead = false
	_next_move()


## a checkpoint into the truce: straight into "Enough."
func force_enough() -> void:
	reset()
	g.visible = true
	mode = "enough"
	enough_t = 1.0
	respect = 1.0
	x = 0.0
	z = 14.0
	y = PF + 0.6
	yaw = PI
	label = "TRUCE?"


func is_done() -> bool:
	return mode == "enough" or mode == "tamed"


func is_fighting() -> bool:
	return mode == "fight" or mode == "intro"
