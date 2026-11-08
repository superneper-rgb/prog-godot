class_name ConsoleCommands
extends RefCounted
## DEV CONSOLE: the basic game commands (devtools/commands.js + the ones at the bottom of index.html), wired to what exists in the port. To add one, copy a block below or call Game.ui.console.register({...}) from anywhere; help picks it up.
## A JS command whose system is not ported yet is registered too and says so, so the name a person types always answers.


static func _num(v: Variant, d: float) -> float:
	var s := str(v)
	return s.to_float() if s.is_valid_float() else d


static func _on_off(v: Variant, cur: bool) -> bool:
	if v == null:
		return not cur
	var s := str(v).to_lower()
	if s in ["1", "on", "true", "yes"]:
		return true
	if s in ["0", "off", "false", "no"]:
		return false
	return not cur


static func _arg(a: Array, i: int) -> Variant:
	return a[i] if i < a.size() else null


static func _pending(con: DebugConsole, nm: String, usage: String, desc: String, what: String) -> void:
	con.register({"name": nm, "usage": usage, "desc": desc, "category": "pending", "run": func(_a: Array, c: DebugConsole, _r: String) -> Variant:
		c.warn(nm + ": " + what + " is not ported yet.")
		return null})


static func _find_weapon(s: String) -> int:
	var W := Weapons.WEAPONS
	if s.is_valid_int():
		return s.to_int() if s.to_int() >= 0 and s.to_int() < W.size() else -1
	var q := s.to_lower()
	for i in W.size():
		if W[i].id.to_lower() == q:
			return i
	for i in W.size():
		if W[i].name.to_lower().contains(q) or W[i].id.to_lower().contains(q):
			return i
	return -1


static func register_basic(con: DebugConsole) -> void:
	_player_commands(con)
	_weapon_commands(con)
	_enemy_commands(con)
	_game_commands(con)
	con.register({"name": "mirror", "usage": "[on|off]", "desc": "Front-view window (top left) of the player model: see items and animations", "aliases": ["frontview"], "category": "player",
		"run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
			var v: View = Game.view
			v.set_mirror(_on_off(_arg(a, 0), v.mirror_on))
			return "Mirror window " + ("ON" if v.mirror_on else "OFF")})


