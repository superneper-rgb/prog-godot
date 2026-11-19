class_name CityMap
extends Control
## The hub's map (View / Back on the pad, M on the keyboard): the street, the bridge and FOINT CITY seen from above, drawn from what the level itself holds (its road plan, the Deck, the building colliders), with where you stand and a
## list of the places worth knowing. D-pad up / down (or the arrow keys) picks one: the readout gives the distance and the way. North is up and the city lies south of the street, as it does in the plan (+z is south).
## Sits in the same SchleedTech monitor as the pause terminal, zoomed until the glass fills the window. The world stands still while it is up (it registers in Game.menus).

const LOGICAL := Vector2(1066.0, 800.0)      # the page, at the glass's own 4:3. The pause terminal's zoomed pages are laid out the same way
const MARGIN := 36.0
const PANEL_TOP := 96.0
const PANEL_H := 590.0
const GAP := 18.0
const BRIDGE_W := 44.0
const STREET_Z0 := 66.0          # where the street ends and the bridge begins (HubLevel: BRIDGE.z0 is 64, the road's end a little past it)
const CITY_Z0 := 170.0           # the city's north edge (life.json land)

## One place on the map.
class Mark:
	var name := ""
	var note := ""
	var x := 0.0
	var z := 0.0
	var city := false        # on the city panel (else the street panel)
	var live := false        # he walks about: x and z are refreshed from the level every frame (Sambo)

## One plot: a rectangle on the page and the world rectangle it shows.
class Plot:
	var r := Rect2()
	var x0 := 0.0
	var x1 := 0.0
	var z0 := 0.0
	var z1 := 0.0
	func at(x: float, z: float) -> Vector2:
		return Vector2(r.position.x + (x - x0) / (x1 - x0) * r.size.x, r.position.y + (z - z0) / (z1 - z0) * r.size.y)
	func scale() -> float:
		return r.size.x / (x1 - x0)
	func rect(xa: float, xb: float, za: float, zb: float) -> Rect2:
		var a := at(xa, za)
		var b := at(xb, zb)
		return Rect2(a, b - a)

## The page on the terminal's glass.
class PageView extends Control:
	var m: CityMap
	func _draw() -> void:
		if m != null:
			m._draw_page(self)

var is_open: bool = false

var _hub: HubLevel = null
var _bg: ColorRect
var _stage: Control
var _view: CrtScreen
var _page: PageView
var _art: TextureRect
var _glow_mul: ColorRect
var _glow_add: ColorRect
var _sw := 1000.0
var _sh := 810.0
var _gx := 0.0
var _gy := 0.0
var _gw := 600.0
var _gh := 440.0
var _zoom := 1.0
var _t := Vector2.ZERO
var _time := 0.0
var _street := Plot.new()
var _city := Plot.new()
var _roads: Array = []           # the plan's roads as the level exported them: {name, axis, c, rect}
var _decks: Array = []           # [x0, x1, z0, z1]
var _blocks: Array[Rect2] = []   # building footprints in the street: x, z, w, h in metres
var _towers: Array[Rect2] = []   # the same in the city
var _marks: Array[Mark] = []
var _sel := 0
var _repeat := 0.0
var _opened_at := -1      # the frame it opened on: the press that opened it is still down in Game's menu update of the same frame


func _init() -> void:
	name = "CityMap"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 19


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color.WHITE
	CrtTheme.full(_bg)
	_bg.material = CrtTheme.mat("res://ui/backdrop.gdshader")
	add_child(_bg)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_view = CrtScreen.new(LOGICAL)
	_view.param(&"glow_tint", Vector3(80.0 / 255.0, 1.0, 140.0 / 255.0))
	_view.param(&"glow_amount", 0.62)
	_view.param(&"glow_radius", 7.0)
	_stage.add_child(_view)
	_page = PageView.new()
	_page.m = self
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = LOGICAL
	_view.content.add_child(_page)
	_art = TextureRect.new()
	_art.texture = load("res://assets/ui/cut/pausecrt.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(_art)
	_glow_mul = _glow_rect("res://ui/box_glow_mul.gdshader")
	_glow_add = _glow_rect("res://ui/box_glow.gdshader")
	_stage.add_child(_glow_mul)
	_stage.add_child(_glow_add)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)


