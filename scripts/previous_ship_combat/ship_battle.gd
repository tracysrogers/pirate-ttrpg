extends Node
class_name LegacyShipBattle

signal battle_updated(text: String)
signal boarding_started(attacker_is_player: bool)
signal battle_finished(player_won: bool, disengaged: bool)

enum Phase {
	PLANNING,
	RESOLVED,
	MOVE_ANIM
}

enum SailSetting {
	SLOW,
	BATTLE,
	FULL
}

var phase: Phase = Phase.PLANNING
var player_hull: int = 16
var enemy_hull: int = 16
var player_crew: int = 24
var enemy_crew: int = 24
var player_has_boarding_advantage: bool = false
var enemy_has_boarding_advantage: bool = false
var player_ship_class: String = "Sloop"
var enemy_ship_class: String = "Brig"
var player_position: Vector2 = Vector2(0.26, 0.62)
var enemy_position: Vector2 = Vector2(0.74, 0.38)
var player_heading_deg: float = 0.0
var enemy_heading_deg: float = 180.0
var wind_direction_deg: float = 90.0
var wind_speed_m_s: float = 6.0
var combat_cols: int = 120
var combat_rows: int = 70
var player_cell: Vector2i = Vector2i(16, 13)
var enemy_cell: Vector2i = Vector2i(27, 11)
var player_cell_pos: Vector2 = Vector2(16.0, 13.0)
var enemy_cell_pos: Vector2 = Vector2(27.0, 11.0)
var player_heading_idx: int = 2
var enemy_heading_idx: int = 6
var player_move_points: int = 0
var enemy_move_points: int = 0
var player_navigator_skill: int = 2
var enemy_navigator_skill: int = 2
var enemy_behavior: String = "engage"
var player_sail_setting: SailSetting = SailSetting.BATTLE
var player_ordered_sail_setting: SailSetting = SailSetting.BATTLE
var enemy_sail_setting: SailSetting = SailSetting.BATTLE
var player_movement_plotted: bool = false
var player_plan_end_pos: Vector2 = Vector2.ZERO
var player_plan_end_heading: float = 0.0
var player_plan_board: bool = false
var player_turn_start_cell_pos: Vector2 = Vector2.ZERO
## Straight squares in current heading; persists across legs and turns until heading changes.
var player_run_cells: int = 0
var player_run_heading_idx: int = 0
var enemy_run_cells: int = 0
var enemy_run_heading_idx: int = 0
var enemy_plan_end_pos: Vector2 = Vector2.ZERO
var enemy_plan_end_heading: float = 0.0
var enemy_plan_volley_when_in_range: bool = false
var enemy_plan_board: bool = false
## Broadside batteries: 0 = port, 1 = starboard (chase/raking nominally use port for bookkeeping).
var player_port_cannon_reload_turns_remaining: int = 0
var player_starboard_cannon_reload_turns_remaining: int = 0
var enemy_port_cannon_reload_turns_remaining: int = 0
var enemy_starboard_cannon_reload_turns_remaining: int = 0
var player_hull_battle_start: int = 16
var enemy_hull_battle_start: int = 16
var player_crew_battle_start: int = 24
var enemy_crew_battle_start: int = 24
var _completed_wego_rounds: int = 0
## Full terminal state chosen for the player (cell, mp, pos, heading); used for path playback.
var player_plan_terminal: Dictionary = {}
var enemy_plan_terminal: Dictionary = {}
var player_plan_preview_path: Array[Dictionary] = []
var player_round_path: Array[Dictionary] = []
var enemy_round_path: Array[Dictionary] = []
var _move_anim_elapsed: float = 0.0
## During MOVE_ANIM: "player" then "enemy" — turn-based, not simultaneous.
var _move_anim_actor: String = ""
var _player_movement_preview_cache_frame: int = -1
var _player_movement_preview_cache: Dictionary = {}
var _gun_range_overlay_cache_key: String = ""
var _gun_range_overlay_cache: Array[Dictionary] = []
var _sail_movement_hints_cache_frame: int = -1
var _sail_movement_hints_cache_key: String = ""
var _sail_movement_hints_cache: Dictionary = {}
var _player_move_options_cache_frame: int = -1
var _player_move_options_cache_key: String = ""
var _player_move_options_cache: bool = false
const MOVE_ANIM_DURATION_SEC: float = 1.35
var hazard_cells: Dictionary = {}
const COMBAT_GRID_FEET: float = 12.5
## Straight run at FULL sail should cover this many hull lengths (grid cells along track).
const STRAIGHT_HULL_LENGTHS_AT_FULL: float = 3.0
const COMBAT_MOVE_SCALE_MIN: float = 0.35
const COMBAT_MOVE_SCALE_MAX: float = 1.95
const TURN_STEP_DEG: float = 45.0
const DISENGAGE_MIN_CELL_DIST: float = 52.0
const CANNON_RELOAD_BASE_ROUNDS: int = 3
const CANNON_RELOAD_MAX_ROUNDS: int = 10
const CANNON_RELOAD_HULL_STRAIN_MAX: float = 2.35
const CANNON_RELOAD_CREW_STRAIN_MAX: float = 1.85
const CANNON_RELOAD_FATIGUE_MAX: float = 1.55
const CANNON_RELOAD_FATIGUE_PER_ROUND: float = 0.024
## Naval gunnery uses this cell size for range / accuracy (historical stand-in; crew skill later).
const COMBAT_CELL_YARDS: float = 30.0
## Beyond this, batteries are treated as out of effective range (no volley / no gun-range cell).
const CANNON_MAX_EFFECTIVE_RANGE_YARDS: float = 1500.0
## Placeholder until crew / officer stats feed gunnery (multiplier on per-gun hit chance).
const GUNNERY_BASELINE_MULT: float = 1.0

func start_battle(context: Dictionary = {}) -> void:
	phase = Phase.PLANNING
	player_ship_class = str(context.get("player_ship_class", "Sloop"))
	enemy_ship_class = str(context.get("enemy_ship_class", "Brig"))

	var player_stats: Dictionary = _ship_stats(player_ship_class)
	var enemy_stats: Dictionary = _ship_stats(enemy_ship_class)
	var hull_max: int = int(player_stats.get("hull", 16))
	var enemy_hull_max: int = int(enemy_stats.get("hull", 16))
	player_hull = clampi(int(context.get("player_hull", hull_max)), 1, hull_max)
	enemy_hull = enemy_hull_max
	player_crew = maxi(1, int(context.get("player_crew", player_stats.get("crew", 24))))
	enemy_crew = int(enemy_stats.get("crew", 24))
	player_hull_battle_start = player_hull
	enemy_hull_battle_start = enemy_hull
	player_crew_battle_start = player_crew
	enemy_crew_battle_start = enemy_crew
	_completed_wego_rounds = 0
	player_has_boarding_advantage = false
	enemy_has_boarding_advantage = false
	player_heading_deg = _vector_to_bearing_deg(context.get("player_heading", Vector2.RIGHT))
	enemy_heading_deg = _vector_to_bearing_deg(context.get("enemy_heading", Vector2.LEFT))
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	if bool(context.get("skip_opening_spacing", false)):
		player_cell_pos = Vector2(float(context.get("player_cell_x", 16.0)), float(context.get("player_cell_y", 13.0)))
		enemy_cell_pos = Vector2(float(context.get("enemy_cell_x", 27.0)), float(context.get("enemy_cell_y", 11.0)))
	else:
		_layout_opening_positions_at_cannon_range()
	player_navigator_skill = clampi(int(context.get("player_navigator_skill", 2)), 0, 5)
	enemy_navigator_skill = clampi(int(context.get("enemy_navigator_skill", 2)), 0, 5)
	var wind_variant: Variant = context.get("wind", {"direction_deg": 90.0, "speed_m_s": 6.0})
	var wind_data: Dictionary = (wind_variant as Dictionary) if wind_variant is Dictionary else {"direction_deg": 90.0, "speed_m_s": 6.0}
	wind_direction_deg = float(wind_data.get("direction_deg", 90.0))
	wind_speed_m_s = float(wind_data.get("speed_m_s", 6.0))
	enemy_behavior = "engage" if bool(context.get("enemy_wants_pursuit", true)) else "escape"
	player_port_cannon_reload_turns_remaining = 0
	player_starboard_cannon_reload_turns_remaining = 0
	enemy_port_cannon_reload_turns_remaining = 0
	enemy_starboard_cannon_reload_turns_remaining = 0
	_generate_hazards(bool(context.get("near_land", false)))
	_sync_pose_from_positions()
	player_sail_setting = SailSetting.BATTLE
	player_ordered_sail_setting = SailSetting.BATTLE
	enemy_sail_setting = SailSetting.BATTLE
	_begin_planning_round()
	emit_signal(
		"battle_updated",
		"Enemy %s sighted. You command a %s. Your turn: order sails (next turn), plot moves (Enter), highlight Port/Starboard, Fire Cannons when ready, E ends turn. [/] sails. X break off." % [
			enemy_ship_class,
			player_ship_class
		]
	)

func set_player_planned_move_cell(target_cell: Vector2i) -> bool:
	if phase != Phase.PLANNING:
		return false
	var best: Dictionary = {}
	for opt in get_player_move_options():
		if opt.get("cell", Vector2i(-1, -1)) != target_cell:
			continue
		if best.is_empty() or _better_player_stop_state_for_cell(opt, best):
			best = opt
	if best.is_empty():
		return false
	return _apply_player_planned_move_state(best)

func _apply_player_planned_move_state(best: Dictionary) -> bool:
	_invalidate_player_movement_preview_cache()
	player_plan_end_pos = best["pos"] as Vector2
	player_plan_end_heading = float(best["heading_deg"])
	player_movement_plotted = true
	player_plan_terminal = best.duplicate(true)
	player_plan_preview_path = _reconstruct_path_to_terminal(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_ship_class,
		player_cell,
		player_sail_setting,
		player_plan_terminal,
		player_run_cells
	)
	_ensure_path_has_endpoints(
		player_plan_preview_path,
		player_cell_pos,
		player_heading_deg,
		player_plan_end_pos,
		player_plan_end_heading
	)
	return true

func player_can_order_battery_fire(battery: int) -> bool:
	if phase != Phase.PLANNING:
		return false
	if battery == 0:
		return player_port_cannon_reload_turns_remaining <= 0
	return player_starboard_cannon_reload_turns_remaining <= 0

func player_attempt_boarding() -> void:
	if phase != Phase.PLANNING:
		return
	if can_player_board_now():
		_try_player_grapple()
		return
	if player_plan_board:
		player_plan_board = false
		emit_signal("battle_updated", "Grapple order cancelled.")
		return
	player_plan_board = true
	emit_signal("battle_updated", "Grapple order set — end your turn adjacent to hook the enemy.")

func can_player_board_now() -> bool:
	if phase != Phase.PLANNING:
		return false
	return (
		_ship_footprint_distance(
			player_cell_pos,
			player_heading_deg,
			player_ship_class,
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class
		)
		<= 1
	)

func get_ship_separation() -> float:
	return player_cell_pos.distance_to(enemy_cell_pos)

func can_player_disengage() -> bool:
	if phase != Phase.PLANNING:
		return false
	return get_ship_separation() >= DISENGAGE_MIN_CELL_DIST

func player_disengage() -> void:
	if phase != Phase.PLANNING:
		return
	if not can_player_disengage():
		emit_signal("battle_updated", "Enemy is still too close to break off safely.")
		return
	_finish_mutual_disengage(true)

func _finish_mutual_disengage(player_initiated: bool) -> void:
	if phase == Phase.RESOLVED:
		return
	phase = Phase.RESOLVED
	var msg: String
	if player_initiated:
		msg = "You haul off and break contact; the enemy does not close again this day."
	else:
		msg = "Distance opens between the squadrons; the engagement is broken off."
	emit_signal("battle_updated", msg)
	emit_signal("battle_finished", false, true)

func can_player_execute_move_leg() -> bool:
	if phase != Phase.PLANNING:
		return false
	if not player_movement_plotted:
		return false
	if not _player_plan_is_valid_state():
		return false
	var leg_mp_remaining: int = int(player_plan_terminal.get("mp", -1))
	if leg_mp_remaining < 0:
		return false
	var spent_mp: int = player_move_points - leg_mp_remaining
	var moved_pose: bool = (
		player_plan_end_pos.distance_to(player_cell_pos) > 0.05
		or absf(_angle_delta_deg(player_plan_end_heading, player_heading_deg)) > 0.5
	)
	return spent_mp > 0 or moved_pose

func _player_turn_movement_distance_cells() -> float:
	return player_turn_start_cell_pos.distance_to(player_cell_pos)

func _player_minimum_turn_movement_cells() -> float:
	var hull_len: float = float(max(1, get_ship_length_cells(player_ship_class)))
	var sail_mul: float = _sail_forward_multiplier(player_sail_setting)
	return STRAIGHT_HULL_LENGTHS_AT_FULL * hull_len * sail_mul

func _player_has_remaining_move_options() -> bool:
	if phase != Phase.PLANNING:
		return false
	if player_move_points <= 0:
		return false
	var cache_key: String = "%.3f,%.3f|%.2f|%d|%d" % [
		player_cell_pos.x, player_cell_pos.y, player_heading_deg, player_move_points, int(player_sail_setting)
	]
	var frame: int = Engine.get_process_frames()
	if frame == _player_move_options_cache_frame and cache_key == _player_move_options_cache_key:
		return _player_move_options_cache
	for opt in get_player_move_options():
		if opt is Dictionary:
			_player_move_options_cache_frame = frame
			_player_move_options_cache_key = cache_key
			_player_move_options_cache = true
			return true
	_player_move_options_cache_frame = frame
	_player_move_options_cache_key = cache_key
	_player_move_options_cache = false
	return false

func can_player_end_turn() -> bool:
	if phase != Phase.PLANNING:
		return false
	if _player_turn_movement_distance_cells() >= _player_minimum_turn_movement_cells():
		return true
	return not _player_has_remaining_move_options()

