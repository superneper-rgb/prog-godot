class_name VhStorm
extends RefCounted
## VISITING HOURS storm (JS storm.js): the cloud dome and the rain are the export's shaders, fed here; lightning (a jagged bolt, the sky and the whole marsh lit for a moment, the fog thinned so the prison stands out) and its thunder, which arrives late by the strike's distance (sound at 343 m/s).

const FOG := 0x213a5c
const FOG_D := 0.0021
const HEMI_SKY := 0x7088b4
const HEMI_GROUND := 0x2a2430
const HEMI0 := 1.35
const MAX_PTS := 600

var lv: ExportedLevel
var audio: VhAudio
var sky: Node3D
var rain: Node3D
var sky_m: ShaderMaterial
var rain_m: ShaderMaterial
var bolt: MeshInstance3D
var bolt_mesh := ArrayMesh.new()
var glow_sp: MeshInstance3D
var flash := 0.0
var mist := 1.0
var next_t := 4.0
var strikes: Array = []
var sheet_t := 2.0
var sheet_k := 0.0
var _hemi_last := -1.0
var fog_col := MsKit.srgb(FOG)
var fog_flash := MsKit.srgb(0x86a4dc)
var fog_warm := MsKit.srgb(0x553524)
var color_now := MsKit.srgb(FOG)


func _init(p_lv: ExportedLevel, p_audio: VhAudio) -> void:
	lv = p_lv
	audio = p_audio
	var ports: ShaderPorts = lv.shader_ports
	sky_m = ports.mats.get("shader_2a7ca1#0")
	rain_m = ports.mats.get("shader_312693#0")
	sky = VhKit.one(lv, "vh-sky")
	rain = VhKit.one(lv, "vh-rain")
	for mi in VhKit.meshes(sky):
		mi.extra_cull_margin = 16384.0
	for mi in VhKit.meshes(rain):      # (JS frustumCulled false: the shader carries it round the camera)
		mi.extra_cull_margin = 16384.0
	for n: Node3D in lv.node_named("vh-bolt"):
		n.visible = false
	for n: Node3D in lv.node_named("vh-bolt-glow"):
		n.visible = false
	bolt = MsKit.glow(lv, bolt_mesh, 0, 0xe8f0ff, 1.0)
	bolt.extra_cull_margin = 16384.0
	bolt.visible = false
	glow_sp = MsKit.sprite8(lv, 0xbfd2ff, 0.0, 260.0)
	glow_sp.visible = false


func _make_bolt(x: float, z: float, top: float) -> void:
	var pts := PackedVector3Array()
	_branch(pts, Vector3(x, top, z), Vector3.ZERO, top * 1.4, 0)
	bolt_mesh.clear_surfaces()
	if pts.size() < 2:
		return
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	bolt_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)


func _branch(pts: PackedVector3Array, p: Vector3, dir: Vector3, len_: float, depth: int) -> void:
	var q := p
	var steps := int(ceil(len_ / 18.0))
	for _i in steps:
		if pts.size() + 2 > MAX_PTS:
			return
		var r := q + Vector3(dir.x * 18.0 + (randf() - 0.5) * 22.0, -18.0 * (0.6 + randf() * 0.6), dir.z * 18.0 + (randf() - 0.5) * 22.0)
		if r.y < 0.0:
			r.y = 0.0
		pts.append(q)
		pts.append(r)
		if depth < 2 and randf() < 0.22:
			_branch(pts, r, Vector3((randf() - 0.5) * 1.4, 0.0, (randf() - 0.5) * 1.4), len_ * 0.35, depth + 1)
		q = r
		if q.y <= 0.0:
			break


func _cam() -> Vector3:
	return Game.camera.global_position if Game.camera != null else Vector3.ZERO


## a strike now: at (x, z) (default: somewhere 200-900 m from the camera), big = brighter, longer, closer-sounding
func strike(x: float = NAN, z: float = NAN, big: bool = false) -> void:
	var cam := _cam()
	if is_nan(x):
		var a := randf() * TAU
		var dd := 200.0 + randf() * 700.0
		x = cam.x + sin(a) * dd
		z = cam.z + cos(a) * dd
	if sky_m != null:
		sky_m.set_shader_parameter(&"uStrike", Vector3(x - cam.x, 300.0, z - cam.z))
	_make_bolt(x, z, 260.0 + randf() * 120.0)
	glow_sp.position = Vector3(x, 220.0, z)
	glow_sp.scale = Vector3.ONE * (420.0 if big else 260.0)
	var d := U.hyp(x - cam.x, z - cam.z)
	var pattern: Array = [0.0, 0.09, 0.2, 0.34] if big else ([0.0, 0.12] if randf() < 0.5 else [0.0, 0.08, 0.22])
	strikes.append({"t": 0.0, "pattern": pattern, "big": big, "life": 0.6 if big else 0.42})
	audio.thunder(d / 343.0, d, big)      # the rumble comes late: count the gap
	if Game.fx != null and d < 500.0:
		Game.fx.shake = maxf(Game.fx.shake, 0.35 if big else 0.15)


