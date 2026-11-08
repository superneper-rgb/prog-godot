class_name VhPipe
extends RefCounted
## VISITING HOURS: the outfall pipe running (JS pipe.js): the crawl pose inside it, the sewage's ripples (Prog's hands and knees, drips, swimming rats), the rats and alien bugs bolting away from him, the rubbish carried on the current. The art and colliders are the export's.

const Z := 961.0
const X0 := VhLayout.W - 16.0
const X1 := 190.0
const HW := 0.78
const FL := 0.14
const CY := 0.85
const CR := 0.8
const WL := 0.32
const CRAWL_LIFT := 0.42      # (the kit's crawl sank Prog's knees ~0.4 m through the round floor)
const P_X0 := 190.0
const P_X1 := 202.0
const P_Z0 := 955.0
const P_Z1 := 967.0


class Critter:
	var mm: MultiMesh
	var i := 0
	var zig := false
	var speed := 0.0
	var room := false
	var x := 0.0
	var z := 0.0
	var h := 0.0
	var v := 0.0
	var t := 0.0
	var ph := 0.0
	var dodge := 0.0


class Bit:
	var x := 0.0
	var z := 0.0
	var v := 0.0
	var yaw := 0.0
	var spin := 0.0
	var s := 0.0
	var vx := 0.0
	var vz := 0.0


var lv: ExportedLevel
var audio: VhAudio
var crawl: CrawlKit = null
var sew: ShaderMaterial
var ripples := PackedVector4Array()
var rip := 0
var critters: Array[Critter] = []
var bits: Array[Bit] = []
var junk: MultiMesh
var wade := 0.0
var side := 1.0
var splash_t := 0.0
var drip_t := 0.0
var rat_t := 0.0
var lit := 0.15


func _init(p_lv: ExportedLevel, p_audio: VhAudio) -> void:
	lv = p_lv
	audio = p_audio
	ripples.resize(16)
	ripples.fill(Vector4(0.0, 0.0, -99.0, 0.0))
	sew = lv.shader_ports.mats.get("shader_149d8e#0")
	if sew != null:
		sew.set_shader_parameter(&"uRip", ripples)
	_kind("vh-rats", 2.6, false, 9)
	_kind("vh-bugs", 1.8, true, 22)
	var jn: Node3D = VhKit.one(lv, "vh-junk")
	if jn is MultiMeshInstance3D:
		junk = (jn as MultiMeshInstance3D).multimesh
		jn.extra_cull_margin = 60.0
		for _i in junk.instance_count:
			var b := Bit.new()
			b.x = X0 + randf() * (X1 - X0)
			b.z = Z + (randf() - 0.5) * 0.9
			b.v = 0.4 + randf() * 0.35
			b.yaw = randf() * 6.3
			b.spin = (randf() - 0.5) * 0.6
			b.s = 0.5 + randf() * 1.2
			bits.append(b)


func _kind(nm: String, speed: float, zig: bool, n: int) -> void:
	var node: Node3D = VhKit.one(lv, nm)
	if not node is MultiMeshInstance3D:
		return
	var mm := (node as MultiMeshInstance3D).multimesh
	node.extra_cull_margin = 60.0
	for i in mini(n, mm.instance_count):
		var c := Critter.new()
		c.mm = mm
		c.i = i
		c.zig = zig
		c.speed = speed
		c.room = randf() < 0.25
		c.x = P_X0 + 1.0 + randf() * 10.0 if c.room else X0 + 1.0 + randf() * (X1 - X0 - 2.0)
		c.z = P_Z0 + 1.0 + randf() * 10.0 if c.room else Z + (randf() - 0.5) * 1.1
		c.h = randf() * 6.28
		c.t = randf() * 2.0
		c.ph = randf() * 6.0
		critters.append(c)


static func inside(P: Player) -> bool:
	return P.x > X0 - 0.9 and P.x < X1 + 0.1 and absf(P.z - Z) < HW + 0.15 and P.y < 1.2


## turn on the crawl pose (section 3's pipe is live)
func run(on: bool) -> void:
	if on and crawl == null and Game.player != null:
		crawl = CrawlKit.new(inside, CRAWL_LIFT)


func _step_critters(dt: float, P: Player, time: float) -> void:
	for c in critters:
		c.t -= dt
		var px := P.x - c.x if P != null else 99.0
		var pz := P.z - c.z if P != null else 99.0
		var scared := P != null and U.hyp(px, pz) < 2.4 and absf(P.y - (0.0 if c.room else FL)) < 1.5
		if scared and c.dodge == 0.0:      # (Prog close: in the pipe, hug a wall and carry on past him; in the room, scuttle off)
			c.dodge = atan2(-px, -pz) if c.room else (1.0 if randf() < 0.5 else -1.0)
			c.t = minf(c.t, 0.8)
		if not scared:
			c.dodge = 0.0
		if c.t <= 0.0:
			var go := randf() < 0.55
			c.v = c.speed * (0.4 + randf() * 0.6) if go else 0.0
			c.h = randf() * 6.28 if c.room else (PI / 2.0 if randf() < 0.5 else -PI / 2.0) + (randf() - 0.5) * 0.6
			c.t = 0.3 + randf() * (1.2 if go else 2.0)
		var hw := sin(time * 20.0 + c.ph) * 0.3 if c.zig and c.v > 0.0 else 0.0      # (bugs zig-zag as they run)
		if c.dodge != 0.0 and c.room:
			c.h = c.dodge
			c.v = maxf(c.v, c.speed)
		c.x += sin(c.h + hw) * c.v * dt
		c.z += cos(c.h + hw) * c.v * dt
		if c.dodge != 0.0 and not c.room:
			c.z += (Z + c.dodge * 0.67 - c.z) * minf(1.0, dt * 6.0)
		if c.room:
			c.x = minf(P_X1 - 0.4, maxf(P_X0 + 0.4, c.x))
			c.z = minf(P_Z1 - 0.4, maxf(P_Z0 + 0.4, c.z))
		else:
			if c.x < X0 + 0.3 or c.x > X1 - 0.2:
				c.h = -c.h
				c.x = minf(X1 - 0.2, maxf(X0 + 0.3, c.x))
			c.z = minf(Z + 0.7, maxf(Z - 0.7, c.z))
			if c.zig:      # (bugs keep to the dry curve of the wall, rats swim the middle)
				var dz := c.z - Z
				if dz == 0.0:
					dz = 0.1
				c.z = Z + signf(dz) * maxf(0.64, absf(dz))
		var wall := CY - sqrt(maxf(0.0, CR * CR - (c.z - Z) * (c.z - Z)))      # (up the pipe's curve near its sides)
		var y := (0.02 if c.room else (wall + 0.01 if c.zig else maxf(WL - 0.05, wall))) + (absf(sin(time * 18.0 + c.ph)) * 0.015 if c.v > 0.0 else 0.0)
		c.mm.set_instance_transform(c.i, Transform3D(Basis(Vector3.UP, c.h + hw), Vector3(c.x, y, c.z)))


