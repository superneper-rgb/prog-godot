class_name CityAmbience
extends Node
## JS city-ambience.js: the quiet wet-night city, from short field recordings: distant traffic, rain (a storm's hammering downpour instead in the Back Alley), the shop's music inside it, CLUB 9's music leaking out of its door.
## ENGINE DIFFERENCES: the JS crossfades each loop's last 1.5 s over its start when it decodes the file; here two players do the same crossfade live, because script cannot read an mp3's samples. Its loudness (targetRms / rms) was measured in the browser: all four hit their maxGain, so that is the constant here.
## The JS only ever loads the rain of the first level played, so coming from the hub the alley kept the hub's drizzle: its own comment says the alley has the heavy rain, so here it follows the level.

const CLUB_RANGE := 8.0     # metres from the CLUB 9 door within which its muffled music can be heard on the street
const OVERLAP := 1.5


## One file, one bus with its filters, two players for the crossfade.
class Loop:
	var stream: AudioStream
	var length := 0.0
	var a: AudioStreamPlayer
	var b: AudioStreamPlayer
	var gain := 1.0         # JS targetRms / rms
	var ramp := 0.0         # JS's 3.5 s linear start
	var x := -1.0           # crossfade position; < 0 = none running
	var on := false
	var crossfades := true

	func _init(owner: Node, path: String, bus_name: StringName, high: float, low: float, p_gain: float, q: float = 0.5) -> void:
		stream = load(path)
		length = stream.get_length()
		gain = p_gain
		var i := AudioServer.get_bus_index(bus_name)
		if i < 0:
			AudioServer.add_bus()
			i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"SFX")
			var res := pow(10.0, q / 20.0)      # (Web Audio filter Q is in dB)
			if high > 0.0:
				var h := AudioEffectHighPassFilter.new()
				h.cutoff_hz = high
				h.resonance = res
				AudioServer.add_bus_effect(i, h)
			var l := AudioEffectLowPassFilter.new()
			l.cutoff_hz = low
			l.resonance = res
			AudioServer.add_bus_effect(i, l)
		a = AudioStreamPlayer.new()
		b = AudioStreamPlayer.new()
		a.stream = stream
		b.stream = stream
		a.bus = bus_name
		b.bus = bus_name
		owner.add_child(a)
		owner.add_child(b)

	func start() -> void:
		if on:
			return
		on = true
		a.play()
		x = -1.0

	func stop() -> void:
		on = false
		a.stop()
		b.stop()
		ramp = 0.0
		x = -1.0

	func set_level(k: float, dt: float) -> void:
		if not on:
			return
		ramp = minf(1.0, ramp + dt / 3.5)
		var v := k * gain * ramp
		if x < 0.0 and a.get_playback_position() >= length - OVERLAP:
			x = 0.0
			b.play()
		if x >= 0.0:
			x += dt / OVERLAP
			if x >= 1.0:
				a.stop()
				var s := a
				a = b
				b = s
				x = -1.0
		if x >= 0.0:
			a.volume_db = linear_to_db(maxf(v * (1.0 - x), 1e-5))
			b.volume_db = linear_to_db(maxf(v * x, 1e-5))
		else:
			a.volume_db = linear_to_db(maxf(v, 1e-5))
		if not a.playing:         # (a stalled stream comes back rather than leaving the street silent)
			a.play()


var storm := false
var level := -1.0
var rain_level := -1.0
var _bus_v := 0.0
var _bus_tc := 1.8
var _rain_v := 1.0
var _traffic: Loop
var _rain_heavy: Loop
var _rain_far: Loop
var _rain_light: Loop
var _shop: Loop
var _club: Loop
var _shop_v := 0.0
var _club_v := 0.0
var _club_idle := 0.0
var shop_level := -1.0
var club_level := -1.0
var shop_tc := 1.1
var club_tc := 0.35
var tv_duck := false
var _ready_now := false


