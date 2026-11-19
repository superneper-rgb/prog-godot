class_name UfTurret
extends Node3D
## SERN's gun on the last train (user 2026-11-15: "its so difficult with our ammo we should have a proper turret to make it even more like a proper arcade scene"). A rotary cannon on a raised ring at
## the front of the flatcar (on the front section, the last one a blow tears off), firing back over the car at the Sigil and anything of the hive that comes aboard. Prog mans it from the moment the
## train goes; E (pad X) lets go of it or takes it again. It aims where the camera looks (the view's crosshair), fires while fire is held, never needs a reload, and heats instead: past red it
## locks until it has cooled. The heat is on the gun itself (a strip along the receiver, the barrels glowing), not on the HUD: the game's cues are diegetic.
## Built in code: a hard-surface prop the camera sits behind, made of boxes and cylinders in the train's cyber palette (levels/underfoint/uf_train.gd).
## (2026-11-15, user: "make the turret play and function like a halo 3 turret". It now has the Halo 3 machine gun's feel: the barrels spin up for 0.3 s before it reaches its full rate, and the rate climbs
## with the spin; its rounds are real, flying from the muzzle to what the crosshair is on at SPEED, seen as amber streaks (one MultiMesh pool), each swept against the world and the targets every frame
## so none tunnels; the cone opens as it heats; the cradle kicks back each round; the view eases into the gun cam and out of it (mount_k, read by uf_chase.gd _ride_cam). It stays on its ring: no
## carrying it off. It still overheats (user: "its allowed to overheat"). Its ring turns all the way round, no yaw arc: the Sigil attacks from ahead and both sides as well as from behind.)

const Y := UnderfointLevel.STATION_Y
const HOME := UfRoute.HOME
const AT := Vector3(70.0, Y + UfTrain.DECK + 0.62, 309.0 + 4.0)      # the ring's middle: on the front section, so the camera behind him is over the car, not in the tender (the front section is the last to go)
const RATE := 14.0               # rounds a second, spun up
const RATE_MIN := 5.0            # ...and as it first starts to turn over
const SPOOL_UP := 0.3            # seconds from still to full spin (Halo 3's machine gun)
const SPOOL_DOWN := 0.9          # ...and from full spin to still, let go of
const SPOOL_FIRE := 0.4          # how far spun up before the first round
const SPEED := 170.0             # m/s: a round's flight is seen, and a Taken running across the car wants a little lead
const RANGE := 220.0
const STREAK := 3.2              # a round's streak, metres
const POOL := 48                 # rounds in the air at once (14 a second for 1.3 s at most)
const DMG := 8.0                 # a screen is 24: three rounds
const SPREAD := 0.006            # cold; it opens to 2.5x this hot
const HEAT := 0.016              # per round: ~4.5 s of fire from cold to locked (0.03 locked it every 2.4 s: a held trigger spent a quarter of the ride locked)
const COOL := 0.8                # per second, not firing
const UNLOCK := 0.45             # locked until it is this cool again (~0.7 s)
const GUNNER := 1.15             # how far behind the ring Prog stands
const PITCH_MIN := -0.6
const PITCH_MAX := 0.95
const CYAN := Color(0.35, 0.95, 1.0)
const AMBER := Color(1.0, 0.6, 0.15)

