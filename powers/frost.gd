class_name Frost
extends Node3D
## FROST (JS powers/frost.js, the cryo implant): hold fire in power mode to spray a cone of freezing mist from the left hand. Enemies in the cone take a little cold damage and CHILL (0..1): they slow down and ice crystals grow on them. At full chill they FREEZE solid inside an ice shell for FREEZE seconds: no AI, no animation. A punch or hammer fist on a frozen enemy SHATTERS it: instant kill, the body is gone in a burst of ice. Anything that kills a frozen enemy shatters it too. Cold air sinks off the left hand whenever the implant is equipped.
## Enemy state lives on the target: T.chill (0..1), T.frozen_t (seconds left frozen), T.shattered (hide its view while dead).

const RANGE := 8.5          # cone length (m)
const CONE := 0.34          # half angle (rad)
const CHILL_RATE := 0.65    # chill per second at point blank (falls to half at the far end of the cone)
const HEAVY_RATE := 0.45    # heavy enemies chill at this fraction of the rate
const THAW := 0.3           # chill lost per second out of the spray
const FREEZE := 4.0         # seconds frozen (heavy enemies: 60%)
const DPS := 8.0            # cold damage per second in the cone
const TICK := 0.1
const MAXS := 220


class Ice:
	var g: Node3D
	var shell: MeshInstance3D
	var crystals: Array = []      # [MeshInstance3D, size, threshold]


class Shard:
	var life := 0.0
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var q := Quaternion.IDENTITY
	var w := Vector3.ZERO
	var s := 0.0
	var floor_y := 0.0


var _mist: PowerPuffs
var _flakes: PowerPuffs
var _ice_mat: StandardMaterial3D
var _crystal_mat: StandardMaterial3D
var _crystal_mesh: ArrayMesh
var _shell_mesh: ArrayMesh
var _ice: Dictionary = {}      # Target -> Ice
var _ice_free: Array[Ice] = []
var _shards_mm: MultiMesh
var _S: Array[Shard] = []
var _si := 0
var _light: OmniLight3D
var _hiss: AudioStreamPlayer
var _crackle: AudioStreamWAV = null
var _smash: AudioStreamWAV = null
var _thaw: AudioStreamWAV = null
var _tick := 0.0
var _t := 0.0
var _acc := 0.0
var _idle_acc := 0.0
var _sweep := 1.0


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


## an octahedron stretched along Y, flat shaded (JS OctahedronGeometry(1, 0).scale)
static func _octa(sx: float, sy: float, sz: float) -> ArrayMesh:
	var V := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var F := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4], [1, 4, 2]]
	var P := PackedVector3Array()
	var I := PackedInt32Array()
	for f: Array in F:
		var o := P.size()
		for i: int in f:
			var q: Vector3 = V[i]
			P.append(Vector3(q.x * sx, q.y * sy, q.z * sz))
		I.append_array([o, o + 1, o + 2])
	return Goggles.indexed_mesh(P, I)


## JS: CylinderGeometry(1, 1.08, 1, 7, 3), every vertex pushed about a little, base at y = 0
static func _shell() -> ArrayMesh:
	var P := PackedVector3Array()
	var I := PackedInt32Array()
	var seg := 7
	var rows := 3
	var ring := PackedVector3Array()
	for r in rows + 1:
		var v := float(r) / rows
		var y := 0.5 - v
		var rad := 1.0 + 0.08 * v
		for s in seg:
			var a := TAU * s / seg
			ring.append(Vector3(sin(a) * rad * _rnd(0.88, 1.12), y + (_rnd(-0.05, 0.05) if absf(y) < 0.49 else 0.0) + 0.5, cos(a) * rad * _rnd(0.88, 1.12)))
	for r in rows:
		for s in seg:
			var a := ring[r * seg + s]
			var b := ring[(r + 1) * seg + s]
			var c := ring[(r + 1) * seg + (s + 1) % seg]
			var d := ring[r * seg + (s + 1) % seg]
			var o := P.size()
			P.append_array([a, b, c, d])
			I.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
	for cap_y: int in [0, rows]:      # the ends
		var o := P.size()
		for s in seg:
			P.append(ring[cap_y * seg + s])
		for s in range(1, seg - 1):
			if cap_y == 0:
				I.append_array([o, o + s, o + s + 1])
			else:
				I.append_array([o, o + s + 1, o + s])
	return Goggles.indexed_mesh(P, I)


