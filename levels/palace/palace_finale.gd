class_name PalaceFinale
extends Cutscene
## The Pervert Palace's finale (user, 2026-11-19), at the top of crane A in its man-basket, as the user wrote it: Sambo hangs himself from the crane; his pretend human body snaps off at the neck,
## leaving the head with the little alien inside; he throws a fit, seen from the stream camera's point of view with the chat scrolling, calling him a scam fraud who faked it; he says fuck it and
## presses the big red button on a remote; cut to Earth, a boojie ship comes into frame (his rich parents) and launches a drop pod; it crashes into the site and opens on a replacement mech; his
## head, still dangling from the crane, sprouts robot legs, drops down onto the site and climbs into its place as the mech's head. Then Prog drops to the slab and the fight begins.
## One clock (t) drives it all, shot by shot (the times are the constants below). The stream camera's shots wear its frame (ui/stream_chat.gd pov) and shake in the hand. It is the level's `cine`
## while `on`: the world runs; Sambo (his SamboBody, cut at the neck: npcs/sambo/sambo_body.gd split), the falling suit, the head's legs (head_legs.gd), the pod and mech (sambo_mech.gd) and
## the space shot (palace_space.gd) are all posed from t here. X skips to the fight.

const TOP_Y := 46.0                                  # the man-basket's floor at the top
const ANCHOR := Vector3(176.4, 51.35, 201.0)         # where the rope is tied to the jib's bottom chord
const ROPE := 7.0
const CAM_SHAKE := 0.012
# the clock
const T_LINE1 := 0.4
const T_LINE2 := 10.4
const T_NOOSE := 11.2
const T_RAIL := 13.6
const T_JUMP := 16.9
const T_SNAP := 17.75
const T_LAND := 19.4
const T_FIT := 20.6
const T_READ1 := 31.0
const T_READ2 := 38.2
const T_READ3 := 43.8
const T_FUCK := 49.9
const T_REMOTE := 50.9
const T_PRESS := 52.4
const T_SPACE := 53.0
const T_SKY := T_SPACE + PalaceSpace.DUR
const T_IMPACT := T_SKY + 2.2
const T_OPEN := T_IMPACT + 2.4
const T_LEGS := T_OPEN + 2.8
const T_DROP := T_LEGS + 1.4
const T_SCUTTLE := T_DROP + 1.4
const T_CLIMB := T_SCUTTLE + 2.5
const T_SEAT := T_CLIMB + 1.6
const T_POWER := T_SEAT + 1.0
const T_STEP := T_POWER + 2.0
const T_BASKET := T_STEP + 3.8
const T_PROG := T_BASKET + 1.2
const T_END := T_PROG + 2.8

var lv: PalaceLevel
var play := false      # (core/view.gd: not a playable cutscene)
var t := 0.0
var _prev := 0.0
var space: PalaceSpace
var corpse: SamboBody            # the suit's body, once it has come off
var legs: HeadLegs
var _rope: MeshInstance3D
var _noose: MeshInstance3D
var _remote: Node3D
var _button: MeshInstance3D
var _pov := false
var _shake := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _body_v := Vector3.ZERO
var _body_p := Vector3.ZERO
var _body_spin := Vector3.ZERO
var _body_down := false
var _swing := 0.0                # the head's pendulum (radians about z) after the snap
var _swing_v := 0.0
var _head_at := Vector3.ZERO     # where the head is, world (its neck stump)
var _snap_snd: AudioStreamPlayer
var _boom_snd: AudioStreamPlayer
var _click_snd: AudioStreamPlayer
var _skipped := false