static func _player_commands(con: DebugConsole) -> void:
	con.register({"name": "god", "usage": "[on|off]", "desc": "Toggle invincibility (enemies cannot hurt you)", "category": "player", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		var p := Game.player
		p.god = _on_off(_arg(a, 0), p.god)
		return "God mode " + ("ON" if p.god else "OFF")})
	con.register({"name": "heal", "usage": "[amount]", "desc": "Restore health (full if no amount)", "aliases": ["hp"], "category": "player", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		var p := Game.player
		if p.dead:
			p.respawn()
			Game.hud.dead(false)
			return "You were down: respawned."
		p.hp = minf(p.max_hp, p.max_hp if a.is_empty() else p.hp + _num(a[0], 0.0))
		return "HP %d / %d" % [roundi(p.hp), roundi(p.max_hp)]})
	con.register({"name": "fatigue", "usage": "[50|25|off]", "desc": "Hold your health at 50 % or 25 % to look at the tired posture (off: full health, regen back on)", "category": "player", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		var p := Game.player
		var k := _num(_arg(a, 0), 0.0)
		if k <= 0.0:
			p.hp = p.max_hp
			p.regen_t = 0.0
			return "Fatigue off, HP full."
		p.hp = p.max_hp * minf(k, 100.0) / 100.0
		p.regen_t = INF
		return "HP held at %d / %d (fatigue off to release; a hit lets regen resume)." % [roundi(p.hp), roundi(p.max_hp)]})
	con.register({"name": "respawn", "desc": "Respawn at the level spawn point", "category": "player", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		Game.player.respawn()
		Game.rig.snap_to(Game.player)
		Game.hud.dead(false)
		return "Respawned."})
	con.register({"name": "pos", "desc": "Print your position and facing", "category": "player", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		var p := Game.player
		return "x %.2f  y %.2f  z %.2f  yaw %d°" % [p.x, p.y, p.z, roundi(rad_to_deg(p.yaw))]})
	con.register({"name": "tp", "usage": "<x> <y> <z> | spawn", "desc": "Teleport (y optional: tp x z lands on the ground)", "aliases": ["teleport"], "category": "player",
		"complete": func(_args: Array) -> Array: return ["spawn"],
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			var p := Game.player
			var w := Game.world
			if a.size() > 0 and a[0] == "spawn":
				p.x = w.spawn.x
				p.y = w.spawn.y
				p.z = w.spawn.z
			elif a.size() == 2:
				p.x = _num(a[0], p.x)
				p.z = _num(a[1], p.z)
				var g := w.ground_height(p.x, p.z, 0.3, 200.0)
				p.y = g if is_finite(g) else p.y
			elif a.size() >= 3:
				p.x = _num(a[0], p.x)
				p.y = _num(a[1], p.y)
				p.z = _num(a[2], p.z)
			else:
				c.error("usage: tp <x> <y> <z>, tp <x> <z> or tp spawn")
				return null
			p.vx = 0.0
			p.vy = 0.0
			p.vz = 0.0
			Game.rig.snap_to(p)
			return "Teleported to %.1f, %.1f, %.1f" % [p.x, p.y, p.z]})
	con.register({"name": "freecam", "usage": "[on|off] [speed]", "desc": "Fly camera: game freezes; WASD move, Space/E up, Q/C down, Shift fast, Ctrl slow, right-drag look. Pad: sticks move/look, RT/A up, LT/B down, RB fast, LB slow, D-pad speed", "aliases": ["fc", "fly"], "category": "player", "run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
		var f: Freecam = Game.freecam
		var sp: Variant = null
		var word: Variant = null
		for x: Variant in a:
			if str(x).is_valid_float():
				sp = x
			else:
				word = x
		if sp != null:
			f.speed = clampf(_num(sp, f.speed), 0.5, 200.0)
		var want := _on_off(word, f.on)
		if want and not f.on:
			f.enable(Game.rig)
			c.close()
			Game.ui.unlock()     # the fly camera looks with a right-drag
			return "Free cam ON (game frozen). WASD move, Space/E up, Q/C down, Shift fast, right-drag look. Open the console and type freecam to leave."
		if not want and f.on:
			f.disable()
			Game.rig.snap_to(Game.player)
		return "Free cam " + ("ON" if f.on else "OFF")})
	# hub only: jump to the sights of FOINT CITY (JS levels/hub/district-view.js `places`) or back to the street
	var places := {"bridge": [0.0, 90.0], "landing": [0.0, 192.0], "arena": [0.0, 224.0], "alley": [84.0, 330.0], "office": [117.6, 330.0], "quay": [127.5, 186.0], "street": null}
	con.register({"name": "go", "usage": "<place>", "desc": "Hub: teleport to bridge, landing, arena, alley, office, quay (by a ladder into the harbour) or street", "aliases": ["goto"], "category": "player",
		"complete": func(_args: Array) -> Array: return places.keys(),
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			if Game.level == null or Game.level.id != "hub":
				c.warn("this level has no named places (hub only)")
				return null
			var k := str(_arg(a, 0)).to_lower() if a.size() > 0 else ""
			if not places.has(k):
				return "Places: " + ", ".join(PackedStringArray(places.keys()))
			var p := Game.player
			var to: Variant = places[k]
			if to == null:
				p.x = float(Game.world.spawn.x)
				p.y = float(Game.world.spawn.y)
				p.z = float(Game.world.spawn.z)
			else:
				p.x = float(to[0])
				p.z = float(to[1])
				var g := Game.world.ground_height(p.x, p.z, 0.3, -9.5 if k == "office" else 200.0)
				p.y = g if is_finite(g) else 0.0
			p.vx = 0.0
			p.vy = 0.0
			p.vz = 0.0
			Game.rig.snap_to(p)
			return "Teleported to " + k})
	con.register({"name": "clone", "usage": "[prog|tommy] [follow|idle] [weapon|fists]", "desc": "Spawn an armed AI ally using the player rig and combat moveset", "category": "player", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		if not Game.started:
			return "Start the game before spawning a clone."
		var o := {"mode": str(_arg(a, 1)) if a.size() > 1 else "follow", "weapon": str(_arg(a, 2)) if a.size() > 2 else "rifle"}
		if a.size() > 0:
			o["character"] = str(_arg(a, 0))
		var clone: PlayerClones.Clone = Game.player_clones.spawn(o)
		return Game.player_clones.error if clone == null else "Spawned clone %d" % clone.id})
	con.register({"name": "cloneclear", "desc": "Remove all AI player clones", "category": "player", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		Game.player_clones.clear()
		return "Player clones removed."})
	con.register({"name": "vehicle", "usage": "[mustang|scorpion]", "desc": "Spawn a drivable vehicle in front of the player (E to get in)", "category": "player",
		"run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
			if not Game.started:
				return "Start the game first."
			var type := str(_arg(a, 0)) if a.size() > 0 else "mustang"
			if not Vehicles.SPECS.has(type):
				return "Unknown vehicle. Try: " + ", ".join(PackedStringArray(Vehicles.SPECS.keys()))
			var p := Game.player
			var x := p.x + sin(p.yaw) * 7.0
			var z := p.z + cos(p.yaw) * 7.0
			var g := Game.world.ground_height(x, z, 0.3, p.y + 3.0)
			if not is_finite(g):
				return "No ground there."
			return "Spawned " + type if Game.vehicles.spawn(type, x, z, p.yaw, g) != null else "No ground there."})
	con.register({"name": "armor", "usage": "[suit id]", "desc": "List the suits, or get and wear one for free (armor omen; armor standard takes it off)", "aliases": ["suit"], "category": "player", "run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
		var id := str(_arg(a, 0)).to_lower() if a.size() > 0 else ""
		if id == "":
			for s: ArmorStore.Suit in ArmorStore.ARMOR_CATALOG:
				c.print_line(s.id.rpad(20) + s.name + ("  (worn)" if ArmorStore.is_equipped(s.id) else ("  (owned)" if ArmorStore.is_owned(s.id) else "")))
			return null
		var known := false
		for s: ArmorStore.Suit in ArmorStore.ARMOR_CATALOG:
			if s.id == id:
				known = true
		if not known:
			return "No such suit: " + id
		ArmorStore.owned[id] = true
		ArmorStore.equip(id)
		return "Wearing " + id})


