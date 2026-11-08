class_name RobotGfx
extends RefCounted
## The hostile robot's shared art (JS robotGfx(), robotCanvas(), the BREAKER unit: wide pauldrons, ram-fist right arm, bolt-cannon left arm, scanner head, twin exhaust stacks). Built once for the
## session: the worn paint textures, the model folded into one mesh, its glow and health bar meshes, the materials. Per robot there is only a row in the batch (RobotView).
## The skeleton is 17 joints; every part is rigidly attached to exactly one joint (weight 1.0), which is what suits hard-surface machinery.

# material rows (JS: 0 armour, 1 steel, 2 hazard; then the unlit lights)
const A := 0
const S := 1
const H := 2
const LIGHT := 3      # visor / core / lamps
const CHARGE := 4     # muzzle charge light
const PLATE := 5      # the unit number plate
const H_BLACK := 6
const H_SILVER := 7
const H_RED := 8
const H_LAMP := 9

# joints that carry parts. neck and fall carry none; the left pauldron rides the left shoulder, the right one has its own row because it gets knocked off in the death
const J_HIPS := 0
const J_SPINE := 1
const J_HEAD := 2
const J_DISH := 3
const J_SH_L := 4
const J_SH_R := 5
const J_EL_L := 6
const J_EL_R := 7
const J_TH_L := 8
const J_TH_R := 9
const J_KN_L := 10
const J_KN_R := 11
const J_ANK_L := 12
const J_ANK_R := 13
const J_PAU_R := 14
const JOINTS := 15
# the debris copy: the knocked-off pieces fly on their own, each piece a joint of its own
const D_PAU_R := 0
const D_DISH := 1
const SPRITE_POS: Array[Vector3] = [Vector3(0.0, 0.025, 0.2), Vector3(0.0, 0.5, 0.27), Vector3(0.14, 1.0, -0.33)]
const SPRITE_JOINT: Array[int] = [J_HEAD, J_SPINE, J_SPINE]
const MUZZLE := Vector3(0.0, -0.86, 0.0)

const DIGIT_PX := 12.1          # width of one character of "bold 22px monospace" on the JS plate canvas
const PLATE_W := 0.14
const PLATE_H := 0.07

static var shared: RobotGfx = null
static var heavies := {}

var batch: RigidBatch
var debris: RigidBatch


## The art, built the first time anything asks (JS warms this at load: call it while a level loads).
## FOINT's heavies: the same robot in black and silver with plating bolted to its joints: one batch per variant, built while the level loads
static func heavy_gfx(v: String) -> RobotGfx:
	if not heavies.has(v):
		heavies[v] = RobotGfx.new(v)
	return heavies[v]


static func _plating(o: MeshBuild.Soup, v: String) -> void:
	var sp := _mk(o, J_SPINE)
	sp.box(H_SILVER if v == "elite" else H_BLACK, 0.86, 0.56, 0.16, 0, 0.5, 0.25)
	sp.box(H_LAMP, 0.16, 0.05, 0.03, 0, 0.66, 0.34)
	sp.box(H_RED, 0.78, 0.12, 0.5, 0, 0.08, 0)
	sp.cyl(H_SILVER, 0.07, 0.07, 0.36, 0.17, 0.96, -0.32, {"seg": 8})
	sp.cyl(H_SILVER, 0.07, 0.07, 0.36, -0.17, 0.96, -0.32, {"seg": 8})
	for q: Array in [[J_SH_L, 1.0], [J_SH_R, -1.0]]:
		var b := _mk(o, q[0])
		var s: float = q[1]
		b.box(H_BLACK, 0.46, 0.2, 0.46, s * 0.06, 0.16, 0, {"rz": s * -0.18})
		b.cyl(H_SILVER, 0.005, 0.07, 0.32, s * 0.12 - s * 0.08, 0.26 + 0.14, 0.1, {"seg": 6, "rz": s * -0.5})
		b.cyl(H_SILVER, 0.005, 0.07, 0.32, s * 0.12 - s * 0.08, 0.26 + 0.14, -0.1, {"seg": 6, "rz": s * -0.5})
	_mk(o, J_HEAD).box(H_BLACK if v == "suppression" else H_RED, 0.07, 0.14, 0.42, 0, 0.28, -0.02)


static func get_shared() -> RobotGfx:
	if shared == null:
		shared = RobotGfx.new()
	return shared