func setup(level: PalaceLevel) -> void:
	lv = level
	_rng.seed = 13
	space = PalaceSpace.new()
	lv.add_child(space)
	space.build(lv)
	corpse = SamboBody.new()
	corpse.name = "SamboSuit"
	lv.add_child(corpse)
	corpse.selfie = 0.0
	corpse.ring_on = false
	corpse.visible = false
	legs = HeadLegs.fit(lv.sambo.body)
	_rope = _line_node(Color(0.32, 0.24, 0.14))
	_noose = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.07
	tm.outer_radius = 0.095
	tm.rings = 16
	tm.ring_segments = 6
	_noose.mesh = tm
	_noose.material_override = PalaceKit.plain(Color(0.32, 0.24, 0.14), 0.95)
	_noose.visible = false
	lv.add_child(_noose)
	_remote = Node3D.new()
	_remote.name = "Remote"
	lv.add_child(_remote)
	var rb := BoxMesh.new()
	rb.size = Vector3(0.05, 0.025, 0.085)
	var rm := MeshInstance3D.new()
	rm.mesh = rb
	rm.material_override = PalaceKit.plain(Color(0.12, 0.12, 0.13), 0.4, 0.3)
	_remote.add_child(rm)
	var bt := CylinderMesh.new()
	bt.top_radius = 0.016
	bt.bottom_radius = 0.018
	bt.height = 0.012
	_button = MeshInstance3D.new()
	_button.mesh = bt
	_button.material_override = PalaceKit.glow(Color(1.0, 0.05, 0.03), 0.4)
	_button.position = Vector3(0.0, 0.017, 0.012)
	_remote.add_child(_button)
	_remote.visible = false
	_snap_snd = _snd(Cutscene.synth(0.9, [[0.0, 0.08, 900.0, 300.0, &"square", 0.25, 0.001], [0.02, 0.5, 140.0, 60.0, &"sine", 0.4, 0.002]], [[0.0, 0.18, &"bandpass", 2400.0, 800.0, 1.2, 0.5, 0.001]]))
	_boom_snd = _snd(Cutscene.synth(2.4, [[0.0, 2.0, 55.0, 24.0, &"sine", 0.9, 0.003]], [[0.0, 1.8, &"lowpass", 900.0, 90.0, 0.7, 0.9, 0.002], [0.0, 0.3, &"highpass", 3000.0, 1200.0, 0.7, 0.4, 0.001]]))
	_click_snd = _snd(Cutscene.synth(0.6, [[0.0, 0.03, 2200.0, 1800.0, &"square", 0.2, 0.001], [0.12, 0.35, 1320.0, 1320.0, &"sine", 0.18, 0.005]], []))


