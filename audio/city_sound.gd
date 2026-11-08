class_name CitySound
extends Node
## FOINT CITY street sound (JS levels/hub/city-sound.js): engine notes for the three cars nearest the listener (pitch from speed, a deeper note for trucks and buses), horns when a driver leans on it, the ticking of the pedestrian signal at the nearest junction (fast while WALK is lit), steam hissing from the vents, the crowd inside the dome and a siren far off now and then. Silent unless the listener is down town and the game is running; everything fades rather than cuts. ENGINE DIFFERENCE: the JS synthesises this on its audio graph; here the graph's voices are baked (assets/sfx/city/) and their pitch, filters and levels are driven live.

const DIR := "res://assets/sfx/city/"
const FX_POOL := 6
const ENGINE_HZ := 40.0      # the note engine.wav was baked at


class Voice:
	var o: AudioStreamPlayer
	var noise: AudioStreamPlayer
	var bus := -1
	var lp: AudioEffectLowPassFilter
	var pan_fx: AudioEffectPanner
	var nbus := -1
	var nf: AudioEffectBandPassFilter
	var npan: AudioEffectPanner      # (kept as the effect itself: a bus index goes stale when another level's buses are removed after this one was built)
	var g := 0.0
	var g_t := 0.0
	var f := 36.0
	var f_t := 36.0
	var lp_v := 260.0
	var lp_t := 260.0
	var nf_v := 500.0
	var nf_t := 500.0
	var pan := 0.0
	var pan_t := 0.0


var traffic: CityTraffic
var plan: CityPlan
var vents: Array = []
var arena: Dictionary = {}
var GY := 0.0
var voices: Array[Voice] = []
var hiss: AudioStreamPlayer
var crowd_a: AudioStreamPlayer
var crowd_b: AudioStreamPlayer
var crowd_f: AudioEffectBandPassFilter
var pool: Array[AudioStreamPlayer] = []
var pool_pan: Array[AudioEffectPanner] = []
var next_p := 0
var bus_v := 0.0
var hv := 0.0
var hv_t := 0.0
var crowd_v := 0.0
var crowd_t := 0.0
var crowd_tc := 1.2
var crowd_fv := 520.0
var crowd_ft := 520.0
var crowd_back := 0.0
var g2 := 0.25
var g2_t := 0.25
var next_tick := 0.0
var next_cheer := 8.0
var next_siren := 30.0
var _streams := {}


func _bus(nm: String, send: StringName = &"SFX") -> int:
	var i := AudioServer.get_bus_index(nm)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nm)
		AudioServer.set_bus_send(i, send)
	return i