func _init(p_heavy: String = "") -> void:
	var maps := Texture2DArray.new()
	maps.create_from_images([_canvas_image("armor"), _canvas_image("steel"), _canvas_image("hazard"), _plate_image()])
	var mat := ShaderMaterial.new()
	mat.shader = RigidBatch.MATRIX_SHADER
	mat.set_shader_parameter(&"maps", maps)
	var albedo := PackedVector4Array()
	var pbr := PackedVector4Array()
	for i in 24:
		albedo.append(Vector4(1, 1, 1, -1))
		pbr.append(Vector4(1, 0, 0, 0))
	# JS: matA: map armor, roughness .62, metalness .3; matS: map steel, .55, .45; matH: map hazard, .7, .1
	albedo[A] = Vector4(1, 1, 1, 0)
	pbr[A] = Vector4(0.62, 0.3, 0, 1)
	albedo[S] = Vector4(1, 1, 1, 1)
	pbr[S] = Vector4(0.55, 0.45, 0, 0)
	albedo[H] = Vector4(1, 1, 1, 2)
	pbr[H] = Vector4(0.7, 0.1, 0, 0)
	pbr[LIGHT] = Vector4(1, 0, 1, 0)
	pbr[CHARGE] = Vector4(1, 0, 2, 0)
	albedo[PLATE] = Vector4(1, 1, 1, 3)
	pbr[PLATE] = Vector4(1, 0, 3, 0)
	if p_heavy != "":      # FOINT heavies (JS levels/omnisphere/heavy.js): black armour, bright silver, hot red, and the plating's own materials
		albedo[A] = Vector4(0.055, 0.056, 0.062, 0)
		pbr[A] = Vector4(0.32, 0.55, 0, 1)
		albedo[S] = Vector4(1.35, 1.37, 1.42, 1)
		pbr[S] = Vector4(0.22, 0.7, 0, 0)
		albedo[H] = Vector4(0.95, 0.1, 0.06, 2)
		albedo[H_BLACK] = Vector4(0.018, 0.018, 0.02, -1)
		pbr[H_BLACK] = Vector4(0.45, 0.6, 0, 0)
		albedo[H_SILVER] = Vector4(0.8, 0.82, 0.86, -1)
		pbr[H_SILVER] = Vector4(0.2, 0.95, 0, 0)
		albedo[H_RED] = Vector4(0.62, 0.05, 0.03, -1)
		pbr[H_RED] = Vector4(0.5, 0.2, 0, 0)
		albedo[H_LAMP] = Vector4(1.0, 0.09, 0.03, -1)
		pbr[H_LAMP] = Vector4(1, 0, 3, 0)
	mat.set_shader_parameter(&"mat_albedo", albedo)
	mat.set_shader_parameter(&"mat_pbr", pbr)
	mat.set_shader_parameter(&"digit_adv", DIGIT_PX / 64.0 * PLATE_W)

	batch = RigidBatch.new(JOINTS, 16)
	batch.add_layer(_build_body(p_heavy), mat, true)
	var glow := ShaderMaterial.new()
	glow.shader = RigidBatch.GLOW_SHADER
	batch.add_layer(_build_glow(), glow, false)
	var bar := ShaderMaterial.new()
	bar.shader = RigidBatch.BAR_SHADER
	bar.render_priority = 100
	batch.add_layer(build_bar_mesh(), bar, false)

	debris = RigidBatch.new(2, 8)
	debris.add_layer(_build_debris(), mat.duplicate(), true)


# ---------------------------------------------------------------- the model. joint-local coordinates: +z forward, +x the robot's left, y up
const DARK := Color(0.62, 0.64, 0.68)
const MID := Color(0.85, 0.86, 0.9)
const SIDE: Array[float] = [-1.0, 1.0]


static func _hips(b: MeshBuild.PartBuilder) -> void:
	b.box(S, 0.5, 0.22, 0.34, 0, 0, 0, {"col": DARK})
	b.box(A, 0.46, 0.2, 0.05, 0, -0.1, 0.19, {"rx": 0.12})
	b.box(A, 0.46, 0.2, 0.05, 0, -0.1, -0.19, {"rx": -0.12})                     # belt skirt plates
	b.box(H, 0.16, 0.1, 0.02, 0, -0.1, 0.225, {"rx": 0.12})
	b.cyl(S, 0.075, 0.075, 0.74, 0, 0, 0, {"axis": "x", "col": DARK, "seg": 6})
	for sx in SIDE:
		b.box(A, 0.12, 0.17, 0.2, sx * 0.31, -0.02, 0, {"rz": -sx * 0.1})        # hip guards