func _snd(st: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = &"SFX"
	lv.add_child(p)
	return p


func _line_node(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PalaceKit.tube_mesh(5)
	mi.material_override = PalaceKit.plain(c, 0.95)
	mi.top_level = true
	mi.visible = false
	lv.add_child(mi)
	return mi


func start() -> void:
	on = true
	t = 0.0
	_prev = -1.0
	_skipped = false
	_body_down = false
	_swing = 0.0
	_swing_v = 0.0
	enter_cine(false)
	lv.bo.clear_enemies()
	lv.sambo.held = true
	lv.sambo.body.split(&"all")
	lv.sambo.body.selfie = 0.0
	lv.sambo.body.ring_on = false
	lv.chat.show_chat(true)
	lv.chat.set_mood(&"hype", 3.8)
	lv.chat.add_viewers(6000.0)
	update(0.0)


func skip() -> void:
	if not on or _skipped:
		return
	_skipped = true
	t = T_END
	_finish()


func _crossed(at: float) -> bool:
	return _prev < at and t >= at


func update(dt: float) -> void:
	if not on:
		return
	if Game.ui.dlg_req or (Inp.using_pad and Inp.btn(&"attack").pressed):      # X: on to the fight
		Game.ui.dlg_req = false
		Inp.btn(&"attack").pressed = false
		skip()
		return
	_prev = t
	t += dt
	_events()
	_sambo(dt)
	_suit(dt)
	_pod(dt)
	_prog(dt)
	_camera(dt)
	if t >= T_END:
		_finish()


# ---------------------------------------------------------------------------------------------- what happens when

func _events() -> void:
	var S := lv.sambo
	var C := lv.chat
	if _crossed(T_LINE1):
		S.say("s_hang_01")
	if _crossed(T_LINE2):
		S.say("s_hang_02")
	if _crossed(T_SNAP):
		_snap_snd.play()
		Game.fx.shake = maxf(Game.fx.shake, 0.3)
		lv.sambo.body.split(&"head")
		corpse.split(&"body")
		corpse.visible = true
		corpse.global_transform = lv.sambo.body.global_transform
		_body_p = corpse.global_position
		_body_v = Vector3(-1.4, -6.0, 0.4)
		_body_spin = Vector3(_rng.randf_range(-3.0, -1.5), _rng.randf_range(-2.0, 2.0), _rng.randf_range(1.5, 3.5))
		_swing_v = -1.1
	if _crossed(T_FIT - 0.6):
		C.set_mood(&"scam", 6.5)
		C.add_viewers(45000.0)
		for i in 4:
			C.push(StreamChat.USERS[_rng.randi() % StreamChat.USERS.size()], ["SCAM FRAUD", "RUBBER NECK LMAOOO", "IT WAS A SUIT", "SCUM FUCK"][i])
	if _crossed(T_FIT):
		S.say("s_hang_03")
	if _crossed(T_READ1):
		S.say("s_hang_04")
	if _crossed(T_READ2):
		S.say("s_hang_05")
	if _crossed(T_READ3):
		S.say("s_hang_06")
	if _crossed(T_FUCK):
		S.say("s_hang_07")
	if _crossed(T_PRESS):
		_click_snd.play()
		(_button.material_override as StandardMaterial3D).emission_energy_multiplier = 8.0
	if _crossed(T_SPACE):
		space.shot(true)
		C.set_mood(&"ship", 4.5)
	if _crossed(T_SKY):
		space.shot(false)
		_remote.visible = false
	if _crossed(T_IMPACT):
		_boom_snd.play()
		Game.fx.explosion(PalaceMechAt.pod() + Vector3(0.0, 1.0, 0.0), 6.5)
		Game.fx.dust(PalaceMechAt.pod(), 40, 7.0)
		Game.fx.shake = maxf(Game.fx.shake, 1.2)
		C.add_viewers(60000.0)
	if _crossed(T_POWER + 0.4):
		S.say("s_hang_08")
	if _crossed(T_STEP + 1.2):
		C.set_mood(&"boss", 4.0)
		C.push("skullet_enjoyer", "CAMERAMAN WE BELIEVE IN YOU")
	if _crossed(T_PROG + 0.4):
		lv.sambo.say("p_mech_01", 1.6)


# ---------------------------------------------------------------------------------------------- Sambo

## Sambo, his rope and his noose, then his head on its own: in the basket talking to the stream; the noose over his head; up on the rail; off; the snap; the head on the rope throwing its fit;
## the remote; then the legs, the drop, the scuttle over to the mech, the climb, the seat
func _sambo(dt: float) -> void:
	var S := lv.sambo
	var B := S.body
	var bp := lv.basket.pos
	var stand := Vector3(bp.x - 1.15, bp.y, bp.z + 0.1)
	var rail := Vector3(bp.x - 1.62, bp.y + 1.1, bp.z + 0.1)
	var cam_side := Vector3(bp.x + 0.9, bp.y + 1.6, bp.z - 0.4)
	var head_off := Vector3(0.0, HeadLegs.HIP_Y, 0.0)      # (the neck stump, from the body's origin)
	if t < T_SNAP:
		var p := stand
		if t >= T_RAIL:
			p = stand.lerp(rail, ease_(seg(t, T_RAIL, T_RAIL + 1.0)))
		if t >= T_JUMP:      # off the rail backward, out over the slab, falling
			var u := t - T_JUMP
			p = rail + Vector3(-1.6 * u, 2.2 * u - 4.9 * u * u, 0.0)
		S.pos = p
		S.yaw = PI / 2.0
		B.global_position = p
		B.rotation = Vector3(0.0, PI / 2.0, (t - T_JUMP) * 0.6 if t > T_JUMP else 0.0)
		B.speed = 0.0
		B.talking = S.talking()
		B.look_on = true
		B.look_target = cam_side
		B.gesture = &"fists" if (t > T_LINE2 + 5.0 and t < T_JUMP) else &""
		if t < T_LINE2:
			B.gesture = &"point" if fmod(t, 4.0) > 2.6 else &""
			B.point_at = cam_side
		B.update(dt)
		# the rope: from the jib to his hand, then (from T_NOOSE) to his neck, the noose round it
		var neck := B.global_transform * head_off
		var hand := neck + Vector3(0.25, 0.1, 0.0)
		var end := hand if t < T_NOOSE + 0.8 else neck
		_rope.visible = t >= T_NOOSE - 0.6
		if _rope.visible:
			PalaceSite.stretch(_rope, ANCHOR, end, 0.018)
		_noose.visible = t >= T_NOOSE + 0.8
		if _noose.visible:
			_noose.global_transform = Transform3D(Basis(), neck + Vector3(0.0, 0.0, 0.0))
		_head_at = neck
		return
	# after the snap: the head on the rope, a pendulum about the anchor, then its legs and the drop
	if t < T_DROP:
		var g := 9.8 / ROPE
		_swing_v += (-g * sin(_swing) - 0.5 * _swing_v) * dt
		_swing += _swing_v * dt
		var hang := ANCHOR + Vector3(sin(_swing) * ROPE, -cos(_swing) * ROPE, 0.0)
		if t < T_SNAP + 0.25:      # (the jerk as it takes the weight)
			hang += Vector3(0.0, (1.0 - seg(t, T_SNAP, T_SNAP + 0.25)) * -0.3, 0.0)
		_head_at = hang
		_place_head(hang, PI / 2.0 + _swing * 0.6 + sin(t * 1.3) * 0.15, Vector3(0.0, 0.0, _swing))
		_rope.visible = true
		PalaceSite.stretch(_rope, ANCHOR, hang, 0.018)
		_noose.visible = true
		_noose.global_transform = Transform3D(Basis(), hang)
		# the fit: the little alien thrashes in the hatch while he shouts; he looks up at the camera (the stream)
		var fit := t > T_FIT and t < T_PRESS + 0.6
		B.talking = S.talking()
		B.look_on = true
		var jit := Vector3(sin(t * 23.0), sin(t * 17.0) * 0.5, cos(t * 19.0)) * (0.6 if fit and B.talking else 0.1)
		B.look_target = cam_side + jit
		B.update(dt)
		# the remote: up out of the hatch in his hand, the big red button pressed
		_remote.visible = t > T_REMOTE and t < T_SKY + 0.1
		if _remote.visible:
			var up := ease_(seg(t, T_REMOTE, T_REMOTE + 0.6))
			var m := B.mouth_world() + Vector3(0.1, 0.02 + 0.1 * up, 0.04)
			_remote.global_transform = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.5), m)
			var press := seg(t, T_PRESS - 0.1, T_PRESS) - seg(t, T_PRESS + 0.3, T_PRESS + 0.5)
			_button.position.y = 0.017 - 0.008 * press
		# the legs come out of the stump
		legs.out = ease_(seg(t, T_LEGS, T_LEGS + 1.0))
		legs.brace = 0.0
		legs.stride = 0.6 * legs.out
		legs.step += dt * 2.0 * legs.out
		legs.pose()
		return
	# the drop: off the rope, down to the slab, landing braced on the legs
	var land := Vector3(ANCHOR.x, PalaceSite.ly(PalaceSite.NF), ANCHOR.z)
	var stand_off := Vector3(0.0, HeadLegs.STAND + 0.02, 0.0)
	var mech := lv.mech
	if t < T_SCUTTLE:
		var u := seg(t, T_DROP, T_SCUTTLE - 0.25)
		var from := ANCHOR + Vector3(sin(_swing) * ROPE, -cos(_swing) * ROPE, 0.0)
		_head_at = from.lerp(land + stand_off, u * u)
		_rope.visible = t < T_DROP + 0.05
		_noose.visible = false
		_place_head(_head_at, PI / 2.0 + 0.6 * (1.0 - u), Vector3.ZERO)
		legs.out = 1.0
		legs.brace = 1.0 - seg(t, T_SCUTTLE - 0.25, T_SCUTTLE)
		legs.stride = 0.0
		legs.pose()
		if _crossed(T_SCUTTLE - 0.25):
			Game.fx.dust(land, 10, 1.5)
			Game.fx.sparks(land, 8, 3.0, Vector3.UP, 0xffffff)
		B.look_on = false
		B.update(dt)
		return
	# the scuttle over to the mech, round to its back
	var back := Vector3(mech.x, mech.y, mech.z) - Vector3(sin(mech.yaw), 0.0, cos(mech.yaw)) * 1.5
	if t < T_CLIMB:
		var u := ease_(seg(t, T_SCUTTLE, T_CLIMB))
		var mid := land.lerp(back, 0.5) + Vector3(2.0, 0.0, -1.5)
		var p := land.lerp(mid, u).lerp(mid.lerp(back, u), u)
		var ahead := land.lerp(mid, minf(1.0, u + 0.05)).lerp(mid.lerp(back, minf(1.0, u + 0.05)), minf(1.0, u + 0.05))
		var dirv := ahead - p
		_head_at = p + stand_off
		_place_head(_head_at, atan2(dirv.x, dirv.z) if dirv.length() > 0.001 else 0.0, Vector3.ZERO)
		legs.out = 1.0
		legs.brace = 0.0
		legs.stride = 1.0
		legs.step += dt * 7.0
		legs.pose()
		B.update(dt)
		return
	# up its back to the collar, then into the socket; the legs fold away
	if t < T_SEAT:
		var u := ease_(seg(t, T_CLIMB, T_SEAT))
		var sock := mech.socket_xf().origin
		var p := (back + Vector3(0.0, 0.3, 0.0)).lerp(sock - Vector3(sin(mech.yaw), 0.0, cos(mech.yaw)) * 0.6 + Vector3(0.0, 0.2, 0.0), u)
		_head_at = p
		_place_head(p, mech.yaw, Vector3(-0.9 * (1.0 - u), 0.0, 0.0))
		legs.stride = 1.0
		legs.step += dt * 9.0
		legs.pose()
		B.update(dt)
		return
	if mech.head == null:
		mech.seat_head(B, legs)
	var su := ease_(seg(t, T_SEAT, T_SEAT + 0.5))
	var from_xf := Transform3D(Basis(Vector3.UP, mech.yaw), _head_at - Vector3(0.0, HeadLegs.HIP_Y, 0.0))
	mech.head_to_socket(su, from_xf)
	legs.tuck = su
	legs.stride = 0.0
	legs.pose()
	B.look_on = true
	B.look_target = Game.camera.global_position
	B.talking = S.talking()
	B.update(dt)


