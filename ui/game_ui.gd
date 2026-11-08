class_name GameUi
extends Control
## All the 2D interface under Game.ui_root, built once for the session, and the flow between its screens: boot terminal, logo sting, developer note, main menu, play, pause, back to the menu
## (index.html main.js: start, setPaused, backToMenu, launchLevel, continueGame, playSlot, the part of frame() that reads the menus). Pointer capture: on at play and resume, free on menus.

const VERSION_TEXT := "PROG ALPHA 0.0.5"
const SANDBOX_LEVELS: Array[String] = ["dev"]    # never CONTINUEd into
const PREFS := "user://prefs.cfg"

var hud: Hud
var dialog: DialogBox
var wheel: Wheel
var pause: PauseMenu
var menu: MainMenu
var console: DebugConsole
var tuning: TuningPanel
var _ver: PanelContainer
var _fade: ColorRect
var _fade_lab: Label
var _fade_t := 0.0
var _fade_on := false
var _boot: BootScreen = null
var _intro: Node = null
var launching := false
var _backing_out := false
var _force_enter := false
var _relock_after_tools := false
var interact_hint := Callable()     # () -> {key, text, cls} or {}: the talkers, doors and level actions (JS nearInteract); the wheel's drop prompt is handled here
var last_unlock_ms := -100000
var wheel_discard := false          # X / Delete with the wheel open
var drop_req := false               # X near a weapon on the ground
var dlg_req := false                # X: skip a line, or use what is in reach
var autosave_t := 0.0


func _init() -> void:
	name = "GameUi"
	CrtTheme.full(self)
	z_index = 0


func _ready() -> void:
	CrtTheme.fit_window(get_window())
	_prefs_load()
	hud = Hud.new()
	add_child(hud)
	dialog = DialogBox.new()
	add_child(dialog)
	interact_hint = func() -> Dictionary: return Game.doors.hint()
	wheel = Wheel.new()
	wheel.info = func() -> Dictionary: return {"money": Game.money, "hp": Game.player.hp if Game.player != null else 0.0, "max_hp": Game.player.max_hp if Game.player != null else 100.0}
	add_child(wheel)
	tuning = TuningPanel.new()
	add_child(tuning)
	menu = MainMenu.new()
	add_child(menu)
	pause = PauseMenu.new()
	add_child(pause)
	# #ver
	_ver = PanelContainer.new()
	_ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ver.add_theme_stylebox_override(&"panel", CrtTheme.panel(Color(0, 0, 0, 0.22), 4, Color(0, 0, 0, 0), 8, 3))
	_ver.add_child(CrtTheme.label(VERSION_TEXT, &"raj600", 11, Color(235.0 / 255.0, 242.0 / 255.0, 1.0, 0.8), 2))
	_ver.anchor_left = 1.0
	_ver.anchor_right = 1.0
	_ver.offset_right = -8.0
	_ver.offset_left = -8.0
	_ver.offset_top = 2.0
	_ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ver.z_index = 70
	add_child(_ver)
	# #travelfade
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	CrtTheme.full(_fade)
	_fade.z_index = 200
	_fade.modulate.a = 0.0
	_fade.visible = false
	_fade_lab = CrtTheme.label("", &"vt323", 16, Color("4fd479"), 3)
	_fade_lab.anchor_top = 1.0
	_fade_lab.anchor_bottom = 1.0
	_fade_lab.offset_left = 28.0
	_fade_lab.offset_top = -24.0 - 16.0
	_fade.add_child(_fade_lab)
	add_child(_fade)
	console = DebugConsole.new()
	add_child(console)
	ConsoleCommands.register_basic(console)
	Game.menu_cam = _menu_cam
	Game.freecam = Freecam.new()


# ---- preferences (the browser's localStorage: prog.character, prog.costume) ----

func _prefs_load() -> void:
	var c := ConfigFile.new()
	if c.load(PREFS) == OK:
		var id: String = c.get_value("menu", "character", Game.char_pick)
		var given := false
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--char="):
				given = true
		if Builds.BUILDS.has(id) and not given:
			Game.char_pick = id
		var co: String = c.get_value("menu", "costume", Builds.prog_costume)
		Builds.prog_costume = co if co in ["prog_v2", "prog_v3"] else "standard"


func prefs_save() -> void:
	var c := ConfigFile.new()
	c.set_value("menu", "character", Game.char_pick)
	c.set_value("menu", "costume", Builds.prog_costume)
	c.save(PREFS)


# ---- JS UI: the screens ----

func show_start(on: bool, fade_in: bool = false) -> void:
	menu.show_menu(on, fade_in)


func show_pause(on: bool) -> void:
	pause.on_pause(on)


## The line under the menu ("Loading ...").
func set_loading(m: String) -> void:
	menu.msg = m


