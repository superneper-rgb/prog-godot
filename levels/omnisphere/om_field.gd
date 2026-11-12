class_name OmField
extends RefCounted
## OMNISPHERE: the freight docks' perimeter field, an amber energy curtain on emitter masts round the docks' open east side. It is up until you reach the docks the proper way, so nobody jetpacks across from the runaway tram or from Gamma's deck. Touch it and it throws you back.
## NEW (user, 2026-11-09): not in the JS. Playtesters on the tram kept burning across the 10 m of magma to the docks and skipping Gamma and the assembly line. The user asked for a visible blocker, not an invisible wall. It is solid (feet, shots, AI) only before the docks stage. From the docks stage on it is down (the masts stay, dark), so it never gets in the way of the gunship, whose orbit passes over this edge at about y 34.
## Height: a jump plus a full burn climbs about 9.3 m and is still about 8 m up 10 m out. The worst launch is the tram cab's roof in mid-air over the sagged girder (y 27.2 at the top of the jump, 9 m from the edge), which tops out at about y 36.6 (measured: y 36.1, onto a 36 m top). The top is at y 40. The south return closes the 7 m between the dock's corner and the hall wall (top y 39), which Gamma's deck and the shift room roof can reach.

const FLOOR := 18.0
const TOP := 40.0
const BOTTOM := 10.0      # (solid only: well below the deck, so nobody slips under it on the way down)
const THICK := 0.3
const DMG := 14.0
const SHOVE := 7.0
## the curtain's corners, in order (x, z): hall wall -> the dock's SE corner -> up the east edge -> the NE corner -> along the north edge, short of the bridge mouth.
## It stands 0.6-0.75 m out past the deck's edges (east x -170.0, north z -122.05, south z -62.2): Player._try_ledge feels 0.44-0.66 m ahead of PROG for a lip, so with the deck inside its line he slid down the curtain, caught the deck under it and pulled himself up through it. From out here no lip is within reach. Kept thin so its own top is no ledge (no flat top 1.16 m beyond the lip).
const RUN: Array = [[-176.6, -61.6], [-169.4, -61.6], [-169.4, -122.8], [-186.0, -122.8]]
const SPAN := 10.0      # masts at most this far apart
const AMBER := 0xffa030
const DOCK := Vector2(-205.0, -92.0)      # the docks' middle (the masts' brackets face it)

const CURTAIN := "shader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;\nuniform vec3 col : source_color = vec3(1.0, 0.63, 0.19);\nuniform float amt = 1.0;\nuniform float tall = 18.0;\nuniform vec3 hit_p = vec3(0.0, -1000.0, 0.0);\nuniform float hit_k = 0.0;\nvarying vec3 wp;\nfloat h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\nfloat n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1.)), f.x), f.y); }\nvoid vertex(){ wp = VERTEX; }\nvoid fragment(){\n float u = UV.x, v = UV.y;\n float fl = n(vec2(u * .5, v * .35 - TIME * 1.4)) * .6 + n(vec2(u * 1.6 + TIME * .7, v * 1.2)) * .4;\n float scan = pow(.5 + .5 * sin(v * 5. - TIME * 4.), 10.) * .45;\n float crt = .85 + .15 * sin(v * 60.);\n float post = pow(abs(sin(u * 3.14159 / 2.5)), 40.) * .12;\n float foot = (1. - smoothstep(0., 2.2, v)) * .55;\n float fade = smoothstep(0., .4, v) * (1. - smoothstep(tall - 5., tall, v));\n float d = distance(wp, hit_p);\n float ring = hit_k * (smoothstep(3.5, 0., d) * .9 + smoothstep(.5, 0., abs(d - (1. - hit_k) * 7.)) * .8);\n float a = ((.05 + fl * .09 + scan + post) * crt + foot) * fade + ring;\n ALBEDO = col * a * amt;\n}\n"

var world: World
var solids: Array[World.Solid] = []
var segs: Array[Vector4] = []      # (x0, z0, x1, z1) per straight run
var curtain: MeshInstance3D
var cmat: ShaderMaterial
var lamp_mat: StandardMaterial3D
var beacons: Array[MeshInstance3D] = []
var audio: OmAudio
var on := true
var hit_cd := 0.0
var hit_k := 0.0
var t := 0.0