## The head on its own, its neck stump at `at`: the SamboBody is placed so its rest neck lands there, turned to `yaw`, tilted by `tilt` (radians about x, y, z)
func _place_head(at: Vector3, yaw: float, tilt: Vector3) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis.from_euler(tilt)
	lv.sambo.body.global_transform = Transform3D(b, at - b * Vector3(0.0, HeadLegs.HIP_Y, 0.0))


# ---------------------------------------------------------------------------------------------- the suit's body

## The body that came off falls to the slab, turning over, and lies there (it stays for the fight)
func _suit(dt: float) -> void:
	if t < T_SNAP or not corpse.visible:
		return
	var floor_y := PalaceSite.ly(PalaceSite.NF)
	if not _body_down:
		_body_v.y -= 9.8 * dt
		_body_p += _body_v * dt
		var b := corpse.global_transform.basis.rotated(Vector3.RIGHT, _body_spin.x * dt).rotated(Vector3.UP, _body_spin.y * dt).rotated(Vector3.FORWARD, _body_spin.z * dt)
		corpse.global_transform = Transform3D(b.orthonormalized(), _body_p)
		if _body_p.y <= floor_y + 0.25:
			_body_down = true
			_lay_suit(floor_y)
			Game.fx.dust(Vector3(_body_p.x, floor_y, _body_p.z), 18, 2.0)
			Game.fx.shake = maxf(Game.fx.shake, 0.25)
			_boom_snd.pitch_scale = 2.2
			_boom_snd.play()
	corpse.speed = 0.0
	corpse.update(dt)