static func _spine(b: MeshBuild.PartBuilder) -> void:
	b.box(S, 0.5, 0.3, 0.34, 0, 0.14, 0, {"col": DARK, "top": 1.08})             # waist
	b.box(A, 0.76, 0.42, 0.44, 0, 0.5, 0, {"top": 1.22, "bot": 0.85, "top_z": 1.0})   # barrel chest (armour)
	b.box(S, 0.28, 0.16, 0.05, 0, 0.5, 0.23, {"col": DARK})
	for i: int in [-1, 0, 1]:
		b.box(S, 0.24, 0.02, 0.06, 0, 0.5 + i * 0.045, 0.235, {"col": Color(0.3, 0.3, 0.32)})   # vent grille
	b.box(S, 0.24, 0.07, 0.04, 0, 0.3, 0.2, {"col": DARK})                       # number plate backing
	b.box(A, 0.5, 0.16, 0.05, 0, 0.74, 0.17, {"rx": -0.3, "top": 0.9})           # upper breast plate
	b.cyl(S, 0.2, 0.22, 0.1, 0, 0.77, 0, {"col": DARK, "seg": 8})                # collar
	b.box(S, 0.42, 0.36, 0.17, 0, 0.5, -0.31, {"col": DARK})                     # battery pack
	for sx in SIDE:                                                              # exhaust stacks
		b.cyl(S, 0.045, 0.05, 0.34, sx * 0.14, 0.78, -0.31, {"col": Color(0.45, 0.45, 0.48), "seg": 6})
		b.cyl(A, 0.058, 0.058, 0.05, sx * 0.14, 0.95, -0.31, {"seg": 6})
	b.box(H, 0.34, 0.08, 0.02, 0, 0.5, -0.402, {})                               # hazard strip on the pack
	for sx in SIDE:
		b.cyl(S, 0.1, 0.1, 0.22, sx * 0.4, 0.62, 0, {"axis": "x", "col": DARK, "seg": 8})   # shoulder sockets


static func _head(b: MeshBuild.PartBuilder) -> void:
	b.box(S, 0.3, 0.22, 0.3, 0, 0, 0, {"col": DARK, "top": 0.92})
	b.box(A, 0.34, 0.07, 0.34, 0, 0.12, 0.01, {"rx": 0.12})                      # brow armour
	b.box(S, 0.17, 0.07, 0.04, 0, -0.085, 0.15, {"col": Color(0.3, 0.3, 0.33)})  # mouth vent
	for sx in SIDE:
		b.box(A, 0.04, 0.16, 0.26, sx * 0.17, 0.0, -0.02, {"rz": sx * 0.12})     # cheek plates
	b.cyl(S, 0.012, 0.012, 0.3, -0.1, 0.25, -0.06, {"col": Color(0.5, 0.5, 0.55), "seg": 4})   # antenna mast


static func _dish(b: MeshBuild.PartBuilder) -> void:
	b.cyl(S, 0.06, 0.03, 0.04, 0.03, 0, 0, {"axis": "x", "col": MID, "seg": 8})
	b.cyl(S, 0.012, 0.012, 0.08, 0, 0, 0, {"axis": "x", "seg": 4})


static func _arm(b: MeshBuild.PartBuilder, sx: float) -> void:
	b.cyl(S, 0.1, 0.1, 0.2, 0, 0, 0, {"axis": "x", "col": DARK, "seg": 8})
	b.box(S, 0.15, 0.36, 0.17, 0, -0.2, 0, {"col": MID})                         # upper arm
	b.box(A, 0.18, 0.12, 0.2, 0, -0.1, 0.02, {"top": 0.9})                       # arm sleeve plate
	b.cyl(S, 0.05, 0.05, 0.3, sx * 0.0 + 0.09, -0.2, 0.09, {"col": Color(0.42, 0.43, 0.46), "seg": 6})   # hydraulic ram
	b.cyl(S, 0.08, 0.08, 0.18, 0, -0.36, 0, {"axis": "x", "col": DARK, "seg": 8})    # elbow