static func _weapon_commands(con: DebugConsole) -> void:
	con.register({"name": "weapons", "desc": "List every weapon id (for give)", "category": "weapons", "run": func(_a: Array, c: DebugConsole, _r: String) -> Variant:
		var W := Weapons.WEAPONS
		for i in W.size():
			c.print_line(str(i).lpad(2) + "  " + W[i].id.rpad(14) + W[i].name + ("  (owned)" if Game.combat.owned.has(i) else ""))
		return null})
	con.register({"name": "give", "usage": "<weapon|all>", "desc": "Give a weapon by id, name or number (weapons lists them)", "category": "weapons",
		"complete": func(_args: Array) -> Array:
			var o: Array = ["all"]
			for w: Weapons.Def in Weapons.WEAPONS:
				o.append(w.id)
			return o,
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			if a.is_empty():
				c.error("usage: give <weapon|all>  (type \"weapons\" for the ids)")
				return null
			var W := Weapons.WEAPONS
			var cb := Game.combat
			var want: Array = []
			if str(a[0]).to_lower() == "all":
				for i in W.size():
					want.append(i)
			else:
				want.append(_find_weapon(" ".join(PackedStringArray(a))))
			if want[0] < 0:
				c.error("no weapon \"" + " ".join(PackedStringArray(a)) + "\". Type \"weapons\" for the list.")
				return null
			var got := PackedStringArray()
			var skipped := PackedStringArray()
			for i: int in want:
				if cb.owned.has(i):
					skipped.append(W[i].name + " (owned)")
					continue
				if cb.give(i) >= 0:
					got.append(W[i].name)
				else:
					skipped.append(W[i].name + " (wheel full)")
			if not got.is_empty():
				c.ok("Given: " + ", ".join(got))
			if not skipped.is_empty():
				c.dim("Skipped: " + ", ".join(skipped))
			return null})
	con.register({"name": "ammo", "desc": "Refill magazine and reserve ammo of every weapon you own", "category": "weapons", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		var cb := Game.combat
		var n := 0
		for i: int in cb.owned:
			var w := Weapons.WEAPONS[i]
			cb.ammo[i] = w.mag_size
			cb.reserve[i] = maxi(0, w.max - w.mag_size)
			n += 1
		return ("Refilled %d weapon%s." % [n, "s" if n > 1 else ""]) if n > 0 else "You have no weapons. Try \"give all\"."})
	con.register({"name": "money", "usage": "[amount]", "desc": "Show cash, or add (negative removes) cash", "aliases": ["cash"], "category": "weapons", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		if a.size() > 0:
			Game.add_money(roundi(_num(a[0], 0.0)))
		return "Cash: $%d" % Game.money})