## schedule the next ambient strike sooner / later; force(x, z) = the scripted reveal
func reveal(x: float, z: float) -> void:
	strike(x, z, true)
	next_t = 9.0 + randf() * 4.0


func update(dt: float, time: float, o: Dictionary) -> void:
	var cam := _cam()
	sky.global_position = Vector3(cam.x, 0.0, cam.z)
	if rain_m != null:
		rain_m.set_shader_parameter(&"uLit", 1.0 if o.get("headlights", false) else 0.0)
	rain.visible = not o.get("indoors", false)
	next_t -= dt
	if next_t <= 0.0:
		strike()
		next_t = 5.0 + randf() * 9.0
	# the flash: a strike is a few stutters of light (pattern = start times) decaying fast
	var f := 0.0
	var on := false
	for i in range(strikes.size() - 1, -1, -1):
		var s: Dictionary = strikes[i]
		s.t = float(s.t) + dt
		for p: float in s.pattern:
			var k := float(s.t) - p
			if k >= 0.0:
				f = maxf(f, (1.3 if s.big else 0.85) * exp(-k * 14.0) * (k / 0.03 if k < 0.03 else 1.0))
		if float(s.t) >= float(s.life) + 0.4:
			strikes.remove_at(i)
		elif float(s.t) < float(s.life):
			on = true
	var show := on and f > 0.08
	bolt.visible = show
	glow_sp.visible = show
	if show:
		MsKit.opa(bolt, minf(1.0, f * 1.4))
		MsKit.opa(glow_sp, minf(1.0, f))
	flash = f
	# sheet lightning: flickers inside the cloud somewhere far off, no bolt, no thunder you can hear
	sheet_t -= dt
	if sheet_t <= 0.0:
		sheet_t = 1.5 + randf() * 4.0
		sheet_k = 0.6 + randf() * 0.6
		var a := randf() * TAU
		if sky_m != null:
			sky_m.set_shader_parameter(&"uSheetDir", Vector3(sin(a), 0.12 + randf() * 0.25, cos(a)))
	sheet_k = maxf(0.0, sheet_k - dt * 3.5)
	if sky_m != null:
		sky_m.set_shader_parameter(&"uFlash", f)
		sky_m.set_shader_parameter(&"uSheet", sheet_k * (0.6 + 0.4 * sin(time * 41.0) * sin(time * 17.0)))
		var ga: Vector2 = o.get("glow_at", Vector2.ZERO)
		var ca: Vector2 = o.get("city_at", Vector2.ZERO)
		sky_m.set_shader_parameter(&"uGlowDir", (ga - Vector2(cam.x, cam.z)).normalized())
		sky_m.set_shader_parameter(&"uCityDir", (ca - Vector2(cam.x, cam.z)).normalized())
	if rain_m != null:
		rain_m.set_shader_parameter(&"uFlash", f)
	# the world lit by it: hemi up, fog colour up and thinner (the far prison shows), background follows the fog
	var he := HEMI0 * float(o.get("amb", 1.0)) + f * 3.2 * float(o.get("flash_in", 1.0))      # (indoors: less sky, and the flash only through the windows)
	if absf(he - _hemi_last) > 0.004:
		_hemi_last = he
		Game.view.set_hemi(MsKit.srgb(HEMI_SKY), MsKit.srgb(HEMI_GROUND), he)
	# night: past the drive the storm closes in (darker air); warm: the prison's sodium creeping into the air as you close on it
	# (three.js mixes these in linear; the View takes display colours)
	var l := fog_col.srgb_to_linear().lerp(fog_warm.srgb_to_linear(), float(o.get("warm", 0.0)))
	var nk := 1.0 - float(o.get("night", 0.0)) * 0.55
	l = Color(l.r * nk, l.g * nk, l.b * nk).lerp(fog_flash.srgb_to_linear(), minf(1.0, f))
	var c := l.linear_to_srgb()
	color_now = c
	Game.view.set_fog_exp2(c, FOG_D * mist * (1.0 - minf(0.6, f * 0.55)))
	Game.view.set_background(c)
	if sky_m != null:
		sky_m.set_shader_parameter(&"uFog", Vector3(l.r, l.g, l.b))
