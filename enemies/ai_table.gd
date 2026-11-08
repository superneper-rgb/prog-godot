class_name AiTable
extends RefCounted
## The numbers a Robot runs on: a copy of the shared AI table that an enemy kind can change for itself (JS: a kind swaps its numbers into the shared AI object around super.update). Every plain robot shares DEFAULT.

static var DEFAULT := AiTable.new()

var hp := 60.0
var r := 0.52
var h := 2.05
var step := 0.42
var walk := 1.5
var run := 4.4
var accel := 13.0
var alert_delay := 0.55
var reach := 2.15
var m_wind := 0.66
var m_act := 0.34
var m_hit := 0.12
var m_rec := 0.95
var m_dmg := 22.0
var s_wind := 0.9
var s_act := 0.16
var s_rec := 1.4
var s_dmg := 9.0
var s_speed := 21.0
var s_min := 5.5
var s_max := 26.0
var s_cd := 2.8
var flinch := 0.3
var flinch_cd := 0.3
var stagger := 0.95
var stagger_immune := 1.7
var poise_max := 70.0
var poise_regen := 30.0
var voice_range := 30.0