# ---- the boot terminal, then the opening ----

## The UI part of the boot warm-up (JS warmUp: 'Weapon wheel', 'Screen effects'): every screen's shaders and viewports are made here, behind the boot terminal, instead of the first time each one opens in play.
func warm_up() -> void:
	boot_step("Weapon wheel", 0.9)
	wheel.warm()
	boot_step("Menu backdrop", 0.93)
	menu.prepare_scene()
	boot_step("Screen effects", 0.95)
	hud.warm(true)
	pause.visible = true
	pause._view.refresh()
	menu.visible = true
	await wheel.prerender(4)
	hud.warm(false)
	pause.visible = false
	menu.visible = false


func boot_show() -> void:
	_boot = BootScreen.new()
	add_child(_boot)


func boot_step(label: String, frac: float) -> void:
	if _boot != null:
		_boot.set_step(label, frac)


func boot_hide() -> void:
	if _boot != null:
		_boot.hide_out()
		_boot = null


## The opening that plays on load: the logo sting, the developer note, then the menu fades in. Any failure there would leave the menu up, as the JS does.
func play_intro() -> void:
	hud.set_suppressed(true)
	_intro = LogoIntro.new()
	_intro.on_done = func() -> void:
		_intro = DevNotice.new()
		_intro.on_done = func() -> void:
			_intro = null
			show_menu(true)
		add_child(_intro)
	add_child(_intro)


## The menu over the world (or straight, with no opening).
func show_menu(fade_in: bool = false) -> void:
	unlock()
	hud.set_suppressed(true)
	if Game.animator != null:
		Game.animator.actor.visible = false
	show_start(true, fade_in)


func _menu_cam(now_ms: int) -> View.Shot:
	# slow pan around the street behind the menu: the camera stands in the world and turns; the world's own spawn point is where it stands
	var s := View.Shot.new()
	var w := Game.world
	if w == null:
		return s
	var sp: Dictionary = w.spawn
	var a := now_ms * 0.00012
	var R := 12.0
	s.pos = Vector3(sp.x, 2.4 + 0.15 * sin(now_ms * 0.0003), sp.z)
	s.look = Vector3(sp.x + sin(a) * R, 2.0, sp.z + cos(a) * R)
	return s


# ---- start / pause / pointer lock ----

func lock() -> void:
	if not Peek.enabled:      # (tests drive an off-screen window with no focus)
		Inp.set_pointer_lock(true)


func unlock() -> void:
	if Inp.pointer_locked:
		last_unlock_ms = Time.get_ticks_msec()
	Inp.set_pointer_lock(false)


func start(with_lock: bool) -> void:
	if Game.started:
		return
	Game.spawn_character(Game.char_pick)
	wheel.set_character(Game.char_pick)     # the wheel's terminal frames for this character (Tommy's hands are white)
	show_start(false)
	menu._chars.dispose()
	hud.set_suppressed(false)
	Game.started = true
	if with_lock:
		lock()
	Game.save_game()            # the slot now holds a game, starting here
	if Game.music != null and Game.music.has_method(&"play"):
		Game.music.play()
	if Game.level != null:
		Game.level.start_music()


func set_paused(p: bool) -> void:
	if not Game.started or Game.paused == p:
		return
	Game.paused = p
	if p:
		var s = Game.sfx
		if s != null and s.enemy_audio != null:
			s.enemy_audio.stop()
		if Game.level != null and Game.level.has_method(&"audio_stop"):
			Game.level.audio_stop()
	if Game.music != null and Game.music.has_method(&"duck"):
		Game.music.duck(p)
	show_pause(p)
	CrtTheme.menu_sound("open" if p else "close")
	if p and Inp.pointer_locked:
		unlock()


## PLAY / a level picked on the main menu: swap it in and start.
func launch_level(id: String) -> void:
	if Game.started or launching:
		return
	if Game.level != null and id == Game.level.id:
		start(true)
		return
	launching = true
	set_loading("Loading " + MainMenu.level_name(id) + "...")
	await get_tree().process_frame
	await get_tree().process_frame
	await Game.enter_level(id)
	launching = false
	set_loading("")
	start(true)


## CONTINUE: play the slot in use from where it was saved (its level, the door it came in by). A new slot starts in the default level.
func continue_game() -> void:
	if Game.started or launching:
		return
	var w: Dictionary = Game.save.data.where
	var lv: String = w.get("level", "")
	var id: String = lv if (Game.LEVELS.has(lv) and not SANDBOX_LEVELS.has(lv)) else Game.DEFAULT_LEVEL
	var sa: String = w.get("spawn_at", "")
	if Game.level == null or id != Game.level.id or sa != "" or _force_enter:
		_force_enter = false
		launching = true
		set_loading("Loading " + MainMenu.level_name(id) + "...")
		await get_tree().process_frame
		await get_tree().process_frame
		await Game.enter_level(id, sa)
		launching = false
		set_loading("")
	start(true)


