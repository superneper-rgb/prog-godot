class_name AlleyCine
extends RefCounted
## Shared pieces of the BACK ALLEY cutscenes (JS levels/worldbackalley/cine-kit.js; alley_intro.gd, alley_outro.gd): plain cinematic subtitles with babbled voices, a smoothed camera, skip input, cigarettes with smoke for the grays, Prog's body layers (exhausted slump, knees going, face down in the wet), plasma bolts and a few synthesized sounds. Both cutscenes run in the live world like the Meat Spire's: the game gives the player and the rig no input while `cine.on`, renders from `cine.camera` and calls `cine.pose_player(animator)` after the animator's own update.


static func win(t: float, a: float, b: float) -> float:
	return Cutscene.ease_((t - a) / (b - a))


static func wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


static func rr(a: float, b: float) -> float:
	return a + randf() * (b - a)


## the cutscenes holster his gun; anything that ends one early hands the rifle back
static func arm_rifle() -> void:
	var C := Game.combat
	if C == null or C.cur >= 0:
		return
	for i in Weapons.WEAPONS.size():
		if Weapons.WEAPONS[i].id == "rifle":
			if C.owned.has(i):
				C.equip(i)
			return


# ---- subtitles + voice ----
## speaker: { name, color, pitch, at: Callable -> mouth position, talk: Callable(bool) }
class Subs:
	var box: Control
	var nm: Label
	var cap: Label
	var line: Variant = null
	var _a := 0.0
	var _on := false

	func _init() -> void:
		box = Control.new()
		box.name = "BackAlleySubtitle"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		Game.ui.add_child(box)
		var vp := Game.ui.size
		var h := clampi(int(vp.x * 0.022), 20, 28)
		cap = CrtTheme.label("", &"raj600", h, Color("#f5f7fb"))
		_shadow(cap)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(cap)
		nm = CrtTheme.label("", &"raj600", clampi(int(vp.x * 0.0135), 13, 17), Color.WHITE, 2)
		_shadow(nm)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		box.modulate.a = 0.0

	func _shadow(l: Label) -> void:
		var s: LabelSettings = l.label_settings
		s.shadow_color = Color(0, 0, 0, 0.95)
		s.shadow_size = 5
		s.shadow_offset = Vector2(0, 2)
		s.outline_color = Color(0, 0, 0, 0.55)
		s.outline_size = 3

	func _lay() -> void:
		var vp := Game.ui.size
		var w := minf(900.0, vp.x * 0.92)
		var bot := clampf(vp.y * 0.08, 36.0, 96.0)
		cap.size = Vector2(w, 0.0)
		cap.position = Vector2((vp.x - w) * 0.5, 0.0)
		var ch := cap.get_minimum_size().y
		cap.size = Vector2(w, ch)
		cap.position.y = vp.y - bot - ch
		nm.size = Vector2(w, 0.0)
		nm.position = Vector2((vp.x - w) * 0.5, cap.position.y - nm.get_minimum_size().y - 4.0)

	func say(spk: Dictionary, text: String, rate: float = 30.0) -> void:
		if line != null and spk_talk(line["spk"]):
			(line["spk"]["talk"] as Callable).call(false)
		line = {"spk": spk, "text": text, "rate": rate, "t": 0.0, "voiced": 0, "syl": 0, "hold": clampf(text.length() / 15.0 + 0.9, 2.4, 5.2)}
		nm.text = spk["name"]
		nm.label_settings.font_color = Color(String(spk["color"]))
		cap.text = text
		_lay()
		_on = true

	func spk_talk(s: Dictionary) -> bool:
		return s.has("talk") and (s["talk"] as Callable).is_valid()

	func clear() -> void:
		if line != null and spk_talk(line["spk"]):
			(line["spk"]["talk"] as Callable).call(false)
		line = null
		_on = false

	func _voice(i: int) -> void:
		var spk: Dictionary = line["spk"]
		if not spk.has("pitch") or Game.sfx == null:
			return
		var text: String = line["text"]
		var ch := text.unicode_at(i)
		var h := (text.unicode_at(maxi(0, i - 2)) * 31 + text.unicode_at(maxi(0, i - 1)) * 17 + ch * 7 + i * 13)
		var p: Vector3 = (spk["at"] as Callable).call() if spk.has("at") else Vector3(0.0, 1.6, 0.0)
		var nx := text[i + 1] if i + 1 < text.length() else ""
		Game.sfx.play_at("alienSyl", p.x, p.y, p.z, {"range": 40.0, "ref": 4.0, "h": h, "pitch": spk["pitch"], "last": nx == "." or nx == "!" or nx == "?"})

	func tick(dt: float) -> void:
		# (JS CSS: opacity .18s)
		box.modulate.a = move_toward(box.modulate.a, 1.0 if _on else 0.0, Game.get_process_delta_time() / 0.18)
		if line == null:
			return
		line["t"] += dt
		var text: String = line["text"]
		var n := mini(text.length(), floori(float(line["t"]) * float(line["rate"])))
		for i in range(int(line["voiced"]), n):
			var ch := text[i]
			if ".!?,;:".contains(ch):
				if int(line["syl"]) > 0:
					_voice(maxi(0, i - 1))
				line["syl"] = 0
				continue
			if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
				continue
			line["syl"] = int(line["syl"]) + 1
			if int(line["syl"]) >= 2 + (ch.unicode_at(0) & 1):
				line["syl"] = 0
				_voice(i)
		line["voiced"] = n
		if spk_talk(line["spk"]):
			(line["spk"]["talk"] as Callable).call(n < text.length())
		if float(line["t"]) >= float(line["hold"]):
			clear()

	func dispose() -> void:
		if is_instance_valid(box):
			box.queue_free()