static func _ice_material(col: int, em: int, ei: float, r: float, me: float, op: float, no_depth: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Color.hex((col << 8) | 0xff), op)
	m.emission_enabled = true
	m.emission = Color.hex((em << 8) | 0xff)
	m.emission_energy_multiplier = ei
	m.roughness = r
	m.metallic = me
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if no_depth else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return m


func _ready() -> void:
	name = "Frost"
	_mist = PowerPuffs.new(self, true, 8, 0.4, 0.5)
	_flakes = PowerPuffs.new(self, false, 8, 0.4, 0.5)
	_ice_mat = _ice_material(0xcdeeff, 0x2a5a78, 0.55, 0.12, 0.1, 0.55, true)
	_crystal_mat = _ice_material(0xe6f7ff, 0x4a8ab0, 0.6, 0.1, 0.15, 0.85, false)
	_crystal_mesh = _octa(0.35, 1.0, 0.35)
	_shell_mesh = _shell()
	_shards_mm = MultiMesh.new()
	_shards_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shards_mm.mesh = _octa(0.5, 1.0, 0.5)
	_shards_mm.instance_count = MAXS
	_shards_mm.visible_instance_count = 0
	var o := MultiMeshInstance3D.new()
	o.multimesh = _shards_mm
	o.material_override = _crystal_mat
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	add_child(o)
	for i in MAXS:
		_S.append(Shard.new())
	_light = OmniLight3D.new()
	_light.light_color = Color.hex(0x8fd6ffff)
	_light.omni_range = 7.0
	_light.omni_attenuation = 2.0
	_light.visible = false
	add_child(_light)
	if AudioServer.get_bus_index(&"PowerHiss") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, &"PowerHiss")
		AudioServer.set_bus_send(i, &"SFX")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 2600.0
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 9000.0
		AudioServer.add_bus_effect(i, hp)
		AudioServer.add_bus_effect(i, lp)
	_hiss = AudioStreamPlayer.new()
	_hiss.bus = &"PowerHiss"
	_hiss.stream = load("res://assets/sfx/city/noise.wav")
	add_child(_hiss)


func _sounds() -> void:
	if _crackle != null:
		return
	var R := 44100
	var a := OfflineSynth.make(0.42, R)
	OfflineSynth.noise(a, R, 0.0, {"type": &"bandpass", "f0": 4200.0, "f1": 2200.0, "q": 2.0, "gain": 0.35, "dur": 0.35})
	for i in 4:
		OfflineSynth.tone(a, R, i * 0.04, {"type": &"triangle", "f0": _rnd(2400.0, 4200.0), "f1": _rnd(1800.0, 3000.0), "gain": 0.05, "dur": 0.08})
	_crackle = OfflineSynth.wav(a, R)
	var b := OfflineSynth.make(0.6, R)
	OfflineSynth.noise(b, R, 0.0, {"type": &"highpass", "f0": 3000.0, "f1": 1500.0, "gain": 0.7, "dur": 0.5})
	OfflineSynth.noise(b, R, 0.0, {"type": &"lowpass", "f0": 1400.0, "f1": 200.0, "gain": 0.5, "dur": 0.25})
	for i in 9:
		OfflineSynth.tone(b, R, _rnd(0.0, 0.35), {"type": &"sine", "f0": _rnd(1800.0, 5200.0), "f1": _rnd(1200.0, 3000.0), "gain": 0.07, "dur": _rnd(0.08, 0.2)})
	_smash = OfflineSynth.wav(b, R)
	var c := OfflineSynth.make(0.32, R)
	OfflineSynth.noise(c, R, 0.0, {"type": &"bandpass", "f0": 2600.0, "f1": 1400.0, "q": 1.5, "gain": 0.25, "dur": 0.3})
	_thaw = OfflineSynth.wav(c, R)


static func _loud(p: Vector3) -> float:
	var L: Vector3 = Game.rig.pos if Game.rig != null else p
	return 1.0 / (1.0 + L.distance_to(p) * 0.2)


func _puff(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float, grav: float = 0.0) -> void:
	_mist.emit(x, y, z, vx, vy, vz, life, s0, s1, PowerPuffs.MIST, 2.6, -grav)


func _flake(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s: float = 0.035, grav: float = 0.6) -> void:
	_flakes.emit(x, y, z, vx, vy, vz, life, s, s * 0.6, PowerPuffs.FLAKE, 1.4, -grav)


# ---------------- ice: crystals growing on chilled enemies, a shell when frozen, flying shards when it breaks ----------------