func _glow_rect(shader: String) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color.WHITE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = CrtTheme.mat(shader)
	return c


## The monitor, zoomed until its glass fills the window (what PauseMenu does for its controls page).
func _layout() -> void:
	var vp := get_viewport_rect().size
	var h: Array = UiArt.PAUSE_HOLE
	_sw = minf(vp.x * 0.98, vp.y * 0.98 * UiArt.PAUSE_RATIO)
	_sh = _sw / UiArt.PAUSE_RATIO
	_gx = h[0] * _sw
	_gy = h[1] * _sh
	_gw = (h[2] - h[0]) * _sw
	_gh = (h[3] - h[1]) * _sh
	_zoom = maxf(1.0, minf(vp.x * 0.97 / _gw, vp.y * 0.97 / _gh))
	_t = Vector2(_sw * 0.5 - (h[0] + h[2]) * 0.5 * _sw, _sh * 0.5 - (h[1] + h[3]) * 0.5 * _sh)
	_stage.size = Vector2(_sw, _sh)
	_stage.pivot_offset = Vector2(_gx + _gw * 0.5, _gy + _gh * 0.5)
	_art.size = Vector2(_sw, _sh)
	_view.position = Vector2(_gx, _gy)
	_view.size = Vector2(_gw, _gh)
	_view.set_logical(LOGICAL)
	_view.fit(_zoom)
	var pad := Vector2(_sw * 0.06, _sw * 0.06)
	for c: ColorRect in [_glow_mul, _glow_add]:
		c.position = Vector2(_gx, _gy) - pad
		c.size = Vector2(_gw, _gh) + pad * 2.0
		var m := c.material as ShaderMaterial
		m.set_shader_parameter(&"box_css", Vector2(_gw, _gh))
		m.set_shader_parameter(&"pad", pad)
		m.set_shader_parameter(&"radius", Vector2(_gw * 0.04, _gh * 0.05))
		m.set_shader_parameter(&"outer", Color(90.0 / 255.0, 1.0, 150.0 / 255.0, 0.5))
		m.set_shader_parameter(&"outer_blur", _sw * 0.03)
		m.set_shader_parameter(&"outer_spread", _sw * 0.005)
		m.set_shader_parameter(&"in_a", Color(80.0 / 255.0, 1.0, 140.0 / 255.0, 0.5))
		m.set_shader_parameter(&"in_a_blur", _sw * 0.055)
		m.set_shader_parameter(&"in_b", Color(160.0 / 255.0, 1.0, 200.0 / 255.0, 0.5))
		m.set_shader_parameter(&"in_b_blur", _sw * 0.012)
	var base := (vp - Vector2(_sw, _sh)) * 0.5
	_stage.scale = Vector2.ONE * _zoom
	_stage.position = base + _t
	var f := CrtTheme.px(self)
	_view.param(&"rect_px", Vector2(_gw, _gh) * f * _zoom)
	_view.param(&"px_scale", f * _zoom)
	_view.param(&"overlay", 0.45)


## Is there a map for the level the player is in?
static func available() -> bool:
	return Game.level is HubLevel


func open() -> void:
	_hub = Game.level as HubLevel
	if _hub == null or is_open:
		return
	_gather()
	_opened_at = Engine.get_process_frames()
	is_open = true
	visible = true
	set_process(true)
	_view.live = true
	_view.arm_glitch(true)
	_layout()
	CrtTheme.sfx("wheelOpen")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	set_process(false)
	_view.live = false
	_view.arm_glitch(false)
	CrtTheme.sfx("wheelClose")