const KINDS := {"robot": {}, "heavy": {"heavy": true}, "drone": {"drone": true}, "alien": {"kind": "alien"}, "prophet": {"kind": "prophet"}, "worm": {"kind": "worm"}, "scream": {"kind": "scream"}}


static func _living() -> Array:
	var out: Array = []
	for r: Variant in Game.combat.enemies.robots:
		if not r.dead:
			out.append(r)
	return out


static func _enemy_commands(con: DebugConsole) -> void:
	con.register({"name": "spawn", "usage": "<kind> [count]", "desc": "Spawn enemies in front of you (robot heavy drone alien prophet worm scream)", "category": "enemies",
		"complete": func(args: Array) -> Array: return [] if args.size() > 0 else KINDS.keys(),
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			var kind := str(_arg(a, 0)).to_lower() if a.size() > 0 else ""
			if not KINDS.has(kind):
				c.error("usage: spawn <" + "|".join(PackedStringArray(KINDS.keys())) + "> [count]")
				return null
			var k: Dictionary = KINDS[kind]
			if k.has("kind") and not (Game.has_method(&"can_spawn_kind") and Game.call(&"can_spawn_kind", k.kind)):
				c.error(kind + " is not available (not ported yet)")
				return null
			var n := clampi(roundi(_num(_arg(a, 1), 1.0)), 1, 30)
			var p := Game.player
			for i in n:
				var ang := p.yaw + ((float(i) / (n - 1) - 0.5) * 1.2 if n > 1 else 0.0)
				var d := 5.0 + (i % 3) * 1.2
				var x := p.x + sin(ang) * d
				var z := p.z + cos(ang) * d
				var g := Game.world.ground_height(x, z, 0.3, p.y + 3.0)
				var y := g if is_finite(g) else p.y
				var o := {"no_respawn": true}
				if k.has("kind"):
					o["kind"] = k.kind
				if k.get("drone", false):
					o["drone"] = true
				var rb: Variant = Game.spawn_enemy({"x": x, "y": y + 1.5 if k.get("drone", false) else y, "z": z, "yaw": atan2(p.x - x, p.z - z)}, o)
				if k.get("heavy", false):
					rb.heavy = true
					rb.max = 220.0
					rb.hp = 220.0
					rb.r = 0.72
				rb.console_spawn = true
			return "Spawned %d %s%s." % [n, kind, "s" if n > 1 else ""]})
	con.register({"name": "killall", "desc": "Kill every living enemy", "category": "enemies", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		var L := _living()
		for r: Variant in L:
			Game.combat.damage(r, r.hp + 1.0, Game.player, 0.0)
		return "Killed %d enem%s." % [L.size(), "y" if L.size() == 1 else "ies"]})
	con.register({"name": "despawn", "desc": "Remove every enemy from the level (alive or dead)", "aliases": ["clearenemies"], "category": "enemies", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		var L: Array = Game.combat.enemies.robots.duplicate()
		for r: Variant in L:
			Game.despawn_enemy(r)
		return "Removed %d enem%s." % [L.size(), "y" if L.size() == 1 else "ies"]})
	con.register({"name": "enemies", "desc": "Count enemies by type and state", "category": "enemies", "run": func(_a: Array, c: DebugConsole, _r: String) -> Variant:
		var R: Array = Game.combat.enemies.robots
		if R.is_empty():
			return "No enemies in the level."
		var by := {}
		for r: Variant in R:
			var t := "drone" if r.get("drone") else ("heavy" if r.get("heavy") else "robot")
			var k := t + (" (dead)" if r.dead else "")
			by[k] = int(by.get(k, 0)) + 1
		var ks: Array = by.keys()
		ks.sort()
		for k: String in ks:
			c.print_line(str(by[k]).lpad(3) + "  " + k)
		return null})
	con.register({"name": "ai", "usage": "[on|off]", "desc": "Freeze or unfreeze all enemy AI", "category": "enemies", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		var frozen: bool = Config.get("ai_freeze") != null and float(Config.get("ai_freeze")) != 0.0
		var on := _on_off(_arg(a, 0), not frozen)
		Config.set("ai_freeze", 0 if on else 1)
		return "Enemy AI " + ("running" if on else "FROZEN")})