var lv: UnderfointLevel
var on := false                  # Prog is at it
var live := false                # it has power: it can be taken. (2026-11-15: he no longer mans it for the whole ride; it comes alive for the spiral, levels/underfoint/uf_chase.gd "gun")
var yaw := PI                    # where it points (world yaw: PI is back down the car)
var pitch := 0.05
var heat := 0.0
var locked := false
var _spin := 0.0
var _cd := 0.0
var _flash := 0.0
var _barrel := 0
var _ring: Node3D
var _cradle: Node3D
var _drum: Node3D
var _gauge: MeshInstance3D
var _gauge_mat: StandardMaterial3D
var _hot_mat: StandardMaterial3D
var _flash_node: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _light: OmniLight3D
var _hint_t := 0.0
var _vent_cd := 0.0
var _stripe_mat: StandardMaterial3D
var spool := 0.0                 # the barrels' spin, 0 still to 1 full
var mount_k := 0.0               # 0 on foot to 1 at the gun: the view eases between them (uf_chase.gd _ride_cam)
var _kick := 0.0                 # the cradle's recoil
var _cradle_at := Vector3.ZERO
var _rounds: Array[Round] = []
var _round_mm: MultiMesh
var _round_mi: MultiMeshInstance3D
var _warm_round := false


## One round in the air (pooled: a fixed set, reused)
class Round:
	var pos := Vector3.ZERO
	var dir := Vector3.FORWARD
	var flown := 0.0
	var on := false


func _init(p_lv: UnderfointLevel) -> void:
	lv = p_lv
	name = "UfTurret"


