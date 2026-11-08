class_name VhSpotter
extends RefCounted
## VISITING HOURS: the goggles' rangefinder (JS spotter.js, section 2). With the night vision on and a sniper scope up, the goggles range what the reticle rests on: a green phosphor readout over the scope (bearing, and the name of one of the places the Boss wants found); holding on one a beat reports it once through on_find(poi). No markers on the world. Also the goggles' whiteout: lightning floods the amplified picture for a moment.

var layer: CanvasLayer
var root: Control
var tag: Label
var num: Label
var br: ReferenceRect
var white_r: ColorRect
var on := false
var focus: Variant = null
var hold := 0.0
var found := {}
var typed := ""
var type_t := 0.0
var bare_t := 0.0
var bare_said := false
var white := 0.0
var pois := Callable()      # -> [{id, at: Vector3, r, label, hold}]
var on_find := Callable()
var on_bare := Callable()


func _init(parent: Node) -> void:
	layer = CanvasLayer.new()
	layer.layer = 6
	parent.add_child(layer)
	white_r = ColorRect.new()
	white_r.color = Color("#eaffef")
	white_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	white_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mt := CanvasItemMaterial.new()
	mt.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	white_r.material = mt
	white_r.modulate.a = 0.0
	layer.add_child(white_r)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	layer.add_child(root)
	br = ReferenceRect.new()
	br.editor_only = false
	br.border_color = Color("#ffd27a")
	br.border_width = 2.0
	br.visible = false
	root.add_child(br)
	var font: Font = load("res://assets/fonts/VT323-Regular.ttf")
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 18.0 / 255.0, 6.0 / 255.0, 0.55)
	sb.border_color = Color(110.0 / 255.0, 1.0, 150.0 / 255.0, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5.0)
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 40.0
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	tag = Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override(&"font", font)
	tag.add_theme_font_size_override(&"font_size", 22)
	tag.add_theme_color_override(&"font_color", Color("#ffd27a"))
	box.add_child(tag)
	num = Label.new()
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_override(&"font", font)
	num.add_theme_font_size_override(&"font_size", 22)
	num.add_theme_color_override(&"font_color", Color("#7dffa6"))
	box.add_child(num)


func _show(v: bool) -> void:
	if v != on:
		on = v
		root.visible = v
		if not v:
			focus = null
			br.visible = false


## live: a search is on (the vantage objectives); flash: the storm's lightning this frame (0..1)
func update(dt: float, live: bool, flash: float) -> void:
	var P: Player = Game.player
	var nv: bool = Game.night_vision.on
	var list: Array = pois.call() if live else []
	# the whiteout: the goggles amplify a lightning flash into a wash of white, gone in a moment
	white = maxf(minf(0.85, flash * 1.4) if nv else 0.0, white - dt * 2.2)
	white_r.modulate.a = white
	var scoped: bool = P != null and P.scoped and not Game.vehicles.driving
	if live and scoped and not nv:
		bare_t += dt
		if bare_t > 2.2 and not bare_said:
			bare_said = true
			if on_bare.is_valid():
				on_bare.call()
	else:
		bare_t = 0.0
	_show(live and scoped and nv)
	if not on:
		return
	var cam: Camera3D = Game.camera
	if cam == null:
		return
	var dir := -cam.global_transform.basis.z
	# what is under the reticle: the nearest poi within its angular size (never smaller than ~0.5 deg)
	var best: Variant = null
	var best_a := INF
	for p: Dictionary in list:
		var to: Vector3 = (p.at as Vector3) - cam.global_position
		var ln := to.length()
		var a := dir.angle_to(to)
		var lim := maxf(0.009, atan(float(p.r) / ln))
		if a < lim and a < best_a:
			best = p
			best_a = a
	if best != focus:
		focus = best
		hold = 0.0
		typed = ""
		type_t = 0.0
	if best != null:
		hold += dt
		var full: String = best.label
		type_t += dt
		if typed.length() < full.length() and type_t > 0.035:
			type_t = 0.0
			typed = full.substr(0, typed.length() + 1)
		if hold > float(best.get("hold", 1.0)) and not found.has(best.id):
			found[best.id] = true
			if on_find.is_valid():
				on_find.call(best)
		var sp := cam.unproject_position(best.at)
		var hh := root.size.y * 0.05
		br.size = Vector2(hh, hh)
		br.position = sp - br.size / 2.0
		br.visible = true
	else:
		br.visible = false
	var brg := fposmod(rad_to_deg(atan2(dir.x, dir.z)) + 360.0, 360.0)
	tag.text = (("■ " if found.has(best.id) else "□ ") + typed) if best != null else ""
	num.text = "NV · RANGE LINK   BRG %03d°" % int(round(brg))


## a checkpoint: the nag may come again
func reset() -> void:
	bare_said = false
	bare_t = 0.0