func _init_loops() -> void:
	if _ready_now:
		return
	_ready_now = true
	_traffic = Loop.new(self, "res://assets/sfx/city-distant-traffic.mp3", &"AmbTraffic", 90.0, 1500.0, 0.3)
	_rain_heavy = Loop.new(self, "res://assets/sfx/city-rain.mp3", &"AmbRainHeavy", 100.0, 8000.0, 0.95)
	_rain_far = Loop.new(self, "res://assets/sfx/city-rain-distant.mp3", &"AmbRainFar", 70.0, 2600.0, 0.6)
	_rain_light = Loop.new(self, "res://assets/sfx/city-light-rain.mp3", &"AmbRainLight", 150.0, 5200.0, 0.28)
	_shop = Loop.new(self, "res://assets/sfx/foint-n-shoot-megacorp-outlet.mp3", &"AmbShop", 0.0, 5600.0, 1.0, 0.45)
	_club = Loop.new(self, "res://assets/sfx/club9-timbre-industrial.mp3", &"AmbClub", 90.0, 520.0, 1.0, 0.6)
	_traffic.start()


## Web Audio setTargetAtTime
static func _approach(v: float, target: float, tc: float, dt: float) -> float:
	return target + (v - target) * exp(-dt / maxf(tc, 0.001))


func update(dt: float, active: bool, duck: bool = false, sheltered: bool = false, inside_shop: bool = false, club_distance: float = INF) -> void:
	if active:
		_init_loops()
	if not _ready_now:
		return
	var want_rain: Array[Loop] = []
	if storm:
		want_rain = [_rain_heavy, _rain_far]
	else:
		want_rain = [_rain_light]
	for r: Loop in [_rain_heavy, _rain_far, _rain_light]:
		if want_rain.has(r):
			if active:
				r.start()
		else:
			r.stop()
	var lv := (0.34 if duck else 0.82) if active else 0.0
	var rl := 0.2 if sheltered else 1.0
	rain_level = rl
	_rain_v = _approach(_rain_v, rl, 0.8, dt)
	if lv != level:
		level = lv
		_bus_tc = 1.8 if active else 0.35
	_bus_v = _approach(_bus_v, lv, _bus_tc, dt)
	_traffic.set_level(_bus_v * 0.95, dt)
	for r: Loop in want_rain:
		r.set_level(_bus_v * 0.88 * _rain_v, dt)
	var music := inside_shop and active
	var sl := (0.01 if tv_duck else 0.04) if music else 0.0      # tv_duck: the shop's CRT is playing a video (was 0.24, then 0.11: both too loud)
	if sl != shop_level:
		if music and shop_level <= 0.0:
			_shop.start()
		shop_level = sl
		shop_tc = (0.4 if tv_duck else 1.1) if music else 0.55
	_shop_v = _approach(_shop_v, sl, shop_tc, dt)
	if _shop.on:
		_shop.ramp = 1.0
		_shop.set_level(_shop_v, dt)
		if not music and _shop_v < 0.0005:
			_shop.stop()
	# the music leaking out of the door: only audible on the pavement right by the entrance (CLUB_RANGE m), silent everywhere else on the street
	var prox := clampf(1.0 - club_distance / CLUB_RANGE, 0.0, 1.0) if active and not inside_shop else 0.0
	var cl := 0.075 * pow(prox, 1.4) if prox > 0.0 else 0.0
	if cl > 0.0:
		_club.start()
		_club_idle = 0.0
	else:
		_club_idle += dt
	if cl != club_level:
		club_level = cl
		club_tc = 0.35 if cl > 0.0 else 0.5
	_club_v = _approach(_club_v, cl, club_tc, dt)
	if _club.on:
		_club.ramp = 1.0
		_club.set_level(_club_v, dt)
	if _club_idle > 4.0 and _club.on:      # out of earshot for a few seconds: stop the loop altogether
		_club.stop()
		_club_v = 0.0
