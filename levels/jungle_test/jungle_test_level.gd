class_name JungleTestLevel
extends Level
## JUNGLE TEST (a working name until the user names it): a small alien-jungle clearing built in code, just big enough to try the Briar Dervish encounter before the real jungle level exists.
## A round clearing about 20 m across under giant trees on buttress roots. A gap in the canopy is placed so the sun lands in the middle of the clearing, and golden-teal haze hangs in the
## shaft. Ferns, broadleaf, glowing flowers and mushrooms grow round the edge, with vines hanging from the boughs. Step into the clearing and the Dervish drops out of the leaves.
## A sandbox: its own kit (Combat / GameUi SANDBOX_LEVELS), no saves. Plants: jungle_flora.gd; materials: the jungle_*.gdshader files next to this one. Its flow is the Blockout kit's.

const R_CLEAR := 20.0              # the clearing: flat and open, the fight's zone (the Dervish's leash is a metre inside it)
const R_EDGE := 30.5               # nobody gets further out than this (an invisible ring behind the trunks)
const R_FAR := 115.0               # where the drawn floor ends, long lost in the haze
const SUN_FROM := Vector3(30.0, 50.0, 20.0)      # View.SUN_POS: the sun shines from there. The canopy's gap is cut where the light lands in the middle of the clearing.
const CANOPY := [24.0, 28.5, 33.5] # the leaf ceilings' heights (lowest first)
const GAP_R := 8.0
const BOSS := Vector2(0.0, 3.0)
const SPAWN := {"x": 0.0, "y": 0.3, "z": -16.5, "yaw": 0.0}
## the giants round the clearing: yaw from the middle, distance, trunk radius, height. The one at -0.55 has the bough the Dervish drops from; the one at 1.2 stands where the sun comes in.
const GIANTS := [[-0.55, 24.5, 1.9, 34.0], [0.35, 26.0, 1.6, 31.0], [1.2, 25.0, 2.2, 36.0], [1.95, 23.5, 1.7, 30.0], [2.7, 26.0, 2.0, 33.0], [-2.85, 25.5, 1.8, 32.0], [-2.05, 24.0, 2.3, 35.0], [-1.3, 26.0, 1.6, 30.0]]

## The look (core/looks.gd): humid golden-teal haze, a warm sun on cool shade, glow that holds onto the lights
var look := {"ao": 0.85, "ao_radius": 1.4, "ao_fade": 60.0, "mist": 0.012, "mist_falloff": 0.16, "mist_y": 0.0, "mist_color": [0.42, 0.52, 0.4], "mist_gain": 1.0, "mist_glow": [0.24, 0.19, 0.08], "mist_glow_pow": 3.5,
	"mist_light": [0.48, 0.8, 0.32], "mist_far": 300.0,
	"bloom": 0.45, "bloom_threshold": 0.72, "bloom_knee": 0.25, "bloom_hot": 0.65, "bloom_luma": 0.35, "bloom_spread": 0.85,
	"scurve": 0.12, "saturation": 1.06, "vibrance": 0.2, "shadow_tint": [0.9, 1.02, 1.05], "high_tint": [1.06, 1.01, 0.9], "vignette": 0.34, "vignette_tint": [0.0, 0.02, 0.015], "grain": 0.02, "sharpen": 0.25}
var loadout: Array = ["deagle", "shotgun", "rifle", "smg", "rocket"]
var equip := "rifle"
var bo: Blockout = null

var _rng := RandomNumberGenerator.new()
var _sun := SUN_FROM.normalized()
var _noise: NoiseTexture2D
var _noise_nrm: NoiseTexture2D
var _clump_noise: NoiseTexture2D
var _leaf_cells: NoiseTexture2D
var _m: Dictionary = {}            # name -> material
var _trunks: Array[Vector3] = []   # x, z, radius of every trunk (the plants keep out of them)
var _glows: Array[Vector3] = []    # where the flower patches are (their lights)
var _env_was: Dictionary = {}


# ---- the ground -------------------------------------------------------------------------------------------------------------------------------------------------------

