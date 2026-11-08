class_name Cutscene
extends Node
## What every story cutscene shares (JS cutscenes/*.js createX): `on`, a `camera` Shot for the frame end (View.CUTSCENE_ORDER), update(dt) while on, skip(). Registered by name in Game.cutscenes. While one runs the world is held still and X skips it (Game._process). enter_cine / leave_cine: JS body.classList dlg, cine: the HUD gone and the cutscene's letterbox.

var on := false
var camera := View.Shot.new()


func update(_dt: float) -> void:
	pass


func skip() -> void:
	pass


func enter_cine(bars: bool = true) -> void:
	if bars:
		Game.ui.dialog.set_bars(true, true)
	Game.hud.set_suppressed(true)


func leave_cine() -> void:
	Game.ui.dialog.set_bars(false)
	if Game.started:
		Game.hud.set_suppressed(false)
	Inp.guard_arm()


## A thumbstick for the player in a cutscene: only forward, nothing pressed (JS playerStep's inp, on DEAD_INPUT's buttons)
class StepInput:
	extends Inp.InputView
	func _init() -> void:
		move = Inp.Stick.new()
	func btn(n: StringName) -> Inp.Btn:
		return Inp.dead.btn(n)


var _step_inp: StepInput = null      # (not a static: a script's static holding an instance of its own inner class keeps every script it reaches alive at exit)


## JS playerStep(dt, speed01, heading): the real player physics, driven like a thumbstick
func player_step(dt: float, k: float, heading: float) -> void:
	if _step_inp == null:
		_step_inp = StepInput.new()
	_step_inp.move.y = k
	_step_inp.move.mag = k
	var pl := Game.player
	pl.vx = 0.0
	pl.vz = 0.0
	pl.update_with(dt, _step_inp, _step_inp, heading)


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


## where Prog's face is: his head bone, a little up
static func face_of_player() -> Vector3:
	var an: Animator = Game.animator
	if an != null and an.by_key.has(&"head"):
		return an.bone_world_pos(an.by_key[&"head"].bone) + Vector3(0.0, 0.06, 0.0)
	var pl := Game.player
	return Vector3(pl.x, pl.y + 1.62, pl.z)


func shot(pos: Vector3, look: Vector3, fov: float) -> void:
	camera.pos = pos
	camera.look = look
	camera.fov = fov


static func ease_(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func ease_in(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u


static func ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


## add to a pose bone by its JS key (a.pose[k][0] += x ...)
static func add_pose(an: Animator, k: StringName, x: float, y: float, z: float) -> void:
	var i := Animator.KEYS.find(k)
	if i >= 0:
		an.pose[i] += Vector3(x, y, z)


## JS sfx.tone / sfx.noise one-shots, rendered once and kept: tones [[t, dur, f0, f1, type, gain, attack]], noises [[t, dur, type, f0, f1, q, gain, attack]]
static func synth(dur: float, tones: Array, noises: Array) -> AudioStreamWAV:
	var R := 44100
	var b := OfflineSynth.make(dur, R)
	for e: Array in noises:
		OfflineSynth.noise(b, R, e[0], {"dur": e[1], "type": e[2], "f0": e[3], "f1": e[4], "q": e[5], "gain": e[6], "attack": e[7]})
	for e: Array in tones:
		OfflineSynth.tone(b, R, e[0], {"dur": e[1], "f0": e[2], "f1": e[3], "type": e[4], "gain": e[5], "attack": e[6]})
	return OfflineSynth.wav(b, R)
