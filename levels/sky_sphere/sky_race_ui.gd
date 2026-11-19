class_name SkyRaceUi
extends Control
## The concourse's phosphor ticket terminal and the saucer's race instruments: speed, the boost meter (its segments grow with takedowns),
## the drift's mini-turbo colour, place, lap, takedowns, the item slot, and the callouts (TAKEDOWN, NEAR MISS, WRECKED...). Callouts and the
## item slot added 2026-11-18.

const INK := Color("05241b")
const SCREEN := Color("071911")
const EDGE := Color("2c6549")
const DIM := Color("7bb190")
const GREEN := Color("b9ffce")
const HOT := Color("ffd078")
const CABINET: Texture2D = preload(CrtKit.ART_PATH)

var selecting := false
var race: SkyRace
var _routes: Array[PackedVector2Array] = []
const TIER: Array[Color] = [Color("fff0c0"), Color("55c8ff"), Color("ffa040"), Color("c070ff")]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_routes = race.course.route_map()
	hide()


func refresh(ticket: bool) -> void:
	selecting = ticket
	visible = (ticket or race.on) and Game.started and not Game.paused
	if visible:
		queue_redraw()


func _draw() -> void:
	if selecting or race.results:
		_terminal(race.results)
	else:
		_instruments()


func _terminal(result: bool) -> void:
	var frame_width := minf(size.x * 0.94, size.y * CrtKit.ART_RATIO * 0.93)
	var frame_size := Vector2(frame_width, frame_width / CrtKit.ART_RATIO)
	var cabinet := Rect2((size - frame_size) * 0.5, frame_size)
	var tube_min := cabinet.position + cabinet.size * Vector2(CrtKit.HOLE.x1, CrtKit.HOLE.y1)
	var tube_max := cabinet.position + cabinet.size * Vector2(CrtKit.HOLE.x2, CrtKit.HOLE.y2)
	var unit := (tube_max.x - tube_min.x) / 600.0
	var s := (tube_max - tube_min) / unit
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.016, 0.03, 0.68))
	draw_texture_rect(CABINET, cabinet, false)
	draw_set_transform(tube_min, 0.0, Vector2.ONE * unit)
	draw_rect(Rect2(Vector2.ZERO, s), SCREEN)
	for y in range(2, floori(s.y), 5):
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.24, 0.56, 0.31, 0.075))
	var mono := CrtTheme.font(&"vt323")
	var display := CrtTheme.font(&"orb700")
	var pad := Inp.using_pad
	CrtTheme.draw_text(self, mono, 31.0, 49.0, "SKYSPHERE / " + ("RESULTS" if result else "TICKET STAND"), 26, DIM, 1.55)
	draw_line(Vector2(31, 64), Vector2(569, 64), EDGE, 1.65)
	if result:
		CrtTheme.draw_text(self, display, 31.0, 150.0, _placing(race.place), 54, HOT if race.place == 1 else GREEN)
		CrtTheme.draw_text(self, mono, 32.0, 194.0, "OVERCURRENT  /  RUN COMPLETE", 28, DIM)
		CrtTheme.draw_text(self, mono, 32.0, 232.0, "TAKEDOWNS  %d" % race.takedowns, 30, HOT if race.takedowns > 0 else GREEN)
	else:
		CrtTheme.draw_text(self, display, 31.0, 135.0, "OVERCURRENT", 37, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 169.0, "ONE RUN  /  %d CRAFT  /  NO RULES" % race.racers.size(), 25, HOT)
		CrtTheme.draw_text(self, mono, 31.0, 210.0, "RT / LT    THROTTLE / BRAKE" if pad else "W / S    THROTTLE / BRAKE", 23, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 235.0, "L STICK    STEER" if pad else "A / D    STEER", 23, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 260.0, "A          E-BRAKE / DRIFT / TRICK" if pad else "SPACE    E-BRAKE / DRIFT / TRICK", 23, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 285.0, "L3 (HOLD)  BOOST" if pad else "SHIFT    BOOST", 23, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 310.0, "RB / X     ITEM" if pad else "V        ITEM", 23, GREEN)
		CrtTheme.draw_text(self, mono, 31.0, 338.0, "SLAM RIVALS FOR TAKEDOWNS", 22, HOT)
		_course_map(Rect2(373, 148, 184, 184))
	var bottom := s.y - 68.0
	var command := ("A  RACE AGAIN" if pad else "X  RACE AGAIN") if result else ("A  ENTER RACE" if pad else "X  ENTER RACE")
	draw_rect(Rect2(30.0, bottom - 31.0, 289.0, 41.0), Color("153b2b"))
	draw_rect(Rect2(30.0, bottom - 31.0, 289.0, 41.0), DIM, false, 1.6)
	CrtTheme.draw_text(self, mono, 45.0, bottom - 2.0, command, 28, GREEN, 1.1)
	var back := "B  BACK" if pad else "E  BACK"
	CrtTheme.draw_right(self, mono, 566.0, bottom - 2.0, back, 25, DIM, 1.05)
	for i in 3:
		draw_circle(Vector2(559.0 - i * 10.0, 38.0), 2.8, HOT if i == 0 else EDGE)
	draw_set_transform(Vector2.ZERO)