## The floor's height: nearly flat in the clearing, rising into root-bound mounds under the trees
func ground_y(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var rim := smoothstep(R_CLEAR - 3.0, R_EDGE + 6.0, r)
	var n := PlantBuild.noise3(Vector3(x * 0.07, 3.0, z * 0.07))
	var n2 := PlantBuild.noise3(Vector3(x * 0.23, 11.0, z * 0.23))
	return n * (0.1 + rim * 1.1) + n2 * (0.04 + rim * 0.25) + rim * rim * 3.5


func build() -> void:
	_rng.seed = 7341
	_textures()
	_materials()
	_render_state()
	_ground()
	_trees()
	_canopy()
	_undergrowth()
	_flowers()
	_props()
	_edge()
	_lights()
	_motes()
	world.spawn = SPAWN.duplicate()
	world.target_spots = []           # no shooting-range dummies or pods here (Combat._build_range); the clerk stands far off in the trees
	world.pickup_spots = []
	world.clerk_spot = [0.0, -95.0]
	bo = Blockout.new(self, {"id": id, "name": "JUNGLE TEST", "spawn": SPAWN, "on_spawn": _on_spawn})
	bo.stage({"id": "clearing", "name": "The clearing", "spawn": SPAWN, "task": "Something is up in the canopy.", "objectives": [
		{"id": "step_in", "label": "Step into the clearing", "text": "Step into the clearing.", "at": [0.0, 0.0, -8.0], "radius": 3.5, "area": 4.0},      # (a reach step is an area of radius + 5 m unless it says)
	]})
	bo.stage({"id": "dervish", "name": "The Briar Dervish", "spawn": {"x": 0.0, "y": 0.3, "z": -15.5, "yaw": 0.0}, "task": "Kill the Briar Dervish.", "objectives": [
		# custom, not kill: a kill step ends the level the moment it dies, and the end clears every enemy, so the wilt, the pods popping and the bulb rolling away were never seen
		{"id": "fight", "label": "Briar Dervish", "text": "Kill the Briar Dervish.", "kind": "custom", "done": _dervish_done, "spawns": [{"x": BOSS.x, "z": BOSS.y, "kind": "dervish", "yaw": PI}]},
	]})
	bo.build_checkpoints()


func _dervish() -> BriarDervish:
	for r: Robot in bo.spawned:
		if r is BriarDervish and not r.gone:
			return r
	return null


## the fight is won once it has finished dying (briar_dervish_view.gd: the bulb is off and rolling by 3 s, the rest sinks from 6 s)
func _dervish_done(_b: Blockout, _p: Player, _c: Combat) -> bool:
	var d := _dervish()
	return d == null or (d.dead and d.dead_t > 7.0)


func _on_spawn(r: Robot, _o: Dictionary, _b: Blockout) -> void:
	if r is BriarDervish:
		r.zone = {"x": 0.0, "z": 0.0, "leash": R_CLEAR - 1.0}


func on_enter() -> void:
	bo.on_level_entered()


func on_exit() -> void:
	bo.dispose()
	var env := Game.view.env      # what this level changed of the View's environment goes back
	for k: String in _env_was:
		env.set(k, _env_was[k])


func tick(dt: float) -> void:
	bo.update(dt, Game.player, Game.combat)
	var d := _dervish()
	if d == null or d.dead:
		bo.boss_bar(null)
	else:
		var label := "WOUND UP" if d.mv == &"wound" else ("DIZZY" if d.dizzy else ("UNDERGROUND" if d.under else ""))
		bo.boss_bar({"name": d.boss_bar, "f": maxf(0.0, d.hp) / d.max, "label": label, "hot": d.dizzy or d.mv == &"wound"})


## the console's `cp`, and CONTINUE
var checkpoints: Array:
	get:
		return bo.checkpoints if bo != null else []


func load_checkpoint(which: Variant) -> bool:
	return bo.load_cp(which)


# ---- build -------------------------------------------------------------------------------------------------------------------------------------------------------------

func _noise_tex(kind: FastNoiseLite.NoiseType, freq: float, octaves: int, normal: bool, seed_: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.seed = seed_
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 5.0
	return t


func _textures() -> void:
	_noise = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 5, false, 11)
	_noise_nrm = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 5, true, 11)
	_clump_noise = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008, 3, false, 29)
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.frequency = 0.035
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	cells.cellular_jitter = 0.9
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	cells.seed = 5
	_leaf_cells = NoiseTexture2D.new()
	_leaf_cells.width = 512
	_leaf_cells.height = 512
	_leaf_cells.seamless = true
	_leaf_cells.noise = cells
	_leaf_cells.generate_mipmaps = true