## A slot picked on NEW GAME / LOAD GAME: it becomes the slot in use, everything built from the save is rebuilt from it, and play goes straight into CONTINUE. (The JS reloaded the page for this.)
func play_slot(n: int, is_fresh: bool) -> void:
	if is_fresh:
		Game.save.fresh(n)
	else:
		Game.save.select(n)
	Game.use_save_record()
	_force_enter = true
	set_fade(true, "")
	await get_tree().create_timer(0.45).timeout
	await continue_game()
	await get_tree().create_timer(0.35).timeout
	set_fade(false)


## RETURN TO MENU (pause menu): back to the main menu without a restart. Fades out, closes whatever is open, puts the default level back as a fresh boot would have it (the save and the story are kept) and brings back the menu.
func back_to_menu() -> void:
	if not Game.started or _backing_out:
		return
	_backing_out = true
	set_fade(true, "MAIN MENU ...")
	await get_tree().create_timer(0.48).timeout
	unlock()
	if Game.paused:
		Game.paused = false
		show_pause(false)
		if Game.music != null and Game.music.has_method(&"duck"):
			Game.music.duck(false)
	for m: Variant in Game.menus:
		if m != null and m.is_open:
			m.close()
	if wheel.is_open:
		wheel.close()
	if Game.vehicles != null and Game.vehicles.driving:
		Game.vehicles.exit(true)
	Game.time_scale = 1.0
	Game.save_game()              # (while still playing, so CONTINUE comes back here)
	Game.started = false          # (enter_level runs with the game stopped, as at boot)
	hud.dead(false)
	await Game.enter_level(Game.DEFAULT_LEVEL)
	show_menu()
	_backing_out = false
	await get_tree().create_timer(0.15).timeout
	set_fade(false)


func quit_game() -> void:
	Game.save_game()
	get_tree().quit()


## #travelfade: to black over .45 s, with an optional line of phosphor at the bottom left.
func set_fade(on: bool, label: String = "") -> void:
	_fade_on = on
	_fade_lab.text = label
	_fade.visible = true
	set_process(true)


func _process(delta: float) -> void:
	_fade.modulate.a = move_toward(_fade.modulate.a, 1.0 if _fade_on else 0.0, delta / 0.45)
	_fade_t += delta
	_fade_lab.modulate.a = 1.0 if fmod(_fade_t, 1.1) < 0.55 else 0.35
	if not _fade_on and _fade.modulate.a <= 0.0:
		_fade.visible = false
		set_process(false)


# ---- the frame's UI part (JS frame(): the start of the started branch) ----

## Before the simulation: menus, the pause pad, the pause and F3 keys, number keys, X. Returns nothing; Game reads the flags it set.
func frame_begin(dt: float) -> void:
	if not Game.started:
		if _intro == null and _boot == null and not launching and not _backing_out:
			if menu.visible and not console.is_open:
				menu.pad()
		return
	if Game.paused:
		pause.update_pause_pad(dt)
	if Inp.btn(&"pause").pressed and not Game.menu_open() and (Inp.using_pad or Time.get_ticks_msec() - last_unlock_ms > 250):
		set_paused(not Game.paused)
		if not Game.paused:
			lock()
	if Inp.btn(&"debug").pressed:
		tuning.toggle_debug()
		if tuning.debug_open and Inp.pointer_locked:
			_relock_after_tools = true
			unlock()
		elif not tuning.debug_open and _relock_after_tools:
			_relock_after_tools = false
			lock()
	if not Game.paused and not wheel.is_open and not Game.menu_open():
		# number keys = wheel slots
		for n in 10:
			if Inp.key_hit(KEY_0 + n):
				if Game.combat != null:
					if n == 0:
						Game.combat.equip(-1)
					else:
						var v: Variant = Game.combat.slots[n - 1] if n - 1 < Game.combat.slots.size() else null
						if v != null:
							Game.combat.equip(v)
				break
	# JS keydown: X asks for the dialogue path whenever the game is running and the wheel is shut, a line of dialogue included (which counts as a menu below)
	if not Game.paused and not wheel.is_open and Inp.key_hit(KEY_X):
		dlg_req = true
	# weapons on the ground / in the wheel: X picks up the one in reach; with the wheel open, X (or Delete) discards the highlighted weapon
	if not Game.paused and not Game.menu_open() and Game.combat != null:
		var x := Inp.key_hit(KEY_X)
		if wheel.is_open:
			if x or Inp.key_hit(KEY_DELETE):
				wheel_discard = true
		elif x:
			if Game.combat.drop_focus != null:
				drop_req = true
			dlg_req = true
	# autosave: play time, and a quiet autosave every minute of play
	if not Game.paused:
		Game.save.data.play_ms += dt * 1000.0 / maxf(Game.time_scale, 0.001)
		autosave_t += dt
		if autosave_t > 60.0:
			autosave_t = 0.0
			Game.save_game()