func get_player_end_turn_blocked_reason() -> String:
	if phase != Phase.PLANNING:
		return "Not your planning phase."
	var need: float = _player_minimum_turn_movement_cells()
	var have: float = _player_turn_movement_distance_cells()
	if _player_has_remaining_move_options():
		return "Move farther this turn first (%.1f / %.1f cells)." % [have, need]
	return "Finish moving this turn before ending."

func player_execute_move_leg() -> void:
	if phase != Phase.PLANNING:
		return
	if not can_player_execute_move_leg():
		emit_signal(
			"battle_updated",
			"Pick a reachable stop (directional chevron), then press Enter to move that leg."
		)
		return
	_cache_player_round_path()
	if not _leg_path_has_motion():
		_finish_player_move_leg_without_animation()
		return
	_move_anim_actor = "player"
	phase = Phase.MOVE_ANIM
	_move_anim_elapsed = 0.0
	var remaining: int = int(player_plan_terminal.get("mp", 0))
	emit_signal("battle_updated", "Your squadron moves (%d MP left after)." % remaining)

func player_end_turn() -> void:
	if (phase as Phase) != Phase.PLANNING:
		return
	if get_ship_separation() >= DISENGAGE_MIN_CELL_DIST and enemy_behavior == "escape":
		_finish_mutual_disengage(false)
		return
	if not can_player_end_turn():
		emit_signal("battle_updated", get_player_end_turn_blocked_reason())
		return
	_clear_player_leg_plan()
	_advance_cannon_reload_for_side(true)
	if _resolve_player_end_turn_effects():
		return
	_start_enemy_turn()

func player_commit_orders() -> void:
	player_end_turn()

func _score_enemy_destination_cell(cell: Vector2i, player_goal: Vector2) -> float:
	var dx: float = float(cell.x) - player_goal.x
	var dy: float = float(cell.y) - player_goal.y
	var dist: float = sqrt(dx * dx + dy * dy)
	if enemy_behavior == "escape":
		return dist + randf() * 0.4
	return -dist + randf() * 0.35

func _build_enemy_plan() -> void:
	# Turn-based: enemy plans against your current pose after your movement resolves.
	var player_observed: Vector2 = player_cell_pos
	var built: Dictionary = _build_movement_states(
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_move_points,
		enemy_ship_class,
		player_observed,
		player_heading_deg,
		player_ship_class,
		enemy_cell,
		enemy_sail_setting,
		enemy_run_cells
	)
	var states: Array = built["states"]
	var terminals: Array[Dictionary] = _collect_terminal_states(
		states,
		enemy_ship_class,
		player_observed,
		player_heading_deg,
		player_ship_class,
		enemy_sail_setting,
		float(built["move_scale"])
	)
	var player_cell_now: Vector2i = player_cell
	var best_terminal: Dictionary = {}
	var best_score: float = -INF
	for s in terminals:
		var cell: Vector2i = s["cell"]
		if cell == player_cell_now:
			continue
		var hdg: float = float(s["heading_deg"])
		if _is_heading_in_irons(hdg):
			continue
		var sc: float = _score_enemy_destination_cell(cell, player_observed)
		# Prefer staying out of irons and having a firing solution
		var has_solution: bool = bool(_cannon_shot_classification(s["pos"], hdg, enemy_ship_class, player_observed, player_heading_deg).get("can_fire", false))
		if has_solution:
			sc += 2.0
		if sc > best_score:
			best_score = sc
			best_terminal = s
		elif absf(sc - best_score) <= 0.0001 and not best_terminal.is_empty():
			if int(s["mp"]) < int(best_terminal["mp"]):
				best_terminal = s
	if best_terminal.is_empty():
		enemy_plan_end_pos = enemy_cell_pos
		enemy_plan_end_heading = enemy_heading_deg
		enemy_plan_terminal = {
			"pos": enemy_cell_pos,
			"heading_deg": enemy_heading_deg,
			"mp": enemy_move_points,
			"cell": enemy_cell
		}
	else:
		enemy_plan_end_pos = best_terminal["pos"]
		enemy_plan_end_heading = float(best_terminal["heading_deg"])
		enemy_plan_terminal = best_terminal.duplicate(true)
	if enemy_behavior == "escape":
		enemy_plan_volley_when_in_range = false
		enemy_plan_board = false
	else:
		enemy_plan_volley_when_in_range = (
			enemy_port_cannon_reload_turns_remaining <= 0 or enemy_starboard_cannon_reload_turns_remaining <= 0
		)
		enemy_plan_board = (
			_ship_footprint_distance(
				enemy_plan_end_pos,
				enemy_plan_end_heading,
				enemy_ship_class,
				player_cell_pos,
				player_heading_deg,
				player_ship_class
			) <= 1
			and randf() < 0.38
			and enemy_hull > 4
		)

func _cannon_reload_duration_turns_for_attacker(attacker_is_player: bool) -> int:
	var hull0: int = player_hull_battle_start if attacker_is_player else enemy_hull_battle_start
	var hull_cur: int = player_hull if attacker_is_player else enemy_hull
	var crew0: int = player_crew_battle_start if attacker_is_player else enemy_crew_battle_start
	var crew_cur: int = player_crew if attacker_is_player else enemy_crew
	var hull_strain: float = float(max(1, hull0)) / float(max(1, hull_cur))
	hull_strain = clampf(hull_strain, 1.0, CANNON_RELOAD_HULL_STRAIN_MAX)
	var crew_strain: float = float(max(1, crew0)) / float(max(1, crew_cur))
	crew_strain = clampf(crew_strain, 1.0, CANNON_RELOAD_CREW_STRAIN_MAX)
	var fatigue: float = 1.0 + CANNON_RELOAD_FATIGUE_PER_ROUND * float(_completed_wego_rounds)
	fatigue = clampf(fatigue, 1.0, CANNON_RELOAD_FATIGUE_MAX)
	var raw: float = float(CANNON_RELOAD_BASE_ROUNDS) * hull_strain * crew_strain * fatigue
	return clampi(ceili(raw), CANNON_RELOAD_BASE_ROUNDS, CANNON_RELOAD_MAX_ROUNDS)


func _advance_cannon_reload_for_side(attacker_is_player: bool) -> void:
	if attacker_is_player:
		if player_port_cannon_reload_turns_remaining > 0:
			player_port_cannon_reload_turns_remaining -= 1
		if player_starboard_cannon_reload_turns_remaining > 0:
			player_starboard_cannon_reload_turns_remaining -= 1
	else:
		if enemy_port_cannon_reload_turns_remaining > 0:
			enemy_port_cannon_reload_turns_remaining -= 1
		if enemy_starboard_cannon_reload_turns_remaining > 0:
			enemy_starboard_cannon_reload_turns_remaining -= 1


func _target_in_cannon_arc(
	attacker_pos: Vector2,
	attacker_heading_deg: float,
	attacker_class: String,
	target_pos: Vector2
) -> Dictionary:
	var dist: float = attacker_pos.distance_to(target_pos)
	if dist > _cannon_range(attacker_class):
		return {"in_arc": false}
	var yards: float = _yards_between_norm_positions(attacker_pos, target_pos)
	if yards > CANNON_MAX_EFFECTIVE_RANGE_YARDS:
		return {"in_arc": false}
	var bearing_to_target: float = _vector_to_bearing_deg((target_pos - attacker_pos).normalized())
	var rel: float = absf(_angle_delta_deg(attacker_heading_deg, bearing_to_target))
	var arc_profile: Dictionary = _cannon_arc_profile(attacker_class)
	var broadside_window: float = float(arc_profile.get("broadside_window", 34.0))
	var chase_window: float = float(arc_profile.get("chase_window", 14.0))
	var has_chase_guns: bool = bool(arc_profile.get("has_chase_guns", false))
	var can_broadside: bool = absf(rel - 90.0) <= broadside_window
	var can_chase: bool = has_chase_guns and chase_window > 0.0 and (rel <= chase_window or rel >= (180.0 - chase_window))
	if not can_broadside and not can_chase:
		return {"in_arc": false}
	return {"in_arc": true, "yards": yards, "can_broadside": can_broadside, "can_chase": can_chase}

func _cannon_shot_classification(
	attacker_pos: Vector2,
	attacker_heading_deg: float,
	attacker_class: String,
	target_pos: Vector2,
	target_heading_deg: float
) -> Dictionary:
	var arc: Dictionary = _target_in_cannon_arc(attacker_pos, attacker_heading_deg, attacker_class, target_pos)
	if not bool(arc.get("in_arc", false)):
		return {"can_fire": false}
	var yards: float = float(arc.get("yards", 0.0))
	var can_broadside: bool = bool(arc.get("can_broadside", false))
	var shot_type: String = "broadside" if can_broadside else "chase guns"
	var raking: bool = _is_target_stern_arc(attacker_pos, target_pos, target_heading_deg)
	var firing_battery: int = _broadside_battery_for_target(
		attacker_heading_deg, attacker_pos, target_pos, attacker_class, target_heading_deg
	)
	return {
		"can_fire": true,
		"yards": yards,
		"shot_type": shot_type,
		"raking": raking,
		"can_broadside": can_broadside,
		"firing_battery": firing_battery
	}


func _execute_battery_volley(
	battery: int,
	attacker_pos_norm: Vector2,
	attacker_heading: float,
	attacker_class: String,
	defender_pos_norm: Vector2,
	defender_heading: float,
	attacker_is_player: bool,
	require_bearing_match: bool = true
) -> Dictionary:
	var none: Dictionary = {"fired": false, "firing_battery": -1}
	var cls: Dictionary = _cannon_shot_classification(
		attacker_pos_norm, attacker_heading, attacker_class, defender_pos_norm, defender_heading
	)
	if not bool(cls.get("can_fire", false)):
		if attacker_is_player:
			var side_label: String = "Port" if battery == 0 else "Starboard"
			emit_signal("battle_updated", "%s battery: no firing solution on the enemy." % side_label)
		return none
	if require_bearing_match:
		var bearing_battery: int = int(cls.get("firing_battery", 0))
		if bearing_battery != battery:
			if attacker_is_player:
				var side: String = "port" if battery == 0 else "starboard"
				var other: String = "starboard" if battery == 0 else "port"
				emit_signal("battle_updated", "Your %s battery cannot bear—the enemy is to %s." % [side, other])
			return none
	if attacker_is_player:
		var reload_rem: int = (
			player_port_cannon_reload_turns_remaining if battery == 0 else player_starboard_cannon_reload_turns_remaining
		)
		if reload_rem > 0:
			var side: String = "port" if battery == 0 else "starboard"
			emit_signal(
				"battle_updated",
				"Your %s battery is still running out the tackles—%d more round(s) before it can bear again." % [side, reload_rem]
			)
			return none
	else:
		var ereload: int = (
			enemy_port_cannon_reload_turns_remaining if battery == 0 else enemy_starboard_cannon_reload_turns_remaining
		)
		if ereload > 0:
			emit_signal("battle_updated", "Enemy holds fire; the bearing battery is still reloading.")
			return none
	var yards: float = float(cls.get("yards", 0.0))
	var can_broadside: bool = bool(cls.get("can_broadside", false))
	var raking: bool = bool(cls.get("raking", false))
	var volley: Dictionary = _roll_cannon_volley_damage(attacker_class, yards, can_broadside, raking)
	var damage: int = int(volley.get("damage", 0))
	var shot_type: String = str(cls.get("shot_type", "broadside"))
	var rake_text: String = " Raking fire!" if raking else ""
	var hits: int = int(volley.get("hits", 0))
	var guns: int = int(volley.get("guns_firing", 0))
	var yards_i: int = int(volley.get("yards", 0))
	var side_done: String = "port" if battery == 0 else "starboard"
	var crew_loss_note: String = ""
	if attacker_is_player:
		enemy_hull = max(0, enemy_hull - damage)
		if hits > 0:
			var crew_loss: int = _crew_casualties_from_cannon_hits(hits, false)
			enemy_crew = max(0, enemy_crew - crew_loss)
			if crew_loss > 0:
				crew_loss_note = " Enemy crew losses: %d." % crew_loss
		player_has_boarding_advantage = true
		var dur: int = _cannon_reload_duration_turns_for_attacker(true)
		if battery == 0:
			player_port_cannon_reload_turns_remaining = dur
		else:
			player_starboard_cannon_reload_turns_remaining = dur
		var reload_note: String = " %s battery reloading (%d round(s))." % [side_done.capitalize(), dur]
		if damage > 0:
			emit_signal(
				"battle_updated",
				"Your %s (%s): %d/%d hits (~%d yd) for %d hull damage.%s%s%s"
				% [shot_type, side_done, hits, guns, yards_i, damage, rake_text, reload_note, crew_loss_note]
			)
		else:
			emit_signal(
				"battle_updated",
				"Your %s (%s): %d/%d hits (~%d yd)—no hull damage.%s%s%s"
				% [shot_type, side_done, hits, guns, yards_i, rake_text, reload_note, crew_loss_note]
			)
	else:
		player_hull = max(0, player_hull - damage)
		if hits > 0:
			var crew_loss_p: int = _crew_casualties_from_cannon_hits(hits, true)
			player_crew = max(0, player_crew - crew_loss_p)
			if crew_loss_p > 0:
				crew_loss_note = " Your crew losses: %d." % crew_loss_p
		enemy_has_boarding_advantage = true
		var edur: int = _cannon_reload_duration_turns_for_attacker(false)
		if battery == 0:
			enemy_port_cannon_reload_turns_remaining = edur
		else:
			enemy_starboard_cannon_reload_turns_remaining = edur
		if damage > 0:
			emit_signal(
				"battle_updated",
				"Enemy %s: %d/%d hits (~%d yd) for %d hull damage.%s%s" % [shot_type, hits, guns, yards_i, damage, rake_text, crew_loss_note]
			)
		else:
			emit_signal(
				"battle_updated",
				"Enemy %s: %d/%d hits (~%d yd)—no hull damage.%s%s" % [shot_type, hits, guns, yards_i, rake_text, crew_loss_note]
			)
	return {"fired": true, "firing_battery": battery}