func _shader_mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## every material, made once here (never mid-play)
func _materials() -> void:
	var D := "res://levels/jungle_test/"
	var nz := {"noise_tex": _noise, "noise_nrm": _noise_nrm}
	var bark := nz.duplicate()
	_m["bark"] = _shader_mat(D + "jungle_bark.gdshader", bark)
	var rock := nz.duplicate()
	rock.merge({"scale": 0.45, "stretch": 1.0, "moss": 1.0, "moss_low": 1.5, "vein": 0.0, "bump": 1.6})
	_m["rock"] = _shader_mat(D + "jungle_bark.gdshader", rock)
	var wood := nz.duplicate()
	wood.merge({"scale": 0.4, "stretch": 0.25, "moss": 0.9, "moss_low": 1.0, "vein": 1.2})
	_m["wood"] = _shader_mat(D + "jungle_bark.gdshader", wood)
	var lf := {"noise_tex": _noise}
	_m["leaf"] = _shader_mat(D + "jungle_leaf.gdshader", lf.merged({"sway": 0.1, "sway_speed": 0.7, "backlight": 0.7}))
	_m["fern"] = _shader_mat(D + "jungle_leaf.gdshader", lf.merged({"sway": 0.06, "backlight": 0.5}))
	_m["vine"] = _shader_mat(D + "jungle_leaf.gdshader", lf.merged({"sway": 0.18, "sway_speed": 0.8, "sway_by": 0, "backlight": 0.5}))
	_m["litter"] = _shader_mat(D + "jungle_leaf.gdshader", lf.merged({"sway": 0.0, "backlight": 0.2, "rough": 0.7}))
	_m["glow"] = _shader_mat(D + "jungle_glow.gdshader", {"sway": 0.06, "energy": 4.0})
	_m["glow_vine"] = _shader_mat(D + "jungle_glow.gdshader", {"sway": 0.18, "sway_speed": 0.8, "sway_by": 0, "energy": 5.0, "pulse": 0.45, "speed": 0.9})
	_m["shroom"] = _shader_mat(D + "jungle_glow.gdshader", {"sway": 0.0, "energy": 2.6, "pulse": 0.2, "speed": 0.6})
	_m["ground"] = _shader_mat(D + "jungle_ground.gdshader", nz.duplicate())


## the light: a low warm sun that only gets in through the gap, cool green shade under the leaves, golden-teal haze
func _render_state() -> void:
	Game.view.apply_render_state({"background": Color("7d9670"), "tone_mapping": View.TONE_ACES, "exposure": 1.05, "fog": [Color("7d9670"), 0.011],
		"hemi": [Color("6a9a88"), Color("3d3524"), 1.75], "sun": [Color("ffe1a0"), 5.0], "sun_cast": true, "clip": [0.1, 500.0]})
	var env := Game.view.env
	var set_ := {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.011, "volumetric_fog_albedo": Color(0.92, 0.88, 0.7), "volumetric_fog_emission": Color(0.015, 0.035, 0.03),
		"volumetric_fog_emission_energy": 1.0, "volumetric_fog_anisotropy": 0.6, "volumetric_fog_length": 90.0, "volumetric_fog_detail_spread": 2.0, "volumetric_fog_ambient_inject": 0.15,
		"volumetric_fog_sky_affect": 0.0, "volumetric_fog_gi_inject": 0.0, "volumetric_fog_temporal_reprojection_enabled": true,
		"ssr_enabled": true, "ssr_max_steps": 48, "ssr_fade_in": 0.15, "ssr_fade_out": 2.0, "ssr_depth_tolerance": 0.3}
	for k: String in set_:
		_env_was[k] = env.get(k)
		env.set(k, set_[k])


