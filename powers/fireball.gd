class_name Fireball
extends Node3D
## INCINERATE (JS powers/fireball.js, the fire implant): a fireball cast from the left hand in power mode. Tap fire: a small, fast fireball (direct hit only). Hold fire: the ball forms in the palm and slowly grows and burns hotter (CHARGE_TIME to full); let go and it flies. A charged ball (k >= BLAST_K) bursts on impact and burns everything in a radius. The caller charges the mana. A few embers drift off the left hand whenever the implant is equipped.

const CHARGE_TIME := 1.8      # seconds of holding to reach a full charge
const BLAST_K := 0.25         # charge from which the ball explodes on impact
const SPEED0 := 34.0          # m/s: small ball / full charge
const SPEED1 := 24.0
const R0 := 0.09              # ball radius (m)
const R1 := 0.34
const DMG0 := 25.0            # direct hit
const DMG1 := 100.0
const SPLASH0 := 18.0         # blast damage at the centre (falls off to 40% at the edge)
const SPLASH1 := 60.0
const RAD0 := 1.4             # blast radius (m) from BLAST_K to a full charge
const RAD1 := 3.8
const LIFE := 2.5             # seconds before a ball that hit nothing burns out


class Ball:
	var g: Node3D
	var core: MeshInstance3D
	var halo: MeshInstance3D
	var core_m: ShaderMaterial
	var halo_m: ShaderMaterial
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var dx := 0.0
	var dy := 0.0
	var dz := 1.0
	var k := 0.0
	var r := R0
	var t := 0.0
	var speed := 0.0
	var acc := 0.0


class Blast:
	var flash: MeshInstance3D
	var ring: MeshInstance3D
	var flash_m: ShaderMaterial
	var ring_m: ShaderMaterial
	var R := 1.0
	var t := 0.0
	var dur := 0.4


var balls: Array[Ball] = []
var _flames: PowerPuffs
var _smoke: PowerPuffs
var _free_balls: Array[Ball] = []
var _free_blasts: Array[Blast] = []
var _blasts: Array[Blast] = []
var _held: Ball = null
var _idle_acc := 0.0
var _t := 0.0
var _ball_light: OmniLight3D
var _blast_light: OmniLight3D
var _blast_i := 0.0
var _tex_core: Texture2D
var _tex_halo: Texture2D
var _quad: QuadMesh
var _roar: AudioStreamPlayer
var _roar_low: AudioStreamPlayer
var _roar_fx: AudioEffectBandPassFilter
var _whoosh: Array[AudioStreamWAV] = []
var _boom: Array[AudioStreamWAV] = []
var _sizzle: AudioStreamWAV = null


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


static func radial_tex(stops: Array, size: int = 128) -> GradientTexture2D:
	var gr := Gradient.new()
	var off := PackedFloat32Array()
	var col := PackedColorArray()
	for s: Array in stops:
		off.append(s[0])
		col.append(s[1])
	gr.offsets = off
	gr.colors = col
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _ready() -> void:
	name = "Fireball"
	_quad = QuadMesh.new()
	_flames = PowerPuffs.new(self, true, 8, 0.35, 0.6)
	_smoke = PowerPuffs.new(self, false, 7, 0.35, 0.6)
	_tex_core = radial_tex([[0.0, Color(1, 1, 240.0 / 255.0, 1)], [0.22, Color(1, 228.0 / 255.0, 140.0 / 255.0, 1)], [0.5, Color(1, 130.0 / 255.0, 30.0 / 255.0, 0.85)], [0.78, Color(200.0 / 255.0, 40.0 / 255.0, 0, 0.35)], [1.0, Color(120.0 / 255.0, 10.0 / 255.0, 0, 0)]])
	_tex_halo = radial_tex([[0.0, Color(1, 170.0 / 255.0, 60.0 / 255.0, 0.6)], [0.4, Color(1, 90.0 / 255.0, 20.0 / 255.0, 0.28)], [1.0, Color(1, 40.0 / 255.0, 0, 0)]])
	_ball_light = _light(0xff7a2a, 9.0)
	_blast_light = _light(0xff8a3a, 16.0)
	_build_roar()


