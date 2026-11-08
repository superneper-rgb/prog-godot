class_name OmTowers
extends RefCounted
## OMNISPHERE: THE BRIDGE LOCK (JS towers.js, the freight docks, after the gunship). The bridge north to containment is a drawbridge: its first two sections are one leaf hinged at the dock edge, raised. Three glowing yellow emitters on the leaf's deck hold the lock. Shoot all three and the leaf comes down onto the bridge. Until then the leaf's floor is switched off; once it is down it is ordinary bridge.

const HX := -200.0
const HY := 18.0
const HZ := -122.0
const RAISED := 1.3


class Orb:
	var g: Node3D
	var ball: Node3D
	var halo: MeshInstance3D
	var T: OmProp
	var beacon: OmSecurity.Beacon
	var live := false
	var ph := 0.0


var sec: OmSecurity
var sets: OmSets
var audio: OmAudio
var marks: OmMarks
var alarm: Callable
var leaf: Array = []
var orbs: Array[Orb] = []
var st_on := false
var done := false
var a := RAISED
var v := 0.0
var falling := false
var clock := 0.0


func _init(lv: ExportedLevel, p_sec: OmSecurity, p_sets: OmSets, p_audio: OmAudio, p_marks: OmMarks, bridge: Array, p_alarm: Callable) -> void:
	sec = p_sec
	sets = p_sets
	audio = p_audio
	marks = p_marks
	alarm = p_alarm
	for b: OmEscape.Fall in bridge:
		if b.z > -146.0:      # segments 0 and 1
			leaf.append(b)
	for k in 3:
		var o := Orb.new()
		o.g = VhKit.one(lv, "om-orb-%d" % k)
		o.ball = VhKit.one(lv, "om-orb-%d-ball" % k)
		o.halo = MsKit.sprite8(o.ball, 0xffc020, .8, 3.4)
		o.T = OmProp.make(9890 + k, 0.0, 0.0, 0.0, .8, 1.6, 40.0)
		o.ph = k
		o.beacon = sec.shoot_beacon(o.ball, Vector3.ZERO, 2.6, 0xffd23a)
		o.beacon.set_on(false)
		orbs.append(o)


## pose the leaf at hinge angle p_a (0 = down, flat)
func _pose(p_a: float) -> void:
	for b: OmEscape.Fall in leaf:
		var d := HZ - b.z
		b.g.position = Vector3(HX, HY + d * sin(p_a), HZ - d * cos(p_a))
		b.g.rotation = Vector3(p_a, 0.0, 0.0)
		b.s.set_off(p_a > .01)


func _arm() -> void:
	for o in orbs:
		o.live = true
		o.T.dead = false
		o.T.hp = o.T.max
		o.ball.visible = true
		OmProp.arm(o.T)


func update(dt: float, _P: Player, _C: Combat) -> void:
	clock += dt
	for o in orbs:
		if o.live and (o.T.hp <= 0.0 or o.T.dead):
			o.live = false
			o.T.dead = true
			o.ball.visible = false
			var p := o.g.global_position
			Game.fx.explosion(p, 2.0)
			audio.play_at("boom", p)
			var left := 0
			for q in orbs:
				if q.live:
					left += 1
			Game.hud.toast("EMITTER DOWN  -  %d LEFT" % left if left != 0 else "BRIDGE LOCK GONE  -  STAND CLEAR", 2.0)
			if left == 0:
				falling = true
				alarm.call(4.0)
				if marks != null:
					marks.flare(1.0)
				audio.play_at("groan", Vector3(HX, 26.0, HZ - 10.0))
		if o.live:
			var w := o.ball.global_position
			o.T.x = w.x
			o.T.bx = w.x
			o.T.z = w.z
			o.T.bz = w.z
			o.T.y = w.y - .8
			o.T.kx = 0.0
			o.T.kz = 0.0
			MsKit.opa(o.halo, .6 + .3 * sin(clock * 6.25 + o.ph))
		if o.live != o.beacon.on:
			o.beacon.set_on(o.live)
	if falling:
		v += 2.2 * dt
		a = maxf(0.0, a - v * dt)
		_pose(a)
		if a <= 0.0:
			falling = false
			done = true
			sets.boom(HX, HY, HZ - 20.0, 8.0, 0.0, {"harmless": true})
			Game.fx.shake = 2.0
			audio.play_at("boomBig", Vector3(HX, HY, HZ - 20.0))


## the emitters go live
func start() -> void:
	if st_on:
		return
	st_on = true
	_arm()


func reset(stage: String, obj: int) -> void:
	st_on = false
	done = false
	falling = false
	v = 0.0
	for o in orbs:
		o.live = false
		o.T.dead = true
		o.ball.visible = true
		o.beacon.set_on(false)
	if stage == "escape":      # the collapse owns the bridge from here (it is gone)
		return
	var raised := stage != "drum" and not (stage == "docks" and obj >= 2)
	a = RAISED if raised else 0.0
	_pose(a)
	if not raised:
		done = true
		for o in orbs:
			o.ball.visible = false
	if stage == "docks" and obj == 1:
		start()