func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _box(parent: Node3D, mat: Material, at: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, mat: Material, at: Vector3, r: float, h: float, rot: Vector3 = Vector3.ZERO, r_top: float = -1.0, sides: int = 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r if r_top < 0.0 else r_top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## The gun, at level load. Static meshes are few and small: the whole of it is ~30 parts, three moving nodes (ring, cradle, barrels).
func build() -> void:
	var armor := _mat(Color(0.06, 0.055, 0.085), 0.65, 0.32)      # FOINT's violet-black, wet-glossy
	var steel := _mat(Color(0.16, 0.17, 0.19), 0.9, 0.28)
	var dark := _mat(Color(0.025, 0.025, 0.03), 0.7, 0.45)
	var cyan := _glow(CYAN, 3.0)
	_stripe_mat = _glow(AMBER, 1.6)
	_hot_mat = _mat(Color(0.12, 0.12, 0.13), 0.95, 0.25)
	_hot_mat.emission_enabled = true
	_hot_mat.emission = Color(1.0, 0.35, 0.08)
	_hot_mat.emission_energy_multiplier = 0.0
	_gauge_mat = _glow(CYAN, 3.5)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.0, 0.75, 0.35)
	_flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	position = AT
	# the pedestal on the footplate: a base plate, the post, a cyan ring of light round its foot, hazard tabs
	var base := Node3D.new()
	add_child(base)
	_box(base, armor, Vector3(0.0, -0.56, 0.0), Vector3(1.5, 0.12, 1.3))
	_cyl(base, steel, Vector3(0.0, -0.27, 0.0), 0.36, 0.55, Vector3.ZERO, 0.3)
	_cyl(base, cyan, Vector3(0.0, -0.48, 0.0), 0.5, 0.04, Vector3.ZERO, -1.0, 24)
	for sx: float in [-1.0, 1.0]:
		_box(base, _stripe_mat, Vector3(sx * 0.68, -0.49, 0.0), Vector3(0.08, 0.03, 1.0))
	# the ring: turns with the aim. Its shield, the cheeks, the grips and a seat-back plate the gunner stands against
	_ring = Node3D.new()
	add_child(_ring)
	_cyl(_ring, dark, Vector3.ZERO, 0.72, 0.16, Vector3.ZERO, 0.66, 24)
	_cyl(_ring, cyan, Vector3(0.0, 0.085, 0.0), 0.7, 0.02, Vector3.ZERO, -1.0, 24)
	for sx: float in [-1.0, 1.0]:
		_box(_ring, armor, Vector3(sx * 0.42, 0.4, 0.05), Vector3(0.1, 0.62, 0.9))      # the cheeks the cradle hangs in
		_box(_ring, cyan, Vector3(sx * 0.475, 0.45, 0.05), Vector3(0.012, 0.36, 0.6))
	# the shield: a raked plate in front with a slot for the barrels, its edge lit
	_box(_ring, armor, Vector3(0.0, 0.3, 0.62), Vector3(1.5, 0.5, 0.07), Vector3(-0.45, 0.0, 0.0))
	_box(_ring, armor, Vector3(-0.9, 0.24, 0.45), Vector3(0.5, 0.42, 0.06), Vector3(-0.35, 0.55, 0.0))
	_box(_ring, armor, Vector3(0.9, 0.24, 0.45), Vector3(0.5, 0.42, 0.06), Vector3(-0.35, -0.55, 0.0))
	_box(_ring, cyan, Vector3(0.0, 0.53, 0.73), Vector3(1.36, 0.03, 0.03), Vector3(-0.45, 0.0, 0.0))
	_box(_ring, _stripe_mat, Vector3(0.0, 0.12, 0.66), Vector3(1.15, 0.05, 0.02), Vector3(-0.45, 0.0, 0.0))
	# the cradle: pitches with the aim. Receiver, the drum, the heat strip, the grips, the barrel cluster
	_cradle = Node3D.new()
	_cradle.position = Vector3(0.0, 0.55, 0.05)
	_cradle_at = _cradle.position
	_ring.add_child(_cradle)
	_box(_cradle, steel, Vector3(0.0, 0.0, -0.05), Vector3(0.46, 0.4, 1.0))
	_box(_cradle, armor, Vector3(0.0, 0.23, -0.1), Vector3(0.5, 0.06, 0.9))
	_gauge = _box(_cradle, _gauge_mat, Vector3(0.0, 0.27, -0.1), Vector3(0.36, 0.025, 0.06))
	_gauge.position.z = 0.25
	for sx: float in [-1.0, 1.0]:
		_cyl(_cradle, dark, Vector3(sx * 0.3, 0.0, 0.0), 0.11, 0.18, Vector3(0.0, 0.0, PI * 0.5))      # the trunnions
		_cyl(_cradle, steel, Vector3(sx * 0.28, -0.1, -0.78), 0.035, 0.42, Vector3(PI * 0.5, 0.0, 0.0))      # the grips, back toward him
		_box(_cradle, dark, Vector3(sx * 0.28, -0.1, -1.0), Vector3(0.09, 0.2, 0.09))
	_drum = Node3D.new()
	_drum.position = Vector3(-0.38, -0.08, -0.1)
	_cradle.add_child(_drum)
	_cyl(_drum, armor, Vector3.ZERO, 0.24, 0.24, Vector3(0.0, 0.0, PI * 0.5), -1.0, 18)
	_cyl(_drum, cyan, Vector3(-0.125, 0.0, 0.0), 0.18, 0.012, Vector3(0.0, 0.0, PI * 0.5), -1.0, 18)
	# the barrels: six round a spindle, a shroud ring at each end, the muzzle brake
	var bar := Node3D.new()
	bar.name = "barrels"
	bar.position = Vector3(0.0, 0.0, 0.45)
	_cradle.add_child(bar)
	_cyl(bar, steel, Vector3(0.0, 0.0, 0.75), 0.05, 1.5, Vector3(PI * 0.5, 0.0, 0.0))
	for k in 6:
		var a := TAU * k / 6.0
		_cyl(bar, _hot_mat, Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.8), 0.032, 1.6, Vector3(PI * 0.5, 0.0, 0.0), -1.0, 8)
	for zz: float in [0.15, 0.9, 1.55]:
		_cyl(bar, armor, Vector3(0.0, 0.0, zz), 0.16, 0.08, Vector3(PI * 0.5, 0.0, 0.0), -1.0, 18)
	_cyl(bar, dark, Vector3(0.0, 0.0, 1.66), 0.13, 0.14, Vector3(PI * 0.5, 0.0, 0.0), 0.15, 12)
	_cyl(bar, cyan, Vector3(0.0, 0.0, 0.9), 0.165, 0.015, Vector3(PI * 0.5, 0.0, 0.0), -1.0, 18)
	set_meta(&"barrels", bar)
	# the flash: two crossed cards at the muzzle, and its light
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	_flash_node = MeshInstance3D.new()
	_flash_node.mesh = q
	_flash_node.material_override = _flash_mat
	_flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_node.position = Vector3(0.0, 0.0, 2.35)
	_flash_node.visible = false
	_cradle.add_child(_flash_node)
	var q2 := MeshInstance3D.new()
	q2.mesh = q
	q2.material_override = _flash_mat
	q2.rotation = Vector3(0.0, PI * 0.5, 0.0)
	_flash_node.add_child(q2)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.72, 0.4)
	_light.omni_range = 8.0
	_light.omni_attenuation = 1.6
	_light.light_energy = 0.0
	_light.position = Vector3(0.0, 0.1, 2.2)
	_cradle.add_child(_light)
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mi == _flash_node else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# the rounds: one MultiMesh of glowing streaks, in world space (top level: the gun turning does not carry them)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(2.0, 1.05, 0.3)      # (2.6, 1.6, 0.55 blew out white: amber, as the gun's flash)
	var rb := BoxMesh.new()
	rb.size = Vector3.ONE
	rb.material = rm
	_round_mm = MultiMesh.new()
	_round_mm.transform_format = MultiMesh.TRANSFORM_3D
	_round_mm.mesh = rb
	_round_mm.instance_count = POOL
	_round_mm.visible_instance_count = 0
	_round_mi = MultiMeshInstance3D.new()
	_round_mi.multimesh = _round_mm
	_round_mi.top_level = true
	_round_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_round_mi.custom_aabb = AABB(Vector3(-400.0, -200.0, -400.0), Vector3(800.0, 400.0, 800.0))
	add_child(_round_mi)
	_round_mi.transform = Transform3D.IDENTITY
	for k in POOL:
		_rounds.append(Round.new())
	_pose()