# ---- camera ----
## camera.pos / camera.look is what the frame renders from. shot(dt, key, pos, look, rate, cut): rate = how fast it eases there (per second); cut = jump
class Cam:
	var camera := View.Shot.new()
	var p := Vector3.ZERO
	var l := Vector3.ZERO
	var _init_done := false
	var _shake := 0.0
	var _last_key := &""

	func reset() -> void:
		_init_done = false
		_last_key = &""

	func kick(k: float) -> void:
		_shake = maxf(_shake, k)

	## key: a name for the shot; a new key with cut = true jumps instead of easing
	func shot(dt: float, key: StringName, pos: Vector3, look: Vector3, rate: float = 4.0, cut: bool = false) -> void:
		if not _init_done or (cut and key != _last_key):
			p = pos
			l = look
			_init_done = true
		_last_key = key
		var f := 1.0 - exp(-rate * dt)
		p += (pos - p) * f
		l += (look - l) * f
		_shake = maxf(0.0, _shake - dt * 2.5)
		var tt := Time.get_ticks_msec() * 0.001
		var hb := 0.012      # a little handheld drift always
		camera.pos = Vector3(p.x + _j(tt, 0.0) + sin(tt * 0.9) * hb, p.y + _j(tt, 1.7) + sin(tt * 1.3 + 1.0) * hb, p.z + _j(tt, 3.1))
		camera.look = Vector3(l.x + _j(tt, 4.4) * 0.6, l.y + _j(tt, 5.9) * 0.6, l.z + _j(tt, 7.3) * 0.6)

	func _j(tt: float, s: float) -> float:
		return (sin(tt * 47.3 + s) + sin(tt * 31.7 + s * 2.1)) * 0.5 * 0.12 * _shake

	## ease from wherever the shot camera is to the gameplay rig (k 0..1)
	func to_rig(rig: CameraRig, k: float) -> void:
		var q := Cutscene.ease_(k)
		camera.pos = Vector3(lerpf(p.x, rig.pos.x, q), lerpf(p.y, rig.pos.y, q) + sin(PI * q) * 0.8, lerpf(p.z, rig.pos.z, q))
		camera.look = l.lerp(rig.look, q)