func _course_map(box: Rect2) -> void:
	draw_rect(box, INK)
	draw_rect(box, EDGE, false, 1.0)
	for i in range(1, 9):
		var x := box.position.x + box.size.x * i / 9.0
		var y := box.position.y + box.size.y * i / 9.0
		draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), Color("174432"))
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), Color("174432"))
	for k in _routes.size():
		var pts := PackedVector2Array()
		for q: Vector2 in _routes[k]:
			pts.append(box.position + Vector2(6.0, 6.0) + q * (box.size - Vector2(12.0, 12.0)))
		if pts.size() < 2:
			continue
		if k == 0:
			draw_polyline(pts, Color("397d5f"), 6.0, true)
			draw_polyline(pts, GREEN, 1.75, true)
			draw_circle(pts[0], 3.8, HOT)
			draw_circle(pts[pts.size() - 1], 3.8, GREEN)
		else:
			draw_polyline(pts, HOT, 1.5, true)


func _instruments() -> void:
	var speed := race.speed_kmh()
	var velocity := smoothstep(170.0, 470.0, float(speed))
	_speed_lines(velocity)
	var unit := clampf(size.y / 1080.0, 0.55, 1.6)
	var mono := CrtTheme.font(&"vt323")
	var display := CrtTheme.font(&"orb700")
	var origin := Vector2(50.0 * unit, size.y - 186.0 * unit)
	draw_set_transform(origin, 0.0, Vector2.ONE * unit)
	_pod(Vector2(334, 136))
	CrtTheme.draw_text(self, display, 15, 53, "%03d" % speed, 44, GREEN)
	CrtTheme.draw_text(self, mono, 139, 51, "KM/H", 24, DIM)
	var tier := race.drift_tier()
	if tier > 0:
		CrtTheme.draw_right(self, mono, 318.0, 51.0, "DRIFT", 25, TIER[tier])
		draw_rect(Rect2(250.0, 58.0, 68.0, 4.0), TIER[tier])
	elif race.draft > 0.3:
		CrtTheme.draw_right(self, mono, 318.0, 51.0, "DRAFT", 25, HOT)
	# the boost meter: one cell per segment it has grown to, filled to what is left
	var burning := race.boosting()
	var meter_color := HOT if burning else (GREEN if race.meter() >= 1.0 else DIM)
	if race.overcharged():
		meter_color = SkyItems.COLORS[SkyItems.OVERCHARGE]
	CrtTheme.draw_text(self, mono, 16, 92, "BOOST", 26, meter_color)
	var cells := int(round(race.meter_max())) + (1 if race.overcharged() else 0)
	var cell_w := 208.0 / 5.0 if cells > 4 else 208.0 / 4.0
	for i in cells:
		var cell := Rect2(98.0 + i * cell_w, 75.0, cell_w - 5.0, 20.0)
		draw_rect(cell, Color("254737"))
		var fill := clampf(race.meter() - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(cell.position, Vector2(cell.size.x * fill, cell.size.y)), meter_color)
		draw_rect(cell, EDGE, false, 1.2)
	CrtTheme.draw_text(self, mono, 16.0, 124.0, "B  RETURN TO TICKETS" if Inp.using_pad else "E  RETURN TO TICKETS", 19, DIM)
	draw_set_transform(Vector2(size.x - 251.0 * unit, 46.0 * unit), 0.0, Vector2.ONE * unit)
	_pod(Vector2(205, 124))
	CrtTheme.draw_text(self, display, 16.0, 42.0, _placing(race.place).get_slice(" ", 0), 31, HOT if race.place == 1 else GREEN)
	CrtTheme.draw_right(self, mono, 187.0, 41.0, "/  %d" % race.racers.size(), 24, DIM)
	CrtTheme.draw_text(self, mono, 17.0, 75.0, "CP  %d / %d" % [race.checkpoint, race.course.checkpoints.size()], 26, GREEN, 0.65)
	CrtTheme.draw_text(self, mono, 17.0, 104.0, "TAKEDOWNS  %d" % race.takedowns, 24, HOT if race.takedowns > 0 else DIM, 0.65)
	draw_set_transform(Vector2(50.0 * unit, 46.0 * unit), 0.0, Vector2.ONE * unit)      # (top left: top centre hid the road ahead)
	_item_slot(mono)
	draw_set_transform(Vector2.ZERO)
	_callouts(display, mono)