## At the end of the frame: the near-interact prompt, the HUD.
func frame_end(dt: float) -> void:
	var G := Game
	var show := G.started and not G.paused
	var combat: Combat = G.combat
	if G.player != null and hud != null:
		# (the JS: near TV, clerk, armory, plasmid, depot come with the shops; then talkers, doors and actions; then a weapon on the ground)
		var can := G.started and not G.paused and not wheel.is_open and not G.menu_open()
		var done := false
		if can:
			var sh: Dictionary = G.shops.hint()
			if not sh.is_empty():
				hud.hint(sh.text, sh.cls, sh.key)
				done = true
		if not done and can and interact_hint.is_valid():
			var h: Dictionary = interact_hint.call()
			if not h.is_empty():
				hud.hint(h.get("text", ""), h.get("cls", "talk"), h.get("key", "X"))
				done = true
		if not done:
			if can and combat != null and combat.drop_focus != null:
				var d: Combat.Drop = combat.drop_focus
				var w := Weapons.WEAPONS[d.i]
				var own: bool = combat.owned.has(d.i)
				if own and combat.ammo[d.i] + combat.reserve[d.i] >= w.max:
					hud.hint(w.name + " — AMMO FULL", "drop dim")
				elif not own and not combat.slots.has(null):
					hud.hint("WEAPON WHEEL FULL — DISCARD ONE TO TAKE THE " + w.name, "drop dim")
				else:
					hud.hint(("TAKE AMMO — " if own else "PICK UP — ") + w.name, "drop", "X")
			else:
				hud.hint("")
		hud.update(dt, combat, show and not wheel.is_open)
		hud.health(dt, G.player, show)
		hud.mana(dt, G.player, show)
		var lock_hint := show and not G.menu_open() and not Inp.pointer_locked and not Inp.pad_connected and not tuning.debug_open and not console.is_open
		hud.ui_update(dt, lock_hint)
	if tuning.debug_open:
		tuning.readout_update(dt)


## JS pickUpDrop
func pick_up_drop(d: Combat.Drop) -> void:
	var w := Weapons.WEAPONS[d.i]
	var r: String = Game.combat.pick_up(d)
	if r == "new" or r == "ammo":
		CrtTheme.sfx("pickup")
		hud.toast(("PICKED UP " + w.name) if r == "new" else ("+ " + w.name + " AMMO"))
	else:
		CrtTheme.sfx("deny")
		hud.toast((w.name + " AMMO FULL") if r == "maxed" else "WEAPON WHEEL FULL - DISCARD ONE FIRST")


## JS discardSelected
func discard_selected() -> void:
	var v: Variant = wheel.item(wheel.sel, Game.combat)
	if v == null or int(v) < 0:
		CrtTheme.sfx("deny")
		return
	Game.combat.discard(int(v), Game.player)
	CrtTheme.sfx("equip", {"heavy": 0.2})
	hud.toast("DISCARDED " + Weapons.WEAPONS[int(v)].name)
	wheel.flash(wheel.sel)
	wheel.refresh(Game.combat)


## JS cycleWeapon
func cycle_weapon(d: int) -> void:
	var c := Game.combat
	var list := [-1]
	for v: Variant in c.slots:
		if v != null:
			list.append(v)
	var k := list.find(c.cur)
	c.equip(list[posmod(k + d, list.size())])


# ---- the mouse in play (JS: the canvas click, pointerlockchange) ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not Inp.capture_blocked and Game.started and not Game.paused and not tuning.debug_open and not console.is_open and not Inp.pointer_locked and not Game.menu_open():
			lock()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# losing the window while the mouse is captured pauses, as losing the browser's pointer lock did
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not Peek.enabled:
		if Game.started and not Game.paused and Inp.pointer_locked and not Game.menu_open() and not tuning.debug_open:
			set_paused(true)


## Tools (the console) took the mouse: give it back after, if play had it.
func tools_opened() -> void:
	if Inp.pointer_locked:
		_relock_after_tools = true
		unlock()


func tools_closed() -> void:
	if _relock_after_tools and not tuning.debug_open and Game.started and not Game.paused:
		_relock_after_tools = false
		lock()


## The wheel terminal hides the version line too (body.whPip #ver).
func set_ver_hidden(on: bool) -> void:
	_ver.visible = not on
