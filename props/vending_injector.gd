class_name VendingInjector
extends Node3D
## The injector rig behind the implant machine's vent flap (JS props/plasmid-vending.js buildInjector): two telescoping two-link arms (a claw that holds the head, a syringe for the neck). Hidden until cutscenes/implant_inject.gd drives it. Everything is given in WORLD space: flap(open 0..1), claw_place(wrist, dir, ext, twist, grip, size), syringe_place(wrist, dir, ext, inject), set_liquid, hide_all. This node stands where the machine stands, with its yaw and scale. needle() = wrist-to-needle-tip distance in world metres.

const BRASS_DK := 0x6b5226
const L := 0.78
const ROOT := Vector3(0.56, 0.4, 0.3)
const NEEDLE_L := 0.3
const BARREL0 := 0.06
const BARREL1 := 0.22

var flap_node: Node3D = null
var _steel: StandardMaterial3D
var _joint: StandardMaterial3D
var _liquid_mat: StandardMaterial3D
var _claw: Arm
var _syr: Arm
var _fingers: Array = []
var _liquid: Node3D
var _rod: Node3D
var _disc: Node3D


class Arm:
	var grp: Node3D
	var tip: Node3D
	var upper: Node3D
	var fore: Node3D
	var elbow: Node3D
	var root := Vector3.ZERO
	var pole := Vector3.UP

	## two-link IK in the machine's local space; the links telescope shorter while the arm is not fully out
	func solve(wrist_l: Vector3, dir_l: Vector3, ext: float, twist: float) -> void:
		grp.visible = ext > 0.02
		if not grp.visible:
			return
		var k := 0.3 + 0.7 * ext
		var l1 := L * k
		var l2 := L * k
		var d := (wrist_l - root) * ext
		var full := d.length()
		var dist := minf(maxf(full, 0.02), l1 + l2 - 0.002)
		var dn := d / full if full > 1e-5 else d
		var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
		var h := sqrt(maxf(0.0, l1 * l1 - a * a))
		var po := (pole - dn * pole.dot(dn)).normalized()
		var elb := root + dn * a + po * h
		var wr := root + ((wrist_l - root) * ext).limit_length(dist)
		upper.position = root
		upper.basis = VendingInjector._y_to((elb - root).normalized()) * Basis.from_scale(Vector3(1.0, l1, 1.0))
		fore.position = elb
		fore.basis = VendingInjector._y_to((wr - elb).normalized()) * Basis.from_scale(Vector3(1.0, l2, 1.0))
		elbow.position = elb
		tip.position = wr
		var sc := tip.basis.get_scale()
		tip.basis = VendingInjector._y_to(dir_l) * Basis(Vector3.UP, twist) * Basis.from_scale(sc)


static func _y_to(d: Vector3) -> Basis:
	var dn := d.normalized()
	if dn.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dn))


func _ready() -> void:
	name = "VendingInjector"
	_steel = Goggles._std(0x7d8a8e, 0.42, 0.9)
	_steel.emission_enabled = true
	_steel.emission = Color.hex(0x0a1418ff)
	_steel.emission_energy_multiplier = 0.6
	_joint = Goggles._std(BRASS_DK, 0.5, 0.85)
	_liquid_mat = Goggles._std(0xff3b30, 0.3, 0.0)
	_liquid_mat.emission_enabled = true
	_liquid_mat.emission = Color.hex(0xff3b30ff)
	_liquid_mat.emission_energy_multiplier = 1.8
	_claw = _make_arm(-0.07, -1.0)
	_syr = _make_arm(0.07, 1.0)
	_build_claw()
	_build_syringe()


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 8
	return s


func _unit_cyl(par: Node3D, r: float, mat: Material) -> MeshInstance3D:
	var o := Goggles.part(par, Goggles.cyl_mesh(r, r, 1.0, 10), mat)
	# (JS geo.translate(0, 0.5, 0): the base at the node, one metre long along +Y)
	var pivot_mesh := CylinderMesh.new()
	pivot_mesh.top_radius = r
	pivot_mesh.bottom_radius = r
	pivot_mesh.height = 1.0
	pivot_mesh.radial_segments = 10
	var st := SurfaceTool.new()
	st.create_from(pivot_mesh, 0)
	var arr := st.commit_to_arrays()
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in V.size():
		V[i].y += 0.5
	arr[Mesh.ARRAY_VERTEX] = V
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	o.mesh = m
	return o


func _make_arm(root_x: float, side: float) -> Arm:
	var A := Arm.new()
	A.grp = Node3D.new()
	A.grp.visible = false
	add_child(A.grp)
	A.root = ROOT + Vector3(root_x, 0.0, 0.0)
	A.pole = Vector3(side * 0.35, 1.0, 0.2).normalized()
	A.upper = Node3D.new()
	A.fore = Node3D.new()
	A.tip = Node3D.new()
	A.grp.add_child(A.upper)
	A.grp.add_child(A.fore)
	A.grp.add_child(A.tip)
	_unit_cyl(A.upper, 0.05, _steel)
	_unit_cyl(A.fore, 0.04, _steel)
	A.elbow = Goggles.part(A.grp, _sphere(0.065), _joint)
	Goggles.part(A.grp, _sphere(0.07), _joint, A.root)
	return A