## The held item, top left: its sign and name, or the roulette spinning through them.
func _item_slot(mono: Font) -> void:
	_pod(Vector2(132, 112))
	var item := race.item()
	var rolling := race.item_rolling()
	if rolling:
		item = int(Game.time * 14.0) % SkyItems.NAMES.size()
	if item < 0:
		draw_arc(Vector2(66, 48), 24.0, 0.0, TAU, 24, EDGE, 1.5)
		return
	var col: Color = SkyItems.COLORS[item]
	if rolling:
		col = col.darkened(0.35)
	_glyph(item, Vector2(66, 46), 26.0, col)
	if not rolling:
		var label: String = SkyItems.NAMES[item]
		var w := mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(mono, Vector2(66.0 - w * 0.5, 100.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		CrtTheme.draw_right(self, mono, 126.0, 20.0, "RB" if Inp.using_pad else "V", 18, DIM)


func _glyph(item: int, c: Vector2, r: float, col: Color) -> void:
	match item:
		SkyItems.MINE:
			draw_circle(c, r * 0.55, Color(col, 0.35))
			draw_arc(c, r * 0.55, 0.0, TAU, 20, col, 2.5)
			for k in 8:
				var a := TAU * k / 8.0 + Game.time * 0.6
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.6, c + Vector2(cos(a), sin(a)) * r, col, 2.5)
			draw_circle(c, r * 0.18, col)
		SkyItems.HARPOON:
			draw_line(c + Vector2(-r, r * 0.5), c + Vector2(r * 0.7, -r * 0.35), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r, -r * 0.5), c + Vector2(r * 0.45, -r * 0.55), c + Vector2(r * 0.7, -r * 0.05)]), col)
			for k in 4:
				draw_circle(c + Vector2(-r + k * 5.0, r * 0.5 - k * 2.4), 1.6, col)
		SkyItems.SHELL:
			draw_arc(c, r * 0.9, 0.0, TAU, 28, col, 3.0)
			draw_arc(c, r * 0.6, 0.0, TAU, 24, Color(col, 0.6), 2.0)
			draw_circle(c, r * 0.6, Color(col, 0.18))
		SkyItems.PULSE:
			for k in 3:
				var ring := r * (0.35 + 0.3 * k) * (0.9 + 0.1 * sin(Game.time * 6.0 - k))
				draw_arc(c, ring, 0.0, TAU, 28, Color(col, 1.0 - k * 0.28), 2.5)
			draw_circle(c, r * 0.14, col)
		SkyItems.OVERCHARGE:
			var bolt := PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.5, r * 0.1), c + Vector2(-r * 0.02, r * 0.1),
				c + Vector2(-r * 0.2, r), c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.02, -r * 0.15)])
			draw_colored_polygon(bolt, col)


## The big words: newest at the top, each punching in and fading.
func _callouts(display: Font, mono: Font) -> void:
	var y := size.y * 0.2
	if race.wrong_way and fmod(Game.time * 2.0, 1.0) < 0.6:
		_centred(display, "WRONG WAY", 52.0 * size.y / 1080.0, y, Color(1.0, 0.36, 0.2))
		y += 70.0 * size.y / 1080.0
	for k in range(race.popups.size() - 1, -1, -1):
		var p: SkyRace.Callout = race.popups[k]
		var t := p.age / SkyRace.POP_TIME
		var alpha := clampf((1.0 - t) * 3.0, 0.0, 1.0)
		var punch := 1.0 + maxf(0.0, 0.25 - p.age) * 1.6
		var px := (58.0 if p.big else 38.0) * punch * size.y / 1080.0
		var col := HOT if p.hot else GREEN
		col.a = alpha
		_centred(display, p.text, px, y, col)
		y += px * 1.05
		if p.sub != "":
			var sc := DIM
			sc.a = alpha
			_centred(mono, p.sub, px * 0.55, y, sc)
			y += px * 0.7
		y += 8.0


func _centred(font: Font, text: String, px: float, y: float, col: Color) -> void:
	var fs := int(px)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2((size.x - w) * 0.5, y + px)
	draw_string(font, at + Vector2(3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.0, 0.03, 0.02, col.a * 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _pod(dimensions: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, dimensions), Color(0.013, 0.045, 0.037, 0.88))
	draw_rect(Rect2(Vector2.ZERO, dimensions), EDGE, false, 1.65)
	draw_line(Vector2(0.0, 0.0), Vector2(44.0, 0.0), GREEN, 2.5)


func _speed_lines(velocity: float) -> void:
	if velocity < 0.01 and race.flash < 0.02:
		return
	var boost := race.boost
	var clock := Game.time * (0.82 + boost * 0.68)
	var middle := size * Vector2(0.5, 0.46)
	var reach := size * Vector2(0.58, 0.68)
	for i in 36:
		var phase := fposmod(clock + i * 0.618, 1.0)
		var angle := float(i) * 2.39996
		var aim := Vector2(cos(angle), sin(angle)) * reach
		var begin := 0.62 + phase * 0.45
		var end := begin + (velocity * 0.09 + boost * 0.14) * (0.52 + 0.48 * phase)
		var alpha := sin(phase * PI) * (velocity * 0.19 + boost * 0.24)
		var streak := Color(0.57, 0.88, 1.0, alpha)
		draw_line(middle + aim * begin, middle + aim * end, streak, 1.0 + boost * 0.9, true)
	if race.flash > 0.0:
		var edge := Color(1.0, 0.43, 0.13, race.flash * 0.48)
		draw_rect(Rect2(Vector2(9, 9), size - Vector2(18, 18)), edge, false, 3.0)


static func _placing(place: int) -> String:
	return ["1ST", "2ND", "3RD", "4TH", "5TH", "6TH"][clampi(place - 1, 0, 5)] + " PLACE"
