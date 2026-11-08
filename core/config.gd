extends Node
## Autoload Config: central tuning, ported value for value from CONFIG in the three.js game (index.html config.js).
## A level that changes one of these for itself lists it in its `config_overrides`; Game restores defaults on unload.

# --- input ---
var deadzone := 0.15          # radial deadzone (both sticks)
var move_exp := 1.3           # left stick response curve
var cam_exp := 1.8            # right stick response curve
var invert_y := false         # right stick Y invert
var pad_look_speed := 3.4     # rad/s at full right-stick deflection
var pad_look_ease := 45.0     # spring rate of the stick's turn speed; off while aiming; the mouse is never eased
var mouse_sens := 0.0023      # rad per pixel

# --- ground ---
var run_speed := 6.2
var ground_accel := 44.0      # ~0.14s to full run
var ground_decel := 62.0      # ~0.10s brake
var turn_boost := 1.0         # extra accel when changing direction
var land_drag := 0.3          # fraction of horizontal speed lost on a hard landing
var strafe_speed_mult := 1.0
var sprint_speed_mult := 1.4
var sprint_fov := 7.0
var crouch_speed_mult := 0.22
var turn_k := 14.0            # body turn (exp smoothing rate)
var strafe_turn_k := 30.0
var air_turn_k := 14.0
var start_boost := 1.5        # extra accel multiplier launching from a standstill
var strafe_accel_mult := 1.25
var turn_snap := 0.6          # body turns up to (1+turn_snap)x faster on big heading changes
var air_turn_boost := 0.6
var apex_grav := 0.8          # gravity multiplier near the jump apex
var apex_vel := 2.5           # |vy| below this counts as the apex

# --- reload ---
var reload_speed := 1.0
var auto_reload := 1
var aim_hold := 0.3
var aim_hold_semi := 0.3
var aim_hold_max := 1.0
var reload_tilt := 1.0

# --- jumping ---
var jump_vel := 11.2
var double_jump_mult := 1.0
var jet_fuel := 0.0           # jetpack seconds of thrust per airtime (0 = not equipped; a level turns it on)
var jet_boost := 4.5
var jet_accel := 62.0
var jet_max_rise := 7.5
var pole_swing := 0           # 1 = hands grab horizontal poles in world.poles (a level turns it on)
var pole_accel := 9.0
var pole_kick := 8.0
var pole_launch := 1.3
var pole_com := 1.0
var pole_shimmy := 2.4
var wall_run := 0             # 1 = run along walls (a level turns it on)
var wall_run_time := 1.5
var wall_run_min := 4.0
var wall_run_speed := 9.5
var wall_kick := 7.5
var jet_air := 1.25
var high_jump_mult := 1.75
var jump_cut_vel := 5.5
var gravity_up := 36.0
var gravity_down := 60.0
var max_fall := 42.0
var air_accel := 26.0
var air_drag := 4.0
var coyote := 0.16
var jump_buffer := 0.16
var flip_dur := 0.62
var slam_windup := 0.16
var slam_speed := 27.0
var slam_radius := 3.4
var slam_dmg := 62.0
var land_dur := 0.44
var aerial_flip_dur := 0.6

# --- body ---
var height := 1.8
var crouch_height := 1.1
var radius := 0.36
var step_up := 0.42
var step_down := 0.5

# --- ledge grab ---
var ledge_min := 1.35
var ledge_max := 2.15
var hang_drop := 2.05
var hang_time := 0.22
var pull_time := 0.62
var hang_twist := 1.5

# --- swimming ---
var swim_speed := 3.3
var swim_sprint := 5.4
var swim_accel := 7.0
var swim_drag := 2.4
var swim_turn_k := 6.0
var swim_float := 1.35
var swim_hop := 4.2
var swim_climb := 1.9

# --- camera ---
var fov := 62.0
var first_person := false
var cam_dist := 5.6
var cam_dist_strafe := 4.3
var cam_height := 1.45
var cam_pitch_min := -1.3
var cam_pitch_max := 1.25
var cam_pitch_default := 0.30
var cam_follow_k := 2.1
var cam_pos_k := 14.0
var cam_vert_k := 9.0
var cam_vert_air_k := 2.0
var cam_strafe_k := 28.0
var cam_dist_aim := 3.4
var cam_shoulder := 0.8
var ads_dist := 2.35
var ads_shoulder := 1.25
var ads_fov_cut := 24.0
var ads_speed_mult := 0.28
var ads_spread := 0.35
var aim_fov_cut := 9.0
var cam_manual_hold := 0.9
var cam_follow_ramp := 0.8
var cam_follow_delay := 0.18
var cam_steady_rate := 3.0
var cam_follow_side := 0.3
var cam_follow_max := 2.2
var cam_follow_smooth := 8.0
var cam_follow_air := 0.4
var cam_lead := 0.1
var cam_lead_k := 4.0
var cam_land_dip := 0.008
var cam_jump_band := 0.4
var cam_run_at_dist := 0.8
var cam_follow_leash := 1.0
var cam_leash_smooth := 5.0
var cam_follow_leash_room := 0.5
# camera collision
var cam_probe := 0.22
var cam_wall_gap := 0.28
var cam_clear_in_k := 30.0
var cam_clear_out_k := 2.5
var cam_clear_hold := 0.3
var cam_lift_max := 1.2
var cam_swing_max := 3.0
var cam_shake := 0.6

# --- enemies and player damage (JS enemy.js: Object.assign(CONFIG, ...)) ---
var ai_alert_radius := 16.0
var ai_search_time := 7.0
var ai_lose_time := 2.5
var ai_sight := 30.0
var ai_notice_range := 0.0
var ai_damage := 1.0
var ai_respawn := 25.0
var ai_stagger_dmg := 40.0
var ai_max_voices := 2
var ai_melee_slots := 2
var ai_shot_slots := 2
var ai_debug := 0
var ai_freeze := 0
var player_regen := 6.0
var player_regen_delay := 5.0

var _defaults := {}


func _ready() -> void:
	for p: Dictionary in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p.name).begins_with("_"):
			_defaults[p.name] = get(p.name)


## Put every tunable back to its shipped value (a level changed some for itself).
func restore_defaults() -> void:
	for k: String in _defaults:
		set(k, _defaults[k])
