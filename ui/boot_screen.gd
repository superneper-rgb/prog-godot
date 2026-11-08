class_name BootScreen
extends Control
## The boot / warm-up screen (CSS #warm): a green terminal over everything until the game is compiled and ready. Bar, a short log, a blinking cursor; fades out over .55 s.

var _frac := 0.0
var _shown := 0.0
var _log: PackedStringArray = []
var _now := "LOADING"
var _time := 0.0
var _out := false
var _screen: CrtScreen
var _view: Page


class Page extends Control:
	var b: BootScreen
	func _draw() -> void:
		if b == null:
			return
		var f := CrtTheme.font(&"vt323")
		var w := minf(480.0, size.x * 0.86)
		var x := (size.x - w) * 0.5
		var y := (size.y - 130.0) * 0.5
		# .w-title
		CrtTheme.draw_text(self, f, x, y + 18.0, "PROG // SYSTEM BOOT", 18, CrtTheme.PH_HI, 18.0 * 0.34)
		# .w-bar
		var bar := Rect2(x, y + 22.0 + 14.0, w, 12.0)
		CrtTheme.glow_box(self, bar, Color(80.0 / 255.0, 1.0, 150.0 / 255.0, 0.35), 12.0)
		draw_rect(bar, Color("3fae6a"), false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((w - 4.0) * b._shown, 8.0)), Color("6dffa8"))
		# .w-log, .w-now
		var ly := bar.end.y + 12.0
		var lh := 16.0 * 1.6
		var first := maxi(0, b._log.size() - 3)
		for i in range(first, b._log.size()):
			CrtTheme.draw_text(self, f, x, ly + 16.0, b._log[i], 16, Color(157.0 / 255.0, 1.0, 191.0 / 255.0, 0.75))
			ly += lh
		var e := CrtTheme.draw_text(self, f, x, ly + 16.0, b._now, 16, CrtTheme.PH_HI)
		if fmod(b._time, 1.0) < 0.5:
			CrtTheme.draw_text(self, f, e, ly + 16.0, "_", 16, CrtTheme.PH_HI)


func _init() -> void:
	name = "Boot"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 300


func _ready() -> void:
	_screen = CrtScreen.new(get_viewport_rect().size)
	CrtTheme.full(_screen)
	# background: #020503 radial-gradient(ellipse at center, #06150b 0, #020503 72%); ::after repeating-linear-gradient(0deg, rgba(0,0,0,.28) 0 1px, transparent 1px 3px)
	_screen.param(&"bg_center", Color("06150b"))
	_screen.param(&"bg_edge", Color("020503"))
	_screen.param(&"bg_size", Vector2(1.0, 1.0))
	_screen.param(&"vig_inner", Color(0, 0, 0, 0))
	_screen.param(&"vig_outer", Color(0, 0, 0, 0))
	_screen.param(&"scan", 0.28)
	_screen.param(&"roll_alpha", 0.0)
	_screen.param(&"flick_period", 0.0)
	_screen.param(&"glow_tint", Vector3(100.0 / 255.0, 1.0, 160.0 / 255.0))
	_screen.param(&"glow_amount", 0.5)
	_screen.param(&"glow_radius", 8.0)
	add_child(_screen)
	_view = Page.new()
	_view.b = self
	_view.size = _screen.logical
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.content.add_child(_view)
	_screen.live = true
	get_viewport().size_changed.connect(_on_size)


func _on_size() -> void:
	_screen.set_logical(get_viewport_rect().size)
	_view.size = _screen.logical


func set_step(label: String, frac: float) -> void:
	if _now != "LOADING":
		_log.append(_now + " ... ok")
	_now = label.to_upper()
	_frac = frac


func hide_out() -> void:
	_frac = 1.0
	_out = true


func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, _frac, delta / 0.3)
	_view.queue_redraw()
	if _out:
		modulate.a = move_toward(modulate.a, 0.0, delta / 0.55)
		if modulate.a <= 0.0:
			_screen.live = false
			queue_free()