static func _pauldron(b: MeshBuild.PartBuilder, sx: float) -> void:
	b.box(A, 0.34, 0.15, 0.4, sx * 0.05, 0.1, 0, {"rz": -sx * 0.28})
	b.box(A, 0.22, 0.12, 0.34, sx * 0.1, 0.02, 0, {"rz": -sx * 0.28, "col": Color(0.9, 0.9, 0.9)})
	b.box(S, 0.34, 0.03, 0.42, sx * 0.07, 0.17, 0, {"rz": -sx * 0.28, "col": DARK})
	b.box(H, 0.1, 0.02, 0.2, sx * 0.07, 0.19, 0, {"rz": -sx * 0.28})


## bolt cannon forearm
static func _el_l(b: MeshBuild.PartBuilder) -> void:
	b.box(A, 0.19, 0.28, 0.23, 0, -0.17, 0.0, {"top": 0.92})
	b.box(S, 0.08, 0.2, 0.15, 0.13, -0.18, 0, {"col": DARK})
	b.cyl(S, 0.075, 0.08, 0.2, 0, -0.38, 0, {"col": DARK, "seg": 8})
	b.cyl(S, 0.043, 0.043, 0.5, 0, -0.6, 0, {"col": Color(0.35, 0.36, 0.4), "seg": 8})
	b.cyl(A, 0.062, 0.062, 0.05, 0, -0.76, 0, {"seg": 8})
	b.cyl(S, 0.03, 0.03, 0.28, 0, -0.52, 0.075, {"col": MID, "seg": 6})


## breaker fist forearm
static func _el_r(b: MeshBuild.PartBuilder) -> void:
	b.box(S, 0.2, 0.26, 0.22, 0, -0.16, 0, {"col": MID})
	b.cyl(S, 0.03, 0.03, 0.3, 0.11, -0.2, 0.08, {"col": Color(0.42, 0.43, 0.46), "seg": 6})
	b.box(A, 0.34, 0.3, 0.34, 0, -0.46, 0, {"top": 1.0, "bot": 0.86})
	b.box(S, 0.37, 0.08, 0.37, 0, -0.64, 0, {"col": DARK})
	for sx in SIDE:
		b.box(S, 0.06, 0.13, 0.06, sx * 0.1, -0.74, 0.1, {"col": DARK})
	b.box(H, 0.2, 0.07, 0.02, 0, -0.44, 0.175, {})


## thigh
static func _leg(b: MeshBuild.PartBuilder) -> void:
	b.cyl(S, 0.11, 0.11, 0.22, 0, 0, 0, {"axis": "x", "col": DARK, "seg": 8})
	b.box(S, 0.2, 0.4, 0.22, 0, -0.22, 0, {"col": MID, "top": 1.0, "bot": 0.9})
	b.box(A, 0.2, 0.2, 0.05, 0, -0.18, 0.13, {"rx": 0.1})
	b.box(S, 0.14, 0.06, 0.1, 0, -0.34, 0.1, {"col": DARK})


static func _shin(b: MeshBuild.PartBuilder) -> void:
	b.cyl(S, 0.1, 0.1, 0.25, 0, 0, 0, {"axis": "x", "col": DARK, "seg": 8})
	b.box(A, 0.2, 0.14, 0.1, 0, 0.02, 0.13, {"rx": -0.35})                       # knee guard
	b.box(S, 0.2, 0.4, 0.22, 0, -0.23, -0.01, {"col": MID, "top": 1.0, "bot": 0.74})
	b.cyl(S, 0.025, 0.025, 0.36, 0, -0.2, 0.14, {"col": Color(0.45, 0.46, 0.5), "seg": 5})
	b.box(A, 0.15, 0.2, 0.04, 0, -0.26, -0.13, {})                               # front ram + calf armour
	b.cyl(S, 0.075, 0.075, 0.2, 0, -0.42, 0, {"axis": "x", "col": DARK, "seg": 6})    # ankle


static func _foot(b: MeshBuild.PartBuilder) -> void:
	b.box(S, 0.24, 0.1, 0.4, 0, -0.06, 0.07, {"col": DARK})
	b.box(A, 0.22, 0.05, 0.2, 0, -0.005, 0.15, {"rx": -0.1})
	b.box(S, 0.2, 0.08, 0.1, 0, -0.07, -0.18, {"col": DARK})