func _mesh(g: PlantBuild.Geo, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## a mesh of several surfaces: [Geo, material] pairs
func _surfaces(parts: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	for p: Array in parts:
		var g: PlantBuild.Geo = p[0]
		if g.pos.is_empty():
			continue
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g.arrays())
		m.surface_set_material(m.get_surface_count() - 1, p[1])
	return m


func _instances(mesh: Mesh, xfs: Array[Transform3D], tints: PackedColorArray, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not tints.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, tints[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## a triangle whose face is up (front faces are clockwise: PlantBuild.Geo.smooth)
static func _tri_up(g: PlantBuild.Geo, a: int, b: int, c: int) -> void:
	if (g.pos[c] - g.pos[a]).cross(g.pos[b] - g.pos[a]).y >= 0.0:
		g.idx.append_array([a, b, c])
	else:
		g.idx.append_array([a, c, b])


## The floor: rings round the middle, fine out to the edge, coarser into the haze. Colour carries wet / moss / shade for jungle_ground.gdshader. Its inner part is the collider.
func _ground() -> void:
	var radii := PackedFloat32Array([0.0])
	var r := 0.0
	var step := 0.5
	while r < R_FAR:
		r += step
		radii.append(r)
		if r > 42.0:
			step *= 1.08
	var seg := 240
	var g := PlantBuild.Geo.new()
	for i in radii.size():
		var rr := radii[i]
		for j in (1 if i == 0 else seg):
			var a := TAU * j / seg
			var x := sin(a) * rr
			var z := cos(a) * rr
			g.pos.append(Vector3(x, ground_y(x, z), z))
			var n := PlantBuild.noise3(Vector3(x * 0.07, 3.0, z * 0.07)) + 0.6 * PlantBuild.noise3(Vector3(x * 0.23, 11.0, z * 0.23))
			var wet := clampf(-n * 1.8 + 0.3, 0.0, 1.0) * (1.0 - 0.6 * smoothstep(R_CLEAR, R_EDGE + 10.0, rr))
			var moss := 0.2 + 0.8 * smoothstep(R_CLEAR - 6.0, R_EDGE, rr)
			var shade := 0.85 * smoothstep(R_EDGE + 8.0, 75.0, rr)
			g.col.append(Color(wet, moss, shade, 1.0))
	for j in seg:
		_tri_up(g, 0, 1 + j, 1 + (j + 1) % seg)
	var solid_tris := 0
	for i in range(1, radii.size() - 1):
		var o0 := 1 + (i - 1) * seg
		var o1 := o0 + seg
		for j in seg:
			var a := o0 + j
			var b := o0 + (j + 1) % seg
			var c := o1 + j
			var d := o1 + (j + 1) % seg
			_tri_up(g, a, c, b)
			_tri_up(g, b, c, d)
		if radii[i + 1] <= 44.0:
			solid_tris = g.idx.size()
	g.smooth()
	var tris := PackedVector3Array()
	tris.resize(solid_tris)
	for i in solid_tris:
		tris[i] = g.pos[g.idx[i]]
	world.add_mesh(tris, "floor")
	world.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": 120.0, "hz": 120.0, "bottom": -8.0, "top": -3.0, "tag": "floor"})      # (a net under it all)
	_mesh(g, _m["ground"], false)


# ---- the trees --------------------------------------------------------------------------------------------------------------------------------------------------------

func _foot(x: float, z: float) -> Vector3:
	return Vector3(x, ground_y(x, z), z)


## inside the sun's shaft (or so close a leaf clump would hang into it): no bough grows here
func _in_shaft(p: Vector3) -> bool:
	var axis := Vector2(_sun.x, _sun.z) * (p.y / _sun.y)
	return p.y > 5.0 and Vector2(p.x, p.z).distance_to(axis) < GAP_R + 4.5


func _trees() -> void:
	var bark := PlantBuild.Geo.new()
	var near: Array[Transform3D] = []
	var far: Array[Transform3D] = []
	var hangs := PackedVector3Array()
	var gaze := atan2(_sun.x, _sun.z)      # the sun's side: no bough crosses the shaft
	var giant_feet: Array[Vector3] = []
	for i in GIANTS.size():
		var gd: Array = GIANTS[i]
		var ya: float = gd[0]
		var dist: float = gd[1]
		var foot := _foot(sin(ya) * dist, cos(ya) * dist)
		var h: float = gd[3]
		var boughs: Array = []
		var inward := ya + PI
		if i == 0:      # the Dervish's bough: right over where it drops
			var to := Vector2(BOSS.x - foot.x, BOSS.y - foot.z)
			boughs.append({"yaw": atan2(to.x, to.y), "len": to.length() - 1.5, "y": 16.5, "rise": 0.2})
		elif absf(wrapf(ya - gaze, -PI, PI)) > 0.5:
			var off := 0.0 if absf(wrapf(ya - gaze, -PI, PI)) > 0.9 else -0.45 * signf(wrapf(ya - gaze, -PI, PI))
			boughs.append({"yaw": inward + off + _rng.randf_range(-0.2, 0.2), "len": dist - _rng.randf_range(9.0, 12.0), "y": h * _rng.randf_range(0.58, 0.68), "rise": 0.16})
		for k in 2:
			boughs.append({"yaw": ya + _rng.randf_range(-1.4, 1.4) + (PI * 0.5 if k == 0 else -PI * 0.5), "len": _rng.randf_range(8.0, 12.0), "y": h * _rng.randf_range(0.6, 0.78)})
		var T := JungleFlora.tree(foot, h, gd[2], _rng, {"fins": 6, "boughs": boughs, "keep_out": _in_shaft}, ground_y)
		_add_tree(T, bark, near, hangs)
		giant_feet.append(foot)
	for i in 13:
		var ya := TAU * i / 13.0 + _rng.randf_range(-0.15, 0.15)
		var dist := _rng.randf_range(34.0, 40.0)
		var h := _rng.randf_range(28.0, 34.0)
		var boughs: Array = []
		for k in 2:
			boughs.append({"yaw": _rng.randf() * TAU, "len": _rng.randf_range(7.0, 11.0), "y": h * _rng.randf_range(0.62, 0.8)})
		var T := JungleFlora.tree(_foot(sin(ya) * dist, cos(ya) * dist), h, _rng.randf_range(1.2, 1.8), _rng, {"fins": 5, "boughs": boughs, "keep_out": _in_shaft}, ground_y)
		_add_tree(T, bark, near, hangs)
	for i in 26:
		var ya := TAU * i / 26.0 + _rng.randf_range(-0.1, 0.1)
		var dist := _rng.randf_range(46.0, 85.0)
		var h := _rng.randf_range(30.0, 42.0)
		var T := JungleFlora.tree(_foot(sin(ya) * dist, cos(ya) * dist), h, _rng.randf_range(1.1, 2.2), _rng, {"fins": 0, "crown": 1, "keep_out": _in_shaft, "boughs": [{"yaw": _rng.randf() * TAU, "len": _rng.randf_range(7.0, 10.0)}]}, ground_y)
		_add_tree(T, bark, far, PackedVector3Array())
	# lianas slung between neighbouring giants
	var lianas := PlantBuild.Geo.new()
	for i in giant_feet.size():
		var a := giant_feet[i]
		var b := giant_feet[(i + 1) % giant_feet.size()]
		var ra := _trunk_r_at(a)
		var rb := _trunk_r_at(b)
		var ab := (b - a).normalized()
		lianas.merge(JungleFlora.liana(a + ab * ra + Vector3.UP * _rng.randf_range(9.0, 15.0), b - ab * rb + Vector3.UP * _rng.randf_range(9.0, 15.0), _rng.randf_range(3.0, 6.0), _rng))
	bark.merge(lianas)
	_mesh(bark, _m["bark"])
	_instances(JungleFlora.clump(_rng).mesh(_m["leaf"]), near, _tints(near.size(), 0.18), true)
	_instances(_lite_clump().mesh(_m["leaf"]), far, _tints(far.size(), 0.25), true)
	# tree ferns between the giants, at the clearing's edge
	var tf_trunks := PlantBuild.Geo.new()
	var crowns: Array[Transform3D] = []
	var crown_g: PlantBuild.Geo = null
	for i in GIANTS.size():
		var gd: Array = GIANTS[i]
		var ya: float = float(gd[0]) + _rng.randf_range(0.3, 0.5)
		var dist := _rng.randf_range(18.0, 21.5)
		var foot := _foot(sin(ya) * dist, cos(ya) * dist)
		if Vector2(foot.x - float(SPAWN.x), foot.z - float(SPAWN.z)).length() < 4.0:
			continue
		var F := JungleFlora.tree_fern(_rng, _rng.randf_range(3.5, 6.0))
		tf_trunks.merge(F.trunk, Transform3D(Basis.IDENTITY, foot))
		if crown_g == null:
			crown_g = F.crown
		crowns.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.15)), foot + F.top))
		world.add({"kind": "disc", "cx": foot.x, "cz": foot.z, "r": 0.3, "bottom": foot.y - 2.0, "top": foot.y + F.top.y, "tag": "wall"})
		_trunks.append(Vector3(foot.x, foot.z, 0.5))
	_mesh(tf_trunks, _m["wood"])
	_instances(crown_g.mesh(_m["fern"]), crowns, _tints(crowns.size(), 0.15), true)
	_vines(hangs)