func _ice_for(tg: Target) -> Ice:
	var I: Ice = _ice.get(tg)
	if I != null:
		return I
	if not _ice_free.is_empty():
		I = _ice_free.pop_back()
	else:
		I = Ice.new()
		I.g = Node3D.new()
		I.g.name = "frost-ice"
		I.shell = Goggles.part(I.g, _shell_mesh, _ice_mat)
		for i in 14:
			var m := Goggles.part(I.g, _crystal_mesh, _crystal_mat)
			I.crystals.append([m, 0.0, 0.0])
		add_child(I.g)
	var r := tg.r if tg.r != 0.0 else 0.5
	var h := tg.h if tg.h != 0.0 else 1.8
	I.shell.visible = false
	I.g.visible = true
	for k: Array in I.crystals:
		var m: MeshInstance3D = k[0]
		var a := _rnd(0.0, 6.28)
		var y := _rnd(0.05, 0.95) * h
		var pos := Vector3(cos(a) * r * 0.95, y, sin(a) * r * 0.95)
		var aim := Vector3(cos(a) * r * 3.0, y + _rnd(-0.6, 1.4), sin(a) * r * 3.0)
		# point outward (the octahedron's long axis is Y)
		var up := (aim - pos).normalized()
		var sd := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		m.transform = Transform3D(Basis(sd, up, sd.cross(up)), pos)
		k[1] = _rnd(0.07, 0.16) * (0.7 + h / 4.0)
		k[2] = _rnd(0.05, 0.9)
		m.scale = Vector3.ONE * 0.001
	_ice[tg] = I
	return I


func _ice_drop(tg: Target) -> void:
	var I: Ice = _ice.get(tg)
	if I == null:
		return
	I.g.visible = false
	_ice.erase(tg)
	_ice_free.append(I)


func _shard(x: float, y: float, z: float, vx: float, vy: float, vz: float, s: float, floor_y: float) -> void:
	_si = (_si + 1) % MAXS
	var o := _S[_si]
	o.p = Vector3(x, y, z)
	o.v = Vector3(vx, vy, vz)
	o.q = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).get_rotation_quaternion()
	o.w = Vector3(_rnd(-12.0, 12.0), _rnd(-12.0, 12.0), _rnd(-12.0, 12.0))
	o.s = s
	o.life = _rnd(1.6, 2.6)
	o.floor_y = floor_y


func _step_shards(dt: float) -> void:
	var n := 0
	for o in _S:
		if o.life <= 0.0:
			continue
		o.life -= dt
		o.v.y -= 14.0 * dt
		o.p += o.v * dt
		if o.p.y < o.floor_y + o.s * 0.5:
			o.p.y = o.floor_y + o.s * 0.5
			o.v.y *= -0.3
			o.v.x *= 0.6
			o.v.z *= 0.6
			o.w *= 0.6
		o.q = o.q * Basis.from_euler(o.w * dt).get_rotation_quaternion()
		var k := minf(1.0, o.life / 0.5)
		_shards_mm.set_instance_transform(n, Transform3D(Basis(o.q).scaled(Vector3.ONE * (o.s * k)), o.p))
		n += 1
	_shards_mm.visible_instance_count = n


# ---------------- gameplay ----------------

static func _hittable(o: Target) -> bool:
	return o != null and not o.dead and not o.npc and o.actor_state == null


## one spray tick: every enemy in the cone (with a clear line from the hand) chills and takes a little cold damage
func _spray_tick(hand: Vector3, dir: Vector3, dt: float) -> void:
	for O: Target in Game.combat.targets:
		if not _hittable(O):
			continue
		var h := O.h if O.h != 0.0 else 1.8
		var r := O.r if O.r != 0.0 else 0.5
		var c := Vector3(O.x, clampf(hand.y, O.y + 0.2, O.y + h - 0.2), O.z)      # nearest height on the body to the spray
		var dv := c - hand
		var d := dv.length()
		if d > RANGE + r:
			continue
		var along := dv.dot(dir)
		if along < 0.0:
			continue
		var off := sqrt(maxf(0.0, d * d - along * along))
		if off > tan(CONE) * along + r + 0.2:
			continue
		if Game.world.ray_clear(hand.x, hand.y, hand.z, dv.x / d, dv.y / d, dv.z / d, d, 0.01) < d - r - 0.3:
			continue
		var near := 1.0 - 0.5 * clampf(d / RANGE, 0.0, 1.0)
		var rate := CHILL_RATE * near * (HEAVY_RATE if O.heavy else 1.0)
		if not O.frozen_t > 0.0:
			O.chill = minf(1.0, O.chill + rate * dt)
			if O.chill >= 1.0:
				O.frozen_t = FREEZE * (0.6 if O.heavy else 1.0)
				_sounds()
				Game.sfx.clip(_crackle, {"gain": 0.4 + 0.6 * _loud(Vector3(O.x, O.y, O.z)), "wet": 0.3})
				Game.combat.events.append({"t": "frozen", "x": O.x, "y": O.y + 1.0, "z": O.z, "tid": O.id})
				for i in 16:
					_puff(O.x + _rnd(-r, r), O.y + _rnd(0.0, h), O.z + _rnd(-r, r), 0.0, _rnd(0.2, 0.6), 0.0, _rnd(0.5, 1.0), 0.3, 0.9)
		O.chill_hold = 0.25      # no thawing while the spray is on it
		O.cold_dmg += DPS * dt * near      # banked and dealt in chunks (no stream of "1" damage numbers)
		if O.cold_dmg >= 4.0:
			var a := O.cold_dmg
			O.cold_dmg = 0.0
			Game.combat.damage(O, a, {"x": hand.x, "y": hand.y, "z": hand.z}, 0.0, null)


