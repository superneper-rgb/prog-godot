class_name SynthAudio
extends RefCounted
## JS audio/synth-audio.js: a bounded mixer: smooth spatial gain, envelopes, variation and cleanup. Sounds were rendered (bank keys = the spec's ids); this keeps the JS limits: 12 voices, per-id limit and cooldown, 48 m range.

const MAX_ACTIVE := 12

class Active:
	var id := ""
	var voice: Variant = null   # Sfx.SpatialVoice (untyped: Sfx -> RobotAudio -> SynthAudio must not be a cycle)
	var point: Variant = null   # Vector3 (fixed), an Object with x y z (follows it), a Callable returning Vector3, or null (no position)
	var level := 0.0
	var gain := 0.0             # smoothed
	var pan := 0.0
	var cutoff := 4600.0
	var t := 0.0
	var dur := 0.0

var sfx: Variant = null
var sounds: Dictionary          # id -> {duration, gain, cooldown, limit, loop?}
var active: Array[Active] = []
var cooldowns := {}
var takes := {}
var running := false
var player: Variant = null
var time := 0.0


func _init(p_sfx: Variant, p_sounds: Dictionary) -> void:
	sfx = p_sfx
	sounds = p_sounds


func _ready_now() -> bool:
	return running


func _remove(i: int) -> void:
	var a := active[i]
	a.voice.reserved = false
	a.voice.stop_now()
	active.remove_at(i)


func stop_all() -> void:
	for i in range(active.size() - 1, -1, -1):
		_remove(i)


func _point_of(a: Variant) -> Variant:
	if a is Callable:
		return (a as Callable).call()
	if a is Vector3 or a == null:
		return a
	return Vector3(a.x, a.y, a.z)


func _spatial(a: Active, dt: float) -> void:
	var point: Variant = _point_of(a.point)
	var distance := 0.0
	if point != null and player != null:
		var pv: Vector3 = point
		distance = Vector3(pv.x - player.x, pv.y - player.y, pv.z - player.z).length()
	var attenuation := maxf(0.0, 1.0 - distance / 48.0) / (1.0 + (distance / 16.0) * (distance / 16.0)) if point != null else 1.0
	var voices := 0
	for o: Active in active:
		if o.id == a.id:
			voices += 1
	var target := a.level * attenuation / sqrt(maxf(1.0, voices))
	a.gain += (target - a.gain) * (1.0 - exp(-dt / 0.045))
	if point != null and player != null:
		var pv: Vector3 = point
		var dx: float = pv.x - player.x
		var dz: float = pv.z - player.z
		var h := Vector2(dx, dz).length()
		if h == 0.0:
			h = 1.0
		var pl_yaw: float = player.yaw
		var want := clampf((-cos(pl_yaw) * dx + sin(pl_yaw) * dz) / h * 0.8, -0.8, 0.8)
		a.pan += (want - a.pan) * (1.0 - exp(-dt / 0.04))
	var cut := maxf(1600.0, 4600.0 / (1.0 + distance * 0.035))
	a.cutoff += (cut - a.cutoff) * (1.0 - exp(-dt / 0.06))
	a.voice.lp.cutoff_hz = a.cutoff
	# the envelope the JS schedules at start: 24 ms in, the last min(0.38, 40 %) out
	var env := minf(1.0, a.t / 0.024)
	var release := minf(0.38, a.dur * 0.4)
	if a.t > a.dur - release:
		env *= clampf((a.dur - a.t) / release, 0.0, 1.0)
	var th := (a.pan + 1.0) * PI * 0.25
	var lg := cos(th)
	var rg := sin(th)
	a.voice.panner.pan = (rg - lg) / (rg + lg)
	a.voice.player.volume_db = linear_to_db(maxf(a.gain * env * (lg + rg) * 0.5, 1e-5))


func play(id: String, point: Variant = null, rate: float = 1.0) -> bool:
	if not running or not sounds.has(id) or not SfxBank.BANK.has(id):
		return false
	var spec: Dictionary = sounds[id]
	if time < float(cooldowns.get(id, 0.0)) or active.size() >= MAX_ACTIVE:
		return false
	var same := 0
	for o: Active in active:
		if o.id == id:
			same += 1
	if same >= int(spec.limit):
		return false
	if not (point is Callable) and point != null and player != null:
		var pv: Vector3 = _point_of(point)
		if Vector3(pv.x - player.x, pv.y - player.y, pv.z - player.z).length() > 48.0:
			return false
	var bank: Array = sfx._takes(id)
	if bank.is_empty():
		return false
	var take: int = takes.get(id, 0)
	takes[id] = take + 1
	var st: AudioStreamWAV = bank[take % bank.size()]
	var r: float = rate * float([0.99, 1.025, 0.975][take % 3])
	var a := Active.new()
	a.id = id
	a.point = point
	var b: Dictionary = SfxBank.BANK[id]
	var gs: Array = b.gs
	a.level = float(spec.gain) * float(gs[take % gs.size()])
	a.dur = st.get_length() / r
	a.voice = sfx._acquire()
	a.voice.reserved = true
	sfx._arm(a.voice, st, 1e-4, r, 0.0, 4600.0, -1)
	a.voice.lp.resonance = 1.065              # the JS sets this filter's Q to 0.55 dB
	active.append(a)
	_spatial(a, 1.0 / 60.0)
	cooldowns[id] = time + float(spec.cooldown)
	return true


func update(dt: float, P: Variant, enabled: bool) -> void:
	running = enabled and dt > 0.0 and P != null and not P.dead
	player = P
	if not running:
		stop_all()
		return
	time += dt
	for i in range(active.size() - 1, -1, -1):
		var a := active[i]
		a.t += dt
		if a.t >= a.dur:
			a.voice.lp.resonance = 1.122
			_remove(i)
		else:
			_spatial(a, dt)


func stop() -> void:
	running = false
	stop_all()


func reset() -> void:
	stop_all()
	cooldowns.clear()