func _trunk_r_at(foot: Vector3) -> float:
	for t: Vector3 in _trunks:
		if absf(t.x - foot.x) < 0.01 and absf(t.y - foot.z) < 0.01:
			return t.z
	return 1.5


func _add_tree(T: JungleFlora.Giant, bark: PlantBuild.Geo, clumps: Array[Transform3D], hangs: PackedVector3Array) -> void:
	bark.merge(T.bark)
	clumps.append_array(T.clumps)
	hangs.append_array(T.hangs)
	_trunks.append(Vector3(T.foot.x, T.foot.z, T.foot_r))
	if T.foot.length() < 50.0:
		world.add({"kind": "disc", "cx": T.foot.x, "cz": T.foot.z, "r": T.foot_r, "bottom": T.foot.y - 2.0, "top": T.foot.y + T.height, "tag": "wall"})
		if not T.hulls.is_empty():
			world.add_convex(T.hulls, "wall")


## the far trees' clumps: fewer, plainer leaves (only seen through haze)
func _lite_clump() -> PlantBuild.Geo:
	var g := PlantBuild.Geo.new()
	for i in 10:
		var u := i / 10.0
		var b := Basis(Vector3.UP, i * 2.39996) * Basis(Vector3.RIGHT, lerpf(-0.4, 1.1, sqrt(u)))
		g.merge(PlantBuild.leaf(2.6, 1.3, 1.0, 0.25, 0x123f33, 0x2f7a52, 4, 1), Transform3D(b, Vector3.ZERO))
	return g


