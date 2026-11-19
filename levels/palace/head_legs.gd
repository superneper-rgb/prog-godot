class_name HeadLegs
extends Node3D
## The robot legs Sambo's head sprouts from its neck stump (user, 2026-11-19: "his head still dangling from the crane sprouts robo legs and rapidly drops down onto the construction site and
## climbs into its new position as the head of the mech"). Six jointed chrome legs, each a thigh and a shin to a pointed foot, round the stump; drawn in the head's own rest frame (it rides the
## head bone of a SamboBody, npcs/sambo/sambo_body.gd), so the head carries them wherever it goes. `out` (0..1) unfolds them from inside the stump; `step` (any) walks them in two tripods;
## `brace` (0..1) spreads them for a landing; `tuck` (0..1) folds them up under the head (seated in the mech's collar).

const HIP_Y := 1.46            # the stump's underside, model space
const HIP_R := 0.055
const THIGH := 0.15
const SHIN := 0.2
const FOOT_R := 0.26           # where the feet stand, from the stump's middle
const STAND := 0.24            # how far under the hips the feet are when it stands

var out := 0.0
var step := 0.0
var stride := 0.0              # how far the feet swing (0 standing)
var brace := 0.0
var tuck := 0.0
var _att: BoneAttachment3D
var _thighs: Array[MeshInstance3D] = []
var _shins: Array[MeshInstance3D] = []
var _knees: Array[MeshInstance3D] = []
var _feet: Array[MeshInstance3D] = []
var _hub: MeshInstance3D


## Fit them to a SamboBody's head bone
static func fit(sb: SamboBody) -> HeadLegs:
	var h := HeadLegs.new()
	h._att = BoneAttachment3D.new()
	h._att.name = "HeadLegsMount"
	h._att.bone_idx = sb.B["head"]
	sb.skel.add_child(h._att)
	h._att.add_child(h)
	h.transform = sb.skel.get_bone_global_rest(sb.B["head"]).affine_inverse()      # (children in the model's rest space)
	h._build()
	h.visible = false
	return h


func _build() -> void:
	name = "HeadLegs"
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.72, 0.74, 0.78)
	chrome.metallic = 1.0
	chrome.roughness = 0.18
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	dark.metallic = 0.7
	dark.roughness = 0.4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 0.05, 0.03)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.25, 0.1)
	glow.emission_energy_multiplier = 3.0
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 1.0
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 8
	_hub = MeshInstance3D.new()
	_hub.mesh = ball
	_hub.material_override = dark
	_hub.scale = Vector3(0.07, 0.03, 0.07)
	_hub.position = Vector3(0.0, HIP_Y - 0.01, 0.0)
	add_child(_hub)
	for i in 6:
		for arr: Array in [[_thighs, tube, chrome], [_shins, tube, chrome], [_knees, ball, glow], [_feet, cone, dark]]:
			var mi := MeshInstance3D.new()
			mi.mesh = arr[1]
			mi.material_override = arr[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mi)
			(arr[0] as Array).append(mi)


func remove() -> void:
	if _att != null and is_instance_valid(_att):
		_att.queue_free()


static func _member(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	mi.transform = PalaceKit.span(a, b, r, r)


## Pose the legs from out / step / stride / brace / tuck (model rest space: the stump's middle at (0, HIP_Y, 0), the head facing +Z)
func pose() -> void:
	visible = out > 0.01
	if not visible:
		return
	var k := clampf(out, 0.0, 1.0)
	_hub.scale = Vector3(0.07, 0.03, 0.07) * maxf(0.3, k)
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		var hip := Vector3(0.0, HIP_Y, 0.0) + dir * HIP_R
		var grow := clampf(k * 1.4 - i * 0.07, 0.0, 1.0)      # (they come out one after another)
		var l1 := THIGH * grow
		var l2 := SHIN * grow
		# the foot: out on its circle and down under the hips; walking, the two tripods swing in turn
		var ph := step * TAU + (PI if i % 2 == 1 else 0.0)
		var lift := maxf(0.0, sin(ph)) * 0.06 * stride
		var swing := cos(ph) * 0.07 * stride
		var r := lerpf(FOOT_R, FOOT_R * 1.35, brace)
		r = lerpf(r, HIP_R + 0.03, tuck)
		var foot := Vector3(0.0, HIP_Y, 0.0) + dir * r + Vector3(0.0, -lerpf(STAND, 0.05, tuck) * grow + lift, 0.0) + Vector3(0.0, 0.0, swing)
		foot.y = lerpf(HIP_Y, foot.y, grow)
		# the knee: up and out, on the plane through the hip and the foot
		var d := foot - hip
		var L := maxf(0.001, d.length())
		var reach := clampf(L, 0.01, (l1 + l2) * 0.999)
		var dn := d / L
		var av := (l1 * l1 - l2 * l2 + reach * reach) / (2.0 * reach)
		var hh := sqrt(maxf(0.0, l1 * l1 - av * av))
		var up := (Vector3.UP - dn * Vector3.UP.dot(dn))
		up = up.normalized() if up.length() > 1e-4 else dir
		var knee := hip + dn * av + up * hh
		var tip := hip + dn * reach
		_member(_thighs[i], hip, knee, 0.012)
		_member(_shins[i], knee, tip, 0.009)
		_knees[i].transform = Transform3D(Basis().scaled(Vector3.ONE * 0.016), knee)
		_feet[i].transform = PalaceKit.span(tip - Vector3(0.0, 0.01, 0.0), tip + Vector3(0.0, 0.035, 0.0), 0.011, 0.011)      # (the cone's point down)
		_thighs[i].visible = grow > 0.02
		_shins[i].visible = grow > 0.02
		_knees[i].visible = grow > 0.02
		_feet[i].visible = grow > 0.02