## break a frozen enemy: the ice and the body go in a spray of shards
func shatter(O: Target) -> void:
	var r := O.r if O.r != 0.0 else 0.5
	var h := O.h if O.h != 0.0 else 1.8
	for i in 46:
		var a := _rnd(0.0, 6.28)
		var sp := _rnd(2.0, 7.0)
		_shard(O.x + cos(a) * r * _rnd(0.2, 1.0), O.y + _rnd(0.1, 1.0) * h, O.z + sin(a) * r * _rnd(0.2, 1.0), cos(a) * sp, _rnd(1.5, 6.0), sin(a) * sp, _rnd(0.05, 0.16) * (0.7 + h / 4.0), O.y)
	for i in 26:
		_puff(O.x + _rnd(-r, r), O.y + _rnd(0.0, h), O.z + _rnd(-r, r), _rnd(-1.5, 1.5), _rnd(0.0, 1.5), _rnd(-1.5, 1.5), _rnd(0.6, 1.3), 0.4, 1.4)
	for i in 40:
		_flake(O.x, O.y + _rnd(0.2, h), O.z, _rnd(-4.0, 4.0), _rnd(0.0, 4.0), _rnd(-4.0, 4.0), _rnd(0.8, 1.6), 0.04, 5.0)
	_sounds()
	Game.sfx.clip(_smash, {"gain": 0.4 + 0.6 * _loud(Vector3(O.x, O.y, O.z)), "wet": 0.4})
	O.shattered = true
	O.frozen_t = 0.0
	O.chill = 0.0
	_ice_drop(O)
	if Game.fx != null and Game.rig != null:
		var d: float = Game.rig.pos.distance_to(Vector3(O.x, O.y + 1.0, O.z))
		Game.fx.shake = maxf(Game.fx.shake, 0.18 * clampf(1.0 - d / 20.0, 0.0, 1.0))
	Game.combat.events.append({"t": "shatter", "x": O.x, "y": O.y + 1.0, "z": O.z, "tid": O.id})


