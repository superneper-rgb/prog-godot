class_name CharPreviews
extends Control
## The start screen's character select: a small live turntable of each character (JS charSelect), each in its own little 3D world behind the card. Built when the panel first opens, freed with the game's start.

class Turntable:
	var id := ""
	var vp: SubViewport
	var rect: TextureRect
	var holder: Node3D
	var prop: Node3D
	var ph := 0.0


var _views: Array[Turntable] = []
## BUG-103 (tracker): the card the pad / mouse is on. It is only a highlight; the card that says SELECTED is `Game.char_pick`, set by A / Enter / a click (`pick`). (The three.js game had the mouse only, where a click was both.)
var focus := "prog"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_active(on: bool) -> void:
	visible = on
	if on:
		focus = Game.char_pick
	if on and _views.is_empty():
		for id: String in ["prog", "tommy"]:
			_views.append(_make(id))
	for t in _views:
		t.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _free_all() -> void:
	for t in _views:
		t.vp.queue_free()
		t.rect.queue_free()
	_views.clear()


## Starting a game disposes the previews, so each comeback builds them anew.
func dispose() -> void:
	_free_all()
	visible = false


func _make(id: String) -> Turntable:
	var t := Turntable.new()
	t.id = id
	t.ph = 0.0 if id == "prog" else 1.7
	var B := Builds.character_build(id)
	t.vp = SubViewport.new()
	t.vp.own_world_3d = true
	t.vp.transparent_bg = true
	t.vp.msaa_3d = Viewport.MSAA_4X
	t.vp.size = Vector2i(256, 190)
	t.vp.gui_disable_input = true
	t.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	t.vp.audio_listener_enable_3d = false
	add_child(t.vp)
	var world := Node3D.new()
	t.vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe9ff").lerp(Color("3a3020"), 0.35)      # (the hemisphere light, sky and ground averaged)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.7
	key.position = Vector3(1.5, 3, 4)
	world.add_child(key)
	key.look_at(Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7fb4ff")
	rim.light_energy = 1.2
	rim.position = Vector3(-2, 2, -3)
	world.add_child(rim)
	rim.look_at(Vector3.ZERO)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.1
	cam.far = 30.0
	cam.position = Vector3(0, 1.05, 4.6)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.86, 0))     # same framing for both, so the height difference reads
	cam.current = true
	t.holder = Node3D.new()
	t.holder.scale = Vector3.ONE * B.scale
	world.add_child(t.holder)
	var ps: PackedScene = load(B.file)
	var m: Node3D = ps.instantiate()
	t.holder.add_child(m)
	t.prop = m.find_child("propeller", true, false) as Node3D
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.62
	cyl.height = 0.002
	cyl.radial_segments = 40
	disc.mesh = cyl
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0, 0, 0, 0.35)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = mt
	disc.position.y = 0.002
	world.add_child(disc)
	t.rect = TextureRect.new()
	t.rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.rect.texture = t.vp.get_texture()
	add_child(t.rect)
	return t


var _r_prog := Rect2()
var _r_tommy := Rect2()


func place(r_prog: Rect2, r_tommy: Rect2) -> void:
	_r_prog = r_prog
	_r_tommy = r_tommy
	_apply_rects()


func _apply_rects() -> void:
	for t in _views:
		var r := _r_prog if t.id == "prog" else _r_tommy
		t.rect.position = r.position + Vector2(10.0, 8.0)
		t.rect.size = Vector2(r.size.x - 20.0, 190.0)
		var sz := Vector2i(maxi(16, int(t.rect.size.x)), 190)
		if t.vp.size != sz:
			t.vp.size = sz


func frame(dt: float, t: float, on: bool) -> void:
	if not on:
		return
	if not _views.is_empty():
		_apply_rects()
	for v in _views:
		var sel := Game.char_pick == v.id
		v.holder.rotation.y = 0.45 * sin(t * 0.6 + v.ph) + (0.0 if sel else 0.3)
		v.holder.position.y = 0.012 * absf(sin(t * 2.4)) if sel else 0.0
		if v.prop != null:
			v.prop.rotation.y += dt * (9.0 if sel else 2.5)


func pick(id: String, quiet: bool = false) -> void:
	if not Builds.BUILDS.has(id) or Game.started:
		return
	Game.char_pick = id
	focus = id
	Game.ui.prefs_save()
	if not quiet:
		CrtTheme.sfx("uiMove")


## Pad / arrows move the highlight only; `confirm` makes it the pick.
func step(d: int) -> void:
	if Game.started:
		return
	var ids: Array = Builds.BUILDS.keys()
	var k := ids.find(focus)
	focus = ids[posmod(k + d, ids.size())]
	CrtTheme.sfx("uiMove")


func confirm() -> void:
	pick(focus)