func _lay_suit(floor_y: float) -> void:
	_body_p.y = floor_y + 0.18
	corpse.global_transform = Transform3D(Basis(Vector3.UP, 2.4) * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.FORWARD, 0.2), Vector3(_body_p.x, _body_p.y, _body_p.z))


# ---------------------------------------------------------------------------------------------- the pod and the mech

func _pod(_dt: float) -> void:
	var mech := lv.mech
	if t < T_SKY:
		return
	if t < T_IMPACT:
		var u := seg(t, T_SKY, T_IMPACT)
		mech.pod_fall(u * u)
		return
	mech.pod_fall(1.0)
	mech.pod_open(seg(t, T_OPEN, T_OPEN + 1.8))
	var dome := mech.P_.get("dome") as Node3D
	if dome != null:      # open over the empty socket until the head is in, then down
		var rest: Transform3D = mech.R_["dome"]
		var open := 1.0 - ease_(seg(t, T_SEAT + 0.4, T_SEAT + 1.0))
		dome.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, -deg_to_rad(70.0) * open), rest.origin)
	mech._set_power(ease_(seg(t, T_POWER, T_POWER + 1.6)) * (0.7 + 0.3 * sin(t * 30.0) if t < T_POWER + 1.0 else 1.0))
	if t >= T_STEP:      # out of the pod and onto the slab, stomping
		var u := ease_(seg(t, T_STEP, T_STEP + 3.0))
		var from := Vector3(SamboMech.POD_AT.x, SamboMech.POD_AT.y + 0.3, SamboMech.POD_AT.z)
		var p := from.lerp(SamboMech.START, u)
		var before := Vector2(mech.x, mech.z)
		mech.x = p.x
		mech.z = p.z
		mech.y = lerpf(from.y, SamboMech.START.y, u)
		mech.yaw = lerp_angle(mech.yaw, PI, u)
		mech.speed = 2.0 if u < 1.0 else 0.0
		mech.step_ph += Vector2(mech.x, mech.z).distance_to(before) / 1.8
		mech.mode = &"idle"
	mech._pose(0.0)
	if mech.head != null and t >= T_SEAT + 0.5:
		mech.head_to_socket()