func _ring(x: float, z: float, w: float, time: float) -> void:
	ripples[rip % 16] = Vector4(x, z, time, w)
	rip += 1
	if sew != null:
		sew.set_shader_parameter(&"uRip", ripples)


func update(dt: float, P: Player, time: float) -> void:
	if P != null and crawl == null and Game.player != null:      # (not only from run(): after a level reload mid-pipe the stage's on_start never ran and Prog walked upright through the roof)
		crawl = CrawlKit.new(inside, CRAWL_LIFT)
	if crawl != null:
		crawl.update(dt)
	# (nobody can see it from further than this: the part is hidden indoors and out of range; the JS runs it regardless)
	var cam := Game.camera.global_position if Game.camera != null else Vector3.ZERO
	if cam.x < X0 - 60.0 or cam.x > P_X1 + 40.0 or absf(cam.z - Z) > 60.0 or cam.y > 12.0:
		return
	_step_critters(dt, P, time)
	lit += ((1.0 if Game.night_vision.on else 0.12) - lit) * minf(1.0, dt * 4.0)
	if sew != null:
		sew.set_shader_parameter(&"uT", time)
		sew.set_shader_parameter(&"uLit", lit)
	var sp := U.hyp(P.vx, P.vz) if P != null else 0.0
	var wet := P != null and inside(P)
	if wet and P.x > X0:      # (held on the centre line: the crawl's elbows and hands clear the curve either side)
		P.z += (Z - P.z) * minf(1.0, dt * 8.0)
	# Prog's hands and knees, left and right in turn, a little ahead of his centre: the rings overlap into a wake behind him
	if wet and sp > 0.15:
		wade -= dt
		if wade <= 0.0:
			wade = 0.14
			side = -side
			var fx := sin(P.yaw)
			var fz := cos(P.yaw)
			_ring(P.x + fx * 0.35 + fz * side * 0.17, P.z + fz * 0.35 - fx * side * 0.17, minf(1.0, 0.4 + sp), time)
			splash_t -= 0.14
			if splash_t <= 0.0:
				splash_t = 0.45
				audio.splash(0.1 + randf() * 0.08)
	# drips off the crown near you; the odd swimming rat
	if P != null:
		drip_t -= dt
		if drip_t <= 0.0:
			drip_t = 0.5 + randf() * 0.9
			var x := P.x + (randf() - 0.3) * 9.0
			if x > X0 and x < X1:
				_ring(x, Z + (randf() - 0.5) * 0.5, 0.5, time)
	rat_t -= dt
	if rat_t <= 0.0 and not critters.is_empty():
		rat_t = 0.35
		var c: Critter = critters[randi() % critters.size()]
		if not c.room and not c.zig and c.v > 0.0:
			_ring(c.x, c.z, 0.35, time)
	# the rubbish: carried by the current, bobbing, pushed off Prog
	for i in bits.size():
		var b: Bit = bits[i]
		b.vx += (-b.v - b.vx) * minf(1.0, dt * 1.5)
		b.vz *= 1.0 - minf(1.0, dt * 2.0)
		if wet:
			var dx := b.x - P.x
			var dz := b.z - P.z
			var d := U.hyp(dx, dz)
			if d < 0.55:
				var k := (0.55 - d) / 0.55 * 12.0 * dt
				var dd := d if d != 0.0 else 1.0
				b.vx += dx / dd * k
				b.vz += dz / dd * k
		b.x += b.vx * dt
		b.z += b.vz * dt
		b.yaw += b.spin * dt
		if absf(b.z - Z) > 0.5:
			b.z = Z + signf(b.z - Z) * 0.5
			b.vz *= -0.4
		if b.x < X0 - 0.3:
			b.x = X1 - 0.3
			b.z = Z + (randf() - 0.5) * 0.8
			b.vx = 0.0
		var y := WL + 0.006 + sin(time * 2.1 + i * 1.7 + b.x * 3.0) * 0.005
		var bs := Basis.from_euler(Vector3(sin(time * 1.7 + i) * 0.08, b.yaw, cos(time * 1.3 + i) * 0.08)).scaled_local(Vector3(b.s, 1.0, b.s * (1.0 if i % 3 != 0 else 2.5)))
		junk.set_instance_transform(i, Transform3D(bs, Vector3(b.x, y, b.z)))


func dispose() -> void:
	if crawl != null:
		crawl.dispose()
		crawl = null
