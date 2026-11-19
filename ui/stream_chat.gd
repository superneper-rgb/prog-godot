class_name StreamChat
extends CanvasLayer
## WeFoint (user, 2026-11-19: "a stream chat shows up on the side of the screen with rapid fire chats"): Sambo Fenrir's live stream, as the cameraman's screen shows it. Down the right side the
## chat, a message every fraction of a second in the mood of the moment (set_mood): hyping him up and roasting the crew and the fat, old, bald cameraman with the skullet while he climbs;
## SCAM FRAUD when the suit snaps; nepo-baby jokes at the ship; then on the cameraman's side through the fight. Above it the platform's bar: the WeFoint mark, LIVE, the viewers (they climb
## with what happens: add_viewers) and the stream's title. Donations come up as highlighted rows (donate). pov(true) draws the stream camera's own frame over the whole screen (REC, the
## running time, the corners) for the shots seen through it. A level makes one and keeps it as its child: it goes with the level.

const FONT := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const FONT_B := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_W := "res://assets/fonts/Orbitron-Variable.ttf"
const ROWS := 15
const NAME_COLS: Array[String] = ["ff5d73", "7be34a", "59d0ff", "ffb84a", "c78bff", "ff8a3a", "4affc3", "ff7bd5", "f4e85c", "8fb5ff", "ff4a4a", "a6ff7a"]
const USERS: Array[String] = ["xXFointLordXx", "toadhater99", "skullet_enjoyer", "GOINT_insured", "sambo_simp4life", "rasta_pasta_fan", "mod_gerald", "crane_op_420", "uncle_vibes",
	"bald_is_beautiful", "notafed", "dave_wants_refund", "pervertpalace_hr", "foint_intern", "nepo_watch", "big_toad_union", "ratking_77", "deck_rat", "harbor_st_hank", "glorp",
	"the_real_scam_fraud", "hotdog_man_official", "twohead_gaming", "fishbowl_fred", "conehead_carl", "cyclops_gamer", "slimeboi", "tvbot_reruns", "brain_in_a_jar", "ufo_dad",
	"lurker_9000", "midnight_snacker", "heaven_bound", "kevin_from_accounts", "foint_after_dark", "xX_SamboHater_Xx", "chat_is_this_real", "pervert_prince", "vox_ave_vic", "gleeman_greg"]