static func _mk(out: MeshBuild.Soup, slot: int) -> MeshBuild.PartBuilder:
	return MeshBuild.PartBuilder.new(out, slot)


func _build_body(p_heavy: String = "") -> ArrayMesh:
	var o := MeshBuild.Soup.new()
	if p_heavy != "":
		_plating(o, p_heavy)
	_hips(_mk(o, J_HIPS))
	_spine(_mk(o, J_SPINE))
	_head(_mk(o, J_HEAD))
	_dish(_mk(o, J_DISH))
	_arm(_mk(o, J_SH_L), 1.0)
	_arm(_mk(o, J_SH_R), -1.0)
	_el_l(_mk(o, J_EL_L))
	_el_r(_mk(o, J_EL_R))
	_leg(_mk(o, J_TH_L))
	_leg(_mk(o, J_TH_R))
	_shin(_mk(o, J_KN_L))
	_shin(_mk(o, J_KN_R))
	_foot(_mk(o, J_ANK_L))
	_foot(_mk(o, J_ANK_R))
	_pauldron(_mk(o, J_SH_L), 1.0)
	_pauldron(_mk(o, J_PAU_R), -1.0)
	# the light-bearing parts
	var lm := func(g: MeshBuild.Geo, m: int, slot: int, x: float, y: float, z: float, rz: float = 0.0) -> void:
		g.place(x, y, z, 0.0, 0.0, rz)
		o.add(g, slot, m)
	lm.call(MeshBuild.box(0.25, 0.05, 0.03), LIGHT, J_HEAD, 0.0, 0.025, 0.155)
	var core := MeshBuild.cylinder(0.06, 0.06, 0.04, 10)
	core.rotate_x(PI * 0.5)
	lm.call(core, LIGHT, J_SPINE, 0.0, 0.5, 0.235)
	lm.call(MeshBuild.box(0.07, 0.05, 0.07), LIGHT, J_SH_L, 0.12, 0.2, 0.0, -0.28)
	lm.call(MeshBuild.box(0.07, 0.05, 0.07), LIGHT, J_SH_R, -0.12, 0.2, 0.0, 0.28)
	lm.call(MeshBuild.cylinder(0.03, 0.03, 0.05, 6), LIGHT, J_SPINE, 0.14, 0.99, -0.31)
	lm.call(MeshBuild.sphere(0.03, 6, 4), LIGHT, J_HEAD, -0.1, 0.41, -0.06)
	lm.call(MeshBuild.cylinder(0.028, 0.028, 0.05, 8), CHARGE, J_EL_L, 0.0, -0.8, 0.0)
	# the unit number plate: backing + one quad per digit (the glyph is picked in the shader, from the robot's number)
	var back := MeshBuild.plane(PLATE_W, PLATE_H)
	for i in back.uv.size():
		back.uv[i] = Vector2(back.uv[i].x * 64.0 / 256.0, 1.0 - (1.0 - back.uv[i].y) * 32.0 / 256.0)
	back.translate(0.0, 0.3, 0.223)
	o.add(back, J_SPINE, PLATE)
	var cell_w := DIGIT_PX / 64.0 * PLATE_W
	var cell_h := 26.0 / 32.0 * PLATE_H
	for pos in 4:                                 # pos 0 = the ones, on the right
		var g := MeshBuild.plane(cell_w, cell_h)
		for i in g.uv.size():                     # the row of glyphs under the backing in the atlas: starts on the 0
			g.uv[i] = Vector2(g.uv[i].x * DIGIT_PX / 256.0, 1.0 - (32.0 + (1.0 - g.uv[i].y) * 26.0) / 256.0)
		g.translate((float(pos) - 1.5) * -cell_w, 0.3 - PLATE_H / 32.0, 0.2232)      # the canvas's text middle is at y 17 of 32
		o.add(g, J_SPINE, PLATE, Color(1, 1, 1, float(pos + 1) / 10.0))
	return o.commit()


func _build_debris() -> ArrayMesh:
	var o := MeshBuild.Soup.new()
	_pauldron(_mk(o, D_PAU_R), -1.0)
	_dish(_mk(o, D_DISH))
	return o.commit()