func _light(col: int, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color.hex((col << 8) | 0xff)
	l.light_energy = 0.0
	l.omni_range = rng
	l.omni_attenuation = 2.0
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l


func _sprite_part(tex: Texture2D) -> Array:
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/menu_scene/menu_glow.gdshader")
	m.set_shader_parameter(&"map", tex)
	m.set_shader_parameter(&"billboard", true)
	m.render_priority = 9
	var o := MeshInstance3D.new()
	o.mesh = _quad
	o.material_override = m
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.extra_cull_margin = 8.0
	return [o, m]


func _make_ball() -> Ball:
	if not _free_balls.is_empty():
		var f: Ball = _free_balls.pop_back()
		f.g.visible = true
		f.acc = 0.0
		return f
	var b := Ball.new()
	b.g = Node3D.new()
	b.g.name = "fireball"
	var h := _sprite_part(_tex_halo)
	var c := _sprite_part(_tex_core)
	b.halo = h[0]
	b.halo_m = h[1]
	b.core = c[0]
	b.core_m = c[1]
	b.g.add_child(b.halo)
	b.g.add_child(b.core)
	add_child(b.g)
	return b


func _drop_ball(b: Ball) -> void:
	b.g.visible = false
	_free_balls.append(b)


func _look(b: Ball, flick: float) -> void:
	var k := b.k
	var r := b.r * (1.0 + 0.08 * sin(_t * 31.0 + b.x) + 0.05 * randf()) * flick
	b.g.position = Vector3(b.x, b.y, b.z)
	b.core.scale = Vector3.ONE * (r * 2.6)
	b.halo.scale = Vector3.ONE * (r * (4.6 + 1.2 * k))
	b.core_m.set_shader_parameter(&"col", Vector3(1.0, 0.82 + 0.18 * k, 0.65 + 0.35 * k))
	b.halo_m.set_shader_parameter(&"opacity", 0.55 + 0.45 * k)


func _flame(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float) -> void:
	_flames.emit(x, y, z, vx, vy, vz, life, s0, s1, PowerPuffs.FLAME, 2.2, 1.8)


func _ember(x: float, y: float, z: float, vx: float, vy: float, vz: float) -> void:
	_flames.emit(x, y, z, vx, vy, vz, _rnd(0.5, 1.1), 0.035, 0.015, PowerPuffs.EMBER, 0.6, 0.4)


func _puff_smoke(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float) -> void:
	_smoke.emit(x, y, z, vx, vy, vz, life, s0, s1, PowerPuffs.SMOKE, 1.2, 0.7)


# ---------------- sound ----------------

static func _loud(p: Vector3) -> float:
	var L: Vector3 = Game.rig.pos if Game.rig != null else p
	return 1.0 / (1.0 + L.distance_to(p) * 0.18)


## the charging roar: looping noise through a band-pass + a low rumble (its pitch and level are live)
func _build_roar() -> void:
	if AudioServer.get_bus_index(&"PowerRoar") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, &"PowerRoar")
		AudioServer.set_bus_send(i, &"SFX")
		var f := AudioEffectBandPassFilter.new()
		f.cutoff_hz = 300.0
		f.resonance = 0.5
		AudioServer.add_bus_effect(i, f)
	_roar_fx = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"PowerRoar"), 0) as AudioEffectBandPassFilter
	_roar = AudioStreamPlayer.new()
	_roar.bus = &"PowerRoar"
	_roar.stream = load("res://assets/sfx/city/noise.wav")
	add_child(_roar)
	_roar_low = AudioStreamPlayer.new()
	_roar_low.bus = &"SFX"
	var rate := 22050
	var s := OfflineSynth.make(1.0, rate)
	for i in s.size():
		s[i] = sin(TAU * 55.0 * i / rate)
	_roar_low.stream = OfflineSynth.wav(s, rate, true)
	add_child(_roar_low)


func _roar_start() -> void:
	if not _roar.playing:
		_roar.volume_db = -80.0
		_roar_low.volume_db = -80.0
		_roar.play(randf())
		_roar_low.play()