const MOODS := {
	&"start": ["first", "FIRST", "yo sambo", "what is this stream title bro", "sambo live LETS GO", "this better not be another prank", "hi chat", "o7", "PogFoint", "who is the guy holding the camera",
		"is this the heaven stream", "sambo you owe me 20 bucks", "ok im here", "WeFoint is lagging again", "chat what did i miss"],
	&"hype": ["LETS GOOOO", "SAMBO SAMBO SAMBO", "bro is actually doing it", "W STREAM", "clip it CLIP IT", "this is so illegal lmao", "hes gonna do it chat", "SAMBO FOR PRESIDENT", "who let him cook",
		"+1000 aura", "mods are asleep post toads", "PogFoint PogFoint PogFoint", "this is cinema", "RUN SAMBO RUN", "bro said parkour", "he really ran past the foreman LMAO", "THE CONTENT",
		"gaming", "ok this is actually peak", "FOINTLUL", "best stream of the year and its november", "chat we are witnessing history", "sambo moving like a rubber chicken"],
	&"workers": ["toad boy cant even hit a rubber man LMAO", "the hard hat is doing all the work", "union break in 3... 2...", "bro is holding that nail gun like a phone", "get this frog a hard hat that fits",
		"imagine getting outplayed by a skin suit", "toads on scaffolds is my new favourite genre", "construction workers seeing actual work FOINTLUL", "the foreman is SO mad", "OSHA where are you",
		"the brick guy has an arm on him ngl", "toad down TOAD DOWN", "frog said nail gun go brrr", "they really pay these guys", "this site has zero safety rails lmao", "workplace incident speedrun"],
	&"prog": ["who is the cameraman bro looks like a thumb", "cameraman built like a mailbox", "BALD FATHER", "the skullet is CRAZY", "business in the back and the back and the back", "camera guy breathing louder than sambo",
		"is the cameraman ok hes like 60", "unc is cooking tho", "cameraman needs a cardio arc", "the skullet has its own chat", "old man strength is real", "cameraman's head is reflecting the floodlights LMAO",
		"bald guy hit that toad so hard his skullet flinched", "unc fights like he has a mortgage", "camera guy dad bod supremacy", "who gave grandpa a gun", "skullet7 skullet7 skullet7", "the cameraman is carrying this stream"],
	&"scam": ["SCAM FRAUD", "HES FAKING IT", "rubber neck LMAOOOO", "IT WAS A SUIT THE WHOLE TIME", "exposed on his own stream FOINTLUL", "refund my sub", "scum fuck", "bro really thought",
		"fake ass suicide", "unfollowed", "the little guy inside is SO mad", "hes literally a head now", "is that a little green guy in there??", "SCAM FRAUD SCAM FRAUD SCAM FRAUD", "heaven is a crane apparently",
		"most fake thing ive ever seen and i watch wrestling", "chat he is CRYING", "SCUM FUCK", "sambo fenrir aka scam fraud", "clipped. its over for him", "the head is yelling at us LMAO", "WeCry", "he cant even die right"],
	&"ship": ["IS THAT HIS PARENTS SHIP", "NEPO BABY CONFIRMED", "mommy and daddy to the rescue", "generational wealth arc", "ok that ship is kinda fire though", "rich kid speedrun", "the red button LMAO",
		"he called his parents on stream", "imagine being this rich and this stupid", "daddy's credit card incoming", "WHAT IS FALLING", "orbital nepotism"],
	&"boss": ["GO CAMERAMAN GO", "SKULLET SUPREMACY", "BALD GOD", "camera guy is the real streamer now", "we ride with unc", "W CAMERAMAN", "break his little rich kid robot", "subscribed to the cameraman",
		"shoot the gold part", "aim for the glowy bit", "scam fraud got a mech now LOL", "bought his way into a boss fight", "daddy's money cant buy aim", "imagine needing your parents to finish a stream",
		"SCUM FUCK SCUM FUCK", "hes crying in the gold robot", "ITALIAN LEATHER LMAOOO", "mods ban sambo", "unc is NOT losing to a nepo baby", "jump the shockwave bro", "the mech has a little cupholder i bet",
		"CAMERAMAN CAMERAMAN CAMERAMAN", "this is the best boss fight on WeFoint", "unc please", "bald rage activated"],
	&"end": ["W STREAM (for the cameraman)", "the little guy is begging LMAO", "let him go unc", "best stream ever and its not even his", "cameraman spared him. aura +10000", "unfollowed sambo, followed the cameraman",
		"THIS IS PEAK CONTENT", "scam fraud aka scum fuck aka sambo fenrir", "he said verified LMAO", "role model btw", "unc rolled his eyes so hard i felt it", "clip of the year", "o7 cameraman", "GG"],
}

var mood := &"start"
var rate := 2.0                      # messages a second
var viewers := 1204.0
var viewers_goal := 1204.0
var title := "CAN I STILL GET INTO HEAVEN IF I KILL MYSELF?? (NOT CLICKBAIT) | sponsored by RASTA PASTA"
var _root: Control
var _panel: Panel
var _rows: VBoxContainer
var _view_l: Label
var _live_dot: ColorRect
var _title_l: Label
var _pov: Control
var _pov_on := false
var _pov_t := 0.0
var _t := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()
var _recent: Array[String] = []
var _font: FontFile
var _font_b: FontFile
var _shown := false
var _alpha := 0.0


func _init() -> void:
	layer = 6
	name = "StreamChat"
	_rng.seed = 420
	_font = load(FONT)
	_font_b = load(FONT_B)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_pov()
	_build_panel()
	_root.modulate.a = 0.0
	visible = false


## Up (or down) on the side of the screen
func show_chat(v: bool) -> void:
	_shown = v
	if v:
		visible = true


func set_mood(m: StringName, per_second: float = -1.0) -> void:
	mood = m
	if per_second > 0.0:
		rate = per_second
	_recent.clear()


func add_viewers(n: float) -> void:
	viewers_goal += n


## A line typed by somebody in particular (a scripted beat): name, text
func push(user: String, text: String, col: String = "") -> void:
	_add_row(user, text, col if col != "" else NAME_COLS[absi(user.hash()) % NAME_COLS.size()], false)


## A donation: highlighted, with its amount
func donate(user: String, amount: int, text: String) -> void:
	_add_row(user, "donated $%d: %s" % [amount, text], "ffcf4a", true)