func _init(lv: ExportedLevel, p_audio: OmAudio) -> void:
	world = lv.world
	audio = p_audio
	var root := Node3D.new()
	root.name = "om-field"
	lv.add_child(root)
	# masts at every corner and along each run, evenly
	var masts: Array[Vector2] = []
	for i in RUN.size() - 1:
		var a := Vector2(float(RUN[i][0]), float(RUN[i][1]))
		var b := Vector2(float(RUN[i + 1][0]), float(RUN[i + 1][1]))
		segs.append(Vector4(a.x, a.y, b.x, b.y))
		var n := maxi(1, ceili(a.distance_to(b) / SPAN))
		for k in n:
			masts.append(a.lerp(b, float(k) / n))
	masts.append(Vector2(float(RUN[-1][0]), float(RUN[-1][1])))
	# ---- the solids: one thin wall per run
	for s in segs:
		var cx := (s.x + s.z) / 2.0
		var cz := (s.y + s.w) / 2.0
		var wd := absf(s.z - s.x) + THICK
		var dp := absf(s.w - s.y) + THICK
		solids.append(world.box(cx, cz, wd, dp, TOP, {"bottom": BOTTOM, "no_cam": true, "tag": "wall"}))
	# ---- the masts: one detailed mesh (om_field_mast.gd) in a MultiMesh, x along the field, its bracket and brace into the dock
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = MsKit.srgb(0x3a2a14)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = MsKit.srgb(AMBER)
	lamp_mat.emission_energy_multiplier = 3.0
	var xf: Array[Transform3D] = []
	for i in masts.size():
		var m := masts[i]
		var tan := (masts[mini(i + 1, masts.size() - 1)] - masts[maxi(i - 1, 0)]).normalized()
		var yaw := atan2(-tan.y, tan.x)      # (local +x onto the run)
		var inward := Vector2(DOCK.x - m.x, DOCK.y - m.y)
		if Vector2(sin(yaw), cos(yaw)).dot(inward) < 0.0:      # (local +z into the dock)
			yaw += PI
		xf.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x, 0.0, m.y)))
		var bc := MsKit.sprite8(root, AMBER, .9, 1.1)
		bc.position = Vector3(m.x, TOP + 1.42, m.y)
		beacons.append(bc)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = OmFieldMast.build(FLOOR, TOP, lamp_mat)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	# ---- the curtain: one quad strip per run, UV in metres (along, up)
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var along := 0.0
	var tall := TOP - FLOOR
	for s in segs:
		var L := Vector2(s.x, s.y).distance_to(Vector2(s.z, s.w))
		var p0 := Vector3(s.x, FLOOR, s.y)
		var p1 := Vector3(s.z, FLOOR, s.w)
		var up := Vector3(0, tall, 0)
		pts.append_array(PackedVector3Array([p0, p1, p1 + up, p0, p1 + up, p0 + up]))
		uvs.append_array(PackedVector2Array([Vector2(along, 0), Vector2(along + L, 0), Vector2(along + L, tall), Vector2(along, 0), Vector2(along + L, tall), Vector2(along, tall)]))
		along += L
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = CURTAIN
	cmat = ShaderMaterial.new()
	cmat.shader = sh
	cmat.set_shader_parameter(&"col", MsKit.srgb(AMBER))
	cmat.set_shader_parameter(&"tall", tall)
	curtain = MeshInstance3D.new()
	curtain.mesh = mesh
	curtain.material_override = cmat
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(curtain)


## up for every stage before the docks, down from the docks on (the gunship works this edge)
func reset(bo: Blockout, stage: String) -> void:
	var docks := -1
	var here := -1
	for i in bo.stages.size():
		var id: String = bo.stages[i].get("id", "")
		if id == "docks":
			docks = i
		if id == stage:
			here = i
	on = here >= 0 and docks >= 0 and here < docks
	for s in solids:
		s.set_off(not on)
	curtain.visible = on
	for b in beacons:
		b.visible = on
	lamp_mat.emission_energy_multiplier = 3.0 if on else 0.0
	hit_cd = 0.0
	hit_k = 0.0


func update(dt: float, P: Player, C: Combat) -> void:
	if not on:
		return
	t += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	hit_k = maxf(0.0, hit_k - dt * 1.6)
	cmat.set_shader_parameter(&"hit_k", hit_k)
	cmat.set_shader_parameter(&"amt", .9 + .1 * sin(t * 9.0))
	for i in beacons.size():
		MsKit.opa(beacons[i], 1.0 if sin(t * 5.0 + i * .7) > 0.0 else .25)
	if P == null or P.dead or C == null or hit_cd > 0.0 or P.y > TOP or P.y + Config.height < FLOOR - 1.0:
		return
	# touching it: thrown back the way you came, a jolt, the jet keeps what it has left
	for s in segs:
		var a := Vector2(s.x, s.y)
		var b := Vector2(s.z, s.w)
		var p := Vector2(P.x, P.z)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d > Config.radius + THICK / 2.0 + .25:
			continue
		var out := (p - q) / d if d > 1e-4 else Vector2(1, 0)
		hit_cd = .6
		hit_k = 1.0
		var hp := Vector3(q.x, clampf(P.y + 1.0, FLOOR, TOP), q.y)
		cmat.set_shader_parameter(&"hit_p", hp)
		C.hurt_player(P, DMG, q.x - out.x, q.y - out.y, "bolt")
		P.ix += out.x * SHOVE
		P.iz += out.y * SHOVE
		if Game.fx != null:
			Game.fx.sparks(hp, 26, 7.0, Vector3(out.x, 0.0, out.y), AMBER)
		audio.play_at("arc", hp)
		return