## Take what the level holds: roads, the Deck, building footprints, the places. Done each time the map opens, so what the story has revealed (the drain, the grate) is up to date.
func _gather() -> void:
	_roads.clear()
	_decks.clear()
	_blocks.clear()
	_towers.clear()
	_marks.clear()
	var J: Dictionary = _hub.life.J if _hub.life != null else {}
	if J.has("plan"):
		for d: Dictionary in J["plan"]["roads"]:
			_roads.append(d)
	for d: Array in J.get("deck_rects", []):
		_decks.append(d)
	for s: World.Solid in _hub.solids_tagged("bld"):
		_blocks.append(Rect2(s.cx - s.hx, s.cz - s.hz, s.hx * 2.0, s.hz * 2.0))
	for s: World.Solid in _hub.solids_tagged("bound"):
		if s.kind == "box" and s.cz >= CITY_Z0 and s.cz <= 548.0 and absf(s.cx) <= 130.0 and s.top >= 5.0 and s.hx * s.hz >= 16.0 and s.bottom < 2.0:
			_towers.append(Rect2(s.cx - s.hx, s.cz - s.hz, s.hx * 2.0, s.hz * 2.0))
	var land: Dictionary = J.get("land", {"x0": -130.0, "x1": 130.0, "z0": CITY_Z0, "z1": 548.0})
	_city.x0 = float(land["x0"])
	_city.x1 = maxf(float(land["x1"]), 150.0)      # the east quay (x 128, where Sambo paces and the Palace site's gate is) lies just past the land's edge
	_city.z0 = float(land["z0"])
	_city.z1 = float(land["z1"]) + 4.0
	_street.x0 = -27.0
	_street.x1 = 27.0
	_street.z0 = -68.0
	_street.z1 = STREET_Z0
	var sh := PANEL_H
	_street.r = Rect2(MARGIN, PANEL_TOP, sh * (_street.x1 - _street.x0) / (_street.z1 - _street.z0), sh)
	_city.r = Rect2(_street.r.end.x + GAP * 2.0 + BRIDGE_W, PANEL_TOP, sh * (_city.x1 - _city.x0) / (_city.z1 - _city.z0), sh)
	_add(false, "CLUB 9", -7.0, -36.6, "THE CLUB. THE DOOR IS ON THE LEFT PAVEMENT.")
	_add(false, "IMPLANT MACHINE", 6.83, -19.4, "THE VENDING MACHINE ON THE RIGHT WALL.")
	_add(false, "GUNSHOP", 18.9, 10.5, "RIGHT SIDE. THE CLERK IS BEHIND THE COUNTER.")
	_add(false, "ARMCHAIR GENERAL", -6.4, 16.4, "LEFT PAVEMENT, BY THE DUMPSTER.")
	_add(false, "PUPPY", -7.15, 29.0, "LEFT PAVEMENT.")
	_add(true, "FOINT DOME", 0.0, 220.5, "THE GATE HALL, AT THE END OF THE BRIDGE PLAZA.")
	_add(true, "B-9 OFFICE", 120.0, 330.0, "THE BOSS'S OFFICE, EAST SIDE.")
	var sb := _hub.sambo
	if sb != null and sb.state != &"in":      # (inside the Palace he is not on the quay)
		_add(true, "PERVERT PALACE", HubSambo.GATE_AT.x, HubSambo.GATE_AT.y, "THE SITE IN THE BAY. ITS GATE IS ON THE EAST QUAY.")
		_add(true, "SAMBO FENRIR", sb.pos.x, sb.pos.z, "")
		_marks[_marks.size() - 1].live = true
		_refresh_live()
	if Game.story_get("ventJob"):
		_add(true, "INTAKE GRATE", 108.0, 327.26, "IN THE ALLEY, LEFT WALL.")
	if Game.story_get("ufFound"):
		_add(true, "STORM DRAIN", HubDrain.AT.x, HubDrain.AT.y, "THE YARD BEHIND THE LAST PIER ON GLEEMAN. DOWN TO UNDERFOINT.")
	var p := Game.player
	var best := 1e30
	_sel = 0
	for i in _marks.size():
		var d := _dist(_marks[i])
		if d < best:
			best = d
			_sel = i
	if p == null:
		_sel = 0