## The stream camera's own frame over the whole screen (the shots seen through it)
func pov(on: bool) -> void:
	_pov_on = on
	_pov.visible = on
	_pov_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	_alpha = move_toward(_alpha, 1.0 if _shown else 0.0, dt * 3.0)
	_root.modulate.a = 1.0
	_panel.modulate.a = _alpha
	if _alpha <= 0.0 and not _pov_on:
		visible = false
		return
	viewers = lerpf(viewers, viewers_goal, 1.0 - exp(-dt * 1.5)) + _rng.randf_range(-3.0, 3.0) * dt * 10.0
	_view_l.text = _fmt(int(viewers))
	_live_dot.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)
	if _shown and not Game.paused:
		_next -= dt
		while _next <= 0.0:
			_next += (1.0 / maxf(0.2, rate)) * _rng.randf_range(0.35, 1.65)
			_random_row()
	if _pov_on:
		_pov_t += dt
		_pov.queue_redraw()


static func _fmt(n: int) -> String:
	var s := str(maxi(0, n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _random_row() -> void:
	var pool: Array = MOODS.get(mood, MOODS[&"hype"])
	if mood == &"hype" and _rng.randf() < 0.45:      # the climb's chat mixes in its roasts
		pool = MOODS[&"workers"] if _rng.randf() < 0.5 else MOODS[&"prog"]
	elif mood == &"boss" and _rng.randf() < 0.2:
		pool = MOODS[&"prog"]
	var text: String = pool[_rng.randi() % pool.size()]
	var tries := 0
	while _recent.has(text) and tries < 6:
		text = pool[_rng.randi() % pool.size()]
		tries += 1
	_recent.append(text)
	if _recent.size() > 8:
		_recent.pop_front()
	if _rng.randf() < 0.18:      # the way chat types
		text = text.to_upper() if _rng.randf() < 0.5 else text + (" " + text.split(" ")[0] if text.split(" ").size() > 0 else "")
	var user: String = USERS[_rng.randi() % USERS.size()]
	_add_row(user, text, NAME_COLS[absi(user.hash()) % NAME_COLS.size()], false)


func _add_row(user: String, text: String, col: String, highlight: bool) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(0, 0)
	r.add_theme_font_override(&"normal_font", _font)
	r.add_theme_font_override(&"bold_font", _font_b)
	var fs := int(clampf(get_viewport().get_visible_rect().size.y * 0.0175, 13.0, 30.0))
	r.add_theme_font_size_override(&"normal_font_size", fs)
	r.add_theme_font_size_override(&"bold_font_size", fs)
	r.add_theme_color_override(&"default_color", Color(0.93, 0.93, 0.97))
	r.add_theme_constant_override(&"outline_size", 4)
	r.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.75))
	var safe := text.replace("[", "(").replace("]", ")")
	var line := "[b][color=#%s]%s[/color][/b]: %s" % [col, user, safe]
	if highlight:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.32, 0.02, 0.55)
		sb.border_color = Color(1.0, 0.75, 0.2, 0.9)
		sb.border_width_left = 3
		sb.content_margin_left = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		r.add_theme_stylebox_override(&"normal", sb)
		line = "[b][color=#ffcf4a]%s[/color][/b] %s" % [user, safe]
	r.text = line
	_rows.add_child(r)
	while _rows.get_child_count() > ROWS:
		var o := _rows.get_child(0)
		_rows.remove_child(o)
		o.queue_free()