# ---------------------------------------------------------------------------------------------- Prog

## Prog: in the basket at the top, filming; at the end the basket comes down hard and he jumps out onto the slab
func _prog(dt: float) -> void:
	var P := Game.player
	var bp := lv.basket.pos
	if t >= T_BASKET:
		var u := seg(t, T_BASKET, T_BASKET + 1.0)
		var y := lerpf(TOP_Y, PalaceSite.ly(PalaceSite.NF), u * u)
		lv.basket.move_to(Vector3(bp.x, y, bp.z))
		if _crossed(T_BASKET + 1.0):
			Game.fx.shake = maxf(Game.fx.shake, 0.5)
			lv.basket.set_gate(true)
	if t < T_PROG:
		P.x = lv.basket.pos.x + 0.55
		P.z = lv.basket.pos.z - 0.35
		P.y = lv.basket.pos.y
		P.yaw = -PI / 2.0
	else:
		var u := ease_(seg(t, T_PROG, T_PROG + 0.6))
		P.x = lerpf(lv.basket.pos.x + 0.55, 176.6, u)
		P.z = lerpf(lv.basket.pos.z - 0.35, 202.4, u)
		P.y = PalaceSite.ly(PalaceSite.NF) + sin(u * PI) * 0.8
		P.yaw = lerp_angle(-PI / 2.0, -2.4, u)
	P.vx = 0.0
	P.vz = 0.0
	P.vy = 0.0


func pose_player(an: Animator) -> void:
	an.actor.visible = not _pov


# ---------------------------------------------------------------------------------------------- the camera