## instance tints round white: a little lighter or darker, a little bluer or yellower
func _tints(n: int, k: float) -> PackedColorArray:
	var out := PackedColorArray()
	for i in n:
		var l := 1.0 + _rng.randf_range(-k, k)
		var hue := _rng.randf_range(-k, k) * 0.6
		out.append(Color(l * (1.0 + hue * 0.5), l, l * (1.0 - hue), 1.0))
	return out


## The canopy: three leaf ceilings, their gaps lined up along the sun so its light falls through all three into the middle of the clearing
func _canopy() -> void:
	var covers := [0.5, 0.6, 0.72]
	for i in CANOPY.size():
		var h: float = CANOPY[i]
		var gap := Vector2(_sun.x, _sun.z) * (h / _sun.y)
		var pm := PlaneMesh.new()
		pm.size = Vector2(800.0, 800.0)
		pm.subdivide_width = 110
		pm.subdivide_depth = 110
		var mat := _shader_mat("res://levels/jungle_test/jungle_canopy.gdshader", {"clump_tex": _clump_noise, "leaf_tex": _leaf_cells, "cover": covers[i], "gap": gap, "gap_r": GAP_R + i * 1.2,
			"clump_scale": 0.022 + i * 0.006, "leaf_scale": 0.3 - i * 0.05, "droop": 0.3 + i * 0.1})
		pm.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.position = Vector3(0.0, h, 0.0)
		add_child(mi)


# ---- what grows on the floor -------------------------------------------------------------------------------------------------------------------------------------------

func _clear_of_trunks(x: float, z: float, pad: float) -> bool:
	for t: Vector3 in _trunks:
		if Vector2(x - t.x, z - t.y).length() < t.z + pad:
			return false
	return true


## a point on the floor between radii r0 and r1 (denser outward), clear of the trunks and the spawn
func _scatter(r0: float, r1: float, pad: float) -> Vector3:
	for tries in 12:
		var a := _rng.randf() * TAU
		var r := lerpf(r0, r1, sqrt(_rng.randf()))
		var x := sin(a) * r
		var z := cos(a) * r
		if _clear_of_trunks(x, z, pad) and Vector2(x - float(SPAWN.x), z - float(SPAWN.z)).length() > 2.5:
			return _foot(x, z)
	return Vector3(INF, 0.0, 0.0)


func _place(p: Vector3, s: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p - Vector3.UP * 0.05)


