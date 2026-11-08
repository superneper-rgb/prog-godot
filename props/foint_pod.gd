class_name FointPod
extends Node3D
## The FOINT-N-SHOOT DISPENSARY POD (JS props/foint-pod.js): FOINT's little walk-up arms vendor, a giant shell casing on a hazard plinth with two bullseye eyes in a visor (dozing, blinking, tracking you) and ammo drums on its sides. Walk up and it wakes: a hop, the cap lifts and spins on a beam, the branded holo ring turns, the drums spin. The model comes from the exporter (assets/objects/pod_<kind>.glb), this is its life. Built at the origin, feet on y = 0, facing +Z.

const RADIUS := 0.86
const HEIGHT := 1.45

var _body: Node3D
var _lids: Node3D
var _pupils: Node3D
var _drums: Array[Node3D] = []
var _cap: Node3D
var _beam: Node3D
var _ring: Node3D
var _beam_m: StandardMaterial3D
var _ring_m: StandardMaterial3D
var _mouth_m: StandardMaterial3D
var _wake := 0.0
var _hop := 0.0
var _blink_at := 2.0 + randf() * 3.0
var _blink_t := 0.0
var _was := false


## kind: ammo | armor
static func build(kind: String = "ammo") -> FointPod:
	var o := FointPod.new()
	o.name = "foint-pod_" + kind
	var sc: Node3D = (load("res://assets/objects/pod_%s.glb" % ("armor" if kind == "armor" else "ammo")) as PackedScene).instantiate()
	o.add_child(sc)
	var n := {}
	ArmsDepot._index(sc, n)
	o._body = n["pod_body"]
	o._lids = n["pod_lids"]
	o._pupils = n["pod_pupils"]
	o._drums = [n["pod_drum0"], n["pod_drum1"]]
	o._cap = n["pod_cap"]
	o._beam = n["pod_beam"]
	o._ring = n["pod_ring"]
	o._beam_m = _own(n["pod_beam"])
	o._ring_m = _own(n["pod_ring"])
	o._mouth_m = _own(n["pod_mouth"])
	return o


static func _own(n: Node) -> StandardMaterial3D:
	var mi := ArmsDepot._mesh_of(n)
	var m: StandardMaterial3D = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	mi.material_override = m
	return m


## life: dozing until you are near; then it hops awake, lifts its cap and watches you
func update_at(t: float, dt: float, P: Player) -> void:
	var near := false
	var lx := 0.0
	var ly := 0.0
	if P != null:
		var V := global_transform.affine_inverse() * Vector3(P.x, P.y + 1.3, P.z)
		var d := Vector2(V.x, V.z).length()
		near = d < 5.5 * (1.0 / scale.x) and absf(V.y) < 4.0
		var f := maxf(0.3, Vector3(V.x, V.y - 1.1, V.z).length())
		lx = clampf(V.x / f, -1.0, 1.0)
		ly = clampf((V.y - 1.1) / f, -1.0, 1.0)
	_wake = clampf(_wake + (2.5 if near else -1.2) * dt, 0.0, 1.0)
	if near and not _was and _wake < 0.2:
		_hop = 1.0
	_was = near
	_hop = maxf(0.0, _hop - dt * 1.6)
	var sq := sin((1.0 - _hop) * PI * 3.0) * _hop if _hop > 0.0 else 0.0
	var breathe := sin(t * 1.7) * 0.012
	_body.scale = Vector3(1.0 - sq * 0.08, 1.0 + sq * 0.14 + breathe, 1.0 - sq * 0.08)
	_body.position.y = 0.2 + maxf(0.0, sq) * 0.12
	var w := _wake * _wake * (3.0 - 2.0 * _wake)
	var lift := w * 0.62 + sin(t * 2.2) * 0.04 * w
	_cap.position.y = 1.22 + lift
	_cap.rotation.y = t * (0.4 + 1.6 * w)
	_beam.scale = Vector3(1.0, maxf(0.01, lift), 1.0)
	_beam.position.y = 1.22 + lift / 2.0
	_beam_m.albedo_color.a = 0.2 * w * (0.85 + 0.15 * sin(t * 13.0))
	_ring.position.y = 1.26 + lift * 0.5
	_ring.rotation.y = -t * 0.7
	_ring_m.albedo_color.a = 0.9 * w * (0.3 if fmod(t, 3.1) < 0.05 else 1.0)
	for i in _drums.size():
		_drums[i].rotation.x += dt * (0.3 + 5.0 * w) * (1.0 if i != 0 else -1.0)
	_mouth_m.albedo_color = Color(0.19 + 0.8 * w, 0.06 + 0.4 * w * (0.8 + 0.2 * sin(t * 9.0)), 0.03).linear_to_srgb()
	_blink_at -= dt
	if _blink_at <= 0.0:
		_blink_t = 0.14
		_blink_at = 1.8 + randf() * 3.5
	_blink_t = maxf(0.0, _blink_t - dt)
	var open := 1.0 if _blink_t > 0.0 else 0.55 * (1.0 - w) + 0.05 * w      # dozing: half-lidded; awake: wide open
	_lids.scale.y += (open - _lids.scale.y) * minf(1.0, dt * (40.0 if _blink_t > 0.0 else 8.0))
	_pupils.position.x += (lx * 0.045 * w - _pupils.position.x) * minf(1.0, dt * 8.0)
	_pupils.position.y += (ly * 0.04 * w - _pupils.position.y) * minf(1.0, dt * 8.0)
	var on := w > 0.01      # asleep: two fewer draws
	_beam.visible = on
	_ring.visible = on