## Sambo's mark follows him; his note says what he is doing.
func _refresh_live() -> void:
	var sb := _hub.sambo
	for m: Mark in _marks:
		if not m.live:
			continue
		if sb == null:
			continue
		m.x = sb.pos.x
		m.z = sb.pos.z
		m.note = "WAITING AT THE SITE'S GATE FOR HIS CAMERA GUY." if sb.state == &"gate" else ("OFF TO THE GATE." if sb.state == &"to_gate" else "PACING THE EAST QUAY, OUTSIDE THE PALACE SITE.")


func _add(city: bool, nm: String, x: float, z: float, note: String) -> void:
	var m := Mark.new()
	m.city = city
	m.name = nm
	m.x = x
	m.z = z
	m.note = note
	_marks.append(m)


func _dist(m: Mark) -> float:
	var p := Game.player
	return INF if p == null else U.hyp(p.x - m.x, p.z - m.z)


# ---- input: Game._process calls update() on every open menu ----

func update(dt: float) -> void:
	if Engine.get_process_frames() == _opened_at:
		return
	if Inp.btn(&"map").pressed or Inp.btn(&"b").pressed or Inp.btn(&"pause").pressed or Inp.key_hit(KEY_ESCAPE):
		Inp.btn(&"map").pressed = false
		Inp.btn(&"b").pressed = false
		Inp.btn(&"pause").pressed = false
		close()
		return
	var step := 0
	if Inp.btn(&"d_down").pressed or Inp.key_hit(KEY_DOWN) or Inp.key_hit(KEY_RIGHT):
		step = 1
	elif Inp.btn(&"d_up").pressed or Inp.key_hit(KEY_UP) or Inp.key_hit(KEY_LEFT):
		step = -1
	elif absf(Inp.raw_ly) > 0.7:      # the stick too, at a walking pace
		_repeat -= dt
		if _repeat <= 0.0:
			step = 1 if Inp.raw_ly > 0.0 else -1
			_repeat = 0.22
	else:
		_repeat = 0.0
	if step != 0 and not _marks.is_empty():
		_sel = posmod(_sel + step, _marks.size())
		CrtTheme.menu_sound("nav")


func _process(delta: float) -> void:
	_time += delta
	_refresh_live()
	var g := lerpf(0.82, 1.0, 0.5 - 0.5 * cos(_time / 4.0 * TAU))
	(_glow_add.material as ShaderMaterial).set_shader_parameter(&"opacity", g)
	(_glow_mul.material as ShaderMaterial).set_shader_parameter(&"opacity", g)
	_page.queue_redraw()


# ---- the page ----

func _draw_page(ci: Control) -> void:
	if _hub == null:      # (the glass draws once when the UI is built, before there is any level to map)
		return
	var f := CrtTheme.font(&"vt323")
	var pl := CrtTheme.PH
	ci.draw_rect(Rect2(Vector2.ZERO, LOGICAL), Color(0.0, 0.02, 0.008, 0.9))
	# title
	CrtTheme.draw_text(ci, f, MARGIN, 52.0, "FOINT CITY  //  MAP", 34, CrtTheme.PH_HI, 3.0)
	CrtTheme.draw_right(ci, f, LOGICAL.x - MARGIN, 52.0, "NORTH UP", 20, CrtTheme.PH_LOW, 3.0)
	ci.draw_line(Vector2(MARGIN, 64.0), Vector2(LOGICAL.x - MARGIN, 64.0), Color(pl, 0.45), 1.0)
	_draw_street(ci, f)
	_draw_city(ci, f)
	_draw_bridge(ci, f)
	_draw_readout(ci, f)
	# footer
	var foot := "D-PAD / ARROWS: PLACE     VIEW / M / B: CLOSE"
	CrtTheme.draw_text(ci, f, MARGIN, LOGICAL.y - 26.0, foot, 20, CrtTheme.PH_LOW, 2.0)