func _camera(dt: float) -> void:
	var bp := lv.basket.pos
	var C := lv.chat
	var cam_pov := Vector3(bp.x + 0.75, bp.y + 1.62, bp.z - 0.42)      # the stream camera on his shoulder
	var pov := (t < T_JUMP + 0.2) or (t >= T_FIT - 0.4 and t < T_PRESS - 0.3)
	if pov != _pov:
		_pov = pov
		C.pov(pov)
	_shake = _shake.lerp(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * CAM_SHAKE, 1.0 - exp(-dt * 6.0))
	if t < T_JUMP + 0.2:      # STREAM: Sambo in the basket, the city behind him
		var face := lv.sambo.body.head_world() + Vector3(0.0, 0.05, 0.0)
		var push := ease_(seg(t, T_RAIL, T_JUMP))
		shot(cam_pov + _shake, face.lerp(face + Vector3(-1.0, 0.2, 0.0), push) + _shake * 4.0, lerpf(55.0, 48.0, ease_(seg(t, 0.0, 9.0))))
	elif t < T_LAND - 0.2:      # WIDE: off the rail, the rope goes taut, the suit tears at the neck
		shot(Vector3(171.6, 48.8, 206.2), Vector3(176.6, 44.6, 201.0), 50.0)
	elif t < T_FIT - 0.4:      # LOW: the suit hits the slab
		var bpos := corpse.global_position
		shot(Vector3(170.4, 30.7, 205.6), bpos.lerp(Vector3(175.8, 30.5, 201.2), 0.3) + Vector3(0.0, 0.8, 0.0), 58.0)
	elif t < T_PRESS - 0.3:      # STREAM: down over the rail at the head on the rope, the little alien losing it
		var h := _head_at + Vector3(0.0, 0.12, 0.0)
		var zoom := ease_(seg(t, T_FIT, T_READ3 + 4.0))
		shot(cam_pov + _shake * 1.5, h + _shake * 6.0, lerpf(44.0, 30.0, zoom))
	elif t < T_SPACE:      # CLOSE: the remote and the big red button
		var m := _remote.global_position
		shot(m + Vector3(0.5, 0.25, 0.55), m, 34.0)
	elif t < T_SKY:      # SPACE: Earth, the yacht, the pod
		var r: Array = space.pose(seg(t, T_SPACE, T_SKY))
		shot(r[0], r[1], 46.0)
	elif t < T_IMPACT + 0.15:      # the sky over the site: a fireball coming down
		var pp := lv.mech.pod.global_position
		shot(Vector3(158.0, 30.9, 194.0), pp + Vector3(0.0, 2.0, 0.0), 60.0)
	elif t < T_OPEN:      # the impact, wide
		shot(Vector3(149.0, 35.0, 196.0) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * Game.fx.shake * 0.4, SamboMech.POD_AT + Vector3(0.0, 2.2, 0.0), 54.0)
	elif t < T_LEGS:      # the pod opens on the mech
		shot(Vector3(158.4, 31.9, 203.6), SamboMech.POD_AT + Vector3(0.0, 3.2, 0.0), 50.0)
	elif t < T_DROP:      # the head on the rope grows legs
		shot(_head_at + Vector3(-1.6, 0.6, -1.9), _head_at, 38.0)
	elif t < T_SCUTTLE:      # it drops
		shot(Vector3(171.0, 31.4, 197.0), _head_at, 50.0)
	elif t < T_CLIMB:      # it scuttles over, low behind it
		var hd := lv.sambo.body.global_transform.basis.z
		shot(_head_at - hd * 1.6 + Vector3(-0.6, 0.55, 0.0), _head_at + hd * 2.0, 52.0)
	elif t < T_POWER:      # up the mech's back, into the collar
		shot(Vector3(lv.mech.x + 3.4, 33.6, lv.mech.z - 3.6), lv.mech.socket_xf().origin, 46.0)
	elif t < T_BASKET:      # it powers up and steps out, low and heroic
		var mp := Vector3(lv.mech.x, lv.mech.y, lv.mech.z)
		shot(Vector3(161.0, 30.9, 199.0), mp + Vector3(0.0, 3.4, 0.0), 56.0)
	else:      # the basket comes down; Prog gets out
		var P := Game.player
		var pp := Vector3(P.x, P.y + 1.4, P.z)
		shot(Vector3(171.8, 31.6, 197.2), pp.lerp(Vector3(lv.mech.x, lv.mech.y + 3.0, lv.mech.z), 0.25), 52.0)


# ---------------------------------------------------------------------------------------------- the end of it

## Everything where the fight finds it (also what a skip jumps to)
func _finish() -> void:
	on = false
	if space.visible:
		space.shot(false)
	_pov = false
	lv.chat.pov(false)
	_remote.visible = false
	_rope.visible = false
	_noose.visible = false
	var mech := lv.mech
	mech.pod_fall(1.0)
	mech.pod_open(1.0)
	var dome := mech.P_.get("dome") as Node3D
	if dome != null:
		dome.transform = mech.R_["dome"]
	if mech.head == null:
		lv.sambo.body.split(&"head")
		mech.seat_head(lv.sambo.body, legs)
	legs.out = 1.0
	legs.tuck = 1.0
	legs.pose()
	mech.x = SamboMech.START.x
	mech.z = SamboMech.START.z
	mech.y = SamboMech.START.y
	mech.yaw = PI
	mech.speed = 0.0
	mech.mode = &"idle"
	mech._set_power(1.0)
	mech.head_to_socket()
	if not _body_down:
		corpse.visible = true
		corpse.split(&"body")
		_body_p = Vector3(175.8, 0.0, 201.2)
		_body_down = true
		_lay_suit(PalaceSite.ly(PalaceSite.NF))
	lv.basket.move_to(Vector3(lv.basket.pos.x, PalaceSite.ly(PalaceSite.NF), lv.basket.pos.z))
	lv.basket.set_gate(true)
	var P := Game.player
	P.x = 176.6
	P.z = 202.4
	P.y = PalaceSite.ly(PalaceSite.NF)
	P.yaw = -2.4
	Game.rig.yaw = -2.4
	Game.rig.snap_to(P)
	Game.animator.actor.visible = true
	lv.chat.set_mood(&"boss", 3.6)
	leave_cine()
	lv.finale_done()


## Where the pod comes down (for the events above)
class PalaceMechAt:
	static func pod() -> Vector3:
		return SamboMech.POD_AT
