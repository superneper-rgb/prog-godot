class_name OmMarks
extends RefCounted
## OMNISPHERE landmarks' runtime (JS landmark.js; the art is exported): the Omnisphere's core that flares on every Draw and runs wild once Juniper is free, the equator ring that turns and later falls, the shockwave pulses, the plates shed off the cage, the two lower siphon lines Juniper tears out, the skyline coming down (stacks topple, cooling towers drop, HQ goes floor by floor), and the end: 1.8 s of implosion, then the blast (fireball, shell, flat ring, thrown cage, mushroom cloud).

const OMNI := Vector3(-340, 168, -310)
const ORAD := 66.0
const FIRE := "shader_type spatial;\nrender_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;\nuniform float uHeat = 1.0;\nuniform float uOpacity = 1.0;\nuniform float uFreq = 0.02;\nvarying vec3 vW;\nfloat h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }\nfloat n3(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);\nreturn mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y), mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z); }\nvoid vertex() { vW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\nvec3 q = vW * uFreq + vec3(0., -TIME * .55, TIME * .2); float n = n3(q) * .55 + n3(q * 2.1 + 7.) * .3 + n3(q * 4.3 + 13.) * .15;\nfloat fr = abs(dot(normalize(NORMAL), normalize(VIEW))), heat = clamp(uHeat * (.45 + .75 * n) * (.35 + .65 * fr), 0., 1.);\nvec3 c = mix(vec3(.32, .05, .01), vec3(1., .42, .07), smoothstep(.12, .55, heat)); c = mix(c, vec3(1., .93, .74), smoothstep(.62, .98, heat));\nfloat a = uOpacity * smoothstep(.0, .45, fr) * (.5 + .5 * n); ALBEDO = c * a; }\n"


class SkyP:
	var name := ""
	var kind := ""
	var g: Node3D
	var h := 0.0
	var x := 0.0
	var z := 0.0
	var t := -1.0
	var src := -1
	var axis := Vector3.RIGHT
	var dir := Vector3.RIGHT
	var booms := 0
	var landed := false


class LineP:
	var g: Node3D
	var home := Vector3.ZERO
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var t := -1.0


class Line:
	var whole: Node3D
	var pieces: Array[LineP] = []
	var ripped := false


class Wave:
	var shell: MeshInstance3D
	var flat: MeshInstance3D
	var t := 0.0
	var dur := 2.8
	var max_r := 900.0
	var hit := false
	var kick := 1.8


var lv: ExportedLevel
var root: Node3D
var sphere_g: Node3D
var core: Node3D
var core_mat: Material
var core_halo: MeshInstance3D
var ring: Node3D
var ring_w := .05
var ring_fall := 0.0
var ring_hit := false
var west_panel: Node3D
var arm_g: Node3D
var sky := {}
var lines: Array[Line] = []
var puff_alive := PackedFloat32Array()
var puff_mat: Material
var bolts: OmRibbon
var bolt_t := 0.0
var flare_v := 0.0
var dark := false
var is_unstable := false
var collapsing := false
var shed_t := 0.0
var boom_t := 0.0
var fx_objs: Array[Node] = []
var waves: Array[Wave] = []
var shed_list: Array = []
var det: Variant = null
var dust_list: Array = []
var cage_pts := PackedVector3Array()
var unit_ball: SphereMesh
var unit_ring: ArrayMesh
var plate_mesh: BoxMesh
var plate_mat: StandardMaterial3D
var on_ring := Callable()
var on_wave := Callable()
var smoke_shader: Shader
var fire_shader: Shader
var clock := 0.0


