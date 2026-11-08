class_name OmPath
extends RefCounted
## An arc-length path sampled by the exporter (JS THREE.Curve getPointAt / getTangentAt, flat [x, y, z, ...] at equal arc length in level.json), so a port cannot drift from the JS curve.

var pts := PackedVector3Array()
var length := 0.0


func _init(flat: Array, p_len: float) -> void:
	length = p_len
	pts.resize(flat.size() / 3)
	for i in pts.size():
		pts[i] = Vector3(flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2])


## u in 0..1 along the path
func at_u(u: float) -> Vector3:
	var f := clampf(u, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


## s in metres along the path
func at(s: float) -> Vector3:
	return at_u(s / length)


func tan_u(u: float) -> Vector3:
	var f := clampf(u, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return (pts[i + 1] - pts[i]).normalized()


func tan(s: float) -> Vector3:
	return tan_u(s / length)