## the claw: a palm and four two-jointed fingers around it, grip 0 (open, splayed) .. 1 (closed round the head)
func _build_claw() -> void:
	var tip := _claw.tip
	Goggles.part(tip, Goggles.cyl_mesh(0.075, 0.09, 0.07, 12), _joint, Vector3(0.0, 0.02, 0.0))
	Goggles.part(tip, _sphere(0.052), _joint, Vector3(0.0, -0.03, 0.0))
	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.albedo_color = Color.hex(0xff2a1aff)
	Goggles.part(tip, _sphere(0.014), led, Vector3(0.0, 0.025, 0.092))
	for i in 4:
		var phi := i * PI / 2.0 + PI / 4.0
		var base := Node3D.new()
		base.position = Vector3(cos(phi) * 0.075, 0.05, sin(phi) * 0.075)
		tip.add_child(base)
		var seg1 := _unit_cyl(base, 0.026, _steel)
		seg1.scale.y = 0.16
		var j2 := Node3D.new()
		j2.position.y = 0.16
		base.add_child(j2)
		var seg2 := _unit_cyl(j2, 0.022, _steel)
		seg2.scale.y = 0.13
		Goggles.part(j2, _sphere(0.03), _joint)
		Goggles.part(j2, _sphere(0.025), _joint, Vector3(0.0, 0.13, 0.0))
		_fingers.append([base, j2, Vector3(-sin(phi), 0.0, cos(phi))])      # positive rotation about this axis curls the finger inward


## the syringe: housing, glass barrel with a glowing liquid and a plunger, a needle (points along +Y)
func _build_syringe() -> void:
	var tip := _syr.tip
	Goggles.part(tip, Goggles.cyl_mesh(0.044, 0.05, 0.08, 12), _joint)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(Color.hex(0xcfe8ffff), 0.22)
	glass.roughness = 0.05
	glass.metallic = 0.2
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var barrel := Goggles.cyl_mesh(0.028, 0.028, BARREL1 - BARREL0, 14)
	barrel.cap_top = false
	barrel.cap_bottom = false
	Goggles.part(tip, barrel, glass, Vector3(0.0, (BARREL0 + BARREL1) / 2.0, 0.0))
	Goggles.part(tip, Goggles.cyl_mesh(0.03, 0.03, 0.014, 14), _joint, Vector3(0.0, BARREL1 + 0.004, 0.0))
	Goggles.part(tip, Goggles.cyl_mesh(0.012, 0.02, 0.034, 10), _joint, Vector3(0.0, BARREL1 + 0.026, 0.0))
	Goggles.part(tip, Goggles.cyl_mesh(0.0035, 0.0065, NEEDLE_L - BARREL1 - 0.04, 8), Goggles._std(0xdfe6e8, 0.2, 1.0), Vector3(0.0, (BARREL1 + 0.04 + NEEDLE_L) / 2.0, 0.0))
	_liquid = _unit_cyl(tip, 0.021, _liquid_mat)
	_rod = _unit_cyl(tip, 0.008, _steel)
	_disc = Goggles.part(tip, Goggles.cyl_mesh(0.023, 0.023, 0.012, 12), _joint)


func needle() -> float:
	return NEEDLE_L * global_basis.get_scale().x


func _local(p: Vector3) -> Vector3:
	return global_transform.affine_inverse() * p


func _local_dir(d: Vector3) -> Vector3:
	return (global_basis.inverse() * d).normalized()


func claw_place(wrist: Vector3, dir: Vector3, ext: float, twist: float = 0.0, grip: float = 0.0, size: float = 1.0) -> void:
	_claw.tip.basis = Basis.from_scale(Vector3.ONE * size)
	_claw.solve(_local(wrist), _local_dir(dir), ext, twist)
	for f: Array in _fingers:
		var ax: Vector3 = f[2]
		(f[0] as Node3D).basis = Basis(ax, -0.45 + 1.0 * grip)
		(f[1] as Node3D).basis = Basis(ax, -0.1 + 1.35 * grip)


func syringe_place(wrist: Vector3, dir: Vector3, ext: float, inject: float = 0.0) -> void:
	_syr.solve(_local(wrist), _local_dir(dir), ext, 0.0)
	var dy := BARREL0 + 0.012 + (BARREL1 - BARREL0 - 0.03) * inject
	var top := BARREL1 - 0.002
	_disc.position.y = dy
	_rod.position.y = 0.0
	_rod.scale.y = dy
	_liquid.position.y = dy + 0.006
	_liquid.scale.y = maxf(0.0005, top - dy - 0.006)
	_liquid.visible = inject < 0.995


func flap(open: float) -> void:
	if flap_node != null:
		flap_node.rotation.x = 1.75 * clampf(open, 0.0, 1.0)


func set_liquid(c: int) -> void:
	var col := Color.hex((c << 8) | 0xff)
	_liquid_mat.albedo_color = col
	_liquid_mat.emission = col


func hide_all() -> void:
	_claw.grp.visible = false
	_syr.grp.visible = false
	if flap_node != null:
		flap_node.rotation.x = 0.0