## The crosshair's ray, exactly as combat builds it (combat/combat.gd: from the rig's position toward its look point, starting past Prog): [origin, direction]. (The camera node's own -Z is not
## the crosshair: aimed along that, the gun's rounds went over the screens.)
static func aim_ray() -> Array:
	var r := Game.rig
	var d: Vector3 = r.look - r.pos
	if d.length() < 0.001:
		d = Vector3(0.0, 0.0, 1.0)
	d = d.normalized()
	return [r.pos + d * r.dist, d]


## At load: its sounds read now (the first round read the rifle's off the disk, 50 ms), and one tracer drawn out of sight so its pipeline exists before the first burst
func warm(cam: Camera3D) -> void:
	Game.sfx.warm(PackedStringArray(["rifle", "empty", "equip", "hit", "kill"]))
	if cam != null:
		var f := -cam.global_transform.basis.z
		var a := cam.global_position + f * 3.0 + Vector3(0.0, -30.0, 0.0)
		Game.fx.tracer(a, a + f * 0.5, 0.01, 0.05, 0xffc070)
		_round_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.01, 0.01, 0.4)), a))      # (and one round, the same way)
		_round_mm.visible_instance_count = 1
		_warm_round = true


## where it points, in the world (its barrels' axis)
func dir() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


func muzzle() -> Vector3:
	return _cradle.global_transform * Vector3(0.0, 0.0, 2.3)


## Prog takes it, or lets go of it. (The chase calls this at each stretch's start: he mans it before the train goes.)
func mount(v: bool) -> void:
	if on == v:
		return
	on = v
	lv.no_fight = v      # his own gun is down while he is at this one (Level.no_fight: no fire, aim or melee reach combat)
	var p := Game.player
	if p != null:
		p.crouch_hide = v
		p.rooted = v
	if v:
		yaw = Game.rig.yaw
	_flash = 0.0