# ---- skip: Enter / Space, or the pad's X (read from the input each frame) ----
class Skip:
	var hint: Label = null
	var on := false
	var on_skip: Callable
	var _t := 0.0

	func _init(cb: Callable) -> void:
		on_skip = cb

	func start() -> void:
		on = true
		_t = 0.0
		if hint == null:
			hint = CrtTheme.label("ENTER  SKIP", &"raj600", 15, Color("#cfe8d4"), 2)
			hint.modulate.a = 0.0
			hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
			Game.ui.add_child(hint)
			hint.position += Vector2(-22.0, -16.0)

	func poll() -> void:
		if hint != null:
			_t += Game.get_process_delta_time()
			hint.modulate.a = move_toward(hint.modulate.a, 0.7 if on and _t > 1.5 else 0.0, Game.get_process_delta_time() / 0.6)
		if not on:
			return
		if Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_SPACE) or Inp.key_hit(KEY_KP_ENTER):
			on_skip.call()
		elif Inp.using_pad and Inp.btn(&"attack").pressed:
			Inp.btn(&"attack").pressed = false
			on_skip.call()

	func stop() -> void:
		on = false

	func dispose() -> void:
		if hint != null and is_instance_valid(hint):
			hint.queue_free()
		hint = null


# ---- cigarettes: in the corner of a gray's mouth, an ember that glows on each drag, smoke curling off it ----
class Cigarette:
	var npc: GrayAlienNpc
	var group: Node3D
	var ember: MeshInstance3D
	var puffs: Array[Dictionary] = []
	var mm: MultiMesh
	var t := 0.0
	var seed_ := 0.0
	var next_drag := 0.0
	var drag_t := -9.0
	var _local: Transform3D

	func _init(p_npc: GrayAlienNpc, parent: Node3D, sd: float) -> void:
		npc = p_npc
		seed_ = sd
		t = sd * 2.7
		next_drag = 1.0 + sd * 1.3
		group = Node3D.new()
		parent.add_child(group)
		var paper := StandardMaterial3D.new()
		paper.albedo_color = Color.hex(0xece6daff)
		paper.roughness = 0.8
		var filt := StandardMaterial3D.new()
		filt.albedo_color = Color.hex(0xc7864aff)
		filt.roughness = 0.8
		CineParts.cyl(group, 0.0075, 0.0075, 0.075, 0.0, 0.04, 0.0, paper, 6)
		CineParts.cyl(group, 0.0078, 0.0078, 0.022, 0.0, 0.0, 0.0, filt, 6)
		ember = CineParts.glow(group, 0xff6a20, 0.05)
		ember.position.y = 0.08
		_local = Transform3D(Basis.from_euler(Vector3(PI / 2.0 - 0.35, 0.0, -0.5), EULER_ORDER_XYZ), Vector3(0.045, 0.1, 0.155))      # out of the corner of his mouth, drooping
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mm.mesh = q
		mm.instance_count = 37
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://cutscenes/cine_glow_mix.gdshader")
		sm.set_shader_parameter(&"col", Color.hex(0x9aa4b0ff))
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 50, 400))
		parent.add_child(mi)
		for i in 37:
			puffs.append({"life": 0.0, "max": 1.0, "big": false, "p": Vector3.ZERO, "vx": 0.0, "vy": 0.0, "vz": 0.0})
			mm.set_instance_color(i, Color(1, 1, 1, 0))

	func _puff(at: Vector3, big: bool) -> void:
		for p: Dictionary in puffs:
			if float(p["life"]) <= 0.0:
				p["p"] = at
				p["life"] = AlleyCine.rr(1.6, 2.4) if big else AlleyCine.rr(1.1, 1.8)
				p["max"] = p["life"]
				p["big"] = big
				p["vx"] = AlleyCine.rr(-0.1, 0.1) + (sin(npc.R.yaw) * 0.5 if big else 0.0)
				p["vz"] = AlleyCine.rr(-0.1, 0.1) + (cos(npc.R.yaw) * 0.5 if big else 0.0)
				p["vy"] = 0.25 if big else 0.32
				return

	func update(dt: float) -> void:
		group.global_transform = npc.head_world() * _local
		t += dt
		if t > next_drag:
			drag_t = t
			next_drag = t + AlleyCine.rr(4.0, 7.0)
		var drag := t - drag_t
		var glow_k := 1.0 + 2.2 * sin(PI * drag / 1.1) if drag < 1.1 else 1.0
		CineParts.glow_opacity(ember, minf(1.0, 0.65 + 0.12 * sin(t * 9.0 + seed_) * glow_k))
		ember.scale = Vector3.ONE * (0.05 * glow_k)
		var tip := ember.global_position
		if randf() < dt * 5.0:
			_puff(tip, false)
		if drag > 1.4 and drag < 2.3 and randf() < dt * 14.0:      # the exhale
			_puff(npc.mouth_world(), true)
		for i in puffs.size():
			var p: Dictionary = puffs[i]
			if float(p["life"]) <= 0.0:
				continue
			p["life"] -= dt
			var u := 1.0 - float(p["life"]) / float(p["max"])
			var big: bool = p["big"]
			p["p"] += Vector3((float(p["vx"]) + 0.25) * dt, float(p["vy"]) * dt, float(p["vz"]) * dt)      # the wind takes it down the street
			p["vx"] *= 0.97
			p["vz"] *= 0.97
			var sc := (0.12 if big else 0.05) + u * (0.7 if big else 0.35)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), p["p"]))
			var a := sin(PI * u) * (0.35 if big else 0.22)
			mm.set_instance_color(i, Color(1, 1, 1, 0.0 if float(p["life"]) <= 0.0 else a))

	func flick() -> void:      # dropped
		group.visible = false