func _roar_stop() -> void:
	_roar.stop()
	_roar_low.stop()


func _sounds() -> void:
	if not _whoosh.is_empty():
		return
	var R := 44100
	for k: float in [0.0, 0.5, 1.0]:
		var d := 0.35 + 0.2 * k
		var a := OfflineSynth.make(maxf(d, 0.3) + 0.05, R)
		OfflineSynth.noise(a, R, 0.0, {"type": &"bandpass", "f0": 1400.0, "f1": 260.0, "q": 1.1, "gain": 0.35 + 0.45 * k, "attack": 0.01, "dur": d})
		OfflineSynth.tone(a, R, 0.0, {"type": &"sawtooth", "f0": 160.0, "f1": 60.0, "gain": 0.06 + 0.1 * k, "dur": 0.3})
		_whoosh.append(OfflineSynth.wav(a, R))
		var bd := 0.7 + 0.5 * k
		var b := OfflineSynth.make(maxf(bd, 0.95) + 0.05, R)
		OfflineSynth.noise(b, R, 0.0, {"type": &"lowpass", "f0": 1800.0, "f1": 90.0, "gain": 0.6 + 0.6 * k, "attack": 0.004, "dur": bd})
		OfflineSynth.tone(b, R, 0.0, {"type": &"sine", "f0": 95.0, "f1": 32.0, "gain": 0.7 + 0.6 * k, "dur": 0.6 + 0.3 * k})
		OfflineSynth.noise(b, R, 0.05, {"type": &"bandpass", "f0": 600.0, "f1": 150.0, "q": 0.8, "gain": 0.25, "dur": 0.9})
		_boom.append(OfflineSynth.wav(b, R))
	var s := OfflineSynth.make(0.35, R)
	OfflineSynth.noise(s, R, 0.0, {"type": &"highpass", "f0": 2500.0, "f1": 1200.0, "gain": 0.35, "dur": 0.3})
	OfflineSynth.noise(s, R, 0.0, {"type": &"lowpass", "f0": 1200.0, "f1": 200.0, "gain": 0.3, "dur": 0.2})
	_sizzle = OfflineSynth.wav(s, R)


func _pick(list: Array[AudioStreamWAV], k: float) -> AudioStreamWAV:
	return list[clampi(roundi(k * 2.0), 0, 2)]


# ---------------- impact ----------------

static func _hittable(o: Target) -> bool:
	return o != null and not o.dead and o.actor_state == null


func _impact(b: Ball, tg: Target) -> void:
	var k := b.k
	var from := {"x": b.x, "y": b.y, "z": b.z}
	if tg != null:
		Game.combat.damage(tg, lerpf(DMG0, DMG1, k), from, 1.0 + 4.0 * k, {"x": b.x, "y": b.y, "z": b.z, "kind": "target", "nx": -b.dx, "ny": -b.dy, "nz": -b.dz})
	if k >= BLAST_K:      # a charged ball bursts: burns everything around it
		var kk := (k - BLAST_K) / (1.0 - BLAST_K)
		var R := lerpf(RAD0, RAD1, kk)
		var dmg := lerpf(SPLASH0, SPLASH1, kk)
		for o: Target in Game.combat.targets:
			if not _hittable(o) or o == tg:
				continue
			var d := Vector3(o.x - b.x, o.y + (o.h if o.h != 0.0 else 1.8) * 0.5 - b.y, o.z - b.z).length()
			if d < R + (o.r if o.r != 0.0 else 0.5):
				Game.combat.damage(o, dmg * (1.0 - 0.6 * clampf(d / R, 0.0, 1.0)), from, 3.0 + 5.0 * kk, null)
		_blast(b.x, b.y, b.z, R, kk)
	else:      # a small one just splashes and hisses out
		for i in 18:
			var a := _rnd(0.0, 6.28)
			var e := _rnd(-0.3, 1.0)
			_flame(b.x, b.y, b.z, cos(a) * _rnd(1.0, 3.0), e * 2.0, sin(a) * _rnd(1.0, 3.0), _rnd(0.2, 0.45), b.r * 1.6, b.r * 0.6)
		for i in 5:
			_puff_smoke(b.x, b.y, b.z, _rnd(-0.4, 0.4), _rnd(0.3, 0.9), _rnd(-0.4, 0.4), _rnd(0.8, 1.4), 0.25, 0.8)
		for i in 6:
			_ember(b.x, b.y, b.z, _rnd(-3.0, 3.0), _rnd(0.0, 3.0), _rnd(-3.0, 3.0))
		_sounds()
		Game.sfx.clip(_sizzle, {"gain": _loud(Vector3(b.x, b.y, b.z)), "wet": 0.3})
	_drop_ball(b)