## ctx: { hand, dir, idle, spraying } or null: always call it (enemies thaw even when the implant is not equipped)
func update(dt: float, c: Variant) -> void:
	_t += dt
	var light_on := 0.0
	# ---- the spray ----
	if c != null and c.spraying:
		var h: Vector3 = c.hand
		var d: Vector3 = c.dir
		if not _hiss.playing:
			_hiss.play(randf())
		_acc += dt * 260.0
		var ux := 0.0 if absf(d.y) < 0.9 else 1.0
		var uy := 0.0 if ux != 0.0 else 1.0
		var rv := Vector3(d.y * 0.0 - d.z * uy, d.z * ux - d.x * 0.0, d.x * uy - d.y * ux)      # a vector across the cone
		var rl := rv.length()
		if rl < 0.0001:
			rl = 1.0
		var av := rv / rl
		var bv := d.cross(av)
		while _acc >= 1.0:
			_acc -= 1.0
			var a := _rnd(0.0, 6.28)
			var s := tan(CONE) * sqrt(randf())
			var sp := _rnd(8.0, 12.0)
			var v := d + (av * cos(a) + bv * sin(a)) * s
			_puff(h.x + d.x * 0.15, h.y + d.y * 0.15, h.z + d.z * 0.15, v.x * sp, v.y * sp, v.z * sp, _rnd(0.45, 0.85), 0.08, _rnd(0.9, 1.6), 0.4)
			if randf() < 0.35:
				_flake(h.x + d.x * 0.15, h.y + d.y * 0.15, h.z + d.z * 0.15, v.x * sp * 0.9, v.y * sp * 0.9, v.z * sp * 0.9, _rnd(0.6, 1.1), _rnd(0.02, 0.045), 1.2)
		_hiss.volume_db = linear_to_db(maxf(0.16 + 0.03 * sin(_t * 23.0), 1e-5))
		_tick -= dt
		if _tick <= 0.0:
			_tick += TICK
			_spray_tick(h, d, TICK)
		_light.position = h + d * 1.2
		light_on = 3.0 + 0.6 * sin(_t * 17.0)
	else:
		if _hiss.playing:
			_hiss.stop()
		_tick = 0.0
	# ---- cold air sinking off the hand while equipped ----
	if c != null and c.idle and not c.spraying:
		var hand: Vector3 = c.hand
		_idle_acc += dt * 10.0
		while _idle_acc >= 1.0:
			_idle_acc -= 1.0
			_puff(hand.x + _rnd(-0.05, 0.05), hand.y - 0.03, hand.z + _rnd(-0.05, 0.05), _rnd(-0.05, 0.05), _rnd(-0.25, -0.1), _rnd(-0.05, 0.05), _rnd(0.6, 1.1), 0.05, _rnd(0.18, 0.3), 0.15)
		if randf() < dt * 4.0:
			_flake(hand.x, hand.y, hand.z, _rnd(-0.1, 0.1), -0.1, _rnd(-0.1, 0.1), _rnd(0.8, 1.4), 0.025, 0.3)
		if light_on == 0.0:
			_light.position = hand
			light_on = 0.5
	_light.visible = light_on != 0.0
	_light.light_energy = light_on / PI
	# ---- every chilled / frozen enemy: thaw, ice growth, frost steam; a frozen one that dies any way at all shatters ----
	for O: Target in Game.combat.targets:
		if O.shattered and not O.dead:      # respawned
			O.shattered = false
		if not O.chill > 0.0 and not O.frozen_t > 0.0:
			if _ice.has(O):
				_ice_drop(O)
			continue
		if O.dead:
			if O.frozen_t > 0.0:
				shatter(O)
			else:
				O.chill = 0.0
				_ice_drop(O)
			continue
		var r := O.r if O.r != 0.0 else 0.5
		var h := O.h if O.h != 0.0 else 1.8
		if O.frozen_t > 0.0:
			O.frozen_t -= dt
			if O.frozen_t <= 0.0:      # thaws: the shell cracks off, still half chilled
				O.frozen_t = 0.0
				O.chill = 0.5
				_sounds()
				Game.sfx.clip(_thaw, {"gain": _loud(Vector3(O.x, O.y, O.z)), "wet": 0.3})
				for i in 18:
					var a := _rnd(0.0, 6.28)
					_shard(O.x + cos(a) * r, O.y + _rnd(0.1, 1.0) * h, O.z + sin(a) * r, cos(a) * _rnd(1.0, 2.5), _rnd(0.5, 2.0), sin(a) * _rnd(1.0, 2.5), _rnd(0.04, 0.1), O.y)
		else:
			O.chill_hold -= dt
			if O.chill_hold <= 0.0:
				O.chill = maxf(0.0, O.chill - THAW * dt)
		var I := _ice_for(O)
		var fr := O.frozen_t > 0.0
		var ch := 1.0 if fr else O.chill
		I.g.position = Vector3(O.x, O.y, O.z)
		I.shell.visible = fr
		if fr:
			var pop := minf(1.0, (FREEZE - O.frozen_t) * 8.0 + 0.4)
			I.shell.scale = Vector3(r * 1.2 * pop, h * 1.04, r * 1.2 * pop)
		for k: Array in I.crystals:
			var grow := clampf((ch - float(k[2]) * 0.6) / 0.4, 0.0, 1.0)
			(k[0] as MeshInstance3D).scale = Vector3.ONE * maxf(0.001, float(k[1]) * (1.25 if fr else grow))
		if randf() < dt * (3.0 + 10.0 * ch):
			_puff(O.x + _rnd(-r, r), O.y + _rnd(0.1, h), O.z + _rnd(-r, r), 0.0, _rnd(-0.2, 0.15), 0.0, _rnd(0.6, 1.2), 0.1, 0.45, 0.2)
	if not _ice.is_empty():
		_sweep -= dt
		if _sweep <= 0.0:      # ice of an enemy removed without dying
			_sweep = 1.0
			for O: Target in _ice.keys():
				if not Game.combat.targets.has(O):
					_ice_drop(O)
	_mist.step(dt)
	_flakes.step(dt)
	_step_shards(dt)


func quiet() -> void:
	if _hiss.playing:
		_hiss.volume_db = -80.0