func _init(p_lv: ExportedLevel) -> void:
	lv = p_lv
	root = Node3D.new()
	root.name = "OmMarks"
	lv.add_child(root)
	sphere_g = VhKit.one(lv, "om-sphere")
	core = VhKit.one(lv, "om-core")
	var cm := VhKit.meshes(core)
	if not cm.is_empty():
		core_mat = cm[0].get_active_material(0)
	core_halo = MsKit.sprite8(root, 0x6dffb8, .55, ORAD * 3.6)
	core_halo.position = OMNI
	core_halo.extra_cull_margin = 2000.0
	ring = VhKit.one(lv, "om-ring")
	west_panel = VhKit.one(lv, "om-west-panel")
	arm_g = VhKit.one(lv, "om-arm")
	var specs := [["hq", "hq", -305.0, -150.0, 150.0, -1], ["cool0", "cool", -420.0, -90.0, 95.0, 0], ["cool1", "cool", -560.0, -260.0, 110.0, 1], ["stack0", "stack", -120.0, -330.0, 120.0, 2], ["stack1", "stack", -95.0, -300.0, 100.0, 3], ["stack2", "stack", -290.0, -5.0, 90.0, 4]]
	for q: Array in specs:
		var p := SkyP.new()
		p.name = q[0]
		p.kind = q[1]
		p.x = q[2]
		p.z = q[3]
		p.h = q[4]
		p.src = q[5]
		p.g = VhKit.one(lv, "om-sky-" + p.name)
		sky[p.name] = p
	for k in 2:
		var L := Line.new()
		L.whole = VhKit.one(lv, "om-line-%d" % k)
		var i := 0
		while true:
			var nodes: Array = lv.node_named("om-line-%d-p-%d" % [k, i])
			if nodes.is_empty():
				break
			var p := LineP.new()
			p.g = nodes[0]
			p.g.visible = false
			p.home = p.g.position
			L.pieces.append(p)
			i += 1
		lines.append(L)
	puff_alive.resize(8)
	puff_alive.fill(1.0)
	var pn: Array = lv.node_named("om-puffs")
	if not pn.is_empty():
		var pm := VhKit.meshes(pn[0])
		if not pm.is_empty():
			puff_mat = pm[0].get_active_material(0)
	bolts = OmRibbon.new(root, 0xc8fff0)
	unit_ball = MsKit.sphere(1.0, 40, 24)
	unit_ring = MsKit.ring(.93, 1.0, 128)
	plate_mesh = BoxMesh.new()
	plate_mesh.size = Vector3(11.0, .9, 9.0)
	plate_mat = MsKit.std(0x14161a, .7, .3, true)
	var cg := IcosphereSeed.points(ORAD)
	cage_pts = cg
	fire_shader = Shader.new()
	fire_shader.code = FIRE
	smoke_shader = load("res://levels/visiting_hours/vh_puff.gdshader")


## the geodesic cage's joints, where the breakdown's explosions and shed plates come from (JS the first vertex of each icosahedron edge; a spread of points on the same shell does the same job)
class IcosphereSeed:
	static func points(r: float) -> PackedVector3Array:
		var out := PackedVector3Array()
		var n := 162
		var ga := PI * (3.0 - sqrt(5.0))
		for i in n:
			var y := 1.0 - (i + .5) / n * 2.0
			var rr := sqrt(maxf(0.0, 1.0 - y * y))
			out.append(Vector3(cos(i * ga) * rr, y, sin(i * ga) * rr) * r)
		return out


func _own(n: Node3D) -> Node3D:
	root.add_child(n)
	fx_objs.append(n)
	return n


func _add_mesh(mesh: Mesh, hex: int, op: float) -> MeshInstance3D:
	var m := MsKit.glow(root, mesh, 0, hex, op)
	m.extra_cull_margin = 4000.0
	fx_objs.append(m)
	return m