func _build_panel() -> void:
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.62)
	sb.border_color = Color(0.45, 0.25, 0.65, 0.5)
	sb.border_width_left = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_left = 6
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.anchor_left = 0.69
	_panel.anchor_right = 0.992
	_panel.anchor_top = 0.16
	_panel.anchor_bottom = 0.83
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.add_theme_constant_override(&"separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	# the platform's bar: the mark, LIVE, the viewers
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var mark := RichTextLabel.new()
	mark.bbcode_enabled = true
	mark.fit_content = true
	mark.scroll_active = false
	mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	mark.custom_minimum_size = Vector2(118, 0)
	mark.add_theme_font_override(&"normal_font", load(FONT_W))
	mark.add_theme_font_size_override(&"normal_font_size", 19)
	mark.text = "[color=#f2f0ff]We[/color][color=#ffa833]FOINT[/color]"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mark)
	var live := PanelContainer.new()
	var lb := StyleBoxFlat.new()
	lb.bg_color = Color(0.85, 0.08, 0.12)
	lb.corner_radius_top_left = 4
	lb.corner_radius_top_right = 4
	lb.corner_radius_bottom_left = 4
	lb.corner_radius_bottom_right = 4
	lb.content_margin_left = 8
	lb.content_margin_right = 8
	live.add_theme_stylebox_override(&"panel", lb)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll := Label.new()
	ll.text = "LIVE"
	ll.add_theme_font_override(&"font", _font_b)
	ll.add_theme_font_size_override(&"font_size", 16)
	live.add_child(ll)
	bar.add_child(live)
	_live_dot = ColorRect.new()
	_live_dot.color = Color(1.0, 0.2, 0.25)
	_live_dot.custom_minimum_size = Vector2(10, 10)
	_live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_live_dot)
	_view_l = Label.new()
	_view_l.add_theme_font_override(&"font", _font_b)
	_view_l.add_theme_font_size_override(&"font_size", 18)
	_view_l.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.55))
	bar.add_child(_view_l)
	_title_l = Label.new()
	_title_l.custom_minimum_size = Vector2(10, 0)
	_title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_l.text = "SAMBO FENRIR  -  " + title
	_title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_l.add_theme_font_override(&"font", _font_b)
	_title_l.add_theme_font_size_override(&"font_size", 15)
	_title_l.add_theme_color_override(&"font_color", Color(0.86, 0.8, 1.0))
	v.add_child(_title_l)
	var sep := ColorRect.new()
	sep.color = Color(0.5, 0.3, 0.7, 0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	# the chat itself, its newest at the bottom
	var clip := Control.new()
	clip.clip_contents = true
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(clip)
	_rows = VBoxContainer.new()
	_rows.anchor_left = 0.0
	_rows.anchor_right = 1.0
	_rows.anchor_top = 1.0
	_rows.anchor_bottom = 1.0
	_rows.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_rows.add_theme_constant_override(&"separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_rows)


## The camera's own frame: corner marks, REC and its dot, the running time, the battery, a soft dark edge
func _build_pov() -> void:
	_pov = Control.new()
	_pov.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pov.visible = false
	_pov.draw.connect(_draw_pov)
	_root.add_child(_pov)


func _draw_pov() -> void:
	var s := _pov.size
	var m := s.y * 0.06
	var L := s.y * 0.09
	var w := maxf(2.0, s.y * 0.004)
	var c := Color(1, 1, 1, 0.85)
	for corner: Vector2 in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
		var dx := L if corner.x < s.x * 0.5 else -L
		var dy := L if corner.y < s.y * 0.5 else -L
		_pov.draw_line(corner, corner + Vector2(dx, 0), c, w)
		_pov.draw_line(corner, corner + Vector2(0, dy), c, w)
	var fs := int(s.y * 0.032)
	if fmod(_pov_t, 1.0) < 0.6:
		_pov.draw_circle(Vector2(m + L * 0.35, m + L * 0.6), s.y * 0.012, Color(1.0, 0.1, 0.1))
	_pov.draw_string(_font_b, Vector2(m + L * 0.55, m + L * 0.6 + fs * 0.35), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	var secs := int(1834.0 + _t)
	var tc := "%02d:%02d:%02d" % [int(secs / 3600.0), int(secs / 60.0) % 60, secs % 60]
	_pov.draw_string(_font_b, Vector2(s.x - m - L * 2.6, m + L * 0.6 + fs * 0.35), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	_pov.draw_string(_font, Vector2(m + L * 0.2, s.y - m - L * 0.4), "WeFOINT  LIVE  1080p60", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.75), Color(1, 1, 1, 0.7))
	var bx := s.x - m - L * 1.4
	var by := s.y - m - L * 0.75
	_pov.draw_rect(Rect2(bx, by, L * 0.9, L * 0.4), c, false, w)
	_pov.draw_rect(Rect2(bx + L * 0.9, by + L * 0.12, L * 0.08, L * 0.16), c)
	_pov.draw_rect(Rect2(bx + w * 2.0, by + w * 2.0, L * 0.25, L * 0.4 - w * 4.0), Color(1.0, 0.3, 0.2))      # (nearly flat)