func _panel_frame(ci: Control, f: Font, p: Plot, title: String) -> void:
	ci.draw_rect(p.r, Color(CrtTheme.PH, 0.035))
	ci.draw_rect(p.r, Color(CrtTheme.PH, 0.7), false, 1.5)
	CrtTheme.draw_text(ci, f, p.r.position.x, p.r.position.y - 9.0, title, 22, CrtTheme.PH_DIM, 3.0)
	# a metre grid, every 50 m: a map reads against a scale
	var gx := ceilf(p.x0 / 50.0) * 50.0
	while gx < p.x1:
		var a := p.at(gx, p.z0)
		var b := p.at(gx, p.z1)
		ci.draw_line(a, b, Color(CrtTheme.PH, 0.06), 1.0)
		gx += 50.0
	var gz := ceilf(p.z0 / 50.0) * 50.0
	while gz < p.z1:
		ci.draw_line(p.at(p.x0, gz), p.at(p.x1, gz), Color(CrtTheme.PH, 0.06), 1.0)
		gz += 50.0


func _draw_street(ci: Control, f: Font) -> void:
	var p := _street
	_panel_frame(ci, f, p, "THE STREET")
	# the roadway and the pavements: 7.4 m each way of the middle, from the far wall to where the bridge starts
	ci.draw_rect(p.rect(-7.4, 7.4, p.z0, p.z1), Color(CrtTheme.PH, 0.16))
	ci.draw_rect(p.rect(-1.4, 1.4, p.z0, p.z1), Color(CrtTheme.PH, 0.05))
	for b: Rect2 in _blocks:
		var r := p.rect(b.position.x, b.end.x, b.position.y, b.end.y)
		ci.draw_rect(r, Color(CrtTheme.PH, 0.09))
		ci.draw_rect(r, Color(CrtTheme.PH, 0.5), false, 1.0)
	# the way on: an arrow off the south end of the street
	var s := p.at(0.0, p.z1)
	CrtTheme.draw_center(ci, CrtTheme.font(&"vt323"), s.x, s.y - 8.0, "BRIDGE", 18, CrtTheme.PH_BTN, 2.0)
	_draw_marks(ci, p, false)


func _draw_city(ci: Control, f: Font) -> void:
	var p := _city
	_panel_frame(ci, f, p, "FOINT CITY")
	for d: Array in _decks:
		var r := p.rect(d[0], d[1], d[2], d[3])
		ci.draw_rect(r, Color(CrtTheme.PH_HI, 0.1))
	for rd: Dictionary in _roads:
		var q: Array = rd["rect"]
		var r := p.rect(q[0], q[1], q[2], q[3])
		ci.draw_rect(r, Color(CrtTheme.PH, 0.2))
		var c: float = rd["c"]
		if rd["axis"] == "x":
			ci.draw_line(p.at(q[0], c), p.at(q[1], c), Color(CrtTheme.PH_HI, 0.35), 1.0)
		else:
			ci.draw_line(p.at(c, q[2]), p.at(c, q[3]), Color(CrtTheme.PH_HI, 0.35), 1.0)
	for t: Rect2 in _towers:
		var r := p.rect(t.position.x, t.end.x, t.position.y, t.end.y)
		ci.draw_rect(r, Color(CrtTheme.PH, 0.1))
		ci.draw_rect(r, Color(CrtTheme.PH, 0.55), false, 1.0)
	# the arena the Dome stands in
	var ar: Dictionary = _hub.life.J.get("arena", {}) if _hub.life != null else {}
	if not ar.is_empty():
		var cc := p.at(float(ar["x"]), float(ar["z"]))
		ci.draw_arc(cc, float(ar["r"]) * p.scale(), 0.0, TAU, 64, Color(CrtTheme.PH, 0.45), 1.0)
	# street names, along their roads
	var small := CrtTheme.font(&"vt323")
	var done := {}
	for rd: Dictionary in _roads:
		var nm: String = String(rd["name"])
		var q: Array = rd["rect"]
		var mid := p.at((q[0] + q[1]) * 0.5, (q[2] + q[3]) * 0.5)
		var w := CrtTheme.text_w(small, nm.to_upper(), 15, 1.5)
		if done.has(nm) and rd["axis"] == "x":
			continue
		if rd["axis"] == "x":
			CrtTheme.draw_text(ci, small, mid.x - w * 0.5, mid.y + 4.5, nm.to_upper(), 15, Color(CrtTheme.PH_HI, 0.8), 1.5)
			done[nm] = true
		else:
			ci.draw_set_transform(mid, -PI / 2.0)
			CrtTheme.draw_text(ci, small, -w * 0.5, 4.5, nm.to_upper(), 15, Color(CrtTheme.PH_HI, 0.8), 1.5)
			ci.draw_set_transform(Vector2.ZERO, 0.0)
	_draw_marks(ci, p, true)