func _undergrowth() -> void:
	var ferns: Array[Transform3D] = []
	for i in 430:
		var p := _scatter(17.0, 42.0, 0.6)
		if p.x != INF:
			ferns.append(_place(p, _rng.randf_range(0.8, 1.5)))
	for i in 45:      # small ones in the clearing
		var p := _scatter(6.0, 18.0, 0.4)
		if p.x != INF:
			ferns.append(_place(p, _rng.randf_range(0.4, 0.7)))
	var fern_mesh := JungleFlora.fern(_rng).mesh(_m["fern"])
	var teal := JungleFlora.fern(_rng, 0x123a40, 0x5ac8c0).mesh(_m["fern"])
	var half := ferns.size() / 2
	_instances(fern_mesh, ferns.slice(0, half), _tints(half, 0.2), false)
	_instances(teal, ferns.slice(half), _tints(ferns.size() - half, 0.2), false)
	var broad: Array[Transform3D] = []
	for i in 80:
		var p := _scatter(18.0, 36.0, 0.9)
		if p.x != INF:
			broad.append(_place(p, _rng.randf_range(0.9, 1.6)))
	_instances(JungleFlora.broadleaf(_rng).mesh(_m["fern"]), broad, _tints(broad.size(), 0.15), false)
	# leaf litter
	var litter: Array[Transform3D] = []
	var lt := PackedColorArray()
	for i in 1600:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 34.0
		var x := sin(a) * r
		var z := cos(a) * r
		litter.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)), Vector3(x, ground_y(x, z) + 0.03, z)))
		var c := [Color(1.0, 0.75, 0.5), Color(0.8, 0.85, 0.5), Color(0.6, 0.5, 0.35), Color(1.1, 0.6, 0.35)][_rng.randi() % 4] as Color
		lt.append(c * _rng.randf_range(0.7, 1.1))
	_instances(PlantBuild.leaf(0.24, 0.13, 0.4, 0.25, 0x6a4a2a, 0x8a6a3a, 3, 1).mesh(_m["litter"]), litter, lt, false)


func _flowers() -> void:
	var lan: Array[Transform3D] = []
	var stars: Array[Transform3D] = []
	var shrooms: Array[Transform3D] = []
	# patches of lantern flowers round the edge and in the roots, star flowers spilling out from them into the clearing
	for i in 13:
		var c := _scatter(16.0, 27.0, 1.2)
		if c.x == INF:
			continue
		_glows.append(c)
		for k in _rng.randi_range(3, 5):
			var p := _foot(c.x + _rng.randf_range(-1.6, 1.6), c.z + _rng.randf_range(-1.6, 1.6))
			if _clear_of_trunks(p.x, p.z, 0.3):
				lan.append(_place(p, _rng.randf_range(0.8, 1.3)))
		for k in _rng.randi_range(6, 12):
			var p := _foot(c.x + _rng.randf_range(-3.5, 3.5), c.z + _rng.randf_range(-3.5, 3.5))
			if _clear_of_trunks(p.x, p.z, 0.2):
				stars.append(_place(p, _rng.randf_range(0.8, 1.4)))
	# mushrooms at the trunks' feet
	for t: Vector3 in _trunks:
		if Vector2(t.x, t.y).length() > 42.0:
			continue
		for k in _rng.randi_range(1, 3):
			var a := _rng.randf() * TAU
			var r := t.z + _rng.randf_range(0.3, 1.6)
			shrooms.append(_place(_foot(t.x + sin(a) * r, t.y + cos(a) * r), _rng.randf_range(0.8, 1.8)))
	var L := JungleFlora.lantern(_rng)
	_instances(_surfaces([[L[0], _m["fern"]], [L[1], _m["glow"]]]), lan, _tints(lan.size(), 0.1), false)
	var S := JungleFlora.star(_rng)
	_instances(_surfaces([[S[0], _m["fern"]], [S[1], _m["glow"]]]), stars, _tints(stars.size(), 0.1), false)
	var M := JungleFlora.mushrooms(_rng)
	_instances(_surfaces([[M[0], _m["fern"]], [M[1], _m["shroom"]]]), shrooms, PackedColorArray(), false)


func _vines(hangs: PackedVector3Array) -> void:
	var plant := PlantBuild.Geo.new()
	var glow := PlantBuild.Geo.new()
	var bulbs := [0x5ff4ff, 0xff5ad0, 0xb0ff5a]
	for p: Vector3 in hangs:
		var floor_y := ground_y(p.x, p.z)
		var room := p.y - floor_y - 3.0      # its end stays well over your head
		if room < 3.0:
			continue
		JungleFlora.vine(p, _rng.randf_range(minf(4.0, room), room), _rng, plant, glow, bulbs[_rng.randi() % bulbs.size()])
	_mesh(plant, _m["vine"], false)
	_mesh(glow, _m["glow_vine"], false)