func _smoke(hex: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MsKit.quad()
	var m := ShaderMaterial.new()
	m.shader = smoke_shader
	mi.material_override = m
	mi.set_instance_shader_parameter(&"col", Vector3(MsKit.lin(hex).r, MsKit.lin(hex).g, MsKit.lin(hex).b))
	mi.set_instance_shader_parameter(&"opacity", 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4000.0
	root.add_child(mi)
	fx_objs.append(mi)
	return mi


static func _sm(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## an explosion far off: the fireball without the camera kick the FX pool gives every blast (shake: what this one is allowed to add)
func far_boom(p: Vector3, r: float, shake: float = 0.0) -> void:
	var f: Variant = Game.fx
	if f == null:
		return
	var s0: float = f.shake
	f.explosion(p, r)
	f.shake = maxf(s0, shake)


## the sphere drinks on every Draw: k = 0..1
func flare(k: float) -> void:
	if not dark:
		flare_v = maxf(flare_v, k)


## Juniper is free and nothing is feeding it: the core runs wild (it flickers and spits lightning, the cage pops) until the end
func unstable() -> void:
	dark = false
	is_unstable = true
	core.visible = true
	core_halo.visible = true


## one shockwave out of the core (camera kick as it passes)
func pulse(o: Dictionary = {}) -> void:
	var w := Wave.new()
	w.shell = _add_mesh(unit_ball, 0xb8fff0, .32)
	w.flat = _add_mesh(unit_ring, 0xd8fff4, .7)
	w.shell.position = OMNI
	w.flat.position = Vector3(OMNI.x, float(o.get("y", 33.0)), OMNI.z)
	w.flat.rotation.x = -PI / 2.0
	w.dur = o.get("dur", 2.8)
	w.max_r = o.get("max", 900.0)
	w.kick = o.get("kick", 1.8)
	waves.append(w)
	far_boom(OMNI, 40.0)
	flare_v = 3.0


## the containment is gone (summit, the last emitter): the cage comes apart (plates peeling off, the cage popping) but the ring stays up for now
func breakup() -> void:
	unstable()
	collapsing = true
	pulse({"dur": 2.4, "max": 800.0, "kick": 2.2})


## the ring lets go (the ending cutscene)
func drop_ring() -> void:
	if ring_fall <= 0.0:
		ring_fall = 1e-3


var ring_down: bool:
	get:
		return ring_fall >= 1.0
var ring_y: float:
	get:
		return ring.position.y
var ring_falling: bool:
	get:
		return ring_fall > 0.0 and ring_fall < 1.0
var det_t: float:
	get:
		return float(det.t) if det != null else -1.0


## the end: implosion, then the blast (the cutscene drives the camera)
func detonate() -> void:
	if det != null:
		return
	det = {"t": 0.0, "blown": false, "chunks": [], "smoke": [], "puffs": [], "cap": [], "stem": []}
	is_unstable = true


func _fire_mat(heat: float, freq: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = fire_shader
	m.set_shader_parameter(&"uHeat", heat)
	m.set_shader_parameter(&"uFreq", freq)
	return m


func _fire_ball(mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = unit_ball
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4000.0
	mi.position = OMNI
	root.add_child(mi)
	fx_objs.append(mi)
	return mi


func _blast() -> void:
	det.blown = true
	sphere_g.visible = false
	core.visible = false
	ring.visible = false
	bolts.node.visible = false
	collapsing = false
	arm_g.visible = false      # (the south-west arm is its own group)
	det.ball = _fire_ball(_fire_mat(1.25, .02))
	det.fire = _fire_ball(_fire_mat(.85, .012))
	det.shell = _add_mesh(unit_ball, 0xcff8ff, .5)
	det.shell.position = OMNI
	det.flat = _add_mesh(unit_ring, 0xfff0d8, .95)
	det.flat.rotation.x = -PI / 2.0
	det.flat.position = Vector3(OMNI.x, 6.0, OMNI.z)
	var light := OmniLight3D.new()
	light.light_color = MsKit.srgb(0xffd0a0)
	light.omni_range = 2400.0
	light.light_energy = 0.0
	light.position = OMNI
	root.add_child(light)
	fx_objs.append(light)
	det.light = light
	var mat_a := MsKit.std(0x3a3f46, .8, .4)
	var mat_b := MsKit.std(0xa02818, .8, .2)
	for k in 26:      # the cage, thrown out across the caldera
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0 + randf() * 7.0, 1.2 + randf() * 2.0, 2.0 + randf() * 9.0)
		var d := Vector3(randf() - .5, randf() * .8 - .1, randf() - .5).normalized()
		var m := MsKit.part(root, bm, mat_a if k % 3 != 0 else mat_b, OMNI + d * (ORAD * .8))
		fx_objs.append(m)
		det.chunks.append({"m": m, "v": d * (40.0 + randf() * 50.0) + Vector3(0, 18, 0), "w": Vector3(randf() - .5, randf() - .5, randf() - .5) * 4.0})
	for k in 16:
		var sp := _smoke(0x2a2220)
		sp.position = Vector3(OMNI.x + (randf() - .5) * 60.0, OMNI.y - 40.0 + k * 18.0, OMNI.z + (randf() - .5) * 60.0)
		sp.scale = Vector3.ONE * 60.0
		det.smoke.append({"sp": sp, "k": k})
	# the mushroom: a stem of smoke up out of the crater and a cap that rolls outward as it climbs, its underside lit by the fire below
	for _k in 30:      # fire licking off the front
		var sp := MsKit.sprite8(root, 0xff8a30, 0.0, 1.0)
		sp.extra_cull_margin = 4000.0
		fx_objs.append(sp)
		det.puffs.append({"sp": sp, "d": Vector3(randf() - .5, randf() * .9 - .2, randf() - .5).normalized(), "k": .78 + randf() * .3, "s": .35 + randf() * .3, "ph": randf() * 6.0})
	for k in 18:
		det.cap.append({"sp": _smoke(0x3a2a24), "a": k / 18.0 * TAU + randf() * .3, "r0": .3 + randf() * .4, "lift": randf() * 40.0, "k": k})
	for k in 10:
		det.stem.append({"sp": _smoke(0x4a3028), "k": k})


func _update_det(dt: float) -> void:
	det.t = float(det.t) + dt
	var T: float = det.t
	if not det.blown:
		var u := _sm(T / 1.8)
		core.scale = Vector3.ONE * (1.0 - .88 * u)
		sphere_g.scale = Vector3.ONE * (1.0 - .09 * u)
		flare_v = 3.0
		core_halo.scale = Vector3.ONE * (ORAD * 3.6 * (1.0 + u * 1.4))
		bolt_t = 0.0
		if T >= 1.8:
			_blast()
		return
	var b := T - 1.8
	(det.ball as MeshInstance3D).scale = Vector3.ONE * maxf(.01, ORAD * 2.1 * _sm(b / .5))
	var bm: ShaderMaterial = det.ball.material_override
	bm.set_shader_parameter(&"uOpacity", 1.0 - _sm((b - .4) / 2.2))
	bm.set_shader_parameter(&"uHeat", 1.3 - minf(.5, b * .3))
	var fire_r := ORAD * (1.0 + 2.9 * _sm(b / 2.2)) * (1.0 + b * .04)      # ~260 m out: it rolls after the lifter, which is ~330 m out by then
	var fire: MeshInstance3D = det.fire
	fire.scale = Vector3.ONE * fire_r
	fire.position.y = OMNI.y + maxf(0.0, b - 1.0) * 10.0
	var fm: ShaderMaterial = fire.material_override
	fm.set_shader_parameter(&"uOpacity", .95 * (1.0 - _sm((b - 2.0) / 7.0)))
	fm.set_shader_parameter(&"uHeat", maxf(.35, 1.0 - b * .07))
	for p: Dictionary in det.puffs:
		var u := _sm((b - .15) / .8) * (1.0 - _sm((b - 3.0) / 6.0))
		var sp: MeshInstance3D = p.sp
		sp.position = fire.position + (p.d as Vector3) * (fire_r * float(p.k))
		sp.scale = Vector3.ONE * (fire_r * float(p.s) * (1.0 + .15 * sin(b * 2.0 + float(p.ph))))
		MsKit.tint(sp, Color(1.0, .45 + .25 * maxf(0.0, 1.0 - b / 4.0), .14), .55 * u)
	(det.shell as MeshInstance3D).scale = Vector3.ONE * (20.0 + 950.0 * _sm(b / 3.0))
	MsKit.opa(det.shell, .5 * (1.0 - _sm(b / 3.0)))
	var fr := 1.0 - pow(1.0 - minf(1.0, b / 4.5), 2.0)
	(det.flat as MeshInstance3D).scale = Vector3.ONE * (20.0 + 1500.0 * fr)
	MsKit.opa(det.flat, .95 * (1.0 - _sm((b - 1.0) / 3.5)))
	(det.light as OmniLight3D).light_energy = 900.0 * pow(maxf(0.0, 1.0 - b / 3.5), 2.0) / PI / 40.0      # (JS candela on a 2400 m range: Godot's falloff is its own, this level matches by eye)
	core_halo.scale = Vector3.ONE * (ORAD * 3.6 * (2.4 + b * 1.5))
	MsKit.opa(core_halo, maxf(0.0, 1.0 - b / 2.5))
	if b < 3.2:
		boom_t -= dt
		if boom_t <= 0.0:
			boom_t = .1
			far_boom(Vector3(OMNI.x + (randf() - .5) * 220.0, OMNI.y - 60.0 + randf() * 200.0, OMNI.z + (randf() - .5) * 220.0), 16.0 + randf() * 14.0)
	for c: Dictionary in det.chunks:
		var m: MeshInstance3D = c.m
		if not m.visible:
			continue
		c.v = (c.v as Vector3) + Vector3(0, -18.0 * dt, 0)
		m.position += (c.v as Vector3) * dt
		m.rotation.x += float(c.w.x) * dt
		m.rotation.y += float(c.w.y) * dt
		if m.position.y < 1.0:
			m.visible = false
			if randf() < .4:
				far_boom(Vector3(m.position.x, 3.0, m.position.z), 9.0)
	for s: Dictionary in det.smoke:
		var u := _sm((b - 1.2 - float(s.k) * .08) / 5.0)
		var sp: MeshInstance3D = s.sp
		sp.set_instance_shader_parameter(&"opacity", .75 * u * (1.0 - _sm((b - 40.0) / 10.0)))
		sp.position.y += dt * (6.0 + float(s.k) * .6)
		sp.scale = Vector3.ONE * (60.0 + u * (90.0 + float(s.k) * 6.0))
	var u2 := _sm((b - 1.5) / 9.0)
	var cap_y := OMNI.y + 40.0 + 1080.0 * (1.0 - pow(1.0 - clampf((b - 1.5) / 16.0, 0.0, 1.0), 2.0))      # it climbs well over the crater's rim
	var fade := 1.0 - _sm((b - 40.0) / 14.0)
	for c: Dictionary in det.cap:
		var r := (70.0 + 300.0 * u2) * (.55 + float(c.r0))
		var a := float(c.a) + b * .02
		var sp: MeshInstance3D = c.sp
		sp.position = Vector3(OMNI.x + cos(a) * r, cap_y + float(c.lift) * u2 + sin(float(c.a) * 3.0) * 18.0, OMNI.z + sin(a) * r)
		sp.scale = Vector3.ONE * (130.0 + 330.0 * u2)
		sp.set_instance_shader_parameter(&"opacity", .9 * _sm((b - 1.6) / 1.5) * fade)
		var hot := maxf(.18, 1.0 - b / 12.0)
		sp.set_instance_shader_parameter(&"col", Vector3(.36 + .64 * hot, .22 + .3 * hot, .16 + .06 * hot))
	for s: Dictionary in det.stem:
		var f := (float(s.k) + .5) / (det.stem as Array).size()
		var sp: MeshInstance3D = s.sp
		sp.position = Vector3(OMNI.x + sin(float(s.k) * 2.3 + b * .3) * 14.0, 20.0 + (cap_y - 40.0) * f, OMNI.z + cos(float(s.k) * 1.7 + b * .3) * 14.0)
		sp.scale = Vector3.ONE * (90.0 + 60.0 * u2 * (1.0 - f * .4))
		sp.set_instance_shader_parameter(&"opacity", .8 * _sm((b - 1.8) / 1.5) * fade)
		sp.set_instance_shader_parameter(&"col", Vector3(.3 + .55 * (1.0 - f) * maxf(.25, 1.0 - b / 14.0), .18 + .12 * (1.0 - f), .12))
	# the blast front knocks the skyline over as it reaches each piece
	var front := 20.0 + 1500.0 * fr
	for k: String in sky:
		var p: SkyP = sky[k]
		if p.t < 0.0 and U.hyp(p.x - OMNI.x, p.z - OMNI.z) < front:
			topple(k)


func _dust(x: float, z: float, n: int, size: float) -> void:
	for k in n:
		var sp := _smoke(0x5a4a42)
		var a := float(k) / n * TAU
		sp.position = Vector3(x + cos(a) * size * .4, 6.0, z + sin(a) * size * .4)
		sp.scale = Vector3.ONE * (size * .5)
		dust_list.append({"sp": sp, "t": 0.0, "a": a, "size": size, "x": x, "z": z})


## a skyline piece comes down now ("hq", "stack0..2", "cool0..1")
func topple(name: String) -> void:
	var p: SkyP = sky.get(name)
	if p == null or p.t >= 0.0:
		return
	p.t = 0.0
	p.booms = 0
	if p.src >= 0:
		puff_alive[p.src] = 0.0
		if puff_mat is ShaderMaterial:
			(puff_mat as ShaderMaterial).set_shader_parameter(&"uAlive", puff_alive)
	var d := Vector3(p.x - OMNI.x, 0.0, p.z - OMNI.z).normalized()
	p.axis = Vector3(d.z, 0.0, -d.x)
	p.dir = d


func _update_sky(dt: float) -> void:
	for k: String in sky:
		var p: SkyP = sky[k]
		if p.t < 0.0 or not p.g.visible:
			continue
		p.t += dt
		var t := p.t
		if p.kind == "stack":
			if p.booms < 3 and t > p.booms * .3:
				p.booms += 1
				far_boom(Vector3(p.x, 6.0 + p.booms * 6.0, p.z), 10.0)
			var u := maxf(0.0, t - .9)
			var ang := minf(1.5, .5 * .45 * u * u)
			p.g.quaternion = Quaternion(p.axis, ang)
			if ang >= 1.5:
				if not p.landed:
					p.landed = true
					far_boom(Vector3(p.x + p.dir.x * p.h * .9, 4.0, p.z + p.dir.z * p.h * .9), 26.0, .5)
					_dust(p.x + p.dir.x * p.h * .6, p.z + p.dir.z * p.h * .6, 6, 50.0)
				p.g.position.y -= dt * 5.0
				if p.g.position.y < -14.0:
					p.g.visible = false
		elif p.kind == "cool":
			if p.booms < 6 and t > p.booms * .15:
				var a := p.booms / 6.0 * TAU
				p.booms += 1
				far_boom(Vector3(p.x + cos(a) * 30.0, 8.0, p.z + sin(a) * 30.0), 12.0)
				if p.booms == 1:
					_dust(p.x, p.z, 8, 90.0)
			var u := maxf(0.0, t - .8)
			p.g.position.y = -3.0 - 6.0 * u * u
			var sc := 1.0 - minf(.12, u * .03)
			p.g.scale = Vector3(sc, 1.0, sc)
			p.g.rotation.z = sin(t * 9.0) * .006
			if p.g.position.y < -p.h - 4.0:
				p.g.visible = false
		else:
			if t < 2.6:
				if t > p.booms * .14:
					p.booms += 1
					var a := randf() * TAU
					far_boom(Vector3(p.x + cos(a) * 30.0, 8.0 + t / 2.6 * 140.0, p.z + sin(a) * 30.0), 12.0 + randf() * 6.0)
			else:
				var u := t - 2.6
				if not p.landed:
					p.landed = true
					_dust(p.x, p.z, 10, 110.0)
				p.g.position.y = -3.0 - 3.2 * u * u
				p.g.quaternion = Quaternion(p.axis, minf(.42, u * u * .02))
				if p.g.position.y < -170.0:
					p.g.visible = false
	for i in range(dust_list.size() - 1, -1, -1):
		var d: Dictionary = dust_list[i]
		d.t = float(d.t) + dt
		var u := minf(1.0, float(d.t) / 6.0)
		var sp: MeshInstance3D = d.sp
		var sz: float = d.size
		sp.set_instance_shader_parameter(&"opacity", .7 * _sm(float(d.t) / .6) * (1.0 - _sm((float(d.t) - 8.0) / 6.0)))
		sp.scale = Vector3.ONE * (sz * (.5 + u * 1.3))
		sp.position = Vector3(float(d.x) + cos(float(d.a)) * sz * (.4 + u * .9), 6.0 + u * sz * .35, float(d.z) + sin(float(d.a)) * sz * (.4 + u * .9))
		if float(d.t) > 14.0:
			sp.visible = false
			dust_list.remove_at(i)


func reset_sphere() -> void:
	ring_fall = 0.0
	ring_hit = false
	ring.visible = true
	ring.position.y = OMNI.y
	ring.rotation = Vector3(0.0, ring.rotation.y, 0.0)
	ring_w = .05
	sphere_g.visible = true
	sphere_g.scale = Vector3.ONE
	core.visible = true
	core.scale = Vector3.ONE
	core_halo.visible = true
	core_halo.scale = Vector3.ONE * (ORAD * 3.6)
	is_unstable = false
	collapsing = false
	dark = false
	det = null
	waves.clear()
	shed_list.clear()
	dust_list.clear()
	for o: Node in fx_objs:
		if is_instance_valid(o):
			o.queue_free()
	fx_objs.clear()
	for k: String in sky:
		var p: SkyP = sky[k]
		p.t = -1.0
		p.landed = false
		p.g.visible = true
		p.g.position = Vector3(p.x, -3.0, p.z)
		p.g.quaternion = Quaternion.IDENTITY
		p.g.scale = Vector3.ONE
	for ln in lines:
		ln.ripped = false
		ln.whole.visible = true
		for p in ln.pieces:
			p.g.visible = false
			p.t = -1.0
	puff_alive.fill(1.0)
	if puff_mat is ShaderMaterial:
		(puff_mat as ShaderMaterial).set_shader_parameter(&"uAlive", puff_alive)
	arm_g.visible = true


func relight() -> void:
	dark = false
	core.visible = true
	core_halo.visible = true


## Juniper tears the two lower siphon lines out of the drum: they come down section by section from the drum outward, into the magma (instant: already gone)
func rip_lines(instant: bool = false) -> void:
	for ln in lines:
		if ln.ripped:
			continue
		ln.ripped = true
		ln.whole.visible = false
		for i in ln.pieces.size():
			var p := ln.pieces[i]
			if instant:
				p.g.visible = false
				p.t = -2.0
				continue
			p.g.visible = true
			p.g.position = p.home
			p.g.rotation = Vector3.ZERO
			p.t = -i * .13 - randf() * .05
			p.v = Vector3((randf() - .5) * 5.0, 2.0 + randf() * 3.0, (randf() - .5) * 5.0)
			p.w = Vector3(randf() - .5, randf() - .5, randf() - .5) * 1.6


## the drum's west panel is gone (Juniper's breach) or back
func breach(v: bool = true) -> void:
	west_panel.visible = not v


func _zap(n: int) -> void:
	bolts.clear()
	for _k in n:
		var a := randf() * TAU
		var from := OMNI + Vector3(cos(a) * ORAD, (randf() - .3) * ORAD, sin(a) * ORAD)
		var to: Vector3
		if randf() < .5:
			to = OMNI + Vector3(cos(a + .4) * ORAD * .92, -ORAD * .42, sin(a + .4) * ORAD * .92)
		else:
			to = OMNI + Vector3((randf() - .5) * 30.0, (randf() - .5) * 30.0, (randf() - .5) * 30.0)
		var prev := from
		var s := Vector3(0, 1.1, 0)
		for i in range(1, 13):
			var nx := from.lerp(to, i / 12.0)
			if i < 12:
				nx += Vector3(randf() - .5, randf() - .5, randf() - .5) * 9.0
			bolts.quad(prev, nx, s)
			prev = nx
	bolts.flush()


func update(dt: float) -> void:
	clock += dt
	# the ring comes off in the collapse: 5.5 s down past the cage, and it lands round the foot of the podium (on_ring fires once, as it hits)
	if ring_fall <= 0.0:
		ring.rotation.y += dt * ring_w
	else:
		ring_fall = minf(1.0, ring_fall + dt / 5.5)
		var e := ring_fall * ring_fall
		ring.position.y = OMNI.y - e * (OMNI.y - 9.0)
		ring.rotation.z = e * .1
		ring.rotation.x = e * .08
		ring.rotation.y += dt * ring_w * (1.0 - e)
		if ring_fall >= 1.0 and not ring_hit:
			ring_hit = true
			if Game.fx != null:
				for k in 12:
					var q := k / 12.0 * TAU
					Game.fx.explosion(Vector3(OMNI.x + cos(q) * 77.0, 10.0, OMNI.z + sin(q) * 77.0), 14.0)
				Game.fx.shake = 2.6
			if on_ring.is_valid():
				on_ring.call()
	# the torn-out siphon lines coming down
	for ln in lines:
		if not ln.ripped:
			continue
		for p in ln.pieces:
			if p.t == -2.0 or not p.g.visible:
				continue
			var was := p.t
			p.t += dt
			if p.t < 0.0:
				continue
			if was < 0.0 and Game.fx != null:
				Game.fx.sparks(p.g.position, 30, 12.0, null, 0x9dffd8)
				Game.fx.sparks(p.g.position, 16, 8.0, null, 0xffc060)
				far_boom(p.g.position, 5.0, .25)
			p.v.y -= 20.0 * dt
			p.g.position += p.v * dt
			p.g.rotation += p.w * dt
			if p.g.position.y < -6.0:
				p.g.visible = false
				p.t = -2.0
	if det != null:
		_update_det(dt)
	_update_sky(dt)
	# shockwaves
	var cam: Vector3 = Game.camera.global_position if Game.camera != null else OMNI
	for i in range(waves.size() - 1, -1, -1):
		var w := waves[i]
		w.t += dt
		var u := w.t / w.dur
		var r := ORAD * .6 + (w.max_r - ORAD * .6) * (1.0 - pow(1.0 - minf(1.0, u), 2.0))
		w.shell.scale = Vector3.ONE * r
		w.flat.scale = Vector3.ONE * r
		MsKit.opa(w.shell, .32 * (1.0 - u))
		MsKit.opa(w.flat, .7 * (1.0 - u))
		if not w.hit and r > cam.distance_to(OMNI):
			w.hit = true
			if Game.fx != null:
				Game.fx.shake = maxf(Game.fx.shake, w.kick)
			if on_wave.is_valid():
				on_wave.call()
		if u >= 1.0:
			w.shell.visible = false
			w.flat.visible = false
			waves.remove_at(i)
	# the core running wild: flicker, wobble, lightning, the cage popping; while it comes apart, plates peel off
	var blown: bool = det != null and det.blown
	if is_unstable and not blown:
		if randf() < dt * 4.0:
			flare_v = maxf(flare_v, .6 + randf() * .8)
		flare_v = maxf(flare_v, .25)
		if det == null:
			core.scale = Vector3.ONE * (1.0 + sin(clock * 13.0) * .025 + sin(clock * 31.0) * .012)
			boom_t -= dt
			if boom_t <= 0.0:
				boom_t = .35 + randf() * .5 if collapsing else .8 + randf() * 1.2
				far_boom(OMNI + cage_pts[randi() % cage_pts.size()] * 1.02, 16.0 if collapsing else 11.0)
		shed_t -= dt
		if collapsing and shed_t <= 0.0 and shed_list.size() < 12:
			shed_t = .5 + randf() * .6
			var A := cage_pts[randi() % cage_pts.size()]
			if A.y >= -ORAD * .3:
				var m := MsKit.part(root, plate_mesh, plate_mat, OMNI + A)
				fx_objs.append(m)
				m.look_at(OMNI)
				shed_list.append({"m": m, "v": A.normalized() * (8.0 + randf() * 10.0) + Vector3(0, 4, 0), "w": Vector3(randf() - .5, randf() - .5, randf() - .5) * 3.0})
	for i in range(shed_list.size() - 1, -1, -1):
		var s: Dictionary = shed_list[i]
		s.v = (s.v as Vector3) + Vector3(0, -16.0 * dt, 0)
		var m: MeshInstance3D = s.m
		m.position += (s.v as Vector3) * dt
		m.rotation.x += float(s.w.x) * dt
		m.rotation.z += float(s.w.z) * dt
		if m.position.y < 2.0:
			far_boom(Vector3(m.position.x, 3.0, m.position.z), 10.0)
			m.visible = false
			shed_list.remove_at(i)
	flare_v = maxf(0.0, flare_v - dt * .6)
	if core_mat is ShaderMaterial:
		(core_mat as ShaderMaterial).set_shader_parameter(&"uFlare", minf(3.0, flare_v))
	if det == null:      # from the ring the glow is round you, not out there: fade it (it washed the cage out white)
		var near := _sm((cam.distance_to(OMNI) - 95.0) / 160.0)
		MsKit.opa(core_halo, (.45 + .4 * minf(1.5, flare_v) + .05 * sin(clock * 3.0)) * (.12 + .88 * near))
	if dark or blown:
		bolts.node.visible = false
		return
	bolt_t -= dt
	if bolt_t <= 0.0:
		bolt_t = .07 if flare_v > .3 else .25 + randf() * 1.6
		_zap((8 if det != null else 4) if flare_v > .3 else 1 + randi() % 2)
		bolts.node.visible = true
	elif bolt_t < .2 and flare_v < .3:
		bolts.node.visible = false
