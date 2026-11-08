class_name VhInmates
extends RefCounted
## VISITING HOURS: the inmates of 3F's tier (JS inmates.js, section 5): Fointers in GOINT's orange, locked in through the lockdown, at their bars shouting and waving at the fight. FOINT CITY's townsfolk: one MultiMesh per species, arms and head moved in the vertex shader (no skinning), every head turned to Prog.

# who is in: [species, row ('s' south, 'n' north), cell index along the row]. Two cells stand empty
const WHO := [["rhino", "s", 0], ["gremlin", "s", 1], ["lanky", "s", 3], ["cyclops", "s", 4], ["frog", "s", 5], ["rhino", "n", 0], ["gremlin", "n", 2]]
const JUMP := 0xe0702a      # GOINT's jumpsuit orange (the folk's clothes take it)


class Inmate:
	var x := 0.0
	var z := 0.0
	var yaw := 0.0
	var look := 0.0


var parent: Node3D
var folk: CityFolk
var meshes: Array = []      # {mm, list}
var col := MsKit.lin(JUMP)


func _init(lv: ExportedLevel, admin: VhAdmin) -> void:
	parent = admin.floors[&"f3"]
	for n: Node3D in lv.node_named("inmates-rhino") + lv.node_named("inmates-gremlin") + lv.node_named("inmates-lanky") + lv.node_named("inmates-cyclops") + lv.node_named("inmates-frog"):
		n.visible = false      # (the export's: stiff, no shader)
	var dir := ExportedLevel.DIR + "hub/"
	var J := ExportedLevel._json(dir + "life.json")
	folk = CityFolk.new(J, FileAccess.get_file_as_bytes(dir + "life.bin"))
	var C3: Dictionary = admin.cells3
	var by_sp := {}
	for w: Array in WHO:
		if not by_sp.has(w[0]):
			by_sp[w[0]] = []
		(by_sp[w[0]] as Array).append(w)
	for sp: String in by_sp:
		var list: Array = by_sp[sp]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = folk.species_mesh_mode(sp, 3.0)      # (mode 3: talks with its hands: at the bars, it reads as shouting)
		mm.instance_count = list.size()
		var people: Array[Inmate] = []
		for k in list.size():
			var w: Array = list[k]
			var south: bool = w[1] == "s"
			var xs: Array = C3.s if south else C3.n
			var i: int = w[2]
			var p := Inmate.new()
			p.x = VhLayout.ad_x((float(xs[i]) + float(xs[i + 1])) / 2.0 + (0.35 if k % 2 == 1 else -0.3))
			p.z = VhLayout.ad_z(float(C3.sFront) if south else float(C3.nFront)) + (-0.36 if south else 0.36)
			p.yaw = 0.0 if south else PI
			people.append(p)
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, p.yaw), Vector3(p.x, VhLayout.FLW[&"f3"], p.z)))
			mm.set_instance_custom_data(k, Color(0.0, 0.0, fmod(sp.length() * 0.17 + k * 0.41 + i * 0.23, 1.0), 1.0))
			mm.set_instance_color(k, Color(col.r, col.g, col.b, 0.0))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = folk.material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		parent.add_child(mi)
		meshes.append({"mm": mm, "list": people})
	folk.release_bin()


func update(dt: float, t: float, P: Player) -> void:
	if not parent.visible:
		return
	folk.material.set_shader_parameter(&"uTime", t)
	for q: Dictionary in meshes:
		var mm: MultiMesh = q.mm
		var list: Array = q.list
		for k in list.size():
			var p: Inmate = list[k]
			var want := clampf(VhLayout.wrap_a(atan2(P.x - p.x, P.z - p.z) - p.yaw), -1.1, 1.1) if P != null else 0.0
			p.look += (want - p.look) * minf(1.0, dt * 4.0)
			mm.set_instance_color(k, Color(col.r, col.g, col.b, p.look))