## The bridge between the two: a plain gauge from the street's end to the city's edge, with a tick where the player is on it.
func _draw_bridge(ci: Control, f: Font) -> void:
	var cx := _street.r.end.x + GAP + BRIDGE_W * 0.5
	var top := PANEL_TOP
	var bot := PANEL_TOP + PANEL_H
	ci.draw_line(Vector2(cx, top), Vector2(cx, bot), Color(CrtTheme.PH, 0.5), 1.0)
	for i in 11:
		var y := lerpf(top, bot, float(i) / 10.0)
		ci.draw_line(Vector2(cx - 5.0, y), Vector2(cx + 5.0, y), Color(CrtTheme.PH, 0.5), 1.0)
	ci.draw_set_transform(Vector2(cx - 12.0, (top + bot) * 0.5), -PI / 2.0)
	CrtTheme.draw_text(ci, f, -40.0, 0.0, "THE BRIDGE", 20, CrtTheme.PH_DIM, 4.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0)
	var p := Game.player
	if p != null and p.z > STREET_Z0 and p.z < CITY_Z0:
		var u := (p.z - STREET_Z0) / (CITY_Z0 - STREET_Z0)
		_draw_arrow(ci, Vector2(cx, lerpf(top, bot, u)), p.yaw, 1.0)


func _draw_marks(ci: Control, pn: Plot, city: bool) -> void:
	var f := CrtTheme.font(&"vt323")
	for i in _marks.size():
		var m := _marks[i]
		if m.city != city:
			continue
		var c := pn.at(m.x, m.z)
		var sel := i == _sel
		var col := CrtTheme.PH_WHITE if sel else CrtTheme.PH_BTN
		var s := 5.0
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Color(col, 0.9 if sel else 0.7))
		if sel:
			var pulse := 0.5 + 0.5 * sin(_time * 5.0)
			ci.draw_arc(c, 11.0 + pulse * 3.0, 0.0, TAU, 28, Color(CrtTheme.PH_WHITE, 0.9 - pulse * 0.4), 1.5)
			var w := CrtTheme.text_w(f, m.name, 18, 1.5)
			var tx := clampf(c.x - w * 0.5, pn.r.position.x + 2.0, pn.r.end.x - w - 2.0)
			ci.draw_rect(Rect2(tx - 3.0, c.y - 33.0, w + 6.0, 20.0), Color(0.0, 0.03, 0.01, 0.85))
			CrtTheme.draw_text(ci, f, tx, c.y - 18.0, m.name, 18, CrtTheme.PH_WHITE, 1.5)
	var p := Game.player
	if p != null:
		var inside := (not city and p.z <= STREET_Z0 and absf(p.x) <= 27.0) or (city and p.z >= CITY_Z0 and p.x >= _city.x0 - 5.0 and p.x <= _city.x1 + 5.0)
		# the Deck's top and the ground under it are one place on a plan: no second marker
		if inside:
			_draw_arrow(ci, pn.at(clampf(p.x, pn.x0, pn.x1), clampf(p.z, pn.z0, pn.z1)), p.yaw, 1.0)


