class_name ForgeMonitor
extends RefCounted
## FORGE's camera, the Monitor: a fly camera that eases in and out of its moves instead of starting and stopping dead (the flight maths are Freecam's, ui/freecam.gd).
## HOVER glides at a set height over whatever is below. ORBIT circles a point (the selection) at a distance. It flies through walls, as an editor camera should.
## yaw 0 looks along +Z, increasing turns left (the player / CameraRig convention); pitch > 0 looks down.

const EASE := 9.0          # how quickly the speed follows the sticks (1/s)
const LOOK := 0.0032       # radians per mouse pixel

var camera := View.Shot.new()
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := 0.35
var fov := 62.0
var speed := 10.0          # m/s at normal pace (the wheel changes it)
var hover := false
var hover_h := 6.0
var orbit: Variant = null  # Vector3: the point it circles, or null
var orbit_d := 8.0


func enable(from: CameraRig) -> void:
	if from != null:
		pos = from.pos
		var d: Vector3 = from.look - from.pos
		yaw = atan2(d.x, d.z)
		pitch = atan2(-d.y, Vector2(d.x, d.z).length())
	vel = Vector3.ZERO
	orbit = null
	fov = Config.fov
	_aim()


func forward() -> Vector3:
	var cp := cos(pitch)
	return Vector3(sin(yaw) * cp, -sin(pitch), cos(yaw) * cp)


func _aim() -> void:
	camera.pos = pos
	camera.look = pos + forward()
	camera.fov = fov


func look(dx: float, dy: float) -> void:
	yaw -= dx
	pitch = clampf(pitch + dy, -1.5, 1.5)


## circle this point from where the camera is looking at it
func orbit_around(c: Vector3, dist: float) -> void:
	orbit = c
	orbit_d = clampf(dist, 1.5, 120.0)


## mv: x = right, y = up, z = forward (each -1..1); pace: 1 normal, more is faster
func update(dt: float, mv: Vector3, pace: float, world: World) -> void:
	if orbit != null:
		if mv.length_squared() > 0.01:
			orbit = null      # flying again leaves the orbit
		else:
			vel = Vector3.ZERO
			pos = (orbit as Vector3) - forward() * orbit_d
			_aim()
			return
	var fw := forward()
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	if hover:
		fw = Vector3(sin(yaw), 0.0, cos(yaw))
	var want := (fw * mv.z + right * mv.x + Vector3.UP * (0.0 if hover else mv.y)) * speed * pace      # (hovering, up / down raises and lowers the hover height instead)
	vel = vel.lerp(want, 1.0 - exp(-dt * EASE))
	pos += vel * dt
	if hover:
		hover_h = clampf(hover_h + mv.y * speed * pace * dt, 0.5, 200.0)
		var g := world.ground_pt(pos.x, pos.z, pos.y + 2.0) if world != null else -INF
		if g > -INF:
			var y := g + hover_h
			pos.y += (y - pos.y) * (1.0 - exp(-dt * 6.0))
	_aim()
