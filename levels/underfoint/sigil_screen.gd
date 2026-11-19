class_name SigilScreen
extends SubViewport
## What is on the glass of the Sigil's television in its cell (levels/underfoint/uf_throne.gd): the face (ui/sigil_face.gd) in a small viewport the set's screen shows.
## It is also the Sigil's body as far as talk goes: the dialogue system's actor (set_talk, look_at_point, mouth_world).

var face: SigilFace
var at := Vector3.ZERO      # where the set's glass is, for the voice and for the eyes


func _init() -> void:
	size = Vector2i(320, 240)
	transparent_bg = false
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	face = SigilFace.new()
	face.size = Vector2(320, 240)
	add_child(face)


func set_talk(v: bool) -> void:
	face.speaking = 1.0 if v else 0.0


## (the glass faces south: your right is its left)
func look_at_point(x: float, _z: float) -> void:
	face.look = clampf((at.x - x) / 5.0, -1.0, 1.0)


func mouth_world() -> Vector3:
	return at
