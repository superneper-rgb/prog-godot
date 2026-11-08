class_name CineParts
extends RefCounted
## What cutscene props are made of: JS-style materials, boxes and cylinders, glow sprites, lights, and one-shot sounds written as the JS's sfx.tone / sfx.noise calls (rendered once, kept).

static var _baked: Dictionary = {}


static func lam(c: int, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((c << 8) | 0xff)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	_opts(m, o)
	return m


## JS MeshPhongMaterial: shininess as a roughness, specular as how much it shows
static func phong(c: int, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((c << 8) | 0xff)
	var sh := float(o.get("shininess", 70.0))
	m.roughness = sqrt(2.0 / (sh + 2.0))
	var sp := Color.hex((int(o.get("specular", 0x555555)) << 8) | 0xff)
	m.metallic_specular = clampf((sp.r + sp.g + sp.b) / 3.0 * 1.5, 0.0, 1.0)
	_opts(m, o)
	return m


## JS MeshBasicMaterial({ toneMapped: false })
static func basic(c: int, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((c << 8) | 0xff)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_opts(m, o)
	return m


static func _opts(m: StandardMaterial3D, o: Dictionary) -> void:
	if o.has("opacity"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(o["opacity"])
	if o.get("double", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED


static func mesh(par: Node3D, me: Mesh, m: Material, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> MeshInstance3D:
	var k := MeshInstance3D.new()
	k.mesh = me
	k.material_override = m
	k.position = Vector3(x, y, z)
	par.add_child(k)
	return k


static func box(par: Node3D, w: float, h: float, d: float, x: float, y: float, z: float, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return mesh(par, b, m, x, y, z)


## JS CylinderGeometry(rTop, rBottom, h, seg)
static func cyl(par: Node3D, r0: float, r1: float, h: float, x: float, y: float, z: float, m: Material, sg: int = 10) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = sg
	c.rings = 1
	return mesh(par, c, m, x, y, z)


## JS glow(color, size, additive, opacity): a camera-facing radial sprite, its size the node's scale
static func glow(par: Node3D, c: int, size: float, additive: bool = true, opacity: float = 1.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = load("res://cutscenes/cine_glow.gdshader" if additive else "res://cutscenes/cine_glow_mix.gdshader")
	var col := Color.hex((c << 8) | 0xff)
	col.a = opacity
	m.set_shader_parameter(&"col", col)
	var k := MeshInstance3D.new()
	k.mesh = q
	k.material_override = m
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.scale = Vector3.ONE * size
	k.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	par.add_child(k)
	return k


static func glow_opacity(k: MeshInstance3D, a: float) -> void:
	var m := k.material_override as ShaderMaterial
	var c: Color = m.get_shader_parameter(&"col")
	c.a = a
	m.set_shader_parameter(&"col", c)


## one light of the JS: Godot's energy is its intensity / PI
static func light(par: Node3D, c: int, intensity: float, range_: float, x: float = 0.0, y: float = 0.0, z: float = 0.0, decay: float = 2.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color.hex((c << 8) | 0xff)
	l.light_energy = intensity / PI
	l.omni_range = range_
	l.omni_attenuation = decay
	l.position = Vector3(x, y, z)
	par.add_child(l)
	return l


## A one-shot written as the JS's calls: ["t", when, dur, f0, f1, { type, gain, wet, attack }] for sfx.tone, ["n", when, dur, { type, f0, f1, q, gain, wet, attack }] for sfx.noise, with sfx.tone / sfx.noise's defaults. Rendered the first time, kept by key. The wet send is one per sound here: the mix of the parts'.
static func sound(key: String, parts: Array) -> Dictionary:
	if _baked.has(key):
		return _baked[key]
	var dur := 0.0
	for p: Array in parts:
		dur = maxf(dur, float(p[1]) + float(p[2]))
	var R := 44100
	var b := OfflineSynth.make(dur + 0.02, R)
	var wg := 0.0
	var gs := 0.0
	for p: Array in parts:
		if p[0] == "t":
			var o: Dictionary = p[5] if p.size() > 5 else {}
			var g := float(o.get("gain", 1.0))
			OfflineSynth.tone(b, R, p[1], {"dur": p[2], "f0": float(p[3]), "f1": float(p[4]), "type": StringName(o.get("type", "sine")), "gain": g, "attack": float(o.get("attack", 0.002))})
			wg += g * float(o.get("wet", 0.2))
			gs += g
		else:
			var o: Dictionary = p[3] if p.size() > 3 else {}
			var f0 := float(o.get("f0", 2000.0))
			var g := float(o.get("gain", 1.0))
			OfflineSynth.noise(b, R, p[1], {"dur": p[2], "f0": f0, "f1": float(o.get("f1", f0)), "type": StringName(o.get("type", "lowpass")), "q": float(o.get("q", 0.7)), "gain": g, "attack": float(o.get("attack", 0.002))})
			wg += g * float(o.get("wet", 0.4))
			gs += g
	var r := {"s": OfflineSynth.wav(b, R), "wet": wg / maxf(gs, 1e-4)}
	_baked[key] = r
	return r


static func play(snd: Dictionary, gain: float = 1.0) -> void:
	Game.sfx.clip(snd["s"], {"gain": gain, "wet": snd["wet"]})
