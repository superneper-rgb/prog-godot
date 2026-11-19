class_name RigCrew
extends RefCounted
## Prog and Pauly in Pauly's rig (the blue saucerB, levels/hub/hub_race_rig.gd): Prog in the driver's seat with his hands where the mind-driven craft has no wheel, Pauly beside him.
## board() puts them in, update() keeps them in their seats every frame after the car has been moved, leave() takes them out. Everything is in the car's own frame (its Chassis node:
## x left, y up, z forward), so it holds at any attitude: nose to the sky on the launch outside CLUB 9, upside down through a loop in the race. It knows nothing about the level.
## Prog sits by the vehicle controller's own seat (Animator.Seat); Pauly is a GreenAlienBoston whose root is turned with the car (AlienView.tilt) and whose legs, arms and back
## are set over the finished pose (AlienView.post_hook).
## The game hides Prog whenever its own camera rig is squeezed against him (Game._process: rig.too_close): a level cutscene that shows him seated says `an.actor.visible = true`
## in its pose_player, as levels/hub/rig_launch.gd does.

const HIP := 0.64            # the alien's hips above his root, standing (AlienView's hips_y): the seat puts them on the cushion
const HAND_TILT := 0.7       # where a saucer driver's hands rest (life.json car_models saucerG: the seat's "wheel")
const HAND_R := 0.12

var car: CityCars.CarModel
var pauly: GrayAlienNpc = null
var on := false
var move_player := true      # the player's own place and heading ride with the car (the rest of the game reads where he is from Game.player)
var brace := 0.0             # 0..1: pressed back into the seats (a launch, the nitro): Pauly's hands go to the deck in front of him, both heads go back
var _seat := Animator.Seat.new()
var _hands := Animator.SeatWheel.new()
var _steer := 0.0
var _brace := 0.0
var _t := 0.0


func _init(p_car: CityCars.CarModel) -> void:
	car = p_car
	_hands.tilt = HAND_TILT
	_hands.r = HAND_R
	_seat.wheel = _hands


## Prog into the driver's seat, Pauly made and put in the passenger's. Call update() the same frame.
func board() -> void:
	if on:
		return
	on = true
	_steer = 0.0
	_brace = brace
	if pauly == null:
		pauly = GreenAlienBoston.make()
		pauly.name = "PaulyInHisRig"
		pauly.top_level = true      # (the view draws in world space from R; the node only ties his life to the car's)
		car.root.add_child(pauly)
		pauly.view.post_hook = _sit
	pauly.set_shown(true)
	if Game.animator != null:
		Game.animator.seat = _seat
	_place()


## Prog out of the seat (the Animator takes his body back to where the player is), Pauly gone.
func leave() -> void:
	if not on:
		return
	on = false
	var an := Game.animator
	if an != null and an.seat == _seat:
		an.seat = null
	if pauly != null and is_instance_valid(pauly):
		pauly.view.post_hook = Callable()
		pauly.queue_free()
	pauly = null


## Out of sight without leaving the seats (the car has gone to a streak of light).
func set_shown(v: bool) -> void:
	if pauly != null and is_instance_valid(pauly):
		pauly.set_shown(v)
	if Game.animator != null and on:
		Game.animator.actor.visible = v


## Every frame, after the car has been moved. steer -1..1 leans them into the turn.
func update(time: float, dt: float, steer: float = 0.0) -> void:
	if not on:
		return
	_t = time
	var k := 1.0 - exp(-dt * 7.0)
	_steer += (clampf(steer, -1.0, 1.0) - _steer) * k
	_brace += (clampf(brace, 0.0, 1.0) - _brace) * (1.0 - exp(-dt * 10.0))
	_place()
	if pauly != null and pauly.is_shown():
		pauly.update(time, dt)


func _frame() -> Transform3D:
	var cw := car.chassis.global_transform
	return Transform3D(cw.basis.orthonormalized(), cw.origin)


