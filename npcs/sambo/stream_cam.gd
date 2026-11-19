class_name StreamCam
extends Node3D
## The WeFoint stream camera Sambo hands Prog (user, 2026-11-19: "Prog agrees and is handed the stream camera so he can record the stream"): a little camcorder on a shoulder mount on his left
## shoulder (his hands stay free for his guns), lens forward, its flip-out screen lit, the tally lamp blinking red while it is live. Worn from the handover in FOINT CITY until the stream ends
## (levels/hub/hub_sambo.gd, levels/palace/palace_level.gd). wear() fits it to the character's left clavicle; remove() takes it off.

const AT := Vector3(0.175, 1.535, 0.03)      # on the shoulder, model space (the character faces +Z, his left is +X)

var _att: BoneAttachment3D = null
var _tally: MeshInstance3D = null
var _t := 0.0


static func wear(an: Animator) -> StreamCam:
	if an == null or not an.by_key.has(&"clavicleL"):
		return null
	var old := an.skel.find_child("StreamCamMount", true, false)
	if old != null:      # (one at a time: a level that wears it over the street's)
		var keep := old.get_child(0) as StreamCam
		if keep != null:
			return keep
	var c := StreamCam.new()
	var rec: Animator.BoneRec = an.by_key[&"clavicleL"]
	c._att = BoneAttachment3D.new()
	c._att.name = "StreamCamMount"
	c._att.bone_idx = rec.bone
	an.skel.add_child(c._att)
	c._att.add_child(c)
	c.transform = an.skel.get_bone_global_rest(rec.bone).affine_inverse() * Transform3D(Basis.IDENTITY, AT)
	c._build()
	return c


func remove() -> void:
	if _att != null and is_instance_valid(_att):
		_att.queue_free()
	_att = null


static func _m(c: Color, rough: float, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _part(mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build() -> void:
	name = "StreamCam"
	var body := _m(Color(0.07, 0.07, 0.08), 0.4, 0.3)
	var trim := _m(Color(0.32, 0.33, 0.36), 0.3, 0.8)
	var b := BoxMesh.new()
	b.size = Vector3(0.068, 0.075, 0.15)
	_part(b, body, Vector3(0.0, 0.045, 0.0))
	var pad := BoxMesh.new()      # the shoulder mount: a padded plate and a strap round under the arm
	pad.size = Vector3(0.11, 0.018, 0.13)
	_part(pad, _m(Color(0.05, 0.05, 0.05), 0.9), Vector3(0.0, 0.0, -0.005))
	var strap := BoxMesh.new()
	strap.size = Vector3(0.03, 0.2, 0.012)
	_part(strap, _m(Color(0.04, 0.04, 0.045), 0.9), Vector3(0.045, -0.09, 0.0), Vector3(0.0, 0.0, -0.35))
	var lens := CylinderMesh.new()
	lens.top_radius = 0.026
	lens.bottom_radius = 0.03
	lens.height = 0.05
	lens.radial_segments = 14
	_part(lens, trim, Vector3(0.0, 0.048, 0.098), Vector3(PI / 2.0, 0.0, 0.0))
	var glass := CylinderMesh.new()
	glass.top_radius = 0.021
	glass.bottom_radius = 0.021
	glass.height = 0.004
	glass.radial_segments = 14
	_part(glass, _m(Color(0.06, 0.1, 0.22), 0.05, 0.6), Vector3(0.0, 0.048, 0.124), Vector3(PI / 2.0, 0.0, 0.0))
	var screen := BoxMesh.new()      # the flip-out screen, open on his left, lit
	screen.size = Vector3(0.004, 0.045, 0.065)
	_part(screen, _m(Color(0.45, 0.7, 1.0), 0.3, 0.0, 1.4), Vector3(0.04, 0.05, 0.01), Vector3(0.0, 0.35, 0.0))
	var tally := SphereMesh.new()
	tally.radius = 0.007
	tally.height = 0.014
	_tally = _part(tally, _m(Color(1.0, 0.08, 0.06), 0.3, 0.0, 6.0), Vector3(0.022, 0.087, 0.06))
	var sticker := QuadMesh.new()      # WeFoint's mark on its side
	sticker.size = Vector2(0.05, 0.016)
	_part(sticker, _m(Color(1.0, 0.62, 0.18), 0.5, 0.0, 0.8), Vector3(-0.0345, 0.045, -0.02), Vector3(0.0, -PI / 2.0, 0.0))


func _process(dt: float) -> void:
	_t += dt
	if _tally != null:
		_tally.visible = fmod(_t, 1.0) < 0.62