## The player: an arrowhead pointing where Prog faces (yaw 0 faces +z, which is down the page), with a slow ring.
func _draw_arrow(ci: Control, c: Vector2, yaw: float, k: float) -> void:
	var d := Vector2(sin(yaw), cos(yaw))
	var n := Vector2(-d.y, d.x)
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	ci.draw_arc(c, (11.0 + pulse * 4.0) * k, 0.0, TAU, 28, Color(CrtTheme.AMBER, 0.55 - pulse * 0.3), 1.5)
	var pts := PackedVector2Array([c + d * 9.0 * k, c - d * 6.0 * k + n * 6.0 * k, c - d * 3.0 * k, c - d * 6.0 * k - n * 6.0 * k])
	ci.draw_colored_polygon(pts, Color(CrtTheme.AMBER, 1.0))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.9, 0.55), 1.0)


func _draw_readout(ci: Control, f: Font) -> void:
	var x := _city.r.end.x + GAP * 2.0
	var w := LOGICAL.x - MARGIN - x
	var r := Rect2(x, PANEL_TOP, w, PANEL_H)
	ci.draw_rect(r, Color(CrtTheme.PH, 0.035))
	ci.draw_rect(r, Color(CrtTheme.PH, 0.7), false, 1.5)
	var y := PANEL_TOP + 26.0
	CrtTheme.draw_text(ci, f, x + 12.0, y, "PLACES", 22, CrtTheme.PH_DIM, 3.0)
	y += 10.0
	for i in _marks.size():
		var m := _marks[i]
		y += 24.0
		var sel := i == _sel
		if sel:
			ci.draw_rect(Rect2(x + 6.0, y - 18.0, w - 12.0, 24.0), Color(CrtTheme.PH, 0.16))
		CrtTheme.draw_text(ci, f, x + 14.0, y, ("> " if sel else "  ") + m.name, 20, CrtTheme.PH_WHITE if sel else CrtTheme.PH, 1.5)
	y = PANEL_TOP + PANEL_H - 170.0
	ci.draw_line(Vector2(x + 8.0, y), Vector2(x + w - 8.0, y), Color(CrtTheme.PH, 0.4), 1.0)
	if _sel < _marks.size():
		var m := _marks[_sel]
		y += 28.0
		CrtTheme.draw_text(ci, f, x + 12.0, y, m.name, 24, CrtTheme.PH_HI, 2.0)
		y += 6.0
		for ln in CrtTheme.wrap(f, m.note, 18, w - 24.0, 1.0):
			y += 20.0
			CrtTheme.draw_text(ci, f, x + 12.0, y, ln, 18, CrtTheme.PH_LOW, 1.0)
		var p := Game.player
		if p != null:
			var dx := m.x - p.x
			var dz := m.z - p.z
			y = PANEL_TOP + PANEL_H - 40.0
			CrtTheme.draw_text(ci, f, x + 12.0, y, "%d M  %s" % [roundi(_dist(m)), _compass(dx, dz)], 24, CrtTheme.AMBER, 2.0)


## The way to a place, as the nearest of the eight points (north is up the page, so -z).
static func _compass(dx: float, dz: float) -> String:
	if dx * dx + dz * dz < 4.0:
		return "HERE"
	var a := fposmod(atan2(dx, -dz), TAU)      # 0 = north, clockwise
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[int(roundf(a / (TAU / 8.0))) % 8]