func _blast(x: float, y: float, z: float, R: float, kk: float) -> void:
	var B: Blast
	if not _free_blasts.is_empty():
		B = _free_blasts.pop_back()
	else:
		B = Blast.new()
		var f := _sprite_part(_tex_core)
		var r := _sprite_part(_tex_halo)
		B.flash = f[0]
		B.flash_m = f[1]
		B.ring = r[0]
		B.ring_m = r[1]
		add_child(B.flash)
		add_child(B.ring)
	B.flash.position = Vector3(x, y, z)
	B.ring.position = Vector3(x, y, z)
	B.flash.visible = true
	B.ring.visible = true
	B.R = R
	B.t = 0.0
	B.dur = 0.38 + 0.12 * kk
	_blasts.append(B)
	for i in roundi(70.0 + 110.0 * kk):
		var a := _rnd(0.0, 6.28)
		var e := _rnd(-0.35, 1.0)
		var sp := _rnd(0.6, 1.0) * R * 3.2
		var c := sqrt(1.0 - e * e)
		_flame(x, y, z, cos(a) * c * sp, e * sp, sin(a) * c * sp, _rnd(0.35, 0.8), _rnd(0.5, 1.2) * (0.6 + 0.6 * kk), _rnd(0.2, 0.5))
	for i in int(24.0 + 20.0 * kk):
		_ember(x, y, z, _rnd(-1.0, 1.0) * R * 3.0, _rnd(0.5, 1.5) * R * 2.0, _rnd(-1.0, 1.0) * R * 3.0)
	for i in int(16.0 + 16.0 * kk):
		var a := _rnd(0.0, 6.28)
		_puff_smoke(x + cos(a) * R * 0.4, y, z + sin(a) * R * 0.4, cos(a) * _rnd(0.5, 1.6), _rnd(0.6, 1.6), sin(a) * _rnd(0.5, 1.6), _rnd(1.4, 2.6), 0.6 + 0.4 * kk, 2.2 + 1.4 * kk)
	_blast_light.position = Vector3(x, y + 0.4, z)
	_blast_i = 30.0 + 40.0 * kk
	_blast_light.omni_range = R * 5.0
	_blast_light.visible = true
	if Game.fx != null and Game.rig != null:
		var d: float = Game.rig.pos.distance_to(Vector3(x, y, z))
		Game.fx.shake = maxf(Game.fx.shake, (0.18 + 0.45 * kk) * clampf(1.0 - d / 28.0, 0.0, 1.0))
	_sounds()
	Game.sfx.clip(_pick(_boom, kk), {"gain": _loud(Vector3(x, y, z)), "wet": 0.5})
	Game.combat.events.append({"t": "fireBlast", "x": x, "y": y, "z": z, "r": R})


# ---------------- per frame ----------------

## release: the held ball (or a new one) flies from origin toward aim with charge k
func launch(origin: Vector3, aim: Vector3, k: float) -> Ball:
	var b := _held if _held != null else _make_ball()
	_held = null
	_roar_stop()
	b.k = clampf(k, 0.0, 1.0)
	b.r = lerpf(R0, R1, b.k)
	b.speed = lerpf(SPEED0, SPEED1, b.k)
	b.t = 0.0
	var dv := aim - origin
	var l := dv.length()
	if l < 0.0001:
		l = 1.0
	dv /= l
	b.dx = dv.x
	b.dy = dv.y
	b.dz = dv.z
	b.x = origin.x + dv.x * (b.r + 0.1)
	b.y = origin.y + dv.y * (b.r + 0.1)
	b.z = origin.z + dv.z * (b.r + 0.1)
	balls.append(b)
	_look(b, 1.0)
	_sounds()
	Game.sfx.clip(_pick(_whoosh, b.k), {"gain": 0.5 + 0.5 * _loud(Vector3(b.x, b.y, b.z)), "wet": 0.2})
	Game.combat.events.append({"t": "fireCast", "x": b.x, "y": b.y, "z": b.z, "k": b.k})
	return b