## The glow sprites: visor, core, back lamp (channel 0, JS glowMat) and the muzzle (channel 1, JS muzSprite).
static func _build_glow() -> ArrayMesh:
	var s := SpriteSoup.new()
	s.sprite(J_HEAD, 0, SPRITE_POS[0], 0.55)
	s.sprite(J_SPINE, 0, SPRITE_POS[1], 0.45)
	s.sprite(J_SPINE, 0, SPRITE_POS[2], 0.3)
	s.sprite(J_EL_L, 1, MUZZLE, 0.5)
	return s.commit()


## Camera-facing quads, and flat additive geometry: VERTEX = centre in the joint's space, UV = corner, UV2 = (joint, channel), CUSTOM0.x = size (0: not a sprite).
class SpriteSoup:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()

	func sprite(slot: int, ch: int, at: Vector3, size: float) -> void:
		for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			_vertex(at, c, slot, ch, size)

	## real 3D geometry in the additive pass (the Gun Drone's call ring)
	func solid(g: MeshBuild.Geo, slot: int, ch: int) -> void:
		for i in g.idx.size():
			_vertex(g.pos[g.idx[i]], Vector2.ZERO, slot, ch, 0.0)

	func _vertex(p: Vector3, c: Vector2, slot: int, ch: int, size: float) -> void:
		pos.append(p)
		uv.append(c)
		uv2.append(Vector2(slot, ch))
		custom.append_array([size, 0.0, 0.0, 0.0])

	func commit() -> ArrayMesh:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_CUSTOM0] = custom
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		return m


## The health bar (same look as the old dummies): background 0.9 x 0.1, fill 0.86 x 0.06, in the plane the camera sees. UV2.x = 1 marks the fill.
static func build_bar_mesh() -> ArrayMesh:
	var o := MeshBuild.Soup.new()
	var fill := MeshBuild.plane(0.86, 0.06)
	fill.translate(0.0, 0.0, 0.001)
	o.add(fill, 1, 0)
	var bg := MeshBuild.plane(0.9, 0.1)
	var c := RigidBatch.lin(0x0a0f18)
	c.a = 0.8
	o.add(bg, 0, 0, c)
	return o.commit()


# ---------------------------------------------------------------- the worn paint (JS robotCanvas). The same seeded random stream draws the same marks

## A tiny software canvas: just what robotCanvas() draws with. Blends in the texture's own (sRGB) values, as a 2D canvas does.
class Canvas:
	var size := 256
	var px := PackedByteArray()
	var seed_ := 0
	var alpha := 1.0
	var r := 0.0
	var g := 0.0
	var b := 0.0

	func _init(s: int, p_seed: int) -> void:
		size = s
		seed_ = p_seed
		px.resize(s * s * 4)

	func rnd() -> float:
		seed_ = (seed_ * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(seed_) / 4294967296.0

	func style(hex: int) -> void:
		r = (hex >> 16) & 255
		g = (hex >> 8) & 255
		b = hex & 255

	func clear(hex: int) -> void:
		style(hex)
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color8(int(r), int(g), int(b)))
		px = img.get_data()

	func _blend(i: int, a: float) -> void:
		var o := i * 4
		px[o] = int(px[o] + (r - px[o]) * a + 0.5)
		px[o + 1] = int(px[o + 1] + (g - px[o + 1]) * a + 0.5)
		px[o + 2] = int(px[o + 2] + (b - px[o + 2]) * a + 0.5)

	## ctx.fillRect, with partial cover at the edges
	func rect(x: float, y: float, w: float, h: float) -> void:
		var x1 := minf(x + w, size)
		var y1 := minf(y + h, size)
		x = maxf(x, 0.0)
		y = maxf(y, 0.0)
		var ix0 := int(x)
		var ix1 := ceili(x1)
		var iy0 := int(y)
		var iy1 := ceili(y1)
		for py in range(iy0, iy1):
			var cy := minf(py + 1.0, y1) - maxf(float(py), y)
			if cy <= 0.0:
				continue
			for qx in range(ix0, ix1):
				var cx := minf(qx + 1.0, x1) - maxf(float(qx), x)
				if cx > 0.0:
					_blend(py * size + qx, alpha * cx * cy)

	func ellipse(cx: float, cy: float, rx: float, ry: float, rot: float) -> void:
		var c := cos(rot)
		var s := sin(rot)
		var ext := ceili(maxf(rx, ry)) + 1
		for py in range(maxi(0, int(cy) - ext), mini(size, int(cy) + ext + 1)):
			for qx in range(maxi(0, int(cx) - ext), mini(size, int(cx) + ext + 1)):
				var dx := qx + 0.5 - cx
				var dy := py + 0.5 - cy
				var lx := (dx * c + dy * s) / rx
				var ly := (-dx * s + dy * c) / ry
				var d := sqrt(lx * lx + ly * ly)
				var cover := clampf((1.0 - d) * minf(rx, ry) + 0.5, 0.0, 1.0)
				if cover > 0.0:
					_blend(py * size + qx, alpha * cover)

	## a thin stroked line
	func line(x0: float, y0: float, x1: float, y1: float, lw: float) -> void:
		var len := sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
		var n := maxi(1, ceili(len))
		for i in n + 1:
			var f := float(i) / n
			var px_ := int(lerpf(x0, x1, f))
			var py_ := int(lerpf(y0, y1, f))
			if px_ >= 0 and px_ < size and py_ >= 0 and py_ < size:
				_blend(py_ * size + px_, alpha * minf(1.0, lw))

	func stroke_rect(x: float, y: float, w: float, h: float, lw: float) -> void:
		var q := lw * 0.5
		rect(x - q, y - q, w + lw, lw)
		rect(x - q, y + h - q, w + lw, lw)
		rect(x - q, y + q, lw, h - lw)
		rect(x + w - q, y + q, lw, h - lw)

	func speck(n: int, cols: Array[int], w0: float, w1: float, a: float) -> void:
		for i in n:
			alpha = a * (0.4 + rnd() * 0.6)
			style(cols[int(rnd() * cols.size())])
			var w := w0 + rnd() * (w1 - w0)
			var x := rnd() * size
			var y := rnd() * size
			rect(x, y, w, w * (0.5 + rnd()))
		alpha = 1.0

	func image() -> Image:
		var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, px)
		img.generate_mipmaps()
		return img