## a few rocks and a fallen log round the clearing's edge: cover from the sap, things for the whirl to glance off. Nothing inside 14 m, where it burrows up.
func _props() -> void:
	var rocks := PlantBuild.Geo.new()
	for d: Array in [[-14.5, 9.5, 1.6], [15.8, -5.0, 1.25], [6.0, -16.8, 0.9], [-9.5, 15.5, 1.1]]:
		var at := _foot(d[0], d[1]) - Vector3.UP * 0.2
		var g := JungleFlora.rock(d[2], _rng).moved(Transform3D(Basis.IDENTITY, at))
		rocks.merge(g)
		var hull: Array[PackedVector3Array] = [g.pos]
		world.add_convex(hull, "wall")
		_trunks.append(Vector3(at.x, at.z, float(d[2]) * 1.2))
	_mesh(rocks, _m["rock"])
	var hulls: Array[PackedVector3Array] = []
	var a := _foot(-18.5, -5.0) + Vector3(0.0, 0.45, 0.0)
	var b := _foot(-12.5, -14.0) + Vector3(0.0, 0.55, 0.0)
	var log_g := JungleFlora.fallen_log(PackedVector3Array([a, a.lerp(b, 0.5) + Vector3(0.4, 0.1, 0.3), b]), 0.75, _rng, hulls)
	_mesh(log_g, _m["wood"])
	world.add_convex(hulls, "wall")
	for i in 5:
		_trunks.append(Vector3(lerpf(a.x, b.x, i / 4.0), lerpf(a.z, b.z, i / 4.0), 0.9))


## the edge nobody walks past: a ring of invisible walls behind the trunks (the camera passes through it)
func _edge() -> void:
	var n := 40
	var half := PI * R_EDGE / n + 0.3
	for i in n:
		var a := TAU * i / n
		world.add({"kind": "box", "cx": sin(a) * R_EDGE, "cz": cos(a) * R_EDGE, "hx": half, "hz": 0.5, "yaw": a, "bottom": -5.0, "top": 30.0, "tag": "wall", "no_cam": true})


func _lights() -> void:
	var bounce := OmniLight3D.new()      # the sunlit floor lights the clearing back up a little
	bounce.position = Vector3(0.0, 2.5, 0.0)
	bounce.light_color = Color("ffd98a")
	bounce.light_energy = 2.2
	bounce.omni_range = 22.0
	bounce.omni_attenuation = 1.2
	bounce.light_specular = 0.1
	add_child(bounce)
	var cols := [Color("5ff0ff"), Color("ff5ad0"), Color("7affb0")]
	for i in _glows.size():
		var l := OmniLight3D.new()
		l.position = _glows[i] + Vector3.UP * 0.9
		l.light_color = cols[i % cols.size()]
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.omni_attenuation = 1.5
		l.light_volumetric_fog_energy = 1.5
		add_child(l)


## dust drifting in the shaft, fireflies round the edge
func _motes() -> void:
	var y := _sun
	var x := y.cross(Vector3.FORWARD).normalized()
	var z := x.cross(y)
	var mid := _sun * (10.0 / _sun.y)
	_particles(Transform3D(Basis(x, y, z), mid), Vector3(5.5, 12.5, 5.5), 420, 0.05, Color(2.2, 1.9, 1.3), 9.0, false)
	_particles(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.2, 0.0)), Vector3(26.0, 1.8, 26.0), 90, 0.09, Color(0.9, 2.6, 1.6), 7.0, true)


func _particles(xf: Transform3D, ext: Vector3, n: int, size: float, col: Color, life: float, blink: bool) -> void:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.preprocess = life
	p.transform = xf
	p.visibility_aabb = AABB(-ext - Vector3.ONE * 3.0, (ext + Vector3.ONE * 3.0) * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.gravity = Vector3(0.0, -0.01, 0.0)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.25 if blink else 0.1
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.12 if blink else 0.06
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color = col
	var gr := Gradient.new()
	if blink:
		gr.offsets = PackedFloat32Array([0.0, 0.1, 0.2, 0.45, 0.55, 0.65, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	else:
		gr.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = gr
	pm.color_ramp = gt
	p.process_material = pm
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 64
	dot.height = 64
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	dg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	dot.gradient = dg
	var q := QuadMesh.new()
	q.size = Vector2(size, size) * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