## The frame: aim at what the camera looks at, fire while fire is held, heat, cool, spin, flash. ride: the train is under way (it is only manned on the ride).
func tick(dt: float, ride: bool) -> void:
	_tick_rounds(dt)
	mount_k = move_toward(mount_k, 1.0 if on else 0.0, dt / 0.35)
	var p := Game.player
	if p == null:
		return
	if not ride:
		if on:
			mount(false)
		spool = move_toward(spool, 0.0, dt / SPOOL_DOWN)
		_spin += spool * 32.0 * dt
		_pose()
		return
	# take it or let go of it: E (pad X) within reach of its grips
	var spot := gunner_spot()
	var near := U.hyp(p.x - spot.x, p.z - spot.z) < 1.8 and absf(p.y - spot.y) < 1.0
	var use := Inp.btn(&"b").pressed or (Inp.using_pad and Inp.btn(&"attack").pressed)
	if use and (on or (near and live)) and not p.dead:
		mount(not on)
	if not on and near and live and not p.dead:
		_hint_t -= dt
		if _hint_t <= 0.0:
			_hint_t = 2.0
			Game.hud.toast(("[X]" if Inp.using_pad else "[E]") + "  TAKE THE GUN", 1.6)
	if on and p.dead:
		mount(false)
	# the barrels spin up while fire is held and run down when it is let go (or it has locked hot)
	var want := on and Inp.btn(&"fire").held and not locked and not Game.paused
	spool = move_toward(spool, 1.0 if want else 0.0, dt / (SPOOL_UP if want else SPOOL_DOWN))
	# aim: the barrels come round to whatever is under the crosshair (a ray from the camera, as a shot's)
	if on:
		var ar := aim_ray()
		var o: Vector3 = ar[0]
		var f: Vector3 = ar[1]
		var r := Game.combat.cast_ray(o.x, o.y, o.z, f.x, f.y, f.z, RANGE)
		var aim := o + f * (r.d if (r.target != null or r.hit_world) else 160.0)
		var d := aim - _cradle.global_position
		var want_yaw := atan2(d.x, d.z)
		var want_pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), PITCH_MIN, PITCH_MAX)
		yaw += U.wrap_angle(want_yaw - yaw) * minf(1.0, dt * 18.0)
		pitch += (want_pitch - pitch) * minf(1.0, dt * 18.0)
		# fire: from part-spun, at a rate that climbs with the spin
		_cd -= dt
		if want and spool >= SPOOL_FIRE and _cd <= 0.0:
			_cd = 1.0 / lerpf(RATE_MIN, RATE, smoothstep(SPOOL_FIRE, 1.0, spool))
			_shoot(aim, f)
	else:
		_cd = 0.0
	# heat: up with every round, down while it rests; past red it locks till it has cooled
	if not (on and Inp.btn(&"fire").held) or locked:
		heat = maxf(0.0, heat - COOL * dt)
	if locked and heat < UNLOCK:
		locked = false
		_click()
	if locked:
		_vent_cd -= dt
		if _vent_cd <= 0.0:      # it vents while it is locked
			_vent_cd = 0.06
			var m := muzzle()
			Game.fx.sparks(m, 2, 1.5)
	_spin += spool * 32.0 * dt
	_flash = maxf(0.0, _flash - dt * 30.0)
	_kick = maxf(0.0, _kick - dt * 14.0)
	_pose()


## A round leaves the muzzle for what the crosshair is on (f: the crosshair's own direction, for an aim point too close to converge on), in a cone that opens as the gun heats
func _shoot(aim: Vector3, f: Vector3) -> void:
	var m := muzzle()
	var d := aim - m
	d = f if d.length() < 4.0 else d.normalized()
	d = (d + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SPREAD * (1.0 + 1.5 * heat)).normalized()
	for r: Round in _rounds:
		if not r.on:
			r.on = true
			r.pos = m
			r.dir = d
			r.flown = 0.0
			break
	heat += HEAT
	if heat >= 1.0:
		heat = 1.0
		locked = true
		Game.sfx.play("empty", {})
	_flash = 1.0
	_kick = 1.0
	_barrel = (_barrel + 1) % 6
	Game.sfx.play("rifle")
	Game.fx.shake = maxf(Game.fx.shake, 0.14)