func _resolve_volley_orders_if_in_range(
	ordered: bool,
	attacker_pos_norm: Vector2,
	attacker_heading: float,
	attacker_class: String,
	defender_pos_norm: Vector2,
	defender_heading: float,
	attacker_is_player: bool
) -> Dictionary:
	var none: Dictionary = {"fired": false, "firing_battery": -1}
	if not ordered:
		return none
	var cls: Dictionary = _cannon_shot_classification(
		attacker_pos_norm, attacker_heading, attacker_class, defender_pos_norm, defender_heading
	)
	if not bool(cls.get("can_fire", false)):
		var who_battery: String = "Your" if attacker_is_player else "Enemy"
		emit_signal("battle_updated", "%s guns: no firing solution on the target after movement." % who_battery)
		return none
	return _execute_battery_volley(
		int(cls.get("firing_battery", 0)),
		attacker_pos_norm,
		attacker_heading,
		attacker_class,
		defender_pos_norm,
		defender_heading,
		attacker_is_player
	)


func player_fire_battery(battery: int) -> bool:
	if phase != Phase.PLANNING:
		return false
	if battery != 0 and battery != 1:
		return false
	if not player_can_order_battery_fire(battery):
		var side: String = "Port" if battery == 0 else "Starboard"
		emit_signal("battle_updated", "%s battery is still reloading." % side)
		return false
	if not enemy_in_player_battery_range(battery):
		var range_side: String = "port" if battery == 0 else "starboard"
		emit_signal(
			"battle_updated",
			"Enemy is not in your highlighted %s range—adjust range or position." % range_side
		)
		return false
	var volley: Dictionary = _execute_battery_volley(
		battery,
		player_position,
		player_heading_deg,
		player_ship_class,
		enemy_position,
		enemy_heading_deg,
		true,
		false
	)
	var fired: bool = bool(volley.get("fired", false))
	if enemy_hull <= 0 or player_hull <= 0:
		_check_resolution_only()
	return fired


func _snap_player_pose_to_planned() -> void:
	_invalidate_player_movement_preview_cache()
	player_cell_pos = player_plan_end_pos
	player_heading_deg = player_plan_end_heading
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	_sync_pose_from_positions()

func _snap_enemy_pose_to_planned() -> void:
	enemy_cell_pos = enemy_plan_end_pos
	enemy_heading_deg = enemy_plan_end_heading
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	_sync_pose_from_positions()

func _resolve_player_leg_effects() -> bool:
	if _check_collision_with_hazard(player_cell):
		emit_signal("battle_updated", "Your ship strikes a hazard!")
		return true
	return false

func _try_player_grapple() -> bool:
	if (
		_ship_footprint_distance(
			player_cell_pos,
			player_heading_deg,
			player_ship_class,
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class
		)
		> 1
	):
		return false
	var chance := 0.38
	var crew_ratio: float = float(player_crew) / float(max(1, enemy_crew))
	chance += clampf((crew_ratio - 1.0) * 0.2, -0.12, 0.2)
	if _is_target_stern_arc(player_position, enemy_position, enemy_heading_deg):
		chance += 0.08
	if player_has_boarding_advantage:
		chance += 0.25
	if randf() <= chance:
		player_plan_board = false
		emit_signal("battle_updated", "Your crew throws the grapples home!")
		emit_signal("boarding_started", true)
		return true
	emit_signal("battle_updated", "Grappling attempt fails; lines part.")
	enemy_has_boarding_advantage = true
	player_plan_board = false
	return false

func _resolve_player_end_turn_effects() -> bool:
	if player_plan_board and _try_player_grapple():
		return true
	return false

func _resolve_player_turn_effects() -> bool:
	return _resolve_player_leg_effects()

func _resolve_enemy_turn_effects() -> bool:
	if _check_collision_with_hazard_enemy(enemy_cell):
		return true
	var p_norm: Vector2 = player_position
	var e_norm: Vector2 = enemy_position
	var p_h: float = player_heading_deg
	var e_h: float = enemy_heading_deg
	var _ev: Dictionary = _resolve_volley_orders_if_in_range(
		enemy_plan_volley_when_in_range, e_norm, e_h, enemy_ship_class, p_norm, p_h, false
	)
	if enemy_hull <= 0 or player_hull <= 0:
		_check_resolution_only()
		return true
	if enemy_plan_board and _ship_footprint_distance(
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_ship_class,
		player_cell_pos,
		player_heading_deg,
		player_ship_class
	) <= 1:
		var ech := 0.34
		var crew_ratio_e: float = float(enemy_crew) / float(max(1, player_crew))
		ech += clampf((crew_ratio_e - 1.0) * 0.2, -0.12, 0.2)
		if enemy_has_boarding_advantage:
			ech += 0.2
		if randf() <= ech:
			emit_signal("battle_updated", "Enemy hooks your rail!")
			emit_signal("boarding_started", false)
			return true
		emit_signal("battle_updated", "Enemy boarders cannot secure a purchase.")
	return false

func _start_enemy_turn() -> void:
	if phase == Phase.RESOLVED:
		return
	_build_enemy_plan()
	_cache_enemy_round_path()
	_move_anim_actor = "enemy"
	_move_anim_elapsed = 0.0
	phase = Phase.MOVE_ANIM
	emit_signal("battle_updated", "Enemy squadron executes.")

func _finish_turn_based_round() -> void:
	_completed_wego_rounds += 1
	emit_signal("battle_updated", "Round complete. Your turn.")
	_check_resolution_or_planning()

func advance_move_animation(delta: float) -> void:
	if phase != Phase.MOVE_ANIM:
		return
	_move_anim_elapsed += delta
	if _move_anim_elapsed < MOVE_ANIM_DURATION_SEC:
		return
	_move_anim_elapsed = 0.0
	if _move_anim_actor == "player":
		_finish_player_move_leg_after_animation()
		return
	if _move_anim_actor == "enemy":
		_snap_enemy_pose_to_planned()
		_commit_enemy_run_cells_after_move()
		var end_combat: bool = _resolve_enemy_turn_effects()
		_move_anim_actor = ""
		if phase == Phase.RESOLVED:
			return
		if end_combat:
			return
		_advance_cannon_reload_for_side(false)
		_finish_turn_based_round()
		if phase == Phase.MOVE_ANIM:
			phase = Phase.PLANNING

func get_active_move_anim_side() -> String:
	if phase != Phase.MOVE_ANIM:
		return ""
	return _move_anim_actor

func get_player_plan_preview_path() -> Array[Dictionary]:
	return player_plan_preview_path

func get_player_display_cell_pos() -> Vector2:
	if phase == Phase.MOVE_ANIM and _move_anim_actor == "player":
		return _sample_anim_path(player_round_path, _move_anim_elapsed / MOVE_ANIM_DURATION_SEC)["pos"] as Vector2
	return player_cell_pos

func get_enemy_display_cell_pos() -> Vector2:
	if phase == Phase.MOVE_ANIM and _move_anim_actor == "enemy":
		return _sample_anim_path(enemy_round_path, _move_anim_elapsed / MOVE_ANIM_DURATION_SEC)["pos"] as Vector2
	return enemy_cell_pos

func get_player_display_heading_deg() -> float:
	if phase == Phase.MOVE_ANIM and _move_anim_actor == "player":
		return float(_sample_anim_path(player_round_path, _move_anim_elapsed / MOVE_ANIM_DURATION_SEC)["heading_deg"])
	return player_heading_deg

func get_enemy_display_heading_deg() -> float:
	if phase == Phase.MOVE_ANIM and _move_anim_actor == "enemy":
		return float(_sample_anim_path(enemy_round_path, _move_anim_elapsed / MOVE_ANIM_DURATION_SEC)["heading_deg"])
	return enemy_heading_deg

func _sample_anim_path(path: Array[Dictionary], u_raw: float) -> Dictionary:
	var u: float = clampf(u_raw, 0.0, 1.0)
	if path.is_empty():
		return {"pos": Vector2.ZERO, "heading_deg": 0.0}
	var n: int = path.size()
	if n == 1:
		return path[0]
	var f: float = u * float(n - 1)
	var seg: int = clampi(int(floor(f)), 0, n - 2)
	var t: float = f - float(seg)
	var a: Dictionary = path[seg]
	var b: Dictionary = path[seg + 1]
	var pa: Vector2 = a["pos"] as Vector2
	var pb: Vector2 = b["pos"] as Vector2
	var ha: float = float(a["heading_deg"])
	var hb: float = float(b["heading_deg"])
	var pos: Vector2 = pa.lerp(pb, t)
	var heading_deg: float = rad_to_deg(lerp_angle(deg_to_rad(ha), deg_to_rad(hb), t))
	return {"pos": pos, "heading_deg": heading_deg}

func _cache_player_round_path() -> void:
	enemy_round_path.clear()
	player_round_path = _reconstruct_path_to_terminal(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_ship_class,
		player_cell,
		player_sail_setting,
		player_plan_terminal,
		player_run_cells
	)
	_ensure_path_has_endpoints(
		player_round_path,
		player_cell_pos,
		player_heading_deg,
		player_plan_end_pos,
		player_plan_end_heading
	)

func _cache_enemy_round_path() -> void:
	enemy_round_path = _reconstruct_path_to_terminal(
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_move_points,
		enemy_ship_class,
		player_cell_pos,
		player_heading_deg,
		player_ship_class,
		enemy_cell,
		enemy_sail_setting,
		enemy_plan_terminal,
		enemy_run_cells
	)
	_ensure_path_has_endpoints(
		enemy_round_path,
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_plan_end_pos,
		enemy_plan_end_heading
	)

func _ensure_path_has_endpoints(
	path: Array[Dictionary],
	start_pos: Vector2,
	start_heading: float,
	end_pos: Vector2,
	end_heading: float
) -> void:
	if path.is_empty():
		path.append({"pos": start_pos, "heading_deg": start_heading})
		path.append({"pos": end_pos, "heading_deg": end_heading})
		return
	var first: Dictionary = path[0]
	var last: Dictionary = path[path.size() - 1]
	if (first["pos"] as Vector2).distance_to(start_pos) > 0.05:
		path.insert(0, {"pos": start_pos, "heading_deg": start_heading})
	if (last["pos"] as Vector2).distance_to(end_pos) > 0.05:
		path.append({"pos": end_pos, "heading_deg": end_heading})

func _movement_state_dict_key(state: Dictionary) -> String:
	var cell: Vector2i = state["cell"] as Vector2i
	var mp: int = int(state["mp"])
	var heading_idx: int = int(state.get("heading_idx", _bearing_to_heading_idx(float(state["heading_deg"]))))
	var run_cells: int = int(state.get("run_cells", 0))
	return "%d:%d:%d:%d:%d" % [cell.x, cell.y, heading_idx, mp, run_cells]

func heading_idx_to_bearing(idx: int) -> float:
	return _heading_idx_to_bearing(idx)

func bearing_to_heading_idx(bearing_deg: float) -> int:
	return _bearing_to_heading_idx(bearing_deg)

func get_player_move_options() -> Array[Dictionary]:
	var preview: Dictionary = get_player_movement_preview()
	var options: Variant = preview.get("move_options", [])
	if options is Array:
		return options
	return []

func get_player_display_move_options() -> Array[Dictionary]:
	return get_player_move_options()

func _canonical_options_per_cell(options: Array[Dictionary]) -> Array[Dictionary]:
	var best_by_cell: Dictionary = {}
	for opt in options:
		if not (opt is Dictionary):
			continue
		var cell: Vector2i = opt.get("cell", Vector2i(-1, -1))
		if cell.x < 0:
			continue
		if not best_by_cell.has(cell) or _better_canonical_stop_for_cell(opt, best_by_cell[cell]):
			best_by_cell[cell] = opt
	var out: Array[Dictionary] = []
	for k in best_by_cell.keys():
		out.append(best_by_cell[k])
	return out

func _is_move_option_behind_ship(opt: Dictionary) -> bool:
	var pos: Vector2 = opt.get("pos", player_cell_pos) as Vector2
	var forward: Vector2 = _bearing_deg_to_vector(player_heading_deg)
	return (pos - player_cell_pos).dot(forward) < 0.15