# ---- Prog's body ----
## layers on top of the animator's pose, driven by `st` (all 0..1 weights): slump (exhausted hunch), flinch, look (head yaw, radians), and the floor modes
class ProgState:
	var t := 0.0
	var slump := 0.0
	var flinch := 0.0
	var look := 0.0
	var mode := &""
	var u := 0.0
	var _i := {}

	func _k(n: String) -> int:
		if not _i.has(n):
			_i[n] = Animator.KEYS.find(StringName(n))
		return _i[n]

	func _pset(a: Animator, n: String, x: float, y: float, z: float, m: float = 1.0) -> void:
		var i := _k(n)
		if i < 0 or m <= 0.0:
			return
		a.pose[i] = a.pose[i].lerp(Vector3(x, y, z), m)

	func _add(a: Animator, n: String, x: float, y: float, z: float, m: float = 1.0) -> void:
		var i := _k(n)
		if i >= 0:
			a.pose[i] += Vector3(x, y, z) * m

	func hook(a: Animator) -> void:
		var s := slump
		if s > 0.0:      # drenched and done: shoulders up round his ears, back rounded, head hanging, arms dead weight
			_add(a, "spine1", 0.16, 0.0, 0.0, s)
			_add(a, "spine2", 0.16, 0.0, 0.0, s)
			_add(a, "chest", 0.08, 0.0, 0.0, s)
			_add(a, "clavicleL", 0.0, 0.0, 0.2, s)
			_add(a, "clavicleR", 0.0, 0.0, -0.2, s)
			_add(a, "neck", 0.18, 0.0, 0.0, s)
			_add(a, "head", 0.3 + 0.05 * sin(t * 1.7), 0.05 * sin(t * 0.6), 0.04 * sin(t * 1.1), s)
			_add(a, "upper_armL", 0.12, 0.0, -0.08, s)
			_add(a, "upper_armR", 0.12, 0.0, 0.08, s)
			_add(a, "forearmL", 0.15, 0.0, 0.0, s)
			_add(a, "forearmR", 0.15, 0.0, 0.0, s)
		if look != 0.0:
			_add(a, "neck", 0.0, look * 0.35, 0.0)
			_add(a, "head", 0.0, look * 0.65, 0.0)
		if flinch != 0.0:
			_add(a, "head", -0.25, 0.35, 0.2, flinch)
			_add(a, "clavicleR", 0.0, 0.0, -0.25, flinch)
			_add(a, "spine2", -0.06, 0.12, 0.0, flinch)
		if mode == &"kneel":      # knees gone: on them, swaying, head lolling
			var k := u
			var sway := sin(t * 2.1) * 0.06
			_pset(a, "thighL", -1.35 * k, 0.0, 0.1, k)
			_pset(a, "thighR", -1.35 * k, 0.0, -0.1, k)
			_pset(a, "shinL", 1.55 * k, 0.0, 0.0, k)
			_pset(a, "shinR", 1.55 * k, 0.0, 0.0, k)
			_pset(a, "upper_armL", -0.05, 0.0, 0.12, k)
			_pset(a, "upper_armR", -0.05, 0.0, -0.12, k)
			_pset(a, "forearmL", -0.2, 0.0, 0.0, k)
			_pset(a, "forearmR", -0.2, 0.0, 0.0, k)
			_add(a, "spine1", 0.1 + sway, 0.0, 0.04 * sin(t * 1.3), k)
			_add(a, "head", 0.15, 0.1 * sin(t * 0.9), 0.12 * sin(t * 1.4), k)
		elif mode == &"fall" or mode == &"lie":      # face first: arms never come up to break it, legs trail
			var k := 1.0 if mode == &"lie" else u
			var br := sin(t * 1.6) * 0.03 * (1.0 if mode == &"lie" else 0.0)
			_pset(a, "thighL", lerpf(-1.35, 0.08, k), 0.0, 0.14)
			_pset(a, "thighR", lerpf(-1.35, 0.02, k), 0.0, -0.12)
			_pset(a, "shinL", lerpf(1.55, 0.25, k), 0.0, 0.0)
			_pset(a, "shinR", lerpf(1.55, 0.1, k), 0.0, 0.0)
			_pset(a, "upper_armL", lerpf(-0.05, 0.25, k), 0.0, 0.22)
			_pset(a, "upper_armR", lerpf(-0.05, 0.3, k), 0.0, -0.18)
			_pset(a, "forearmL", -0.15, 0.0, 0.0)
			_pset(a, "forearmR", -0.1, 0.0, 0.0)
			_pset(a, "spine1", br, 0.0, 0.0)
			_pset(a, "spine2", 0.0, 0.0, 0.0)
			_pset(a, "head", lerpf(0.15, -0.05, k), lerpf(0.0, 0.75, k), 0.1)      # the face turns to the side as he lands