## ctx: { hand, dir, idle, charging, k } (left hand world position, aim direction, implant equipped, fire held in power mode, charge 0..1) or null
func update(dt: float, c: Variant) -> void:
	_t += dt
	var light_at: Variant = null
	var light_i := 0.0
	# ---- the ball in the palm while fire is held: grows, brightens, roars ----
	if c != null and c.charging:
		var hand: Vector3 = c.hand
		var dir: Vector3 = c.dir
		if _held == null:
			_held = _make_ball()
			_roar_start()
		var k: float = c.k
		_held.k = k
		_held.r = lerpf(R0, R1, k)
		_held.x = hand.x + dir.x * (0.08 + _held.r)
		_held.y = hand.y + dir.y * (0.08 + _held.r) + 0.02
		_held.z = hand.z + dir.z * (0.08 + _held.r)
		_look(_held, 1.0 + 0.07 * sin(_t * 20.0) if k > 0.98 else 1.0)
		_held.acc += dt * (30.0 + 230.0 * k)
		while _held.acc >= 1.0:
			_held.acc -= 1.0
			var ox := _rnd(-1.0, 1.0)
			var oy := _rnd(-1.0, 1.0)
			var oz := _rnd(-1.0, 1.0)
			var ol := Vector3(ox, oy, oz).length()
			if ol < 0.0001:
				ol = 1.0
			var rr := _held.r * 0.8 / ol
			_flame(_held.x + ox * rr, _held.y + oy * rr, _held.z + oz * rr, ox / ol * (0.2 + 0.9 * k), 0.5 + 1.6 * k, oz / ol * (0.2 + 0.9 * k), _rnd(0.2, 0.45), _held.r * _rnd(0.9, 1.6), _held.r * 0.4)
			if randf() < 0.06 + 0.1 * k:
				_ember(_held.x, _held.y, _held.z, _rnd(-1.0, 1.0), _rnd(1.0, 2.5), _rnd(-1.0, 1.0))
		if _roar.playing:
			_roar_fx.cutoff_hz = 260.0 + 750.0 * k + randf() * 80.0
			var g := (0.05 + 0.16 * k) * (1.0 + 0.2 * sin(_t * 20.0) if k > 0.98 else 1.0)
			_roar.volume_db = linear_to_db(maxf(g, 1e-5))
			_roar_low.volume_db = linear_to_db(maxf(g * (0.25 + 0.5 * k), 1e-5))
			_roar_low.pitch_scale = (48.0 + 46.0 * k) / 55.0
		light_at = Vector3(_held.x, _held.y, _held.z)
		light_i = 2.0 + 10.0 * k
	elif _held != null:      # let go without casting (power mode off / out of mana): it gutters out
		for i in 10:
			_flame(_held.x, _held.y, _held.z, _rnd(-0.5, 0.5), _rnd(0.5, 1.5), _rnd(-0.5, 0.5), _rnd(0.2, 0.4), _held.r * 1.4, _held.r * 0.3)
		_puff_smoke(_held.x, _held.y, _held.z, 0.0, 0.5, 0.0, 1.2, 0.2, 0.6)
		_drop_ball(_held)
		_held = null
		_roar_stop()
	# ---- embers off the hand while the implant is equipped ----
	if c != null and c.idle and not c.charging:
		var hand: Vector3 = c.hand
		_idle_acc += dt * 16.0
		while _idle_acc >= 1.0:
			_idle_acc -= 1.0
			_flame(hand.x + _rnd(-0.05, 0.05), hand.y + _rnd(-0.03, 0.05), hand.z + _rnd(-0.05, 0.05), _rnd(-0.1, 0.1), _rnd(0.3, 0.7), _rnd(-0.1, 0.1), _rnd(0.25, 0.5), _rnd(0.05, 0.09), 0.02)
		if randf() < dt * 3.0:
			_ember(hand.x, hand.y, hand.z, _rnd(-0.3, 0.3), _rnd(0.5, 1.2), _rnd(-0.3, 0.3))
		if light_at == null:
			light_at = hand
			light_i = 0.9 + 0.3 * sin(_t * 13.0)
	# ---- balls in flight ----
	for i in range(balls.size() - 1, -1, -1):
		var b := balls[i]
		b.t += dt
		var left := b.speed * dt
		var hit := false
		var tg: Target = null
		var w: World = Game.world
		while left > 1e-4 and not hit:
			var st := minf(0.2, left)
			left -= st
			var nx := b.x + b.dx * st
			var ny := b.y + b.dy * st
			var nz := b.z + b.dz * st
			var floor_y: float = w.projectile_floor_at.call(nx, nz) if w.projectile_floor_at.is_valid() else w.projectile_floor_y
			hit = w.point_solid(nx, ny, nz) or ny < floor_y
			if not hit:
				for o: Target in Game.combat.targets:
					if _hittable(o) and U.hyp(nx - o.x, nz - o.z) < (o.r if o.r != 0.0 else 0.5) + b.r * 0.7 and ny > o.y - b.r and ny < o.y + (o.h if o.h != 0.0 else 1.8) + b.r:
						hit = true
						tg = o
						break
			if not hit:
				b.x = nx
				b.y = ny
				b.z = nz
		if hit or b.t > LIFE:
			_impact(b, tg)
			balls.remove_at(i)
			continue
		_look(b, 1.0)
		b.acc += dt * (110.0 + 90.0 * b.k)
		while b.acc >= 1.0:
			b.acc -= 1.0
			_flame(b.x + _rnd(-1.0, 1.0) * b.r * 0.4, b.y + _rnd(-1.0, 1.0) * b.r * 0.4, b.z + _rnd(-1.0, 1.0) * b.r * 0.4, -b.dx * 1.2 + _rnd(-0.4, 0.4), -b.dy * 1.2 + _rnd(-0.2, 0.6), -b.dz * 1.2 + _rnd(-0.4, 0.4), _rnd(0.18, 0.42), b.r * _rnd(1.3, 2.1), b.r * 0.3)
		if randf() < dt * 8.0 * (0.3 + b.k):
			_puff_smoke(b.x, b.y, b.z, 0.0, 0.3, 0.0, _rnd(0.6, 1.1), b.r * 1.2, b.r * 3.0)
		light_at = Vector3(b.x, b.y, b.z)
		light_i = 4.0 + 10.0 * b.k
	# ---- blasts: a white-hot flash and a wide orange bloom, both fading ----
	for i in range(_blasts.size() - 1, -1, -1):
		var B := _blasts[i]
		B.t += dt
		var u := B.t / B.dur
		if u >= 1.0:
			B.flash.visible = false
			B.ring.visible = false
			_free_blasts.append(B)
			_blasts.remove_at(i)
			continue
		var e := 1.0 - pow(1.0 - u, 3.0)
		B.flash.scale = Vector3.ONE * (B.R * (0.6 + 1.6 * e))
		B.flash_m.set_shader_parameter(&"opacity", 1.0 - u)
		B.ring.scale = Vector3.ONE * (B.R * (1.0 + 2.6 * e))
		B.ring_m.set_shader_parameter(&"opacity", (1.0 - u) * 0.9)
	_blast_i *= exp(-7.0 * dt)
	_blast_light.light_energy = _blast_i / PI
	_blast_light.visible = _blast_i > 0.05
	if light_at != null:
		_ball_light.position = light_at
		_ball_light.light_energy = light_i / PI
		_ball_light.visible = true
	else:
		_ball_light.visible = false
	_flames.step(dt)
	_smoke.step(dt)


func quiet() -> void:
	if _roar.playing:
		_roar.volume_db = -80.0
		_roar_low.volume_db = -80.0