static func _canvas_image(kind: String) -> Image:
	var S_ := 256
	var fs := float(S_)
	var x := Canvas.new(S_, 11 if kind == "armor" else (29 if kind == "steel" else 47))
	if kind == "armor":                                    # faded safety-yellow paint, chipped to bare steel and rust, grime streaks, panel seams
		x.clear(0xb48a2c)
		x.speck(900, [0xc49a36, 0xa37a24, 0xbd922f], 2, 7, 0.55)
		for i in 26:                                       # vertical grime
			x.alpha = 0.16
			x.style(0x2a2217)
			var gx := x.rnd() * fs
			var gw := 1.0 + x.rnd() * 5.0
			x.rect(gx, 0.0, gw, 40.0 + x.rnd() * 190.0)
		x.alpha = 1.0
		x.speck(70, [0x3d4148, 0x2b2e33], 1, 5, 0.8)        # chips
		x.speck(36, [0x7b4320, 0x5a2f17], 1, 5, 0.7)        # rust
		x.speck(90, [0xd9bf68], 1, 3, 0.6)                  # edge highlights
		for i in 40:                                       # scratches
			x.alpha = 0.5
			x.style(0xe4cf86 if x.rnd() < 0.5 else 0x2a2a2a)
			var px_ := x.rnd() * fs
			var py_ := x.rnd() * fs
			var ex := px_ + (x.rnd() - 0.5) * 40.0
			var ey := py_ + (x.rnd() - 0.5) * 40.0
			x.line(px_, py_, ex, ey, 0.6)
		x.alpha = 0.45
		x.style(0x2a2316)
		x.stroke_rect(0.5, 0.5, fs - 1.0, fs - 1.0, 1.5)
		x.rect(0.0, fs / 2.0 - 0.75, fs, 1.5)
		x.alpha = 1.0
		for q: Vector2 in [Vector2(10, 10), Vector2(fs - 10, 10), Vector2(10, fs - 10), Vector2(fs - 10, fs - 10)]:     # rivets
			x.style(0x4a3c1c)
			x.ellipse(q.x, q.y, 3.0, 3.0, 0.0)
			x.style(0xd3b45a)
			x.rect(q.x - 1.0, q.y - 2.0, 1.5, 1.5)
	elif kind == "steel":                                  # dark gunmetal with scuffs, oil and brushed streaks
		x.clear(0x4b5059)
		for i in 160:
			x.alpha = 0.07 + x.rnd() * 0.08
			x.style(0x788089 if x.rnd() < 0.5 else 0x2c3036)
			var sy := x.rnd() * fs
			x.rect(0.0, sy, fs, 1.0 + x.rnd() * 2.0)
		x.alpha = 1.0
		x.speck(500, [0x5d636d, 0x3a3e45, 0x6b727c], 1, 5, 0.5)
		x.speck(60, [0x9aa1aa], 1, 3, 0.7)
		for i in 9:                                        # oil
			x.alpha = 0.28
			x.style(0x14120f)
			var ox := x.rnd() * fs
			var oy := x.rnd() * fs
			var orx := 8.0 + x.rnd() * 26.0
			var ory := 5.0 + x.rnd() * 14.0
			x.ellipse(ox, oy, orx, ory, x.rnd() * 3.0)
		x.alpha = 0.5
		x.style(0x22252a)
		x.stroke_rect(0.5, 0.5, fs - 1.0, fs - 1.0, 1.2)
		x.alpha = 1.0
		x.speck(40, [0x6a3a1c], 2, 6, 0.55)
	else:                                                  # hazard stripes, worn
		x.clear(0x1d1e21)
		x.style(0xb08a28)
		var i := -S_
		while i < S_ * 2:
			for py in S_:                                  # the parallelogram (i,0) (i+32,0) (i+32-S,S) (i-S,S), row by row
				x.rect(i - (py + 0.5), float(py), 32.0, 1.0)
			i += 64
		x.speck(500, [0x2e2c26, 0x6d5a22, 0x8c7228], 2, 6, 0.6)
		x.speck(120, [0x444444], 1, 3, 0.8)
	return x.image()