static func _config_key(s: String) -> String:
	var q := s.to_lower().replace("_", "")
	for p: Dictionary in Config.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p.name).begins_with("_"):
			if String(p.name).to_lower().replace("_", "") == q:
				return p.name
	return ""


static func _config_keys() -> Array:
	var out: Array = []
	for p: Dictionary in Config.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p.name).begins_with("_"):
			out.append(p.name)
	return out


static func _game_commands(con: DebugConsole) -> void:
	con.register({"name": "timescale", "usage": "[0.1-3]", "desc": "Slow motion / fast forward (1 = normal)", "aliases": ["slowmo"], "category": "game", "run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
		if a.size() > 0:
			Game.time_scale = clampf(_num(a[0], 1.0), 0.1, 3.0)
		return "Time scale %s" % str(Game.time_scale)})
	con.register({"name": "set", "usage": "<setting> [value]", "desc": "Read or change a Config value (same as the tuning panel)", "aliases": ["get", "cvar"], "category": "game",
		"complete": func(args: Array) -> Array: return [] if args.size() > 0 else _config_keys(),
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			if a.is_empty():
				c.error("usage: set <setting> [value]  (Tab completes setting names; \"settings\" lists them)")
				return null
			var key := _config_key(a[0])
			if key == "":
				c.error("no setting \"" + str(a[0]) + "\"")
				return null
			if a.size() > 1:
				var old: Variant = Config.get(key)
				var v: String = a[1]
				if old is bool:
					Config.set(key, v.to_lower() in ["1", "on", "true", "yes"])
				elif old is int:
					Config.set(key, int(_num(v, old)))
				elif old is float:
					Config.set(key, _num(v, old))
				else:
					Config.set(key, v)
				if Game.ui != null:
					Game.ui.tuning.sync_values()
			return key + " = " + str(Config.get(key))})
	con.register({"name": "settings", "usage": "[filter]", "desc": "List Config settings (optionally only names containing filter)", "category": "game", "run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
		var f := str(a[0]).to_lower() if a.size() > 0 else ""
		var n := 0
		for k: String in _config_keys():
			if k.to_lower().contains(f):
				c.print_line(k + " = " + str(Config.get(k)))
				n += 1
		return "No settings match \"%s\"." % f if n == 0 else null})
	con.register({"name": "tune", "desc": "Open / close the tuning sliders panel (also F3)", "aliases": ["debug"], "category": "game", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		Game.ui.tuning.toggle_debug()
		return "Tuning panel " + ("open" if Game.ui.tuning.debug_open else "closed")})
	con.register({"name": "fps", "desc": "Show the current frame rate", "category": "game", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		return "%d fps" % roundi(Engine.get_frames_per_second())})
	con.register({"name": "look", "usage": "on|off | <level id> | set <key> <value...> | debug ao|bloom|off | dump", "desc": "The picture (post-fx): A/B it, borrow a level's look, tune it live, print it", "category": "game",
		"details": "look off            the bare frame the materials drew; look on brings the look back\nlook spire          wear another level's look\nlook set bloom 0.9  tune a value (several numbers for a colour: look set gain 1.1 1 0.9)\nlook debug ao       see the contact shadows alone (bloom: the glow alone; off: back)\nlook dump           print what differs from the base",
		"run": func(a: Array, _c: DebugConsole, _r: String) -> Variant:
			if Game.view == null:
				return "No view."
			return Game.view.look_command(PackedStringArray(a))})
	con.register({"name": "cutscene", "usage": "list | play <name>", "desc": "List the cutscenes, or play one", "category": "game",
		"details": "cutscene list         show every cutscene name\ncutscene play intro  play a cutscene (the console closes; any key skips it)",
		"complete": func(args: Array) -> Array:
			if args.is_empty():
				return ["list", "play"]
			if args.size() == 1 and str(args[0]).to_lower() == "play":
				var names: Array = []
				for row: Array in ConsoleCutscenes.LIST:
					names.append(row[0])
				return names
			return [],
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			var sub := str(a[0]).to_lower() if a.size() > 0 else ""
			if sub == "list":
				var w := 0
				for row: Array in ConsoleCutscenes.LIST:
					w = maxi(w, String(row[0]).length())
				c.print_line("CUTSCENES", DebugConsole.C_TEXT, true)
				var out := PackedStringArray()
				for row: Array in ConsoleCutscenes.LIST:
					out.append("  " + String(row[0]).rpad(w) + "  " + String(row[1]))
				c.print_line("\n".join(out))
				return null
			if sub == "play":
				if a.size() < 2:
					c.warn("usage: cutscene play <name>  (\"cutscene list\" shows the names)")
					return null
				var nm := str(a[1]).to_lower()
				var err: String = await ConsoleCutscenes.play(nm)
				if err != "":
					c.warn(err)
					return null
				c.close()
				return "Playing " + nm + "."
			c.warn("usage: cutscene list | cutscene play <name>")
			return null})
	con.register({"name": "level", "usage": "list | load <id> | reload | <id>", "desc": "List every level, load one, or reload the current one", "aliases": ["map", "levels"], "category": "game",
		"details": "level list         show every level (the current one is marked)\nlevel load maktar  load a level by id or name (also: level maktar)\nlevel reload       re-enter the current level",
		"complete": func(args: Array) -> Array:
			var ids: Array = Game.LEVELS.keys()
			if args.is_empty():
				return ["list", "load", "reload"] + ids
			return ids if str(args[0]).to_lower() == "load" else [],
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			var all: Array = Game.LEVELS.keys()
			var sub := str(a[0]).to_lower() if a.size() > 0 else ""
			if a.is_empty() or sub == "list":
				var w := 0
				for id: String in all:
					w = maxi(w, id.length())
				c.head("LEVELS")
				for i in all.size():
					var id: String = all[i]
					c.print_line("  " + str(i + 1).lpad(2) + "  " + id.rpad(w) + "  " + MainMenu.level_name(id) + ("   <- current" if (Game.level != null and Game.level.id == id) else ""))
				c.dim("level load <id | number | name>   loads it")
				return null
			if sub == "reload" or sub == "rl":
				var id: String = Game.level.id
				await Game.enter_level(id)
				return "Reloaded " + id + "."
			var q := " ".join(PackedStringArray(a.slice(1) if (sub == "load" or sub == "go") else a)).strip_edges().to_lower()
			if q == "":
				c.error("usage: level load <id>  (\"level list\" shows the levels)")
				return null
			var hit := ""
			if q.is_valid_int() and q.to_int() >= 1 and q.to_int() <= all.size():
				hit = all[q.to_int() - 1]
			else:
				for id: String in all:
					if id == q:
						hit = id
				if hit == "":
					for id: String in all:
						if MainMenu.level_name(id).to_lower() == q:
							hit = id
				if hit == "":
					for id: String in all:
						if id.contains(q) or MainMenu.level_name(id).to_lower().contains(q):
							hit = id
							break
			if hit == "":
				c.error("no level \"" + q + "\" (\"level list\" shows the levels)")
				return null
			if Game.started:
				c.print_line("Loading " + MainMenu.level_name(hit) + "...")
				await Game.enter_level(hit)
				return "Loaded " + hit + "."
			Game.ui.launch_level(hit)
			return "Loading " + MainMenu.level_name(hit) + "..."})
	con.register({"name": "cp", "usage": "[index | 02a | key]", "desc": "Blockout levels: list / load F6 checkpoints", "aliases": ["checkpoint"], "category": "game",
		"complete": func(_args: Array) -> Array:
			var L: Variant = Game.level.get("checkpoints") if Game.level != null else null
			var o: Array = []
			if L != null:
				for x: Variant in L:
					o.append(String(x.name).split(" ")[0])
			return o,
		"run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
			var cps: Variant = Game.level.get("checkpoints") if Game.level != null else null
			if cps == null or not Game.level.has_method(&"load_checkpoint"):
				c.error("this level has no blockout checkpoints")
				return null
			if a.is_empty():
				var i := 0
				for x: Variant in cps:
					c.print_line("  %d  %s" % [i, x.name])
					i += 1
				return null
			var k: Variant = a[0]
			var ok_load: bool = Game.level.load_checkpoint(int(k) if str(k).is_valid_int() else k)
			if not ok_load:
				c.error("no checkpoint \"" + str(k) + "\" (\"cp\" lists them)")
				return null
			return "Loaded checkpoint " + str(k)})
	_pending(con, "mode", "blockout | playtest | release | default", "Blockout levels: show or change the mode", "the blockout kit")
	con.register({"name": "reload", "desc": "Restart the game", "category": "game", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		Game.save_game()
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
		Game.get_tree().quit()
		return "Reloading..."})
	con.register({"name": "save", "usage": "[slot 1-3]", "desc": "Show the save slots; \"save\" writes the slot in use now, \"save <n>\" switches to slot n", "category": "game", "run": func(a: Array, c: DebugConsole, _r: String) -> Variant:
		var n := int(_num(_arg(a, 0), 0.0))
		if n != 0:
			if n < 1 or n > SaveGame.SLOT_COUNT:
				return "Slots are 1-%d" % SaveGame.SLOT_COUNT
			Game.save_game()
			Game.ui.play_slot(n, false)
			return "Switching to slot %d..." % n
		if Game.started:
			Game.save_game(true)
		for s: Dictionary in Game.save.slots():
			c.print_line(("> " if int(s.n) == Game.save.active else "  ") + "SLOT %d  " % int(s.n) + Game.ui.menu.slot_line(s))
		return null})
	con.register({"name": "resetsave", "desc": "Empty the save slot in use (money, weapons, armor, powers, story, arena, where you are)", "aliases": ["wipesave"], "category": "game", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		var n: int = Game.save.active
		Game.save.erase(n)
		Game.use_save_record()
		return "Slot %d wiped." % n})
	con.register({"name": "mem", "desc": "What the game holds (objects, nodes, draw calls, video memory)", "category": "game", "run": func(_a: Array, c: DebugConsole, _r: String) -> Variant:
		for row: Array in [["objects", Performance.OBJECT_COUNT], ["resources", Performance.OBJECT_RESOURCE_COUNT], ["nodes", Performance.OBJECT_NODE_COUNT], ["orphan nodes", Performance.OBJECT_ORPHAN_NODE_COUNT], ["draw calls", Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME], ["objects drawn", Performance.RENDER_TOTAL_OBJECTS_IN_FRAME]]:
			c.print_line(str(row[0]).rpad(16) + str(int(Performance.get_monitor(row[1]))))
		c.print_line("video MB".rpad(16) + str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)))
		c.print_line("static MB".rpad(16) + str(int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)))
		return null})
	_pending(con, "perf", "[on [ms] | off | log [n] | copy | clear]", "Frame-time graph + a log of every slow frame and what caused it", "the perf overlay")
	_pending(con, "levelcycle", "[rounds] [level ...]", "Leak test: visit levels round after round and print how the mem numbers change per round", "the leak test")
	_pending(con, "npc", "<id>", "Spawn an NPC in front of you (DEV level only; npcs lists ids)", "the DEV level")
	_pending(con, "npcs", "", "List the NPC ids you can spawn (DEV level only)", "the DEV level")