## The rounds in the air: each swept along this frame's flight against the world and the targets (so a fast one never passes through a screen between frames), then drawn as a streak behind it
func _tick_rounds(dt: float) -> void:
	var n := 0
	var step := SPEED * dt
	for r: Round in _rounds:
		if not r.on:
			continue
		var h := Game.combat.cast_ray(r.pos.x, r.pos.y, r.pos.z, r.dir.x, r.dir.y, r.dir.z, step)
		if h.target != null:
			var at := r.pos + r.dir * h.d
			Game.combat.damage(h.target, DMG, Game.player, 0.0, {"x": at.x, "y": at.y, "z": at.z, "kind": "target", "nx": -r.dir.x, "ny": -r.dir.y, "nz": -r.dir.z})
			Game.fx.sparks(at, 5, 4.0, -r.dir)
			r.on = false
			continue
		if h.hit_world:
			Game.fx.sparks(r.pos + r.dir * h.d, 7, 4.5, -r.dir)
			r.on = false
			continue
		r.pos += r.dir * step
		r.flown += step
		if r.flown >= RANGE:
			r.on = false
			continue
		var len_ := minf(STREAK, r.flown)
		var up := Vector3.UP if absf(r.dir.y) < 0.999 else Vector3.RIGHT
		var x := up.cross(r.dir).normalized()
		var y := r.dir.cross(x)
		_round_mm.set_instance_transform(n, Transform3D(Basis(x * 0.1, y * 0.1, r.dir * len_), r.pos - r.dir * (len_ * 0.5)))
		n += 1
	if _warm_round and n == 0:      # (the warm-up round stays one frame)
		_warm_round = false
		return
	_warm_round = false
	_round_mm.visible_instance_count = n


func _click() -> void:
	Game.sfx.play("equip", {"heavy": 0.6})


## where Prog stands at it: behind the ring, square to where it points
func gunner_spot() -> Vector3:
	return Vector3(AT.x - sin(yaw) * GUNNER, Y + UfTrain.DECK, AT.z - cos(yaw) * GUNNER)


## Called after the player's own frame (UnderfointLevel.after_player): at the gun he stands at its grips, facing where it points
func hold_player() -> void:
	if not on:
		return
	var p := Game.player
	var at := gunner_spot()
	p.x = at.x
	p.z = at.z
	p.y = at.y + 0.02
	p.vx = 0.0
	p.vz = 0.0
	p.vy = 0.0
	p.yaw = yaw


func _pose() -> void:
	_ring.rotation.y = yaw
	_cradle.rotation.x = -pitch
	_cradle.position = _cradle_at + Vector3(0.0, 0.0, -0.09 * _kick)      # the recoil, back along the receiver
	var bar: Node3D = get_meta(&"barrels")
	bar.rotation.z = _spin
	_drum.rotation.x = -_spin * 0.15
	# the heat: the strip along the receiver fills and goes cyan -> amber -> red, the barrels glow
	_gauge.scale.x = maxf(0.02, 1.0 - heat)
	_gauge_mat.emission = CYAN.lerp(AMBER, smoothstep(0.35, 0.75, heat)).lerp(Color(1.0, 0.12, 0.05), smoothstep(0.75, 1.0, heat))
	_gauge_mat.emission_energy_multiplier = (3.5 if not locked else (5.0 if fmod(Time.get_ticks_msec() * 0.008, 1.0) < 0.5 else 0.6))
	_hot_mat.emission_energy_multiplier = 3.0 * heat * heat
	_flash_node.visible = _flash > 0.4
	if _flash_node.visible:
		_flash_node.rotation.z = randf() * TAU
		_flash_node.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_light.light_energy = 2.4 * _flash * UnderfointLevel.GAIN