## The plate layer of the map array. Top left: the JS plate canvas without its number (64 x 32: dark, with a gold frame). Under it: the glyphs 0-9 of the same font, side by side, on the plate's dark.
static func _plate_image() -> Image:
	var x := Canvas.new(256, 1)
	x.clear(0x191a1d)
	x.alpha = 1.0
	x.style(0xb08a28)
	x.stroke_rect(2.0, 2.0, 60.0, 28.0, 2.0)
	var img := Image.create_from_data(256, 256, false, Image.FORMAT_RGBA8, x.px)
	_draw_digits(img)
	img.generate_mipmaps()
	return img


## JS: nx.font = "bold 22px monospace", gold #d6b23e. Rasterised by the engine's own text server.
static func _draw_digits(img: Image) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var rids := font.get_rids()
	if rids.is_empty():
		return
	var ts := TextServerManager.get_primary_interface()
	var fr: RID = rids[0]
	var fsize := Vector2i(22, 0)
	var gold := Color8(0xd6, 0xb2, 0x3e)
	var bg := Color8(0x19, 0x1a, 0x1d)
	var ascent: float = ts.font_get_ascent(fr, 22)
	var descent: float = ts.font_get_descent(fr, 22)
	for d in 10:
		var cp := 48 + d
		var gl: int = ts.font_get_glyph_index(fr, 22, cp, 0)
		ts.font_render_glyph(fr, fsize, gl)
		var ti: int = ts.font_get_glyph_texture_idx(fr, fsize, gl)
		if ti < 0:
			continue
		var uvr: Rect2 = ts.font_get_glyph_uv_rect(fr, fsize, gl)
		var off: Vector2 = ts.font_get_glyph_offset(fr, fsize, gl)
		var src: Image = ts.font_get_texture_image(fr, fsize, ti)
		if src == null:
			continue
		if src.is_compressed():
			continue
		# centre the glyph in its cell; the cell's middle is the canvas's text middle (y 17 on the 32 px canvas), 13 px below the cell top at y 4
		var cell_x := 0.5 + d * DIGIT_PX
		var baseline := 13.0 + (ascent - descent) * 0.5 + 32.0
		var gw := int(uvr.size.x)
		var gh := int(uvr.size.y)
		var sx := int(uvr.position.x)
		var sy := int(uvr.position.y)
		var ox := int(round(cell_x + off.x))
		var oy := int(round(baseline + off.y))
		for py in gh:
			for qx in gw:
				var c := src.get_pixel(sx + qx, sy + py)
				var a := c.a
				if a <= 0.0:
					continue
				var tx := ox + qx
				var ty := oy + py
				if tx < 0 or ty < 32 or tx >= 256 or ty >= 58:
					continue
				img.set_pixel(tx, ty, bg.lerp(gold, a))