func _place() -> void:
	var cw := car.chassis.global_transform
	var size := cw.basis.get_scale().y
	var F := _frame()
	var q := F.basis.get_rotation_quaternion()
	# Prog: his hips on the driver's cushion, as large as the canopy over the seat allows (Vehicles._seat_scale)
	var an := Game.animator
	if an != null:
		if an.seat != _seat:
			an.seat = _seat      # (a character respawned mid-ride comes back seated)
		var hip := cw * HubRaceRig.DRIVER
		_seat.x = hip.x
		_seat.y = hip.y
		_seat.z = hip.z
		_seat.quat = q * Quaternion(Vector3.FORWARD, _steer * 0.1)      # (leaning into the turn)
		var sit: float = Game.vehicles._sit_height() if Game.vehicles != null else 0.0
		var room := HubRaceRig.ROOF - 0.05 - HubRaceRig.DRIVER.y
		_seat.scale = size * (clampf(room / sit, 0.6, 1.0) if sit > 0.0 else 1.0)
		_seat.recline = 0.06 + 0.1 * _brace
		_seat.steer = _steer
		_seat.wheel_pos = cw * HubRaceRig.DRIVER_HANDS
		_seat.w = 1.0      # seated outright: nothing here plays a climb in
		_seat.sw = 1.0
		_seat.duck = 0.0
		_seat.hands = 1.0
	if move_player and Game.player != null:
		var P := Game.player
		P.x = cw.origin.x
		P.y = cw.origin.y
		P.z = cw.origin.z
		P.vx = 0.0
		P.vz = 0.0
		var fwd := F.basis.z
		if absf(fwd.x) + absf(fwd.z) > 0.05:
			P.yaw = atan2(fwd.x, fwd.z)
	# Pauly: his root under the passenger's cushion, turned with the car
	if pauly != null:
		var R := pauly.R
		var root := cw * HubRaceRig.PASSENGER - F.basis.y * (HIP * size)
		R.x = root.x
		R.y = root.y
		R.z = root.z
		R.yaw = 0.0
		R.lvx = 0.0
		R.lvz = 0.0
		pauly.view.tilt = F.basis * Basis.from_scale(Vector3.ONE * size)


## AlienView's post hook: the view has posed him standing; sit him. Thighs forward on the cushion, shins down, back a little into the seat, hands on his knees (on the deck in
## front of him when braced), and he looks where the car is turning.
func _sit() -> void:
	var v := pauly.view
	var p := v.pose
	var b := _brace
	var sway := sin(_t * 1.3) * 0.02
	p.pos[v.j_hips] = Vector3(0.0, HIP, 0.0)
	p.euler(v.j_hips, -0.1 - 0.12 * b, 0.0, -_steer * 0.1)
	p.euler(v.j_spine, 0.1 + sway, 0.0, -_steer * 0.08)
	p.euler(v.j_head, -0.04 - 0.22 * b, _steer * 0.3, 0.0)
	p.euler(v.j_th_l, -1.42, 0.0, 0.13)
	p.euler(v.j_th_r, -1.42, 0.0, -0.13)
	p.euler(v.j_kn_l, 1.4, 0.0, 0.0)
	p.euler(v.j_kn_r, 1.4, 0.0, 0.0)
	p.euler(v.j_ank_l, 0.1, 0.0, 0.0)
	p.euler(v.j_ank_r, 0.1, 0.0, 0.0)
	p.euler(v.j_sh_l, lerpf(-0.55, -1.25, b), 0.0, lerpf(0.1, 0.22, b))
	p.euler(v.j_sh_r, lerpf(-0.55, -1.25, b), 0.0, lerpf(-0.1, -0.22, b))
	p.euler(v.j_el_l, lerpf(-0.75, -0.25, b), 0.0, 0.0)
	p.euler(v.j_el_r, lerpf(-0.75, -0.25, b), 0.0, 0.0)
