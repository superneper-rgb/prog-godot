class_name Level
extends Node3D
## Base of every level. Everything the level makes goes under this node, so freeing it frees the level; World is disposed by Game.

var id := ""
var world: World
var portals: Array = []      # its doors: {id, label, x, z, radius, to, spawn_at, active, before} (core/doors.gd)
var actions: Array = []      # its own X interactions: {x, z, label, active(player), run()}
var no_fight := false        # nothing here can be fought: no fire, aim or attack reach combat (JS DEAD AIR patches Combat.update for this)


## Play has begun, or the player has come through a door into a level already in play: start its music (JS music.play()).
func start_music() -> void:
	pass


## Make colliders and visuals.
func build() -> void:
	pass


## JS LV.cityAmbience, LV.storm: the street's ambient sound plays here, and which rain.
var city_ambience := false
var storm := false


## The player has been placed.
func on_enter() -> void:
	pass


## About to be freed.
func on_exit() -> void:
	pass


## Once per frame, after the player has moved.
func tick(_dt: float) -> void:
	pass


## Once per frame, when the camera has its final place (JS CityView.update(camPos)). real_dt: not slowed or stopped by a pause.
func camera_placed(_cam: Vector3, _real_dt: float) -> void:
	pass


## This frame's combat events, for a level with bystanders (the hub's crowd). Dictionaries as Combat pushes them.
func combat_events(_events: Array) -> void:
	pass


## Move world.spawn for a named arrival point.
func apply_spawn(_at: String) -> void:
	pass
