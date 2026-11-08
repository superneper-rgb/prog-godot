class_name KameLabLevel
extends KitLevel
## KAME LAB (JS levels/kame-lab/level.js): a flat, empty test floor for prototyping the Kamehameha (kamehameha.gd) against a few respawning enemies, apart from the core game. Unarmed. Hold fire to wind up and charge, let go to fire; the player can't take damage here. Enemies stand still until K wakes them; each comes back RESPAWN_T seconds after it dies.
## The JS borrows player.update, combat._punch and animator.update for the level; here: Player.rooted, Combat.fire_punch_off and punch_off, and the frame's after_player / after_animator hooks.

const RESPAWN_T := 3.0
const SLOTS := [{"x": -6.0, "z": 18.0}, {"x": 0.0, "z": 24.0}, {"x": 6.0, "z": 18.0}, {"x": -12.0, "z": 34.0, "kind": "alien"}, {"x": 12.0, "z": 34.0, "kind": "alien"}, {"x": 0.0, "z": 44.0}]

var loadout: Array = []      # unarmed: fire is the Kamehameha
var hud_unarmed := {"title": "KAMEHAMEHA", "sub": "HOLD FIRE - RELEASE"}
var kame: Kamehameha = null
var _slots: Array[Dictionary] = []
var _hud: Control = null
var _fill: ColorRect = null
var _name_l: Label = null


func kit_options() -> Dictionary:
	return {"id": "kame-lab", "name": "KAME LAB", "spawn": {"x": 0.0, "y": 1.0, "z": 0.0, "yaw": 0.0}}


func setup() -> void:
	for s: Dictionary in SLOTS:
		var d := s.duplicate()
		d["r"] = null
		d["t"] = 0.0
		_slots.append(d)
	kame = Kamehameha.new(Game.combat, func(x: float, z: float, y: float) -> float:
		var g := world.ground_height(x, z, 0.1, y)
		return g if is_finite(g) and g > -INF else 0.0, func() -> Vector3: return -Game.camera.global_basis.z)
	add_child(kame)
	Config.ai_freeze = 1      # dummies by default; K wakes them up (a level's Config value is put back on leaving)
	_build_hud()
	bo.stage({"id": "lab", "name": "Lab", "task": "Hold FIRE to charge a Kamehameha, release to fire.", "objectives": [
		{"id": "play", "label": "Free play", "kind": "custom", "guide": false, "text": "Hold FIRE to charge a Kamehameha, release to fire. Enemies come back after 3 s. K: enemies stand still / fight.", "done": func(_b: Blockout, _p: Player, _c: Combat) -> bool: return false},
	]})


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.ui.add_child(_hud)
	var col := Color("#8dffb4")
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.custom_minimum_size = Vector2(300, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position.y = -150.0
	_hud.add_child(box)
	var l := CrtTheme.label("KAMEHAMEHA", &"vt323", 16, col, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var tr_ := ColorRect.new()
	tr_.color = Color("#031008")
	tr_.custom_minimum_size = Vector2(300, 12)
	box.add_child(tr_)
	_fill = ColorRect.new()
	_fill.color = Color("#2fd46a")
	_fill.size = Vector2(0, 12)
	tr_.add_child(_fill)
	for f: float in [0.25, 0.5, 0.75]:
		var tk := ColorRect.new()
		tk.color = Color("#031008")
		tk.position = Vector2(300.0 * f, 0.0)
		tk.size = Vector2(1, 12)
		tr_.add_child(tk)
	box.modulate.a = 0.0
	_hud.set_meta("box", box)
	_name_l = CrtTheme.label("Kamehameha", &"vt323", 28, Color("#bfe6ff"), 3)
	_name_l.position = Vector2(34, 120)
	_name_l.modulate.a = 0.0
	_hud.add_child(_name_l)


func tick_level(dt: float) -> void:
	var P := Game.player
	if P == null or kame == null:
		return
	P.hp = P.max_hp      # a test floor: nothing kills you
	kame.combat = Game.combat      # (not there yet when the level is built)
	Game.combat.fire_punch_off = true
	Game.combat.punch_off = kame.busy
	P.rooted = kame.rooted
	kame.update(dt, P, Inp.btn(&"fire"))
	_respawn(dt)
	if Inp.key_hit(KEY_K):
		Config.ai_freeze = 0 if Config.ai_freeze != 0 else 1
		Game.hud.toast("ENEMIES: DUMMIES" if Config.ai_freeze != 0 else "ENEMIES: AWAKE")
	var s := kame.state
	var ch := s == "wind" or s == "charge" or s == "thrust"
	var rd := get_process_delta_time()
	var box: Control = _hud.get_meta("box")
	var dlg: bool = Game.dialogue.on or Game.cutscene_on() != null      # (JS body.dlg #kame-hud { visibility: hidden })
	box.modulate.a = move_toward(box.modulate.a, 1.0 if ch and not dlg else 0.0, rd / 0.15)
	_fill.color = Color("#ffb43c") if kame.k >= 1.0 else Color("#2fd46a")
	_fill.size.x = 300.0 * kame.k
	_name_l.modulate.a = move_toward(_name_l.modulate.a, 1.0 if (s == "thrust" or s == "beam" or s == "fade") and not dlg else 0.0, rd / 0.25)


## JS P.update's tail: he turns to the aim while the move has him
func after_player(dt: float) -> void:
	var P := Game.player
	if kame != null and kame.rooted:
		P.vx *= exp(-12.0 * dt)
		P.vz *= exp(-12.0 * dt)
	if kame != null and kame.busy:
		P.yaw += atan2(sin(kame.yaw_ - P.yaw), cos(kame.yaw_ - P.yaw)) * (1.0 - exp(-16.0 * dt))


## JS an.update's tail: the move's arm / torso pose after the normal one
func after_animator(an: Animator, dt: float) -> void:
	if kame != null:
		kame.pose(an, Game.player, dt)


## keep each slot filled: a dead (or vanished) enemy is cleared and replaced after RESPAWN_T
func _respawn(dt: float) -> void:
	for s: Dictionary in _slots:
		var r: Robot = s["r"]
		if r != null and not r.dead and not r.gone:
			continue
		s["t"] += dt
		if r != null and float(s["t"]) < RESPAWN_T:
			continue
		if r != null:
			Game.despawn_enemy(r)
		s["r"] = bo.spawn([s["x"], 0.0, s["z"]], {"kind": s.get("kind", "robot")})
		s["t"] = 0.0


func on_exit() -> void:
	super.on_exit()
	var P := Game.player
	if P != null:
		P.rooted = false
	Game.combat.fire_punch_off = false
	Game.combat.punch_off = false
	if kame != null:
		kame.quiet()
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
