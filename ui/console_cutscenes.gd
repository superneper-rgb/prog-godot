class_name ConsoleCutscenes
extends RefCounted
## The cutscene registry for the dev console (JS index.html CUTSCENES): "cutscene list" / "cutscene play <name>". To add one: add a row to LIST and a case in play(), which returns "" once it has started, or what stopped it. The game is frozen behind a cutscene and unfrozen when it ends. balcony-call is listed as the JS lists it, and fails as the JS's fails: the hub has no apartment any more.

const LIST: Array = [
	["mawmother-entrance", "Meat Spire: you walk into the Mawmother arena, a tendril flings you across it, you rise and she screams"],
	["apartment-wakeup", "Prog's apartment: the phone wakes him, the Boss says Tommy is MIA, he gears up from the closet and leaves for the hub"],
	["emotion-closeup", "Face close-up flipbook: shock, rage, collapse, sobbing (X / click skips)"],
	["intro", "Opening: the SHIT HOUSE logo on a green CRT (the one that plays on load)"],
	["notice", "The developer note shown after the opening logo (press any button to close it)"],
	["intro-alley", "Old opening: Tommy sprays SHIT HOUSE on an alley wall and walks off"],
	["balcony-call", "The boss phones Prog on the apartment balcony (hub): rap from a passing car, \"meet at the usual place\""],
	["firefight", "Tommy (dual SMGs) and Prog (assault rifle) pinned behind a car by gray aliens; \"Ok, now what?\" - the green gang arrives (hub)"],
	["implant-inject", "Buying an implant: the vending machine arms hold the player by the head and inject the back of his neck, he drops and struggles up (hub street / dev level)"],
	["frug-showdown", "OMNISPHERE bridge: Prog + Tommy (phantom suits) meet Frug at Containment; his suit bursts, Tommy is kicked to pieces, Prog takes Frug into the lava"],
	["tommy-ascension", "Cargo Depot 9: FOINT robots corner Prog and Tommy, Prog rambles, Tommy goes Super Saiyan 3 and clears the crowd with the Kamehameha (X skips)"],
	["boss-intro", "Prog walks up to the Boss’s desk in the B-9 office for the first time (hub, recorded voices)"],
	["office-shutup", "B-9 office: Prog and the Boss scream at each other about a failed mission, Tommy (behind Prog) shouts them both down with the Omni-Man voice (hub, recorded voices, X skips)"],
	["boss-intro-alt", "Alt ending of the boss intro (cutscene list only): after \"clean the air filter\" Prog shoots the Boss in the face, then the Cherub and Shit-chan, and walks out. No story flags"],
]


static func _wait(s: float) -> void:
	await Game.get_tree().create_timer(s, true).timeout


## on the main menu: start the level first; prog: the cutscene is Prog's (not saved, the picked character is untouched)
static func _in_level(id: String, prog: bool) -> void:
	if String(Game.level.id if Game.level != null else "") != id:
		await Game.enter_level(id)
	if prog:
		Game.char_pick = "prog"
	if not Game.started:
		Game.ui.start(false)
		await _wait(0.9)
	if prog and Game.animator != null and Game.animator.B.id != "prog":
		Game.spawn_character("prog")


static func _busy() -> bool:
	return Game.menu_open() or Game.cutscene_on() != null


## a full-screen picture over the frozen game
static func _frozen(o: Node) -> void:
	var prev := Game.time_scale
	Game.time_scale = 0.0001
	var back := func(_a: Variant = null) -> void: Game.time_scale = prev
	o.set(&"on_done" if &"on_done" in o else &"on_end", back)
	return


static func play(name_: String) -> String:
	match name_:
		"mawmother-entrance":
			if not Game.started or Game.level == null or Game.level.id != "spire" or not Game.level.has_method(&"arena_intro"):
				return "Start the Meat Spire first (level spire)."
			if not Game.level.arena_intro():
				return "It is already playing."
		"apartment-wakeup":
			var w: Variant = Game.level.get(&"wakeup") if Game.level != null else null
			if not Game.started or w == null:
				return "Go to Prog's apartment first (level apartment)."
			if Game.char_pick != "prog":
				return "This one is Prog's cutscene: pick Prog at the character select first."
			if not w.play():
				return "It is already playing (or something else has the screen)."
		"emotion-closeup":
			var o := EmotionCloseup.new()
			_frozen(o)
			Game.add_child(o)
			o.play()
		"intro":
			var o := LogoIntro.new()
			_frozen(o)
			Game.ui.add_child(o)
		"notice":
			var o := DevNotice.new()
			_frozen(o)
			Game.ui.add_child(o)
		"intro-alley":
			var o := IntroAlley.new()
			_frozen(o)
			Game.ui.add_child(o)
		"balcony-call":
			return "This cutscene only exists in the hub (the apartment balcony)."      # (JS: hubWorld.city.aptBox is gone: the apartment is its own level now)
		"firefight":
			await _in_level("hub", false)
			var c: Variant = Game.cutscenes.get(&"firefight")
			if c == null:
				return "This cutscene only exists in the hub (the street)."
			if _busy():
				return "A cutscene is already playing."
			c.play()
		"implant-inject":
			if not Game.started:
				return "Start the game first (the hub street has the implant vending machine)."
			var s: Variant = Game.shops.vending_spot()
			if s == null:
				return "There is no implant vending machine in this level (hub street, or the dev level)."
			if _busy():
				return "A cutscene is already playing."
			var p := Game.player
			p.x = float(s.prompt.x)
			p.z = float(s.prompt.z)
			p.vx = 0.0
			p.vz = 0.0
			p.vy = 0.0
			Game.rig.snap_to(p)
			for it: Dictionary in Game.shops.plasmids.items:
				if it["id"] == "swarm":
					Game.implant_cs.play(it)
		"frug-showdown":
			await _in_level("omnisphere", false)
			var c: Variant = Game.cutscenes.get(&"frug_showdown")
			if c == null:
				return "This cutscene only exists in OMNISPHERE."
			if _busy():
				return "A cutscene is already playing."
			await c.play()
		"tommy-ascension":
			if not Game.started:
				Game.ui.start(false)
				await _wait(0.9)
			var c: Variant = Game.cutscenes.get(&"tommy_ascension")
			if c == null:
				return "Not available."
			if _busy():
				return "A cutscene is already playing."
			var lc: Variant = Game.level.get(&"cine")
			if lc != null and lc.on:
				return "This level is playing its own cutscene (wait for it to end)."
			await c.play()
		"boss-intro", "boss-intro-alt":
			await _in_level("hub", true)
			var bi: BossIntro = Game.level.get(&"boss_intro")
			if bi == null:
				return "This cutscene only exists in the hub (the B-9 office)."
			if _busy():
				return "A cutscene is already playing."
			var p := Game.player
			p.x = 121.9      # just inside the office, facing the desk
			p.z = 330.2
			p.y = -10.0
			p.vx = 0.0
			p.vz = 0.0
			p.vy = 0.0
			p.yaw = PI / 2.0
			Game.rig.snap_to(p)
			bi.play(name_ == "boss-intro-alt")
		"office-shutup":
			await _in_level("hub", true)
			var os: OfficeShutup = Game.level.get(&"office_shutup")
			if os == null:
				return "This cutscene only exists in the hub (the B-9 office)."
			if _busy():
				return "A cutscene is already playing."
			os.play()
		_:
			return "no cutscene \"" + name_ + "\" (\"cutscene list\" shows the names)"
	return ""
