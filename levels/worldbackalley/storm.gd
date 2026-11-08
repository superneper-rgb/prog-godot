class_name Storm
extends RefCounted
## Thunderstorm for the BACK ALLEY (JS levels/worldbackalley/storm.js): lightning strikes (jagged bolts down the street, sheet lightning in the clouds, overhead strikes that white the screen out), thunder (a crack for close strikes, a rolling low rumble that arrives later the further away the strike was), wind gusts that shove the rain sideways and howl, and rain splashing on the street around the camera.
## The rain itself is the city's rain (CityLife), made heavier by the level's storm settings; the gusts change its slant and opacity on the fly.
## The thunder and the wind were rendered from the JS synth code (tools/export/render-sfx.mjs, keys storm.*), so their random rolls are in the takes.

const WHITE_SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float opacity = 0.0;
void fragment() {
	// radial-gradient(ellipse at 50% 20%, #f4f8ff, #b9c8ef 70%, #8090c0), mix-blend-mode: screen (premultiplied, its alpha taking the frame down as much as it adds)
	float d = clamp(length((UV - vec2(0.5, 0.2)) * vec2(1.0, 1.0)) / 0.95, 0.0, 1.0);
	vec3 c = d < 0.7 ? mix(vec3(0.957, 0.973, 1.0), vec3(0.725, 0.784, 0.937), d / 0.7) : mix(vec3(0.725, 0.784, 0.937), vec3(0.502, 0.565, 0.753), (d - 0.7) / 0.3);
	c *= opacity;
	COLOR = vec4(c, max(c.r, max(c.g, c.b)));
}
"""

var level: ExportedLevel
var city: CityLife
var view: View
var sun_base_i := 0.0
var sun_base_c := Color.WHITE
var hemi_base := 1.0
var fog_base := Color.BLACK
var fog_d := 0.0
const SUN_FLASH := Color8(0xc6, 0xd6, 0xff)
const FOG_FLASH := Color8(0x56, 0x62, 0x7c)
var base0_slant := 0.0
var base0_opacity := 0.0
var bolt: MeshInstance3D
var bolt_mat: StandardMaterial3D
var cloud: MeshInstance3D
var cloud_mat: StandardMaterial3D
var white_mat: ShaderMaterial
var sky_mats: Array[StandardMaterial3D] = []

var t := 0.0
var next := randf_range(1.5, 3.0)
var sheet_next := randf_range(2.0, 4.0)
var gust_next := randf_range(2.0, 5.0)
var strike_t := -99.0
var pulses: Array[Vector3] = []     # x: start, y: peak, z: decay
var gust := 0.0
var gust_t := -99.0
var gust_len := 4.0
var white_k := 0.0
var shake_k := 0.0
var _last_f := -1.0
var _queue: Array = []              # [time, sound]: the thunder arrives after the flash
var _on := true


func _init(p_level: ExportedLevel, p_city: CityLife) -> void:
	level = p_level
	city = p_city
	view = Game.view
	# the flash lights the scene through the view's own sun (no extra directional light: that would be one more light in every lit shader, all the time)
	sun_base_i = view.sun_intensity
	sun_base_c = view.sun_color
	hemi_base = view.hemi_intensity
	fog_base = view.fog_color
	fog_d = view.fog_density
	base0_slant = city.S.slant
	base0_opacity = city.S.opacity
	bolt_mat = StandardMaterial3D.new()
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bolt_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt_mat.disable_fog = true
	bolt_mat.albedo_color = Color8(0xee, 0xf4, 0xff, 0)
	bolt = MeshInstance3D.new()
	bolt.name = "StormBolt"
	bolt.extra_cull_margin = 16384.0
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false
	level.add_child(bolt)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	cloud_mat = bolt_mat.duplicate()
	cloud_mat.albedo_texture = gt
	cloud_mat.albedo_color = Color8(0xb8, 0xc8, 0xff, 0)
	cloud_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_mat.billboard_keep_scale = true
	var q := QuadMesh.new()
	q.size = Vector2(150.0, 70.0)
	cloud = MeshInstance3D.new()
	cloud.name = "StormCloud"
	cloud.mesh = q
	cloud.material_override = cloud_mat
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.visible = false
	level.add_child(cloud)
	# white-out for overhead strikes: the whole screen goes blue-white for a frame or two
	var layer := CanvasLayer.new()
	layer.name = "StormWhite"
	layer.layer = 0
	level.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = WHITE_SHADER
	white_mat = ShaderMaterial.new()
	white_mat.shader = sh
	rect.material = white_mat
	layer.add_child(rect)
	_build_splashes()
	for o: Node3D in level.node_named("HubSky"):
		for c: Node in o.get_children():
			var mi := c as MeshInstance3D
			if mi != null and mi.mesh != null:
				var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
				if m != null:
					sky_mats.append(m)
	if sky_mats.is_empty():
		push_warning("Storm: the city's sky has no plain material to flash")


## 700 specks, each its own quad: the shader runs their lives.
func _build_splashes() -> void:
	const SPL := 700
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	v.resize(SPL * 6)
	uv.resize(SPL * 6)
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in SPL:
		for c in 6:
			v[i * 6 + c] = Vector3(float(i) * 0.137 + 1.0, 0.0, 0.0)
			uv[i * 6 + c] = corners[c]
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://levels/shaders/storm_splash.gdshader")
	m.surface_set_material(0, sm)
	var mi := MeshInstance3D.new()
	mi.name = "StormSplashes"
	mi.mesh = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mi)


## one jagged ribbon (in the XY plane, so it faces a camera looking along the street) from `from` down to to_y
static func _bolt_points(x0: float, y0: float, z: float, to_y: float, wander: float) -> PackedVector3Array:
	var pts := PackedVector3Array([Vector3(x0, y0, z)])
	var x := x0
	var y := y0
	while y > to_y:
		y -= randf_range(4.0, 11.0)
		x += randf_range(-wander, wander)
		pts.append(Vector3(x, maxf(to_y, y), z))
	return pts


static func _ribbon(pts: PackedVector3Array, w: float, out: PackedVector3Array) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dx := b.x - a.x
		var dy := b.y - a.y
		var l := hypot_(dx, dy)
		if l == 0.0:
			l = 1.0
		var nx := -dy / l * w / 2.0
		var ny := dx / l * w / 2.0
		out.append_array([Vector3(a.x - nx, a.y - ny, a.z), Vector3(a.x + nx, a.y + ny, a.z), Vector3(b.x + nx, b.y + ny, b.z), Vector3(a.x - nx, a.y - ny, a.z), Vector3(b.x + nx, b.y + ny, b.z), Vector3(b.x - nx, b.y - ny, b.z)])


static func hypot_(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


func _thunder(close: bool, delay: float, overhead: bool) -> void:
	_queue.append([t + delay, "storm.thunder.overhead" if overhead else ("storm.thunder.close" if close else "storm.thunder.far")])


func _wind_gust(p_len: float) -> void:
	if Game.sfx != null:
		Game.sfx.play("storm.wind.%d" % clampi(roundi(p_len), 3, 6))


## o: { close, overhead, z, x } (all optional; cutscenes force a strike where the camera looks)
func strike(cam: Vector3, o: Dictionary = {}) -> void:
	var overhead: bool = o.get("overhead", randf() < 0.18)
	var close: bool = overhead or o.get("close", randf() < 0.45)
	var dir := 1.0 if randf() < 0.72 else -1.0
	var z: float = o.get("z", cam.z + dir * (randf_range(45.0, 70.0) if overhead else randf_range(80.0 if close else 130.0, 120.0 if close else 190.0)))
	var x: float = o.get("x", cam.x + randf_range(-30.0, 30.0))
	var top := randf_range(120.0, 145.0)
	var main := _bolt_points(x, top, z, randf_range(4.0, 14.0) if overhead else randf_range(18.0, 40.0), 6.0)
	var pos := PackedVector3Array()
	_ribbon(main, 3.4 if overhead else (2.4 if close else 1.6), pos)
	var forks := 2 + randi() % (5 if overhead else 3)      # forks off the main channel
	for b in forks:
		var from := main[1 + randi() % maxi(1, main.size() - 3)]
		_ribbon(_bolt_points(from.x, from.y, z, from.y - randf_range(15.0, 45.0), 8.0), 0.8, pos)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, bolt_mat)
	bolt.mesh = m
	cloud.global_position = Vector3(x, top + 6.0, z)
	strike_t = t
	pulses.clear()
	var peak := 1.4 if overhead else (1.0 if close else 0.6)
	pulses.append(Vector3(t, peak, 8.0))
	for i in 2 + randi() % 4:
		pulses.append(Vector3(t + randf_range(0.05, 0.45), peak * randf_range(0.45, 1.0), randf_range(7.0, 13.0)))
	if overhead:
		white_k = 1.0
		shake_k = 0.8
	_thunder(close, randf_range(0.02, 0.12) if overhead else (randf_range(0.15, 0.5) if close else randf_range(1.3, 3.2)), overhead)
	next = t + (randf_range(6.0, 11.0) if overhead else randf_range(4.0 if close else 2.5, 9.0))
	if randf() < 0.25 and not overhead:
		next = t + randf_range(0.7, 1.4)                   # sometimes a second one right behind it


## a flicker inside the clouds: no bolt, a dim flash and a far rumble
func _sheet() -> void:
	pulses.append(Vector3(t, randf_range(0.18, 0.35), 5.0))
	pulses.append(Vector3(t + randf_range(0.1, 0.3), randf_range(0.12, 0.3), 6.0))
	_thunder(false, randf_range(2.5, 4.5), false)
	sheet_next = t + randf_range(3.0, 7.0)


func flash() -> float:
	var f := 0.0
	for p: Vector3 in pulses:
		if t >= p.x:
			f += p.y * exp(-(t - p.x) * p.z)
	return f


func update(dt: float, cam: Vector3) -> void:
	if dt <= 0.0:
		return
	t += dt
	if t >= next:
		strike(cam)
	if t >= sheet_next:
		_sheet()
	if t >= gust_next:
		gust_t = t
		gust_len = randf_range(3.0, 6.0)
		_wind_gust(gust_len)
		gust_next = t + gust_len + randf_range(2.0, 6.0)
	gust = sin(PI * (t - gust_t) / gust_len) if t - gust_t < gust_len else 0.0
	city.set_rain(base0_slant + gust * 0.45, base0_opacity + gust * 0.12)      # the gust leans the rain over and thickens it
	var i := _queue.size() - 1
	while i >= 0:
		if t >= float(_queue[i][0]):
			if Game.sfx != null:
				Game.sfx.play(String(_queue[i][1]))
			_queue.remove_at(i)
		i -= 1
	var f := minf(1.6, flash())
	var f1 := minf(1.0, f)
	if f > 0.0005 or _last_f != 0.0:
		_last_f = f if f > 0.0005 else 0.0
		view.set_sun(_mix(sun_base_c, SUN_FLASH, f1), sun_base_i + f * 6.0)
		view.set_hemi(view.hemi_color, view.hemi_ground, hemi_base + f * 1.6)
		var s := 1.0 + f * 3.4
		for m: StandardMaterial3D in sky_mats:
			m.albedo_color = Color(s, s, s, m.albedo_color.a)
	if fog_d > 0.0:
		view.set_fog_exp2(_mix(fog_base, FOG_FLASH, f1), fog_d * (1.0 + 0.25 * gust))
	var age := t - strike_t
	var show := age < 0.5 and f > 0.08
	bolt.visible = show
	cloud.visible = show
	if show:
		bolt_mat.albedo_color.a = minf(1.0, f * 1.3) * (1.0 if randf() > 0.15 else 0.4)
		cloud_mat.albedo_color.a = minf(0.6, f * 0.5)
	white_k = maxf(0.0, white_k - dt * 5.0)
	white_mat.set_shader_parameter(&"opacity", white_k * (0.85 if randf() > 0.3 else 0.4))
	if shake_k > 0.0 and age > 0.05:
		if Game.fx != null:
			Game.fx.shake = maxf(Game.fx.shake, shake_k)
		shake_k = 0.0


## three.js Color.lerp works on linear values; Godot's are stored encoded.
static func _mix(a: Color, b: Color, k: float) -> Color:
	return a.srgb_to_linear().lerp(b.srgb_to_linear(), k).linear_to_srgb()