func _wav(id: String, loop: bool = false) -> AudioStream:
	var key := id + ("L" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStreamWAV = load(DIR + id + ".wav")
	if loop:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.get_length() * s.mix_rate
	_streams[key] = s
	return s


func _player(id: String, bus_i: int, loop: bool) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = _wav(id, loop)
	a.bus = AudioServer.get_bus_name(bus_i)
	a.volume_db = -80.0
	add_child(a)
	return a


func setup(p_traffic: CityTraffic, p_plan: CityPlan, J: Dictionary) -> void:
	traffic = p_traffic
	plan = p_plan
	GY = J["GY"]
	vents = J.get("vents", [])
	arena = J.get("arena", {})
	next_siren = 30.0 + randf() * 40.0
	for i in 3:
		var v := Voice.new()
		v.bus = _bus("CityEngine%d" % i)
		if AudioServer.get_bus_effect_count(v.bus) == 0:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 260.0
			lp.resonance = 0.75      # (Q 2.5 dB)
			AudioServer.add_bus_effect(v.bus, lp)
			AudioServer.add_bus_effect(v.bus, AudioEffectPanner.new())
		v.lp = AudioServer.get_bus_effect(v.bus, 0)
		v.pan_fx = AudioServer.get_bus_effect(v.bus, 1)
		v.nbus = _bus("CityRoad%d" % i)
		if AudioServer.get_bus_effect_count(v.nbus) == 0:
			var bp := AudioEffectBandPassFilter.new()
			bp.cutoff_hz = 500.0
			AudioServer.add_bus_effect(v.nbus, bp)
			AudioServer.add_bus_effect(v.nbus, AudioEffectPanner.new())
		v.nf = AudioServer.get_bus_effect(v.nbus, 0)
		v.npan = AudioServer.get_bus_effect(v.nbus, 1)
		v.o = _player("engine", v.bus, true)
		v.noise = _player("noise", v.nbus, true)
		voices.append(v)
	var hb := _bus("CitySteam")
	if AudioServer.get_bus_effect_count(hb) == 0:
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 2400.0
		AudioServer.add_bus_effect(hb, hp)
	hiss = _player("noise", hb, true)
	# the crowd inside the dome: two bands of noise, the roar and the chant, swelling now and then
	var ca := _bus("CityCrowdRoar")
	if AudioServer.get_bus_effect_count(ca) == 0:
		var f := AudioEffectBandPassFilter.new()
		f.cutoff_hz = 520.0
		AudioServer.add_bus_effect(ca, f)
	crowd_f = AudioServer.get_bus_effect(ca, 0)
	crowd_a = _player("noise", ca, true)
	var cb := _bus("CityCrowdChant")
	if AudioServer.get_bus_effect_count(cb) == 0:
		var f2 := AudioEffectBandPassFilter.new()
		f2.cutoff_hz = 1300.0
		f2.resonance = 0.8
		AudioServer.add_bus_effect(cb, f2)
	crowd_b = _player("noise", cb, true)
	for i in FX_POOL:
		var bi := _bus("CityFx%d" % i)
		if AudioServer.get_bus_effect_count(bi) == 0:
			AudioServer.add_bus_effect(bi, AudioEffectPanner.new())
		pool_pan.append(AudioServer.get_bus_effect(bi, 0))
		var a := AudioStreamPlayer.new()
		a.bus = AudioServer.get_bus_name(bi)
		add_child(a)
		pool.append(a)


func _pan_of(lx: float, lz: float, lyaw: float, x: float, z: float) -> float:
	var dx := x - lx
	var dz := z - lz
	var h := U.hyp(dx, dz)
	if h == 0.0:
		h = 1.0
	return clampf((-cos(lyaw) * dx + sin(lyaw) * dz) / h, -1.0, 1.0) * minf(1.0, h / 3.0) * 0.85


## a one-shot at a spot: JS _mkBus's level (full within ref, falling to nothing at range) and pan
func _fx_at(id: String, x: float, y: float, z: float, range_m: float, ref: float, lx: float, ly: float, lz: float, lyaw: float, pitch: float = 1.0) -> void:
	var d := Vector3(x - lx, y - ly, z - lz).length()
	if d > range_m:
		return
	var k := ref / maxf(ref, d)
	k *= clampf(1.0 - d / range_m, 0.0, 1.0)
	var a := pool[next_p]
	pool_pan[next_p].pan = _pan_of(lx, lz, lyaw, x, z)
	next_p = (next_p + 1) % FX_POOL
	a.stream = _wav(id)
	a.pitch_scale = pitch
	a.volume_db = linear_to_db(maxf(k, 0.0001))
	a.play()


func _horn(car: CityTraffic.Car, lx: float, ly: float, lz: float, lyaw: float) -> void:
	var big := car.kind == &"bus" or car.kind == &"truck"
	_fx_at("horn_big" if big else "horn_car", car.x, GY, car.z, 70.0, 8.0, lx, ly, lz, lyaw, 0.98 + randf() * 0.04)
	if randf() < 0.4:      # (a second blip)
		var t := get_tree().create_timer(0.55)
		t.timeout.connect(func() -> void:
			if is_inside_tree():
				_fx_at("horn_big" if big else "horn_car", car.x, GY, car.z, 70.0, 8.0, lx, ly, lz, lyaw, 1.0))


func _approach(v: float, t: float, tc: float, dt: float) -> float:
	return v + (t - v) * (1.0 - exp(-dt / tc))


func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.00001))