func get_player_move_options_for_cell(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for opt in get_player_move_options():
		if opt is Dictionary and opt.get("cell", Vector2i(-1, -1)) == cell:
			out.append(opt)
	return out

func _is_player_start_move_option(state: Dictionary) -> bool:
	if int(state.get("mp", -1)) != player_move_points:
		return false
	if state.get("cell", Vector2i(-1, -1)) != player_cell:
		return false
	var hdg_idx: int = int(state.get("heading_idx", _bearing_to_heading_idx(player_heading_deg)))
	return hdg_idx == _bearing_to_heading_idx(player_heading_deg)

func _decorate_move_option(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var hdg_idx: int = int(state.get("heading_idx", _bearing_to_heading_idx(float(state["heading_deg"]))))
	out["heading_idx"] = hdg_idx
	out["heading_deg"] = _heading_idx_to_bearing(hdg_idx)
	return out

func _reconstruct_path_to_terminal(
	start_pos: Vector2,
	start_heading: float,
	start_mp: int,
	ship_class: String,
	other_pos: Vector2,
	other_heading: float,
	other_ship_class: String,
	start_cell: Vector2i,
	sail: SailSetting,
	goal_terminal: Dictionary,
	start_run_cells: int = 0
) -> Array[Dictionary]:
	if goal_terminal.is_empty():
		return []
	start_pos = _snap_ship_center_to_cell_center(start_pos)
	start_cell = _ship_anchor_cell(start_pos)
	var move_scale: float = _combat_move_scale_for(ship_class, start_heading, start_mp)
	var forward_mul: float = _sail_forward_multiplier(sail)
	var turn_mul: float = _sail_turn_step_multiplier(sail)
	var turn_cost: int = _turn_cost_for(ship_class)
	var goal_key: String = _movement_state_dict_key(goal_terminal)
	var start_heading_idx: int = _bearing_to_heading_idx(start_heading)
	var start_state: Dictionary = {
		"pos": start_pos,
		"heading_deg": start_heading,
		"heading_idx": start_heading_idx,
		"mp": start_mp,
		"cell": start_cell,
		"run_cells": maxi(0, start_run_cells)
	}
	var open: Array[Dictionary] = [start_state]
	var seen: Dictionary = {}
	while not open.is_empty():
		var state: Dictionary = open.pop_front()
		var key: String = _movement_state_dict_key(state)
		if seen.has(key):
			continue
		seen[key] = true
		if key == goal_key:
			return _walk_parents_to_path(state)
		var pos: Vector2 = state["pos"]
		var heading_deg: float = float(state["heading_deg"])
		var heading_idx: int = int(state.get("heading_idx", _bearing_to_heading_idx(heading_deg)))
		var mp: int = int(state["mp"])
		var cell: Vector2i = state["cell"] as Vector2i
		var run_cells: int = int(state.get("run_cells", 0))
		if mp >= 1:
			var step_cells: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale
			var next_pos: Vector2 = pos + _bearing_deg_to_vector(heading_deg) * step_cells
			var nsp: Vector2 = _snap_ship_center_to_cell_center(next_pos)
			if _is_valid_ship_pose(nsp, heading_deg, ship_class, other_pos, other_heading, other_ship_class):
				var next_cell: Vector2i = _ship_anchor_cell(nsp)
				var child: Dictionary = {
					"pos": nsp,
					"heading_deg": heading_deg,
					"heading_idx": heading_idx,
					"mp": mp - 1,
					"cell": next_cell,
					"run_cells": _run_cells_after_forward(cell, run_cells, next_cell),
					"parent": state
				}
				open.append(child)
		if mp >= turn_cost and _can_initiate_turn_from_state(state, sail):
			var left_idx: int = posmod(heading_idx - 1, 8)
			var right_idx: int = posmod(heading_idx + 1, 8)
			var left_heading_deg: float = _heading_idx_to_bearing(left_idx)
			var right_heading_deg: float = _heading_idx_to_bearing(right_idx)
			var turn_step: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale * turn_mul
			var left_pos: Vector2 = pos + _bearing_deg_to_vector(left_heading_deg) * turn_step
			var lsp: Vector2 = _snap_ship_center_to_cell_center(left_pos)
			if _is_valid_ship_pose(lsp, left_heading_deg, ship_class, other_pos, other_heading, other_ship_class):
				var lc: Vector2i = _ship_anchor_cell(lsp)
				var left_child: Dictionary = {
					"pos": lsp,
					"heading_deg": left_heading_deg,
					"heading_idx": left_idx,
					"mp": mp - turn_cost,
					"cell": lc,
					"run_cells": _run_cells_after_turn(cell, lc),
					"parent": state
				}
				open.append(left_child)
			var right_pos: Vector2 = pos + _bearing_deg_to_vector(right_heading_deg) * turn_step
			var rsp: Vector2 = _snap_ship_center_to_cell_center(right_pos)
			if _is_valid_ship_pose(rsp, right_heading_deg, ship_class, other_pos, other_heading, other_ship_class):
				var rc: Vector2i = _ship_anchor_cell(rsp)
				var right_child: Dictionary = {
					"pos": rsp,
					"heading_deg": right_heading_deg,
					"heading_idx": right_idx,
					"mp": mp - turn_cost,
					"cell": rc,
					"run_cells": _run_cells_after_turn(cell, rc),
					"parent": state
				}
				open.append(right_child)
	return []

func _walk_parents_to_path(end_state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cur: Variant = end_state
	while cur is Dictionary:
		var d: Dictionary = cur
		out.append({"pos": d["pos"] as Vector2, "heading_deg": float(d["heading_deg"])})
		if not d.has("parent"):
			break
		cur = d["parent"]
	out.reverse()
	return out

func _layout_opening_positions_at_cannon_range() -> void:
	var cols: int = combat_cols
	var rows: int = combat_rows
	# Broadside geometry: separate along +X so each ship bears 90° to the other; headings 0° / 180°.
	var d_norm: float = minf(_cannon_range(player_ship_class), _cannon_range(enemy_ship_class)) * 0.92
	var half_sep_cells: float = d_norm * float(max(1, cols - 1)) * 0.5
	var max_half: float = float(max(1, cols - 2)) * 0.42
	half_sep_cells = minf(half_sep_cells, max_half)
	var mid_x: float = (float(cols) - 1.0) * 0.5
	var mid_y: float = (float(rows) - 1.0) * 0.5
	player_cell_pos = Vector2(mid_x - half_sep_cells, mid_y)
	enemy_cell_pos = Vector2(mid_x + half_sep_cells, mid_y)
	player_heading_deg = 0.0
	enemy_heading_deg = 180.0
	for _i in range(22):
		if _is_valid_ship_pose(
			player_cell_pos,
			player_heading_deg,
			player_ship_class,
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class
		) and _is_valid_ship_pose(
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class,
			player_cell_pos,
			player_heading_deg,
			player_ship_class
		):
			break
		half_sep_cells *= 0.94
		player_cell_pos = Vector2(mid_x - half_sep_cells, mid_y)
		enemy_cell_pos = Vector2(mid_x + half_sep_cells, mid_y)
	player_cell_pos.x = clampf(player_cell_pos.x, 2.0, float(cols - 3))
	player_cell_pos.y = clampf(player_cell_pos.y, 2.0, float(rows - 3))
	enemy_cell_pos.x = clampf(enemy_cell_pos.x, 2.0, float(cols - 3))
	enemy_cell_pos.y = clampf(enemy_cell_pos.y, 2.0, float(rows - 3))
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	player_cell_pos = _snap_ship_center_to_cell_center(player_cell_pos)
	enemy_cell_pos = _snap_ship_center_to_cell_center(enemy_cell_pos)

func _check_resolution_or_planning() -> void:
	if enemy_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Enemy ship sinks. Victory!")
		emit_signal("battle_finished", true, false)
		return
	if player_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Your ship is lost. Defeat.")
		emit_signal("battle_finished", false, false)
		return
	_begin_planning_round()

func apply_boarding_crew_casualties(player_lost_boarders: int, enemy_lost_boarders: int) -> void:
	if player_lost_boarders > 0:
		player_crew = max(0, player_crew - player_lost_boarders)
	if enemy_lost_boarders > 0:
		enemy_crew = max(0, enemy_crew - enemy_lost_boarders)

func resolve_boarding_result(attacker_is_player: bool, attackers_won: bool) -> void:
	if attackers_won:
		if attacker_is_player:
			enemy_hull = max(0, enemy_hull - 6)
			player_has_boarding_advantage = true
			emit_signal("battle_updated", "Your boarders carry the enemy deck. Enemy ship is crippled.")
		else:
			player_hull = max(0, player_hull - 6)
			enemy_has_boarding_advantage = true
			emit_signal("battle_updated", "Enemy boarders overrun your crew. Your ship is crippled.")
		_check_resolution_or_planning()
	else:
		if attacker_is_player:
			enemy_has_boarding_advantage = true
			emit_signal("battle_updated", "The enemy crew repels your boarders.")
		else:
			player_has_boarding_advantage = true
			emit_signal("battle_updated", "Your crew throws the enemy back into the sea.")
		_begin_planning_round()

func _check_resolution_only() -> void:
	if enemy_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Enemy ship sinks. Victory!")
		emit_signal("battle_finished", true, false)
		return

	if player_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Your ship is lost. Defeat.")
		emit_signal("battle_finished", false, false)

func get_combat_cell_yards() -> float:
	return COMBAT_CELL_YARDS

func get_cannon_max_effective_range_yards() -> float:
	return CANNON_MAX_EFFECTIVE_RANGE_YARDS

func get_player_port_cannon_reload_turns_remaining() -> int:
	return player_port_cannon_reload_turns_remaining

func get_player_starboard_cannon_reload_turns_remaining() -> int:
	return player_starboard_cannon_reload_turns_remaining

func get_enemy_port_cannon_reload_turns_remaining() -> int:
	return enemy_port_cannon_reload_turns_remaining

func get_enemy_starboard_cannon_reload_turns_remaining() -> int:
	return enemy_starboard_cannon_reload_turns_remaining

func get_cannon_reload_max_rounds() -> int:
	return CANNON_RELOAD_MAX_ROUNDS

func _combat_cell_center_from_norm(n: Vector2) -> Vector2:
	return Vector2(n.x * float(max(1, combat_cols - 1)) + 0.5, n.y * float(max(1, combat_rows - 1)) + 0.5)

func _yards_between_norm_positions(a: Vector2, b: Vector2) -> float:
	return _combat_cell_center_from_norm(a).distance_to(_combat_cell_center_from_norm(b)) * COMBAT_CELL_YARDS

func _cannon_gunnery_accuracy_multiplier() -> float:
	return GUNNERY_BASELINE_MULT

## Per-gun hit chance vs range (15 yd/cell); ~400 yd still useful, long shots sparse—crew will modulate later.
func _cannon_per_gun_hit_chance_at_yards(yards: float) -> float:
	var y: float = maxf(0.0, yards)
	var p: float
	if y <= 100.0:
		p = lerpf(0.78, 0.68, y / 100.0)
	elif y <= 400.0:
		p = lerpf(0.68, 0.42, (y - 100.0) / 300.0)
	elif y <= 750.0:
		p = lerpf(0.42, 0.24, (y - 400.0) / 350.0)
	elif y <= 1150.0:
		p = lerpf(0.24, 0.10, (y - 750.0) / 400.0)
	else:
		p = lerpf(0.10, 0.035, clampf((y - 1150.0) / 600.0, 0.0, 1.0))
	return clampf(p * _cannon_gunnery_accuracy_multiplier(), 0.02, 0.92)

func _max_yards_where_per_gun_hit_chance_at_least(p_floor: float, search_hi_yards: float) -> float:
	if _cannon_per_gun_hit_chance_at_yards(0.0) < p_floor:
		return 0.0
	var lo: float = 0.0
	var hi: float = maxf(30.0, search_hi_yards)
	while hi - lo > 2.5:
		var mid: float = (lo + hi) * 0.5
		if _cannon_per_gun_hit_chance_at_yards(mid) >= p_floor:
			lo = mid
		else:
			hi = mid
	return lo

func get_player_cannon_accuracy_ring_yards(hit_chance_floor: float) -> float:
	var hi: float = minf(
		CANNON_MAX_EFFECTIVE_RANGE_YARDS,
		Vector2(float(combat_cols - 1), float(combat_rows - 1)).length() * COMBAT_CELL_YARDS
	)
	return _max_yards_where_per_gun_hit_chance_at_least(hit_chance_floor, hi)

func _crew_casualties_from_cannon_hits(hits: int, _defender_is_player: bool) -> int:
	if hits <= 0:
		return 0
	var base: int = maxi(1, int(round(float(hits) * randf_range(0.35, 0.75))))
	return clampi(base, 1, maxi(1, hits * 3))

func _roll_cannon_volley_damage(ship_class: String, yards: float, can_broadside: bool, raking: bool) -> Dictionary:
	var broadside_guns: int = maxi(1, int(_ship_stats(ship_class).get("broadside", 4)))
	var guns_firing: int = broadside_guns if can_broadside else maxi(1, int(round(float(broadside_guns) * 0.45)))
	var p: float = _cannon_per_gun_hit_chance_at_yards(yards)
	var hits: int = 0
	for _g in range(guns_firing):
		if randf() < p:
			hits += 1
	var yard_factor: float = clampf(1.12 - yards / 2100.0, 0.32, 1.08)
	var per_hit: int = 0
	if hits > 0:
		var base_raw: float = float(randi_range(1, 2)) * yard_factor
		if not can_broadside:
			base_raw *= 0.62
		per_hit = maxi(1, int(round(base_raw)))
	var damage: int = hits * per_hit
	if raking and hits > 0:
		damage = int(round(float(damage) * 1.15))
	return {
		"hits": hits,
		"guns_firing": guns_firing,
		"yards": int(round(yards)),
		"p_hit": p,
		"damage": damage
	}

func _resolve_cannon_shot(attacker_pos: Vector2, attacker_heading_deg: float, attacker_class: String, target_pos: Vector2, target_heading_deg: float) -> Dictionary:
	var c: Dictionary = _cannon_shot_classification(attacker_pos, attacker_heading_deg, attacker_class, target_pos, target_heading_deg)
	if not bool(c.get("can_fire", false)):
		return {"can_fire": false}
	var yards: float = float(c.get("yards", 0.0))
	var can_broadside: bool = bool(c.get("can_broadside", false))
	var raking: bool = bool(c.get("raking", false))
	var volley: Dictionary = _roll_cannon_volley_damage(attacker_class, yards, can_broadside, raking)
	return {
		"can_fire": true,
		"damage": int(volley.get("damage", 0)),
		"shot_type": str(c.get("shot_type", "broadside")),
		"raking": raking,
		"hits": int(volley.get("hits", 0)),
		"guns_firing": int(volley.get("guns_firing", 0)),
		"yards": int(volley.get("yards", 0)),
		"p_hit": float(volley.get("p_hit", 0.0)),
		"firing_battery": int(c.get("firing_battery", 0))
	}

func _cannon_arc_profile(ship_class: String) -> Dictionary:
	match ship_class:
		"Sloop":
			return {"broadside_window": 36.0, "has_chase_guns": false, "chase_window": 14.0}
		"Brig":
			return {"broadside_window": 34.0, "has_chase_guns": false, "chase_window": 14.0}
		"Frigate":
			return {"broadside_window": 32.0, "has_chase_guns": false, "chase_window": 14.0}
		"Merchantman":
			return {"broadside_window": 30.0, "has_chase_guns": false, "chase_window": 14.0}
		_:
			return {"broadside_window": 34.0, "has_chase_guns": false, "chase_window": 14.0}

func _is_target_stern_arc(attacker_pos: Vector2, target_pos: Vector2, target_heading_deg: float) -> bool:
	var bearing_from_target: float = _vector_to_bearing_deg((attacker_pos - target_pos).normalized())
	var rel: float = absf(_angle_delta_deg(target_heading_deg, bearing_from_target))
	return rel <= 35.0

func _cannon_range(ship_class: String) -> float:
	match ship_class:
		"Sloop":
			return 0.70
		"Brig":
			return 0.82
		"Frigate":
			return 0.95
		"Merchantman":
			return 0.76
		_:
			return 0.8

func _begin_planning_round() -> void:
	_invalidate_player_movement_preview_cache()
	phase = Phase.PLANNING
	_move_anim_actor = ""
	player_sail_setting = player_ordered_sail_setting
	player_move_points = _movement_points_for(player_ship_class, player_navigator_skill, player_heading_deg)
	enemy_move_points = _movement_points_for(enemy_ship_class, enemy_navigator_skill, enemy_heading_deg)
	player_plan_end_pos = player_cell_pos
	player_plan_end_heading = player_heading_deg
	player_plan_board = false
	player_movement_plotted = false
	player_plan_terminal.clear()
	enemy_plan_terminal.clear()
	player_plan_preview_path.clear()
	player_round_path.clear()
	enemy_round_path.clear()
	player_turn_start_cell_pos = player_cell_pos
	_sync_player_run_cells_for_round()
	enemy_run_cells = 0
	enemy_run_heading_idx = enemy_heading_idx

func _sync_player_run_cells_for_round() -> void:
	if player_heading_idx != player_run_heading_idx:
		player_run_cells = 0
	player_run_heading_idx = player_heading_idx

func _movement_points_for(ship_class: String, navigator_skill: int, heading_deg: float) -> int:
	var base_mp: int = int(_ship_stats(ship_class).get("base_mp", 4))
	var skill_bonus: int = int(floor(float(navigator_skill) / 2.0))
	var wind_to_deg: float = fposmod(wind_direction_deg + 180.0, 360.0)
	var diff: float = absf(_angle_delta_deg(heading_deg, wind_to_deg))
	var wind_angle_mod: int = 0
	if diff < 35.0:
		wind_angle_mod = 1
	elif diff < 115.0:
		wind_angle_mod = 2
	elif diff < 145.0:
		wind_angle_mod = 0
	else:
		wind_angle_mod = -2
	var wind_speed_mod: int = 0
	if wind_speed_m_s > 10.0:
		wind_speed_mod = 1
	elif wind_speed_m_s < 2.5:
		wind_speed_mod = -1
	return clampi(base_mp + skill_bonus + wind_angle_mod + wind_speed_mod, 1, 9)

func _turn_cost_for(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("turn_cost", 1))

func get_player_turn_cost() -> int:
	return _turn_cost_for(player_ship_class)

func get_enemy_turn_cost() -> int:
	return _turn_cost_for(enemy_ship_class)

func _invalidate_player_movement_preview_cache() -> void:
	_player_movement_preview_cache_frame = -1
	_player_movement_preview_cache.clear()
	_sail_movement_hints_cache_frame = -1
	_sail_movement_hints_cache_key = ""
	_sail_movement_hints_cache.clear()
	_player_move_options_cache_frame = -1
	_player_move_options_cache_key = ""

func get_player_movement_preview() -> Dictionary:
	if phase != Phase.PLANNING:
		return {"reachable_cells": [], "terminal_cells": [], "forward_cells": [], "forward_step_cells": 1.0}
	var frame: int = Engine.get_process_frames()
	if _player_movement_preview_cache_frame == frame:
		return _player_movement_preview_cache
	var built: Dictionary = _build_movement_states(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_ship_class,
		player_cell,
		player_sail_setting,
		player_run_cells
	)
	var reachable: Dictionary = built["reachable"]
	var forward_cells: Array[Vector2i] = built["forward_cells"]
	var reachable_cells: Array[Vector2i] = []
	for c in reachable.keys():
		reachable_cells.append(c)
	var term_seen: Dictionary = {}
	var terminal_cells: Array[Vector2i] = []
	var move_options: Array[Dictionary] = []
	for s_variant in built["states"]:
		if not (s_variant is Dictionary):
			continue
		var decorated: Dictionary = _decorate_move_option(s_variant)
		if _is_player_start_move_option(decorated):
			continue
		if _is_move_option_behind_ship(decorated):
			continue
		move_options.append(decorated)
	move_options = _canonical_options_per_cell(move_options)
	for decorated in move_options:
		var cell: Vector2i = decorated["cell"]
		if term_seen.has(cell):
			continue
		term_seen[cell] = true
		terminal_cells.append(cell)
	var forward_mul: float = _sail_forward_multiplier(player_sail_setting)
	var preview: Dictionary = {
		"reachable_cells": reachable_cells,
		"terminal_cells": terminal_cells,
		"move_options": move_options,
		"flow_edges": built.get("flow_edges", []),
		"forward_cells": forward_cells,
		"forward_step_cells": _forward_cells_per_step(player_ship_class, player_heading_deg) * forward_mul * float(built["move_scale"])
	}
	_player_movement_preview_cache_frame = frame
	_player_movement_preview_cache = preview
	return preview

func get_player_reachable_cells() -> Array[Vector2i]:
	var preview: Dictionary = get_player_movement_preview()
	if preview.has("reachable_cells") and preview["reachable_cells"] is Array:
		return preview["reachable_cells"]
	return []

func can_player_move_to_cell(cell: Vector2i) -> bool:
	return not get_player_move_options_for_cell(cell).is_empty()

func can_player_move_to_option(cell: Vector2i, heading_idx: int) -> bool:
	for opt in get_player_move_options():
		if opt.get("cell", Vector2i(-1, -1)) == cell and int(opt.get("heading_idx", -1)) == heading_idx:
			return true
	return false

func execute_player_move_to_cell(target_cell: Vector2i, heading_idx: int = -1) -> bool:
	if heading_idx >= 0:
		return set_player_planned_move_option(target_cell, heading_idx)
	return set_player_planned_move_cell(target_cell)

func set_player_planned_move_option(target_cell: Vector2i, heading_idx: int) -> bool:
	if phase != Phase.PLANNING:
		return false
	for opt in get_player_move_options():
		if opt.get("cell", Vector2i(-1, -1)) == target_cell and int(opt.get("heading_idx", -1)) == heading_idx:
			return _apply_player_planned_move_state(opt)
	return false

func get_hazard_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in hazard_cells.keys():
		cells.append(cell)
	return cells

func get_combat_grid_feet() -> float:
	return COMBAT_GRID_FEET

func get_ship_max_hull(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("hull", 16))

func get_ship_max_crew(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("crew", 24))

func get_ship_length_cells(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("length_cells", 4))

func get_ship_width_cells(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("width_cells", 1))

func get_player_occupied_cells() -> Array[Vector2i]:
	return _ship_occupied_cells(player_cell_pos, player_heading_deg, player_ship_class)

func get_player_planned_occupied_cells() -> Array[Vector2i]:
	return _ship_occupied_cells(player_plan_end_pos, player_plan_end_heading, player_ship_class)

func get_enemy_occupied_cells() -> Array[Vector2i]:
	return _ship_occupied_cells(enemy_cell_pos, enemy_heading_deg, enemy_ship_class)

func get_player_occupied_cells_for_pose(pos: Vector2, heading_deg: float) -> Array[Vector2i]:
	return _ship_occupied_cells(pos, heading_deg, player_ship_class)

func get_enemy_occupied_cells_for_pose(pos: Vector2, heading_deg: float) -> Array[Vector2i]:
	return _ship_occupied_cells(pos, heading_deg, enemy_ship_class)

func _generate_hazards(near_land: bool) -> void:
	hazard_cells.clear()
	if not near_land:
		return
	# Treat edge shoals/reefs as immediate-loss hazards when combat occurs close to land.
	for x in range(combat_cols):
		hazard_cells[Vector2i(x, 0)] = true
		hazard_cells[Vector2i(x, combat_rows - 1)] = true
	for y in range(combat_rows):
		hazard_cells[Vector2i(0, y)] = true
		hazard_cells[Vector2i(combat_cols - 1, y)] = true

func _check_collision_with_hazard(cell: Vector2i) -> bool:
	if not hazard_cells.has(cell) and not _ship_footprint_hits_hazard(player_cell_pos, player_heading_deg, player_ship_class):
		return false
	phase = Phase.RESOLVED
	emit_signal("battle_updated", "Your ship strikes coastal hazards and is lost.")
	emit_signal("battle_finished", false, false)
	return true

func _check_collision_with_hazard_enemy(cell: Vector2i) -> bool:
	if not hazard_cells.has(cell) and not _ship_footprint_hits_hazard(enemy_cell_pos, enemy_heading_deg, enemy_ship_class):
		return false
	phase = Phase.RESOLVED
	emit_signal("battle_updated", "The enemy is thrown onto the shoals and breaks up.")
	emit_signal("battle_finished", true, false)
	return true

func can_player_commit_round() -> bool:
	return can_player_end_turn()

func is_player_movement_plotted() -> bool:
	return player_movement_plotted

func cycle_player_sail(delta: int) -> void:
	if phase != Phase.PLANNING:
		return
	_order_player_sail(_sail_setting_from_index(int(player_ordered_sail_setting) + delta))

func set_player_sail_setting(sail: SailSetting) -> void:
	if phase != Phase.PLANNING:
		return
	_order_player_sail(sail)

func set_player_sail_index(idx: int) -> void:
	set_player_sail_setting(_sail_setting_from_index(idx))

func _order_player_sail(sail: SailSetting) -> void:
	if sail == player_ordered_sail_setting:
		return
	player_ordered_sail_setting = sail
	if sail == player_sail_setting:
		emit_signal("battle_updated", "%s sail confirmed for this turn." % _sail_label(sail))
	else:
		emit_signal("battle_updated", "%s sail ordered—takes effect next turn." % _sail_label(sail))

func _sail_label(sail: SailSetting) -> String:
	match sail:
		SailSetting.SLOW:
			return "Slow"
		SailSetting.BATTLE:
			return "Battle"
		_:
			return "Full"

func _sail_setting_from_index(i: int) -> SailSetting:
	match posmod(i, 3):
		0:
			return SailSetting.SLOW
		1:
			return SailSetting.BATTLE
		_:
			return SailSetting.FULL

func get_sail_movement_hints() -> Dictionary:
	if phase != Phase.PLANNING:
		return {}
	var cache_key: String = "%.3f,%.3f|%.2f|%d" % [
		player_cell_pos.x, player_cell_pos.y, player_heading_deg, player_move_points
	]
	var frame: int = Engine.get_process_frames()
	if frame == _sail_movement_hints_cache_frame and cache_key == _sail_movement_hints_cache_key:
		return _sail_movement_hints_cache
	var out: Dictionary = {}
	for si in range(3):
		var sail: SailSetting = _sail_setting_from_index(si)
		var built: Dictionary = _build_movement_states(
			player_cell_pos,
			player_heading_deg,
			player_move_points,
			player_ship_class,
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class,
			player_cell,
			sail,
			player_run_cells
		)
		var terms: Array[Dictionary] = _collect_terminal_states(
			built["states"],
			player_ship_class,
			enemy_cell_pos,
			enemy_heading_deg,
			enemy_ship_class,
			sail,
			float(built["move_scale"])
		)
		var max_cheb: int = 0
		for s in terms:
			max_cheb = maxi(max_cheb, _grid_chebyshev_distance(player_cell, s["cell"]))
		var fwd: Array = built["forward_cells"]
		var straight_n: int = fwd.size() if fwd is Array else 0
		var forward_mul: float = _sail_forward_multiplier(sail)
		out[si] = {
			"max_chebyshev": max_cheb,
			"straight_cells": straight_n,
			"forward_step_cells": _forward_cells_per_step(player_ship_class, player_heading_deg) * forward_mul * float(built["move_scale"]),
			"terminal_count": terms.size()
		}
	_sail_movement_hints_cache_frame = frame
	_sail_movement_hints_cache_key = cache_key
	_sail_movement_hints_cache = out
	return out

func _combat_move_scale_for(ship_class: String, start_heading: float, _start_mp: int) -> float:
	var stats: Dictionary = _ship_stats(ship_class)
	var hull_len: float = float(max(1, get_ship_length_cells(ship_class)))
	var target_cells: float = STRAIGHT_HULL_LENGTHS_AT_FULL * hull_len
	var unit_full: float = _forward_cells_per_step(ship_class, start_heading) * _sail_forward_multiplier(SailSetting.FULL)
	var base_mp: int = int(stats.get("base_mp", 4))
	var denom: float = maxf(0.25, float(maxi(1, base_mp)) * unit_full)
	return clampf(target_cells / denom, COMBAT_MOVE_SCALE_MIN, COMBAT_MOVE_SCALE_MAX)

func _sail_forward_multiplier(sail: SailSetting) -> float:
	match sail:
		SailSetting.SLOW:
			return 0.72
		SailSetting.BATTLE:
			return 1.0
		SailSetting.FULL:
			return 1.28
		_:
			return 1.0

func _sail_turn_step_multiplier(sail: SailSetting) -> float:
	match sail:
		SailSetting.SLOW:
			return 0.50
		SailSetting.BATTLE:
			return 0.72
		SailSetting.FULL:
			return 0.98
		_:
			return 0.72

func _min_run_cells_before_turn(_sail: SailSetting) -> int:
	return 0

func _can_initiate_turn_from_state(_state: Dictionary, _sail: SailSetting) -> bool:
	return true

func _run_cells_after_forward(from_cell: Vector2i, from_run: int, to_cell: Vector2i) -> int:
	var advanced: int = _grid_chebyshev_distance(from_cell, to_cell)
	if advanced <= 0:
		return from_run
	return from_run + advanced

func _run_cells_after_turn(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return maxi(1, _grid_chebyshev_distance(from_cell, to_cell))

func _better_player_terminal_for_cell(a: Dictionary, b: Dictionary) -> bool:
	var am: int = int(a["mp"])
	var bm: int = int(b["mp"])
	if am == 0 and bm != 0:
		return true
	if bm == 0 and am != 0:
		return false
	if am != bm:
		return am < bm
	var ad: float = absf(_angle_delta_deg(player_heading_deg, float(a["heading_deg"])))
	var bd: float = absf(_angle_delta_deg(player_heading_deg, float(b["heading_deg"])))
	return ad < bd

func _better_player_stop_state_for_cell(a: Dictionary, b: Dictionary) -> bool:
	return _better_canonical_stop_for_cell(a, b)

func _turn_count_from_start(state: Dictionary) -> int:
	var turns: int = 0
	var cur: Variant = state
	var prev_hdg: int = -1
	while cur is Dictionary:
		var d: Dictionary = cur
		var hdg: int = int(d.get("heading_idx", _bearing_to_heading_idx(float(d.get("heading_deg", 0.0)))))
		if prev_hdg >= 0 and hdg != prev_hdg:
			turns += 1
		prev_hdg = hdg
		if not d.has("parent") or not (d["parent"] is Dictionary):
			break
		cur = d["parent"]
	return turns

func _movement_step_alignment(state: Dictionary) -> float:
	if not state.has("parent") or not (state["parent"] is Dictionary):
		return 1.0
	var parent: Dictionary = state["parent"]
	if not parent.has("cell"):
		return 1.0
	var delta: Vector2 = Vector2(state["cell"] - parent["cell"])
	if delta.length_squared() < 0.01:
		return 1.0
	var step_dir: Vector2 = delta.normalized()
	var heading_vec: Vector2 = _bearing_deg_to_vector(float(state["heading_deg"])).normalized()
	return step_dir.dot(heading_vec)

func _better_canonical_stop_for_cell(a: Dictionary, b: Dictionary) -> bool:
	# Prefer cheapest route: most MP left, fewest turns from start, aligned with step-in direction.
	var am: int = int(a["mp"])
	var bm: int = int(b["mp"])
	if am != bm:
		return am > bm
	var at: int = _turn_count_from_start(a)
	var bt: int = _turn_count_from_start(b)
	if at != bt:
		return at < bt
	var aa: float = _movement_step_alignment(a)
	var ab: float = _movement_step_alignment(b)
	if absf(aa - ab) > 0.01:
		return aa > ab
	var ad: float = absf(_angle_delta_deg(player_heading_deg, float(a["heading_deg"])))
	var bd: float = absf(_angle_delta_deg(player_heading_deg, float(b["heading_deg"])))
	return ad < bd

func _player_plan_is_valid_state() -> bool:
	if player_plan_terminal.is_empty():
		return false
	var built: Dictionary = _build_movement_states(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_ship_class,
		player_cell,
		player_sail_setting,
		player_run_cells
	)
	var plan_key: String = _movement_state_dict_key(player_plan_terminal)
	for s_variant in built["states"]:
		if not s_variant is Dictionary:
			continue
		var s: Dictionary = s_variant
		if _movement_state_dict_key(s) == plan_key:
			return true
	return false

func _leg_path_has_motion() -> bool:
	if player_plan_preview_path.size() < 2:
		return false
	if player_plan_end_pos.distance_to(player_cell_pos) > 0.05:
		return true
	return absf(_angle_delta_deg(player_plan_end_heading, player_heading_deg)) > 0.5

func _clear_player_leg_plan() -> void:
	_invalidate_player_movement_preview_cache()
	player_movement_plotted = false
	player_plan_terminal.clear()
	player_plan_preview_path.clear()
	player_plan_end_pos = player_cell_pos
	player_plan_end_heading = player_heading_deg

func _apply_leg_remaining_move_points() -> void:
	player_move_points = int(player_plan_terminal.get("mp", player_move_points))

func _commit_player_run_cells_after_leg() -> void:
	if player_plan_terminal.is_empty():
		return
	player_run_cells = int(player_plan_terminal.get("run_cells", 0))
	player_run_heading_idx = player_heading_idx

func _commit_enemy_run_cells_after_move() -> void:
	if enemy_plan_terminal.is_empty():
		return
	enemy_run_cells = int(enemy_plan_terminal.get("run_cells", 0))
	enemy_run_heading_idx = enemy_heading_idx

func _finish_player_move_leg_without_animation() -> void:
	_snap_player_pose_to_planned()
	_apply_leg_remaining_move_points()
	_commit_player_run_cells_after_leg()
	if _resolve_player_leg_effects():
		_move_anim_actor = ""
		if phase == Phase.RESOLVED:
			return
		if phase == Phase.MOVE_ANIM:
			phase = Phase.PLANNING
		return
	var remaining: int = player_move_points
	_clear_player_leg_plan()
	_move_anim_actor = ""
	phase = Phase.PLANNING
	emit_signal(
		"battle_updated",
		"%d MP left — fire cannons, plot your next move, or end turn (E)." % remaining
	)

func _finish_player_move_leg_after_animation() -> void:
	_snap_player_pose_to_planned()
	_apply_leg_remaining_move_points()
	_commit_player_run_cells_after_leg()
	if _resolve_player_leg_effects():
		_move_anim_actor = ""
		if phase == Phase.RESOLVED:
			return
		if phase == Phase.MOVE_ANIM:
			phase = Phase.PLANNING
		return
	var remaining: int = player_move_points
	_clear_player_leg_plan()
	_move_anim_actor = ""
	phase = Phase.PLANNING
	emit_signal(
		"battle_updated",
		"%d MP left — fire cannons, plot your next move, or end turn (E)." % remaining
	)

func _movement_state_can_expand(
	s: Dictionary,
	ship_class: String,
	other_pos: Vector2,
	other_heading_deg: float,
	other_ship_class: String,
	sail: SailSetting,
	move_scale: float
) -> bool:
	var pos: Vector2 = s["pos"]
	var heading_deg: float = float(s["heading_deg"])
	var heading_idx: int = int(s.get("heading_idx", _bearing_to_heading_idx(heading_deg)))
	var mp: int = int(s["mp"])
	var forward_mul: float = _sail_forward_multiplier(sail)
	var turn_mul: float = _sail_turn_step_multiplier(sail)
	var turn_cost: int = _turn_cost_for(ship_class)
	if mp >= 1:
		var step_cells: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale
		var next_pos: Vector2 = pos + _bearing_deg_to_vector(heading_deg) * step_cells
		var nsp: Vector2 = _snap_ship_center_to_cell_center(next_pos)
		if _is_valid_ship_pose(nsp, heading_deg, ship_class, other_pos, other_heading_deg, other_ship_class):
			return true
	if mp >= turn_cost and _can_initiate_turn_from_state(s, sail):
		var left_heading_deg: float = _heading_idx_to_bearing(posmod(heading_idx - 1, 8))
		var right_heading_deg: float = _heading_idx_to_bearing(posmod(heading_idx + 1, 8))
		var turn_step: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale * turn_mul
		var left_pos: Vector2 = pos + _bearing_deg_to_vector(left_heading_deg) * turn_step
		var right_pos: Vector2 = pos + _bearing_deg_to_vector(right_heading_deg) * turn_step
		var lsp: Vector2 = _snap_ship_center_to_cell_center(left_pos)
		var rsp: Vector2 = _snap_ship_center_to_cell_center(right_pos)
		if _is_valid_ship_pose(lsp, left_heading_deg, ship_class, other_pos, other_heading_deg, other_ship_class):
			return true
		if _is_valid_ship_pose(rsp, right_heading_deg, ship_class, other_pos, other_heading_deg, other_ship_class):
			return true
	return false

func _collect_terminal_states(
	states: Array,
	ship_class: String,
	other_pos: Vector2,
	other_heading_deg: float,
	other_ship_class: String,
	sail: SailSetting,
	move_scale: float
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(states.size()):
		var s_variant: Variant = states[i]
		if not (s_variant is Dictionary):
			continue
		var s: Dictionary = s_variant
		if not _movement_state_can_expand(s, ship_class, other_pos, other_heading_deg, other_ship_class, sail, move_scale):
			out.append(s)
	return out

func _build_movement_states(
	start_pos: Vector2,
	start_heading: float,
	start_mp: int,
	ship_class: String,
	other_ship_pos: Vector2,
	other_ship_heading: float,
	other_ship_class: String,
	start_cell: Vector2i,
	sail: SailSetting = SailSetting.BATTLE,
	start_run_cells: int = 0
) -> Dictionary:
	start_pos = _snap_ship_center_to_cell_center(start_pos)
	start_cell = _ship_anchor_cell(start_pos)
	var forward_mul: float = _sail_forward_multiplier(sail)
	var turn_mul: float = _sail_turn_step_multiplier(sail)
	var move_scale: float = _combat_move_scale_for(ship_class, start_heading, start_mp)
	var reachable: Dictionary = {}
	var forward_cells: Array[Vector2i] = []
	var flow_edges: Array[Dictionary] = []
	var start_heading_idx: int = _bearing_to_heading_idx(start_heading)
	var start_state: Dictionary = {
		"pos": start_pos,
		"heading_deg": start_heading,
		"heading_idx": start_heading_idx,
		"mp": start_mp,
		"cell": start_cell,
		"run_cells": maxi(0, start_run_cells)
	}
	var open: Array[Dictionary] = [start_state]
	var all_states: Array[Dictionary] = [start_state.duplicate(true)]
	var seen: Dictionary = {}
	var turn_cost: int = _turn_cost_for(ship_class)

	while not open.is_empty():
		var state: Dictionary = open.pop_front()
		var pos: Vector2 = state["pos"]
		var heading_deg: float = float(state["heading_deg"])
		var heading_idx: int = int(state.get("heading_idx", _bearing_to_heading_idx(heading_deg)))
		var mp: int = int(state["mp"])
		var cell: Vector2i = _ship_anchor_cell(pos)
		var run_cells: int = int(state.get("run_cells", 0))
		var key: String = "%d:%d:%d:%d:%d" % [cell.x, cell.y, heading_idx, mp, run_cells]
		if seen.has(key):
			continue
		seen[key] = true
		reachable[cell] = true

		if mp >= 1:
			var step_cells: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale
			var next_pos: Vector2 = pos + _bearing_deg_to_vector(heading_deg) * step_cells
			var nsp: Vector2 = _snap_ship_center_to_cell_center(next_pos)
			if _is_valid_ship_pose(nsp, heading_deg, ship_class, other_ship_pos, other_ship_heading, other_ship_class):
				var next_cell: Vector2i = _ship_anchor_cell(nsp)
				var next_state: Dictionary = {
					"pos": nsp,
					"heading_deg": heading_deg,
					"heading_idx": heading_idx,
					"mp": mp - 1,
					"cell": next_cell,
					"run_cells": _run_cells_after_forward(cell, run_cells, next_cell),
					"parent": state
				}
				open.append(next_state)
				all_states.append(next_state.duplicate(true))
				flow_edges.append({
					"from_cell": cell,
					"from_heading_idx": heading_idx,
					"to_cell": next_cell,
					"to_heading_idx": heading_idx
				})
		if mp >= turn_cost and _can_initiate_turn_from_state(state, sail):
			var left_idx: int = posmod(heading_idx - 1, 8)
			var right_idx: int = posmod(heading_idx + 1, 8)
			var left_heading_deg: float = _heading_idx_to_bearing(left_idx)
			var right_heading_deg: float = _heading_idx_to_bearing(right_idx)
			var turn_step: float = _forward_cells_per_step(ship_class, heading_deg) * forward_mul * move_scale * turn_mul
			var left_pos: Vector2 = pos + _bearing_deg_to_vector(left_heading_deg) * turn_step
			var right_pos: Vector2 = pos + _bearing_deg_to_vector(right_heading_deg) * turn_step
			var lsp: Vector2 = _snap_ship_center_to_cell_center(left_pos)
			if _is_valid_ship_pose(lsp, left_heading_deg, ship_class, other_ship_pos, other_ship_heading, other_ship_class):
				var lc: Vector2i = _ship_anchor_cell(lsp)
				var left_state: Dictionary = {
					"pos": lsp,
					"heading_deg": left_heading_deg,
					"heading_idx": left_idx,
					"mp": mp - turn_cost,
					"cell": lc,
					"run_cells": _run_cells_after_turn(cell, lc),
					"parent": state
				}
				open.append(left_state)
				all_states.append(left_state.duplicate(true))
				flow_edges.append({
					"from_cell": cell,
					"from_heading_idx": heading_idx,
					"to_cell": lc,
					"to_heading_idx": left_idx
				})
			var rsp: Vector2 = _snap_ship_center_to_cell_center(right_pos)
			if _is_valid_ship_pose(rsp, right_heading_deg, ship_class, other_ship_pos, other_ship_heading, other_ship_class):
				var rc: Vector2i = _ship_anchor_cell(rsp)
				var right_state: Dictionary = {
					"pos": rsp,
					"heading_deg": right_heading_deg,
					"heading_idx": right_idx,
					"mp": mp - turn_cost,
					"cell": rc,
					"run_cells": _run_cells_after_turn(cell, rc),
					"parent": state
				}
				open.append(right_state)
				all_states.append(right_state.duplicate(true))
				flow_edges.append({
					"from_cell": cell,
					"from_heading_idx": heading_idx,
					"to_cell": rc,
					"to_heading_idx": right_idx
				})

	var straight_pos: Vector2 = start_pos
	for _i in range(start_mp):
		straight_pos += _bearing_deg_to_vector(start_heading) * _forward_cells_per_step(ship_class, start_heading) * forward_mul * move_scale
		straight_pos = _snap_ship_center_to_cell_center(straight_pos)
		if not _is_valid_ship_pose(straight_pos, start_heading, ship_class, other_ship_pos, other_ship_heading, other_ship_class):
			break
		forward_cells.append(_ship_anchor_cell(straight_pos))

	return {
		"reachable": reachable,
		"forward_cells": forward_cells,
		"states": all_states,
		"flow_edges": flow_edges,
		"move_scale": move_scale
	}

func get_player_action_guidance() -> Dictionary:
	if phase != Phase.PLANNING:
		return {}
	var forward_mul: float = _sail_forward_multiplier(player_sail_setting)
	var turn_mul: float = _sail_turn_step_multiplier(player_sail_setting)
	var move_scale: float = _combat_move_scale_for(player_ship_class, player_heading_deg, player_move_points)
	var turn_cost: int = _turn_cost_for(player_ship_class)
	var guidance := {
		"forward": {
			"label": "Forward",
			"cost": 1,
			"can_execute": false,
			"target_cell": player_cell,
			"target_pos": player_cell_pos
		},
		"left": {
			"label": "Left Turn+Advance",
			"cost": turn_cost,
			"can_execute": false,
			"target_cell": player_cell,
			"target_pos": player_cell_pos
		},
		"right": {
			"label": "Right Turn+Advance",
			"cost": turn_cost,
			"can_execute": false,
			"target_cell": player_cell,
			"target_pos": player_cell_pos
		}
	}

	# Forward action
	if player_move_points >= 1:
		var f_step: float = _forward_cells_per_step(player_ship_class, player_heading_deg) * forward_mul * move_scale
		var f_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(player_heading_deg) * f_step
		var f_snapped: Vector2 = _snap_ship_center_to_cell_center(f_pos)
		if _is_valid_ship_pose(f_snapped, player_heading_deg, player_ship_class, enemy_cell_pos, enemy_heading_deg, enemy_ship_class):
			guidance["forward"] = {
				"label": "Forward",
				"cost": 1,
				"can_execute": true,
				"target_cell": _ship_anchor_cell(f_snapped),
				"target_pos": f_snapped
			}

	# Left turn+advance (port = -45°)
	var start_run_state: Dictionary = {"run_cells": player_run_cells}
	if player_move_points >= turn_cost and _can_initiate_turn_from_state(start_run_state, player_sail_setting):
		var left_heading: float = _heading_idx_to_bearing(posmod(_bearing_to_heading_idx(player_heading_deg) - 1, 8))
		var l_step: float = _forward_cells_per_step(player_ship_class, player_heading_deg) * forward_mul * move_scale * turn_mul
		var l_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(left_heading) * l_step
		var l_snapped: Vector2 = _snap_ship_center_to_cell_center(l_pos)
		if _is_valid_ship_pose(l_snapped, left_heading, player_ship_class, enemy_cell_pos, enemy_heading_deg, enemy_ship_class):
			guidance["left"] = {
				"label": "Left Turn+Advance",
				"cost": turn_cost,
				"can_execute": true,
				"target_cell": _ship_anchor_cell(l_snapped),
				"target_pos": l_snapped
			}

	# Right turn+advance (starboard = +45°)
	if player_move_points >= turn_cost and _can_initiate_turn_from_state(start_run_state, player_sail_setting):
		var right_heading: float = _heading_idx_to_bearing(posmod(_bearing_to_heading_idx(player_heading_deg) + 1, 8))
		var r_step: float = _forward_cells_per_step(player_ship_class, player_heading_deg) * forward_mul * move_scale * turn_mul
		var r_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(right_heading) * r_step
		var r_snapped: Vector2 = _snap_ship_center_to_cell_center(r_pos)
		if _is_valid_ship_pose(r_snapped, right_heading, player_ship_class, enemy_cell_pos, enemy_heading_deg, enemy_ship_class):
			guidance["right"] = {
				"label": "Right Turn+Advance",
				"cost": turn_cost,
				"can_execute": true,
				"target_cell": _ship_anchor_cell(r_snapped),
				"target_pos": r_snapped
			}
	return guidance

func get_player_gun_range_overlay_cells(
	battery: int, view_origin: Vector2 = Vector2.ZERO, view_cols: int = -1, view_rows: int = -1
) -> Array[Dictionary]:
	if phase != Phase.PLANNING:
		_gun_range_overlay_cache_key = ""
		_gun_range_overlay_cache = []
		return []
	if battery != 0 and battery != 1:
		return []
	var cache_key: String = "%d|%.4f,%.4f|%.2f|%d,%d|%.2f,%.2f" % [
		battery,
		player_position.x,
		player_position.y,
		player_heading_deg,
		view_cols,
		view_rows,
		view_origin.x,
		view_origin.y
	]
	if cache_key == _gun_range_overlay_cache_key:
		return _gun_range_overlay_cache
	var out: Array[Dictionary] = []
	var denom_x: float = float(max(1, combat_cols - 1))
	var denom_y: float = float(max(1, combat_rows - 1))
	var att_norm: Vector2 = player_position
	var att_h: float = player_heading_deg
	var anchor_cell: Vector2i = player_cell
	var x0: int = 0
	var y0: int = 0
	var x1: int = combat_cols
	var y1: int = combat_rows
	if view_cols > 0 and view_rows > 0:
		x0 = clampi(int(floor(view_origin.x)), 0, combat_cols - 1)
		y0 = clampi(int(floor(view_origin.y)), 0, combat_rows - 1)
		x1 = clampi(int(ceil(view_origin.x + float(view_cols))), 0, combat_cols)
		y1 = clampi(int(ceil(view_origin.y + float(view_rows))), 0, combat_rows)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var cell := Vector2i(x, y)
			if cell == anchor_cell:
				continue
			var target_pos := Vector2((float(x) + 0.5) / denom_x, (float(y) + 0.5) / denom_y)
			if not _battery_covers_norm_target(
				battery, att_norm, att_h, player_ship_class, target_pos, enemy_heading_deg
			):
				continue
			var yds: float = _yards_between_norm_positions(att_norm, target_pos)
			var pch: float = _cannon_per_gun_hit_chance_at_yards(yds)
			var band: int = 0
			if pch >= 0.75:
				band = 3
			elif pch >= 0.50:
				band = 2
			elif pch >= 0.25:
				band = 1
			out.append({"cell": cell, "band": band, "yards": int(round(yds)), "p_hit": pch})
	_gun_range_overlay_cache_key = cache_key
	_gun_range_overlay_cache = out
	return out

func get_player_gun_range_preview_cells(battery: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for e in get_player_gun_range_overlay_cells(battery):
		cells.append(e["cell"] as Vector2i)
	return cells

func enemy_in_player_battery_range(battery: int) -> bool:
	if phase != Phase.PLANNING:
		return false
	return _battery_covers_norm_target(
		battery, player_position, player_heading_deg, player_ship_class, enemy_position, enemy_heading_deg
	)

func _sync_pose_from_positions() -> void:
	player_cell_pos = _snap_ship_center_to_cell_center(player_cell_pos)
	player_cell_pos.x = clampf(player_cell_pos.x, 0.5, float(combat_cols) - 0.5)
	player_cell_pos.y = clampf(player_cell_pos.y, 0.5, float(combat_rows) - 0.5)
	enemy_cell_pos = _snap_ship_center_to_cell_center(enemy_cell_pos)
	enemy_cell_pos.x = clampf(enemy_cell_pos.x, 0.5, float(combat_cols) - 0.5)
	enemy_cell_pos.y = clampf(enemy_cell_pos.y, 0.5, float(combat_rows) - 0.5)
	player_cell = _ship_anchor_cell(player_cell_pos)
	enemy_cell = _ship_anchor_cell(enemy_cell_pos)
	var dx: float = float(max(1, combat_cols - 1))
	var dy: float = float(max(1, combat_rows - 1))
	player_position = Vector2((player_cell_pos.x - 0.5) / dx, (player_cell_pos.y - 0.5) / dy)
	enemy_position = Vector2((enemy_cell_pos.x - 0.5) / dx, (enemy_cell_pos.y - 0.5) / dy)

func _heading_idx_to_step(idx: int) -> Vector2i:
	match posmod(idx, 8):
		0:
			return Vector2i(0, -1)
		1:
			return Vector2i(1, -1)
		2:
			return Vector2i(1, 0)
		3:
			return Vector2i(1, 1)
		4:
			return Vector2i(0, 1)
		5:
			return Vector2i(-1, 1)
		6:
			return Vector2i(-1, 0)
		_:
			return Vector2i(-1, -1)

func _heading_idx_to_bearing(idx: int) -> float:
	return float(posmod(idx, 8)) * 45.0

func _bearing_to_heading_idx(bearing_deg: float) -> int:
	return posmod(int(round(fposmod(bearing_deg, 360.0) / 45.0)), 8)

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < combat_cols and cell.y < combat_rows

func _is_valid_pos(pos: Vector2) -> bool:
	return pos.x >= 0.5 and pos.y >= 0.5 and pos.x <= float(combat_cols) - 0.5 and pos.y <= float(combat_rows) - 0.5

## Hull pivot stays on cell centers (n+0.5, m+0.5); broad hull does not snap to a cell lattice.
func _snap_ship_center_to_cell_center(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x - 0.5) + 0.5, round(pos.y - 0.5) + 0.5)

func _ship_anchor_cell(center_pos: Vector2) -> Vector2i:
	var c: Vector2 = _snap_ship_center_to_cell_center(center_pos)
	return Vector2i(int(round(c.x - 0.5)), int(round(c.y - 0.5)))

func _ship_center_margin_from_edge(ship_class: String) -> float:
	return maxf(float(get_ship_length_cells(ship_class)), float(get_ship_width_cells(ship_class))) * 0.5 + 0.3

func _ship_center_min_separation_cells(class_a: String, class_b: String) -> float:
	var ea: float = maxf(float(get_ship_length_cells(class_a)), float(get_ship_width_cells(class_a))) * 0.5
	var eb: float = maxf(float(get_ship_length_cells(class_b)), float(get_ship_width_cells(class_b))) * 0.5
	return ea + eb + 0.35

func _is_valid_ship_pose(
	pos: Vector2,
	_heading_deg: float,
	ship_class: String,
	other_pos: Vector2,
	_other_heading_deg: float,
	other_ship_class: String
) -> bool:
	var c: Vector2 = _snap_ship_center_to_cell_center(pos)
	if not _is_valid_pos(c):
		return false
	var margin: float = _ship_center_margin_from_edge(ship_class)
	if c.x < margin or c.y < margin or c.x > float(combat_cols) - 0.5 - margin or c.y > float(combat_rows) - 0.5 - margin:
		return false
	if _ship_footprints_overlap(c, _heading_deg, ship_class, other_pos, _other_heading_deg, other_ship_class):
		return false
	if _is_heading_in_irons(_heading_deg):
		return false
	return true

func _is_heading_in_irons(_heading_deg: float) -> bool:
	# Allow ships to turn into the wind (in irons), but they move very slowly.
	# We only block it if they are stationary or to prevent 'illegal' states if needed,
	# but for pure turning we should allow it.
	return false

func _ship_footprints_overlap(
	a_pos: Vector2,
	a_heading_deg: float,
	a_ship_class: String,
	b_pos: Vector2,
	b_heading_deg: float,
	b_ship_class: String
) -> bool:
	var a_cells: Dictionary = {}
	for cell in _ship_occupied_cells(a_pos, a_heading_deg, a_ship_class):
		a_cells[cell] = true
	for cell in _ship_occupied_cells(b_pos, b_heading_deg, b_ship_class):
		if a_cells.has(cell):
			return true
	return false

func _ship_occupied_cells(pos: Vector2, heading_deg: float, ship_class: String) -> Array[Vector2i]:
	var anchor: Vector2i = _ship_anchor_cell(pos)
	var length_cells: int = get_ship_length_cells(ship_class)
	var width_cells: int = get_ship_width_cells(ship_class)
	var heading_idx: int = _bearing_to_heading_idx(heading_deg)
	var forward: Vector2i = _heading_idx_to_step(heading_idx)
	var starboard: Vector2i = Vector2i(-forward.y, forward.x)
	var half_l: int = length_cells / 2
	var half_w: int = width_cells / 2
	var cells: Array[Vector2i] = []
	for dl in range(-half_l, length_cells - half_l):
		for dw in range(-half_w, width_cells - half_w):
			var cell: Vector2i = anchor + forward * dl + starboard * dw
			if _is_valid_cell(cell):
				cells.append(cell)
	if cells.is_empty():
		cells.append(anchor)
	return cells

func _ship_footprint_hits_hazard(pos: Vector2, heading_deg: float, ship_class: String) -> bool:
	for cell in _ship_occupied_cells(pos, heading_deg, ship_class):
		if hazard_cells.has(cell):
			return true
	return false

func _ship_footprint_distance(
	a_pos: Vector2,
	a_heading_deg: float,
	a_ship_class: String,
	b_pos: Vector2,
	b_heading_deg: float,
	b_ship_class: String
) -> int:
	var best: int = 999999
	for a_cell in _ship_occupied_cells(a_pos, a_heading_deg, a_ship_class):
		for b_cell in _ship_occupied_cells(b_pos, b_heading_deg, b_ship_class):
			best = mini(best, _grid_chebyshev_distance(a_cell, b_cell))
	return best

func _grid_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _forward_cells_per_step(ship_class: String, heading_deg: float) -> float:
	var base: float = float(_ship_stats(ship_class).get("forward_cells", 1.2))
	var wind_to_deg: float = fposmod(wind_direction_deg + 180.0, 360.0)
	var diff: float = absf(_angle_delta_deg(heading_deg, wind_to_deg))
	var angle_factor: float
	if diff < 120.0:
		angle_factor = lerpf(1.2, 1.0, diff / 120.0)
	elif diff < 150.0:
		angle_factor = lerpf(1.0, 0.5, (diff - 120.0) / 30.0)
	else:
		angle_factor = lerpf(0.5, 0.2, (diff - 150.0) / 30.0)
	var wind_factor: float = clampf(0.8 + (wind_speed_m_s / 15.0), 0.7, 1.3)
	if diff > 160.0:
		# Penalize speed heavily when in irons, but keep a higher minimum for turning
		angle_factor *= 0.15
	return clampf(base * angle_factor * wind_factor, 0.25, 2.5)

func _turn_forward_cells(ship_class: String, heading_deg: float, sail: SailSetting = SailSetting.BATTLE) -> float:
	return _forward_cells_per_step(ship_class, heading_deg) * _sail_turn_step_multiplier(sail)

func _battery_beam_direction(attacker_heading_deg: float, battery: int) -> Vector2:
	# Port = ship's left, starboard = ship's right (fixed relative to bow), Y-down screen space.
	var forward: Vector2 = _bearing_deg_to_vector(attacker_heading_deg)
	var starboard: Vector2 = Vector2(-forward.y, forward.x)
	if battery == 0:
		return -starboard
	return starboard

func _battery_covers_norm_target(
	battery: int,
	attacker_pos_norm: Vector2,
	attacker_heading_deg: float,
	attacker_class: String,
	target_pos_norm: Vector2,
	_target_heading_deg: float = 0.0
) -> bool:
	var arc: Dictionary = _target_in_cannon_arc(
		attacker_pos_norm, attacker_heading_deg, attacker_class, target_pos_norm
	)
	if not bool(arc.get("in_arc", false)):
		return false
	var delta: Vector2 = target_pos_norm - attacker_pos_norm
	if delta.length_squared() <= 0.0001:
		return false
	var beam: Vector2 = _battery_beam_direction(attacker_heading_deg, battery)
	return beam.dot(delta.normalized()) > 0.0

func _broadside_battery_for_target(
	attacker_heading_deg: float,
	attacker_pos: Vector2,
	target_pos: Vector2,
	attacker_class: String,
	target_heading_deg: float
) -> int:
	if _battery_covers_norm_target(1, attacker_pos, attacker_heading_deg, attacker_class, target_pos, target_heading_deg):
		return 1
	if _battery_covers_norm_target(0, attacker_pos, attacker_heading_deg, attacker_class, target_pos, target_heading_deg):
		return 0
	return 0

func _bearing_deg_to_vector(bearing_deg: float) -> Vector2:
	var math_deg: float = deg_to_rad(90.0 - bearing_deg)
	return Vector2(cos(math_deg), sin(math_deg)).normalized()

func _vector_to_bearing_deg(v: Vector2) -> float:
	if v.length() <= 0.0001:
		return 90.0
	return fposmod(90.0 - rad_to_deg(atan2(v.y, v.x)), 360.0)

func _angle_delta_deg(a: float, b: float) -> float:
	return fposmod(b - a + 540.0, 360.0) - 180.0

func _ship_stats(ship_class: String) -> Dictionary:
	match ship_class:
		"Sloop":
			return {"hull": 14, "crew": 20, "maneuver": 0.06, "broadside": 4, "base_mp": 5, "turn_cost": 1, "forward_cells": 0.68, "length_cells": 2, "width_cells": 1}
		"Brig":
			return {"hull": 18, "crew": 28, "maneuver": 0.055, "broadside": 5, "base_mp": 4, "turn_cost": 1, "forward_cells": 0.6, "length_cells": 3, "width_cells": 1}
		"Frigate":
			return {"hull": 24, "crew": 40, "maneuver": 0.05, "broadside": 7, "base_mp": 3, "turn_cost": 2, "forward_cells": 0.53, "length_cells": 3, "width_cells": 1}
		"Merchantman":
			return {"hull": 20, "crew": 22, "maneuver": 0.045, "broadside": 3, "base_mp": 3, "turn_cost": 2, "forward_cells": 0.48, "length_cells": 3, "width_cells": 1}
		_:
			return {"hull": 16, "crew": 24, "maneuver": 0.055, "broadside": 4, "base_mp": 4, "turn_cost": 1, "forward_cells": 0.55, "length_cells": 2, "width_cells": 1}

func _save_vec2(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

func _load_vec2(data: Variant, fallback: Vector2) -> Vector2:
	if data is Dictionary:
		return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
	return fallback

func _save_vec2i(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}

func _load_vec2i(data: Variant, fallback: Vector2i) -> Vector2i:
	if data is Dictionary:
		return Vector2i(int(data.get("x", fallback.x)), int(data.get("y", fallback.y)))
	return fallback

func _save_pose_path(path: Array) -> Array:
	var out: Array = []
	for step_variant in path:
		if not step_variant is Dictionary:
			continue
		var step: Dictionary = step_variant
		out.append({
			"pos": _save_vec2(step.get("pos", Vector2.ZERO) as Vector2),
			"heading_deg": float(step.get("heading_deg", 0.0)),
			"mp": int(step.get("mp", 0)),
			"cell": _save_vec2i(step.get("cell", Vector2i.ZERO) as Vector2i)
		})
	return out

func _load_pose_path(data: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not data is Array:
		return out
	for step_variant in data:
		if not step_variant is Dictionary:
			continue
		var step: Dictionary = step_variant
		out.append({
			"pos": _load_vec2(step.get("pos"), Vector2.ZERO),
			"heading_deg": float(step.get("heading_deg", 0.0)),
			"mp": int(step.get("mp", 0)),
			"cell": _load_vec2i(step.get("cell"), Vector2i.ZERO)
		})
	return out

func _save_terminal_state(terminal: Dictionary) -> Dictionary:
	if terminal.is_empty():
		return {}
	return {
		"pos": _save_vec2(terminal.get("pos", Vector2.ZERO) as Vector2),
		"heading_deg": float(terminal.get("heading_deg", 0.0)),
		"mp": int(terminal.get("mp", 0)),
		"cell": _save_vec2i(terminal.get("cell", Vector2i.ZERO) as Vector2i)
	}

func _load_terminal_state(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var terminal: Dictionary = data
	return {
		"pos": _load_vec2(terminal.get("pos"), Vector2.ZERO),
		"heading_deg": float(terminal.get("heading_deg", 0.0)),
		"mp": int(terminal.get("mp", 0)),
		"cell": _load_vec2i(terminal.get("cell"), Vector2i.ZERO)
	}

func get_save_state() -> Dictionary:
	var hazard_list: Array = []
	for cell in hazard_cells.keys():
		if cell is Vector2i:
			hazard_list.append(_save_vec2i(cell))
	return {
		"phase": int(phase),
		"player_hull": player_hull,
		"enemy_hull": enemy_hull,
		"player_crew": player_crew,
		"enemy_crew": enemy_crew,
		"player_has_boarding_advantage": player_has_boarding_advantage,
		"enemy_has_boarding_advantage": enemy_has_boarding_advantage,
		"player_ship_class": player_ship_class,
		"enemy_ship_class": enemy_ship_class,
		"player_heading_deg": player_heading_deg,
		"enemy_heading_deg": enemy_heading_deg,
		"wind_direction_deg": wind_direction_deg,
		"wind_speed_m_s": wind_speed_m_s,
		"player_cell_pos": _save_vec2(player_cell_pos),
		"enemy_cell_pos": _save_vec2(enemy_cell_pos),
		"player_move_points": player_move_points,
		"enemy_move_points": enemy_move_points,
		"player_navigator_skill": player_navigator_skill,
		"enemy_navigator_skill": enemy_navigator_skill,
		"enemy_behavior": enemy_behavior,
		"player_sail_setting": int(player_sail_setting),
		"player_ordered_sail_setting": int(player_ordered_sail_setting),
		"enemy_sail_setting": int(enemy_sail_setting),
		"player_movement_plotted": player_movement_plotted,
		"player_plan_end_pos": _save_vec2(player_plan_end_pos),
		"player_plan_end_heading": player_plan_end_heading,
		"player_plan_board": player_plan_board,
		"player_turn_start_cell_pos": _save_vec2(player_turn_start_cell_pos),
		"player_run_cells": player_run_cells,
		"player_run_heading_idx": player_run_heading_idx,
		"enemy_run_cells": enemy_run_cells,
		"enemy_run_heading_idx": enemy_run_heading_idx,
		"enemy_plan_end_pos": _save_vec2(enemy_plan_end_pos),
		"enemy_plan_end_heading": enemy_plan_end_heading,
		"enemy_plan_volley_when_in_range": enemy_plan_volley_when_in_range,
		"enemy_plan_board": enemy_plan_board,
		"player_port_cannon_reload_turns_remaining": player_port_cannon_reload_turns_remaining,
		"player_starboard_cannon_reload_turns_remaining": player_starboard_cannon_reload_turns_remaining,
		"enemy_port_cannon_reload_turns_remaining": enemy_port_cannon_reload_turns_remaining,
		"enemy_starboard_cannon_reload_turns_remaining": enemy_starboard_cannon_reload_turns_remaining,
		"player_hull_battle_start": player_hull_battle_start,
		"enemy_hull_battle_start": enemy_hull_battle_start,
		"player_crew_battle_start": player_crew_battle_start,
		"enemy_crew_battle_start": enemy_crew_battle_start,
		"completed_wego_rounds": _completed_wego_rounds,
		"player_plan_terminal": _save_terminal_state(player_plan_terminal),
		"enemy_plan_terminal": _save_terminal_state(enemy_plan_terminal),
		"player_plan_preview_path": _save_pose_path(player_plan_preview_path),
		"player_round_path": _save_pose_path(player_round_path),
		"enemy_round_path": _save_pose_path(enemy_round_path),
		"move_anim_elapsed": _move_anim_elapsed,
		"move_anim_actor": _move_anim_actor,
		"hazard_cells": hazard_list
	}

func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	phase = int(state.get("phase", Phase.PLANNING)) as Phase
	player_hull = int(state.get("player_hull", player_hull))
	enemy_hull = int(state.get("enemy_hull", enemy_hull))
	player_crew = int(state.get("player_crew", player_crew))
	enemy_crew = int(state.get("enemy_crew", enemy_crew))
	player_has_boarding_advantage = bool(state.get("player_has_boarding_advantage", false))
	enemy_has_boarding_advantage = bool(state.get("enemy_has_boarding_advantage", false))
	player_ship_class = str(state.get("player_ship_class", player_ship_class))
	enemy_ship_class = str(state.get("enemy_ship_class", enemy_ship_class))
	player_heading_deg = float(state.get("player_heading_deg", player_heading_deg))
	enemy_heading_deg = float(state.get("enemy_heading_deg", enemy_heading_deg))
	wind_direction_deg = float(state.get("wind_direction_deg", wind_direction_deg))
	wind_speed_m_s = float(state.get("wind_speed_m_s", wind_speed_m_s))
	player_cell_pos = _load_vec2(state.get("player_cell_pos"), player_cell_pos)
	enemy_cell_pos = _load_vec2(state.get("enemy_cell_pos"), enemy_cell_pos)
	player_move_points = int(state.get("player_move_points", player_move_points))
	enemy_move_points = int(state.get("enemy_move_points", enemy_move_points))
	player_navigator_skill = int(state.get("player_navigator_skill", player_navigator_skill))
	enemy_navigator_skill = int(state.get("enemy_navigator_skill", enemy_navigator_skill))
	enemy_behavior = str(state.get("enemy_behavior", enemy_behavior))
	player_sail_setting = int(state.get("player_sail_setting", int(player_sail_setting))) as SailSetting
	player_ordered_sail_setting = int(
		state.get("player_ordered_sail_setting", int(player_sail_setting))
	) as SailSetting
	enemy_sail_setting = int(state.get("enemy_sail_setting", int(enemy_sail_setting))) as SailSetting
	player_movement_plotted = bool(state.get("player_movement_plotted", false))
	player_plan_end_pos = _load_vec2(state.get("player_plan_end_pos"), player_plan_end_pos)
	player_plan_end_heading = float(state.get("player_plan_end_heading", player_plan_end_heading))
	player_plan_board = bool(state.get("player_plan_board", false))
	player_turn_start_cell_pos = _load_vec2(state.get("player_turn_start_cell_pos"), player_turn_start_cell_pos)
	player_run_cells = int(state.get("player_run_cells", 0))
	player_run_heading_idx = int(state.get("player_run_heading_idx", player_heading_idx))
	enemy_run_cells = int(state.get("enemy_run_cells", 0))
	enemy_run_heading_idx = int(state.get("enemy_run_heading_idx", enemy_heading_idx))
	enemy_plan_end_pos = _load_vec2(state.get("enemy_plan_end_pos"), enemy_plan_end_pos)
	enemy_plan_end_heading = float(state.get("enemy_plan_end_heading", enemy_plan_end_heading))
	enemy_plan_volley_when_in_range = bool(state.get("enemy_plan_volley_when_in_range", false))
	enemy_plan_board = bool(state.get("enemy_plan_board", false))
	player_port_cannon_reload_turns_remaining = int(state.get("player_port_cannon_reload_turns_remaining", 0))
	player_starboard_cannon_reload_turns_remaining = int(state.get("player_starboard_cannon_reload_turns_remaining", 0))
	enemy_port_cannon_reload_turns_remaining = int(state.get("enemy_port_cannon_reload_turns_remaining", 0))
	enemy_starboard_cannon_reload_turns_remaining = int(state.get("enemy_starboard_cannon_reload_turns_remaining", 0))
	player_hull_battle_start = int(state.get("player_hull_battle_start", player_hull_battle_start))
	enemy_hull_battle_start = int(state.get("enemy_hull_battle_start", enemy_hull_battle_start))
	player_crew_battle_start = int(state.get("player_crew_battle_start", player_crew_battle_start))
	enemy_crew_battle_start = int(state.get("enemy_crew_battle_start", enemy_crew_battle_start))
	_completed_wego_rounds = int(state.get("completed_wego_rounds", 0))
	player_plan_terminal = _load_terminal_state(state.get("player_plan_terminal"))
	enemy_plan_terminal = _load_terminal_state(state.get("enemy_plan_terminal"))
	player_plan_preview_path = _load_pose_path(state.get("player_plan_preview_path"))
	player_round_path = _load_pose_path(state.get("player_round_path"))
	enemy_round_path = _load_pose_path(state.get("enemy_round_path"))
	_move_anim_elapsed = float(state.get("move_anim_elapsed", 0.0))
	_move_anim_actor = str(state.get("move_anim_actor", ""))
	hazard_cells.clear()
	var hazard_list: Variant = state.get("hazard_cells", [])
	if hazard_list is Array:
		for cell_variant in hazard_list:
			var cell: Vector2i = _load_vec2i(cell_variant, Vector2i(-1, -1))
			if _is_valid_cell(cell):
				hazard_cells[cell] = true
	_sync_pose_from_positions()
	_invalidate_player_movement_preview_cache()
	_gun_range_overlay_cache_key = ""
	_gun_range_overlay_cache.clear()