## the actor's origin is his hips (the model hangs below it): kneeling and lying just move / turn that point
static func place_actor(an: Animator, x: float, y: float, z: float, yaw: float, hip: float, pitch: float) -> void:
	var k := (an.B.pivot * an.B.scale) / 0.95
	an.actor.rotation = Vector3(pitch, yaw, 0.0)
	an.actor.position = Vector3(x, y + hip * k, z)


# ---- plasma bolts ----
class Bolts:
	var parent: Node3D
	var list: Array[Dictionary] = []

	func _init(p: Node3D) -> void:
		parent = p

	func fire(from: Vector3, to: Vector3, speed: float, on_hit: Callable = Callable()) -> void:
		var g := Node3D.new()
		parent.add_child(g)
		CineParts.glow(g, 0x39ff6a, 0.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(Color.hex(0xeaffd8ff), 0.95)
		CineParts.box(g, 0.06, 0.06, 0.8, 0.0, 0.0, 0.0, m).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.position = from
		var dir := (to - from).normalized()
		g.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		list.append({"g": g, "from": from, "dir": dir, "len": from.distance_to(to), "d": 0.0, "speed": speed, "on_hit": on_hit, "to": to})

	func update(dt: float) -> void:
		for i in range(list.size() - 1, -1, -1):
			var b: Dictionary = list[i]
			b["d"] += float(b["speed"]) * dt
			(b["g"] as Node3D).position = (b["from"] as Vector3) + (b["dir"] as Vector3) * minf(b["d"], b["len"])
			if float(b["d"]) >= float(b["len"]):
				(b["g"] as Node3D).queue_free()
				list.remove_at(i)
				if (b["on_hit"] as Callable).is_valid():
					(b["on_hit"] as Callable).call(b["to"])


# ---- sounds ----
## a plasma bolt tearing past one ear: a hiss that sweeps down as it passes
static func snd_whizz() -> void:
	CineParts.play(CineParts.sound("ba.whizz", [["n", 0.0, 0.5, {"type": "bandpass", "f0": 5200.0, "f1": 700.0, "q": 2.2, "gain": 0.9, "attack": 0.18, "wet": 0.15}], ["t", 0.1, 0.35, 2600.0, 500.0, {"type": "sawtooth", "gain": 0.08, "attack": 0.08, "wet": 0.2}]]))


static func snd_pistol(p: Vector3) -> void:
	Game.sfx.play_at("plasma", p.x, p.y, p.z, {"range": 80.0})


static func snd_whistle() -> void:
	CineParts.play(CineParts.sound("ba.whistle", [["t", 0.0, 0.32, 1900.0, 2700.0, {"gain": 0.28, "attack": 0.03, "wet": 0.5}], ["t", 0.36, 0.5, 2700.0, 1500.0, {"gain": 0.3, "attack": 0.03, "wet": 0.6}]]))


static func snd_rise() -> void:
	CineParts.play(CineParts.sound("ba.rise", [["n", 0.0, 0.3, {"type": "bandpass", "f0": 900.0, "f1": 1800.0, "q": 0.9, "gain": 0.25, "attack": 0.08, "wet": 0.25}], ["t", 0.0, 0.12, 2200.0, 1500.0, {"type": "square", "gain": 0.05, "wet": 0.3}]]))


static func snd_sting() -> void:
	CineParts.play(CineParts.sound("ba.sting", [["t", 0.0, 1.6, 55.0, 41.0, {"type": "sawtooth", "gain": 0.35, "attack": 0.02, "wet": 0.5}], ["t", 0.0, 1.6, 110.0, 82.0, {"type": "square", "gain": 0.08, "wet": 0.5}], ["n", 0.0, 0.8, {"type": "lowpass", "f0": 1200.0, "f1": 120.0, "gain": 0.5, "wet": 0.5}]]))


static func snd_splash_big() -> void:
	var p := [["n", 0.0, 0.9, {"type": "bandpass", "f0": 1800.0, "f1": 400.0, "q": 0.7, "gain": 0.9, "attack": 0.005, "wet": 0.35}], ["t", 0.0, 0.25, 160.0, 50.0, {"gain": 0.8, "wet": 0.3}]]
	for i in 6:
		p.append(["n", 0.15 + i * rr(0.05, 0.12), 0.07, {"type": "bandpass", "f0": rr(1800.0, 3800.0), "q": 3.0, "gain": 0.18, "wet": 0.3}])
	CineParts.play(CineParts.sound("ba.splash", p))


static func snd_thud() -> void:
	CineParts.play(CineParts.sound("ba.thud", [["t", 0.0, 0.3, 95.0, 32.0, {"gain": 0.8, "wet": 0.3}], ["n", 0.0, 0.18, {"type": "lowpass", "f0": 900.0, "f1": 200.0, "gain": 0.6, "wet": 0.25}]]))


static func snd_breath() -> void:
	CineParts.play(CineParts.sound("ba.breath", [["n", 0.0, 1.1, {"type": "bandpass", "f0": 1000.0, "f1": 600.0, "q": 0.8, "gain": 0.16, "attack": 0.4, "wet": 0.2}]]))


static func snd_bubbles() -> void:
	var p := []
	for i in 9:
		p.append(["t", i * rr(0.06, 0.14), 0.06, rr(300.0, 700.0), rr(800.0, 1400.0), {"gain": 0.12, "wet": 0.3}])
	CineParts.play(CineParts.sound("ba.bubbles", p))


static func snd_groan() -> void:
	CineParts.play(CineParts.sound("ba.groan", [["t", 0.0, 0.9, 120.0, 80.0, {"type": "sawtooth", "gain": 0.12, "attack": 0.15, "wet": 0.4}], ["n", 0.0, 0.9, {"type": "bandpass", "f0": 600.0, "f1": 350.0, "q": 1.4, "gain": 0.12, "attack": 0.15, "wet": 0.4}]]))