func update(t: float, dt: float, active: bool) -> void:
	var S = Game.sfx
	if S == null:
		return
	var lx: float = S.listener_x
	var ly: float = S.listener_y
	var lz: float = S.listener_z
	var lyaw: float = S.listener_yaw
	var down := lz > 120.0 and ly < GY + 60.0
	var on := active and down
	bus_v = _approach(bus_v, 1.0 if on else 0.0, 0.4, dt)
	_apply(dt)
	if bus_v < 0.002:
		for v: Voice in voices:
			if v.o.playing:
				v.o.stop()
				v.noise.stop()
		if hiss.playing:
			hiss.stop()
			crowd_a.stop()
			crowd_b.stop()
		return
	if not hiss.playing:
		for v: Voice in voices:
			v.o.play(randf() * 1.5)
			v.noise.play(randf() * 1.5)
		hiss.play(randf())
		crowd_a.play(randf())
		crowd_b.play(randf())
	if not on:
		for v: Voice in voices:
			v.g_t = 0.0
		return
	# engines: the three nearest cars
	var near: Array = []
	for car: CityTraffic.Car in traffic.cars:
		if car.ctl != &"" and car.ctl != &"stop":
			continue
		var d := Vector3(car.x - lx, GY - ly, car.z - lz).length()
		if d < 60.0:
			near.append([d, car])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in voices.size():
		var v := voices[i]
		if i >= near.size():
			v.g_t = 0.0
			continue
		var d: float = near[i][0]
		var car: CityTraffic.Car = near[i][1]
		var big := car.kind == &"bus" or car.kind == &"truck"
		var k := (0.1 if big else 0.07) / (1.0 + (d / 7.0) * (d / 7.0)) * (1.0 if d < 60.0 else 0.0)
		v.f_t = (26.0 if big else 36.0) + car.v * (3.2 if big else 5.5) + (6.0 if car.kind == &"hatch" else 0.0)
		v.lp_t = 180.0 + car.v * 40.0
		v.nf_t = 300.0 + car.v * 60.0
		v.g_t = k * (0.55 + minf(1.0, car.v / 8.0) * 0.6)
		v.pan_t = _pan_of(lx, lz, lyaw, car.x, car.z)
	for car: CityTraffic.Car in traffic.honks:
		_horn(car, lx, ly, lz, lyaw)
	# the pedestrian signal ticking at the nearest junction
	next_tick -= dt
	if next_tick <= 0.0:
		var best: CityPlan.Junction = null
		var bd := 24.0
		for n: CityPlan.Junction in plan.nodes:
			if not n.signal_on:
				continue
			var d := U.hyp(n.x - lx, n.z - lz)
			if d < bd:
				bd = d
				best = n
		if best != null:
			var walk := CityPlan.signal_at(best, &"x", t) == CityPlan.G or CityPlan.signal_at(best, &"z", t) == CityPlan.G
			_fx_at("tick_fast" if walk else "tick_slow", best.x - 6.75, GY + 2.7, best.z - 6.75, 30.0, 4.0, lx, ly, lz, lyaw)
			next_tick = 0.32 if walk else 1.0
		else:
			next_tick = 0.5
	# steam hiss
	var h := 0.0
	for q: Dictionary in vents:
		var d := U.hyp(float(q.x) - lx, float(q.z) - lz)
		h = maxf(h, 0.025 / (1.0 + (d / 2.5) * (d / 2.5)))
	hv_t = h
	# the dome: louder as you near the gate, a cheer every so often
	if not arena.is_empty():
		var d := maxf(0.0, U.hyp(float(arena.x) - lx, float(arena.z) - lz) - float(arena.r))
		var k := 0.05 / (1.0 + (d / 18.0) * (d / 18.0))
		next_cheer -= dt
		var swell := 1.0
		if next_cheer < 0.0:
			swell = 2.6
			crowd_ft = 700.0
			crowd_back = 2.0
			next_cheer = 9.0 + randf() * 14.0
		crowd_t = k * swell
		crowd_tc = 0.35 if swell > 1.0 else 1.2
		g2_t = 0.18 + 0.12 * sin(t * 1.9) * sin(t * 0.7)
		if crowd_back > 0.0:
			crowd_back -= dt
			if crowd_back <= 0.0:
				crowd_ft = 520.0
	next_siren -= dt
	if next_siren <= 0.0:
		_fx_at("siren", lx + randf_range(-40.0, 40.0), ly, lz + randf_range(-40.0, 40.0), 1e6, 1e6, lx, ly, lz, lyaw)
		next_siren = 70.0 + randf() * 90.0


## setTargetAtTime for everything, once a frame
func _apply(dt: float) -> void:
	for v: Voice in voices:
		v.g = _approach(v.g, v.g_t, 0.15, dt)
		v.f = _approach(v.f, v.f_t, 0.12, dt)
		v.lp_v = _approach(v.lp_v, v.lp_t, 0.15, dt)
		v.nf_v = _approach(v.nf_v, v.nf_t, 0.2, dt)
		v.pan = _approach(v.pan, v.pan_t, 0.1, dt)
		v.o.pitch_scale = maxf(0.05, v.f / ENGINE_HZ)
		v.o.volume_db = _db(v.g * bus_v)
		v.noise.volume_db = _db(v.g * 0.25 * bus_v)
		v.lp.cutoff_hz = v.lp_v
		v.nf.cutoff_hz = v.nf_v
		v.pan_fx.pan = v.pan
		v.npan.pan = v.pan
	hv = _approach(hv, hv_t, 0.3, dt)
	hiss.volume_db = _db(hv * bus_v)
	crowd_v = _approach(crowd_v, crowd_t, crowd_tc, dt)
	crowd_fv = _approach(crowd_fv, crowd_ft, 0.4 if crowd_ft > 600.0 else 1.0, dt)
	crowd_f.cutoff_hz = crowd_fv
	g2 = _approach(g2, g2_t, 0.3, dt)
	crowd_a.volume_db = _db(crowd_v * bus_v)
	crowd_b.volume_db = _db(crowd_v * g2 * bus_v)
