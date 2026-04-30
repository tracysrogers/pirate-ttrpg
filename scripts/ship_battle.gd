extends Node
class_name ShipBattle

signal battle_updated(text: String)
signal boarding_started(attacker_is_player: bool)
signal battle_finished(player_won: bool, disengaged: bool)

enum Phase {
	PLANNING,
	RESOLVED
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
var combat_cols: int = 88
var combat_rows: int = 52
var player_cell: Vector2i = Vector2i(32, 26)
var enemy_cell: Vector2i = Vector2i(54, 22)
var player_cell_pos: Vector2 = Vector2(32.0, 26.0)
var enemy_cell_pos: Vector2 = Vector2(54.0, 22.0)
var player_heading_idx: int = 2
var enemy_heading_idx: int = 6
var player_move_points: int = 0
var enemy_move_points: int = 0
var player_navigator_skill: int = 2
var enemy_navigator_skill: int = 2
var enemy_behavior: String = "engage"
var player_plan_end_pos: Vector2 = Vector2.ZERO
var player_plan_end_heading: float = 0.0
var player_plan_volley_when_in_range: bool = true
var player_plan_board: bool = false
var enemy_plan_end_pos: Vector2 = Vector2.ZERO
var enemy_plan_end_heading: float = 0.0
var enemy_plan_volley_when_in_range: bool = false
var enemy_plan_board: bool = false
var player_cannon_reload_turns_remaining: int = 0
var enemy_cannon_reload_turns_remaining: int = 0
var player_hull_battle_start: int = 16
var enemy_hull_battle_start: int = 16
var player_crew_battle_start: int = 24
var enemy_crew_battle_start: int = 24
var _completed_wego_rounds: int = 0
var hazard_cells: Dictionary = {}
const TURN_STEP_DEG := 15.0
const DISENGAGE_MIN_CELL_DIST := 26.0
const CANNON_RELOAD_BASE_ROUNDS := 3
const CANNON_RELOAD_MAX_ROUNDS := 10
const CANNON_RELOAD_HULL_STRAIN_MAX := 2.35
const CANNON_RELOAD_CREW_STRAIN_MAX := 1.85
const CANNON_RELOAD_FATIGUE_MAX := 1.55
const CANNON_RELOAD_FATIGUE_PER_ROUND := 0.024

func start_battle(context: Dictionary = {}) -> void:
	phase = Phase.PLANNING
	player_ship_class = str(context.get("player_ship_class", "Sloop"))
	enemy_ship_class = str(context.get("enemy_ship_class", "Brig"))

	var player_stats: Dictionary = _ship_stats(player_ship_class)
	var enemy_stats: Dictionary = _ship_stats(enemy_ship_class)
	player_hull = int(player_stats.get("hull", 16))
	enemy_hull = int(enemy_stats.get("hull", 16))
	player_crew = int(player_stats.get("crew", 24))
	enemy_crew = int(enemy_stats.get("crew", 24))
	player_hull_battle_start = player_hull
	enemy_hull_battle_start = enemy_hull
	player_crew_battle_start = player_crew
	enemy_crew_battle_start = enemy_crew
	_completed_wego_rounds = 0
	player_has_boarding_advantage = false
	enemy_has_boarding_advantage = false
	player_cell_pos = Vector2(32.0, 26.0)
	enemy_cell_pos = Vector2(54.0, 22.0)
	player_cell = Vector2i(32, 26)
	enemy_cell = Vector2i(54, 22)
	player_heading_deg = _vector_to_bearing_deg(context.get("player_heading", Vector2.RIGHT))
	enemy_heading_deg = _vector_to_bearing_deg(context.get("enemy_heading", Vector2.LEFT))
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	player_navigator_skill = clampi(int(context.get("player_navigator_skill", 2)), 0, 5)
	enemy_navigator_skill = clampi(int(context.get("enemy_navigator_skill", 2)), 0, 5)
	var wind_variant: Variant = context.get("wind", {"direction_deg": 90.0, "speed_m_s": 6.0})
	var wind_data: Dictionary = (wind_variant as Dictionary) if wind_variant is Dictionary else {"direction_deg": 90.0, "speed_m_s": 6.0}
	wind_direction_deg = float(wind_data.get("direction_deg", 90.0))
	wind_speed_m_s = float(wind_data.get("speed_m_s", 6.0))
	enemy_behavior = "engage" if bool(context.get("enemy_wants_pursuit", true)) else "escape"
	player_cannon_reload_turns_remaining = 0
	enemy_cannon_reload_turns_remaining = 0
	_generate_hazards(bool(context.get("near_land", false)))
	_sync_pose_from_positions()
	_begin_planning_round()
	emit_signal(
		"battle_updated",
		"Enemy %s sighted. You command a %s. WEGO: plan movement, optional Volley if in range, Show gun range to preview arcs, grapple order, then Commit. F toggles gun-range overlay. X breaks off when clear." % [
			enemy_ship_class,
			player_ship_class
		]
	)

func set_player_planned_move_cell(target_cell: Vector2i) -> bool:
	if phase != Phase.PLANNING:
		return false
	var built: Dictionary = _build_movement_states(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		player_cell
	)
	var states: Array = built["states"]
	var best_index: int = -1
	var best_mp: int = -1
	for i in range(states.size()):
		var s_variant: Variant = states[i]
		if not (s_variant is Dictionary):
			continue
		var s: Dictionary = s_variant
		var cell: Vector2i = s["cell"]
		if cell != target_cell:
			continue
		var mp: int = int(s["mp"])
		if mp > best_mp:
			best_mp = mp
			best_index = i
	if best_index < 0:
		return false
	var selected: Dictionary = states[best_index]
	player_plan_end_pos = selected["pos"]
	player_plan_end_heading = float(selected["heading_deg"])
	return true

func player_toggle_volley_when_in_range() -> void:
	if phase != Phase.PLANNING:
		return
	player_plan_volley_when_in_range = not player_plan_volley_when_in_range
	if player_plan_volley_when_in_range:
		emit_signal(
			"battle_updated",
			"Gunnery: fire a controlled volley only if the enemy bears in arc and range after this round's movement."
		)
	else:
		emit_signal("battle_updated", "Gunnery: hold fire this round.")

func player_attempt_boarding() -> void:
	if phase != Phase.PLANNING:
		return
	if player_plan_board:
		player_plan_board = false
		emit_signal("battle_updated", "Boarding order cancelled.")
		return
	player_plan_board = true
	player_plan_volley_when_in_range = true
	emit_signal("battle_updated", "Orders: grapple if you end adjacent to the enemy after this round's movement.")

func can_player_board_now() -> bool:
	return phase == Phase.PLANNING

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

func player_commit_orders() -> void:
	if phase != Phase.PLANNING:
		return
	if get_ship_separation() >= DISENGAGE_MIN_CELL_DIST and enemy_behavior == "escape":
		_finish_mutual_disengage(false)
		return
	_build_enemy_plan()
	_resolve_simultaneous_round()

func _score_enemy_destination_cell(cell: Vector2i, player_goal: Vector2) -> float:
	var dx: float = float(cell.x) - player_goal.x
	var dy: float = float(cell.y) - player_goal.y
	var dist: float = sqrt(dx * dx + dy * dy)
	if enemy_behavior == "escape":
		return dist + randf() * 0.4
	return -dist + randf() * 0.35

func _build_enemy_plan() -> void:
	# Blind planning: enemy only sees your current pose, not your plotted move or aim.
	var player_observed: Vector2 = player_cell_pos
	var built: Dictionary = _build_movement_states(
		enemy_cell_pos,
		enemy_heading_deg,
		enemy_move_points,
		enemy_ship_class,
		player_observed,
		enemy_cell
	)
	var reachable: Dictionary = built["reachable"]
	var states: Array = built["states"]
	var player_cell_now: Vector2i = player_cell
	var best_cell: Vector2i = enemy_cell
	var best_score: float = -INF
	for c in reachable.keys():
		if not (c is Vector2i):
			continue
		var cell: Vector2i = c
		if cell == player_cell_now:
			continue
		var sc: float = _score_enemy_destination_cell(cell, player_observed)
		if sc > best_score:
			best_score = sc
			best_cell = cell
	var best_index: int = -1
	var best_mp: int = -1
	for i in range(states.size()):
		var s_variant: Variant = states[i]
		if not (s_variant is Dictionary):
			continue
		var s: Dictionary = s_variant
		if s["cell"] != best_cell:
			continue
		var mp: int = int(s["mp"])
		if mp > best_mp:
			best_mp = mp
			best_index = i
	if best_index < 0:
		enemy_plan_end_pos = enemy_cell_pos
		enemy_plan_end_heading = enemy_heading_deg
	else:
		var sel: Dictionary = states[best_index]
		enemy_plan_end_pos = sel["pos"]
		enemy_plan_end_heading = float(sel["heading_deg"])
	var enemy_end_cell: Vector2i = Vector2i(int(round(enemy_plan_end_pos.x)), int(round(enemy_plan_end_pos.y)))
	if enemy_behavior == "escape":
		enemy_plan_volley_when_in_range = false
		enemy_plan_board = false
	else:
		enemy_plan_volley_when_in_range = enemy_cannon_reload_turns_remaining <= 0
		enemy_plan_board = (
			_grid_chebyshev_distance(enemy_end_cell, player_cell_now) <= 1
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


func _advance_cannon_reload_after_round(player_battery_hit: bool, enemy_battery_hit: bool) -> void:
	if not player_battery_hit and player_cannon_reload_turns_remaining > 0:
		player_cannon_reload_turns_remaining -= 1
	if not enemy_battery_hit and enemy_cannon_reload_turns_remaining > 0:
		enemy_cannon_reload_turns_remaining -= 1
	_completed_wego_rounds += 1


func _resolve_volley_orders_if_in_range(
	ordered: bool,
	attacker_pos_norm: Vector2,
	attacker_heading: float,
	attacker_class: String,
	defender_pos_norm: Vector2,
	defender_heading: float,
	attacker_is_player: bool
) -> bool:
	if not ordered:
		return false
	if attacker_is_player and player_cannon_reload_turns_remaining > 0:
		emit_signal(
			"battle_updated",
			"Your gun crews are still running out the tackles—%d more round(s) before the battery can volley again."
			% player_cannon_reload_turns_remaining
		)
		return false
	if not attacker_is_player and enemy_cannon_reload_turns_remaining > 0:
		emit_signal("battle_updated", "Enemy holds fire; their battery is still reloading.")
		return false
	var shot: Dictionary = _resolve_cannon_shot(
		attacker_pos_norm, attacker_heading, attacker_class, defender_pos_norm, defender_heading
	)
	var who_battery: String = "Your" if attacker_is_player else "Enemy"
	if not bool(shot.get("can_fire", false)):
		emit_signal("battle_updated", "%s guns: no firing solution on the target after movement." % who_battery)
		return false
	var damage: int = int(shot.get("damage", 0))
	var shot_type: String = str(shot.get("shot_type", "broadside"))
	var rake_text: String = " Raking hit!" if bool(shot.get("raking", false)) else ""
	if attacker_is_player:
		enemy_hull = max(0, enemy_hull - damage)
		player_has_boarding_advantage = true
		player_cannon_reload_turns_remaining = _cannon_reload_duration_turns_for_attacker(true)
		emit_signal("battle_updated", "Your %s strikes for %d hull damage.%s" % [shot_type, damage, rake_text])
	else:
		player_hull = max(0, player_hull - damage)
		enemy_has_boarding_advantage = true
		enemy_cannon_reload_turns_remaining = _cannon_reload_duration_turns_for_attacker(false)
		emit_signal("battle_updated", "Enemy %s strikes for %d hull damage.%s" % [shot_type, damage, rake_text])
	return true

func _resolve_simultaneous_round() -> void:
	var e_pos_save: Vector2 = enemy_cell_pos
	var e_h_save: float = enemy_heading_deg
	player_cell_pos = player_plan_end_pos
	player_heading_deg = player_plan_end_heading
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	enemy_cell_pos = enemy_plan_end_pos
	enemy_heading_deg = enemy_plan_end_heading
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	_sync_pose_from_positions()
	if player_cell == enemy_cell:
		player_cell_pos = player_plan_end_pos
		player_heading_deg = player_plan_end_heading
		enemy_cell_pos = e_pos_save
		enemy_heading_deg = e_h_save
		player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
		enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
		_sync_pose_from_positions()
		emit_signal("battle_updated", "Both ordered the same sea room—you hold it; the enemy backs water.")
	if _check_collision_with_hazard(player_cell):
		_advance_cannon_reload_after_round(false, false)
		return
	if _check_collision_with_hazard_enemy(enemy_cell):
		_advance_cannon_reload_after_round(false, false)
		return
	var p_norm: Vector2 = player_position
	var e_norm: Vector2 = enemy_position
	var p_h: float = player_heading_deg
	var e_h: float = enemy_heading_deg
	var player_battery_hit: bool = _resolve_volley_orders_if_in_range(
		player_plan_volley_when_in_range, p_norm, p_h, player_ship_class, e_norm, e_h, true
	)
	if enemy_hull <= 0:
		_advance_cannon_reload_after_round(player_battery_hit, false)
		_check_resolution_only()
		return
	var enemy_battery_hit: bool = _resolve_volley_orders_if_in_range(
		enemy_plan_volley_when_in_range, e_norm, e_h, enemy_ship_class, p_norm, p_h, false
	)
	if enemy_hull <= 0 or player_hull <= 0:
		_advance_cannon_reload_after_round(player_battery_hit, enemy_battery_hit)
		_check_resolution_only()
		if phase != Phase.RESOLVED:
			_begin_planning_round()
		return
	if player_plan_board and _grid_chebyshev_distance(player_cell, enemy_cell) <= 1:
		var chance := 0.38
		var crew_ratio: float = float(player_crew) / float(max(1, enemy_crew))
		chance += clampf((crew_ratio - 1.0) * 0.2, -0.12, 0.2)
		if _is_target_stern_arc(player_position, enemy_position, enemy_heading_deg):
			chance += 0.08
		if player_has_boarding_advantage:
			chance += 0.25
		if randf() <= chance:
			_advance_cannon_reload_after_round(player_battery_hit, enemy_battery_hit)
			emit_signal("battle_updated", "Your crew throws the grapples home!")
			emit_signal("boarding_started", true)
			return
		emit_signal("battle_updated", "Grappling attempt fails; lines part.")
		enemy_has_boarding_advantage = true
	elif enemy_plan_board and _grid_chebyshev_distance(enemy_cell, player_cell) <= 1:
		var ech := 0.34
		var crew_ratio_e: float = float(enemy_crew) / float(max(1, player_crew))
		ech += clampf((crew_ratio_e - 1.0) * 0.2, -0.12, 0.2)
		if enemy_has_boarding_advantage:
			ech += 0.2
		if randf() <= ech:
			_advance_cannon_reload_after_round(player_battery_hit, enemy_battery_hit)
			emit_signal("battle_updated", "Enemy hooks your rail!")
			emit_signal("boarding_started", false)
			return
		emit_signal("battle_updated", "Enemy boarders cannot secure a purchase.")
	_advance_cannon_reload_after_round(player_battery_hit, enemy_battery_hit)
	emit_signal("battle_updated", "Round complete. New orders.")
	_check_resolution_or_planning()

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

func resolve_boarding_result(defender_successful: bool) -> void:
	if defender_successful:
		emit_signal("battle_updated", "Defense held. You can counter-board now.")
		player_has_boarding_advantage = true
		_begin_planning_round()
	else:
		enemy_hull = max(0, enemy_hull - 6)
		emit_signal("battle_updated", "Boarding assault succeeded. Enemy ship is crippled.")
		_check_resolution_or_planning()

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

func _resolve_cannon_shot(attacker_pos: Vector2, attacker_heading_deg: float, attacker_class: String, target_pos: Vector2, target_heading_deg: float) -> Dictionary:
	var dist: float = attacker_pos.distance_to(target_pos)
	if dist > _cannon_range(attacker_class):
		return {"can_fire": false}
	var bearing_to_target: float = _vector_to_bearing_deg((target_pos - attacker_pos).normalized())
	var rel: float = absf(_angle_delta_deg(attacker_heading_deg, bearing_to_target))
	var arc_profile: Dictionary = _cannon_arc_profile(attacker_class)
	var broadside_window: float = float(arc_profile.get("broadside_window", 34.0))
	var chase_window: float = float(arc_profile.get("chase_window", 14.0))
	var can_broadside: bool = absf(rel - 90.0) <= broadside_window
	var can_chase: bool = rel <= chase_window or rel >= (180.0 - chase_window)
	if not can_broadside and not can_chase:
		return {"can_fire": false}
	var shot_type: String = "broadside" if can_broadside else "chase guns"
	var damage: int = _roll_cannon_damage(attacker_class, dist)
	if not can_broadside:
		damage = max(1, int(round(float(damage) * 0.6)))
	var raking: bool = _is_target_stern_arc(attacker_pos, target_pos, target_heading_deg)
	if raking:
		damage = int(round(float(damage) * 1.2))
	return {
		"can_fire": true,
		"damage": damage,
		"shot_type": shot_type,
		"raking": raking
	}

func _cannon_arc_profile(ship_class: String) -> Dictionary:
	match ship_class:
		"Sloop":
			return {"broadside_window": 36.0, "chase_window": 0.0}
		"Brig":
			return {"broadside_window": 34.0, "chase_window": 0.0}
		"Frigate":
			return {"broadside_window": 32.0, "chase_window": 0.0}
		"Merchantman":
			return {"broadside_window": 30.0, "chase_window": 0.0}
		_:
			return {"broadside_window": 34.0, "chase_window": 0.0}

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

func _roll_cannon_damage(ship_class: String, dist: float) -> int:
	var broadside_base: int = int(_ship_stats(ship_class).get("broadside", 4))
	var range_factor: float = clampf(1.2 - dist * 1.4, 0.55, 1.15)
	var raw: float = float(randi_range(max(1, broadside_base - 1), broadside_base + 2)) * range_factor
	return max(1, int(round(raw)))

func _begin_planning_round() -> void:
	phase = Phase.PLANNING
	player_move_points = _movement_points_for(player_ship_class, player_navigator_skill, player_heading_deg)
	enemy_move_points = _movement_points_for(enemy_ship_class, enemy_navigator_skill, enemy_heading_deg)
	player_plan_end_pos = player_cell_pos
	player_plan_end_heading = player_heading_deg
	player_plan_volley_when_in_range = false
	player_plan_board = false

func _movement_points_for(ship_class: String, navigator_skill: int, heading_deg: float) -> int:
	var base_mp: int = int(_ship_stats(ship_class).get("base_mp", 4))
	var skill_bonus: int = int(floor(float(navigator_skill) / 2.0))
	var wind_to_deg: float = fposmod(wind_direction_deg + 180.0, 360.0)
	var diff: float = absf(_angle_delta_deg(heading_deg, wind_to_deg))
	var wind_angle_mod: int = 0
	if diff <= 45.0:
		wind_angle_mod = 2
	elif diff <= 95.0:
		wind_angle_mod = 1
	elif diff >= 150.0:
		wind_angle_mod = -1
	var wind_speed_mod: int = 0
	if wind_speed_m_s > 8.0:
		wind_speed_mod = 1
	elif wind_speed_m_s < 3.0:
		wind_speed_mod = -1
	return clampi(base_mp + skill_bonus + wind_angle_mod + wind_speed_mod, 1, 8)

func _turn_cost_for(ship_class: String) -> int:
	return int(_ship_stats(ship_class).get("turn_cost", 1))

func get_player_turn_cost() -> int:
	return _turn_cost_for(player_ship_class)

func get_enemy_turn_cost() -> int:
	return _turn_cost_for(enemy_ship_class)

func get_player_movement_preview() -> Dictionary:
	if phase != Phase.PLANNING:
		return {"reachable_cells": [], "forward_cells": [], "forward_step_cells": 1.0}
	var built: Dictionary = _build_movement_states(
		player_cell_pos,
		player_heading_deg,
		player_move_points,
		player_ship_class,
		enemy_cell_pos,
		player_cell
	)
	var reachable: Dictionary = built["reachable"]
	var forward_cells: Array[Vector2i] = built["forward_cells"]
	var reachable_cells: Array[Vector2i] = []
	for c in reachable.keys():
		reachable_cells.append(c)
	return {
		"reachable_cells": reachable_cells,
		"forward_cells": forward_cells,
		"forward_step_cells": _forward_cells_per_step(player_ship_class, player_heading_deg)
	}

func get_player_reachable_cells() -> Array[Vector2i]:
	var preview: Dictionary = get_player_movement_preview()
	if preview.has("reachable_cells") and preview["reachable_cells"] is Array:
		return preview["reachable_cells"]
	return []

func can_player_move_to_cell(cell: Vector2i) -> bool:
	var reachable: Array[Vector2i] = get_player_reachable_cells()
	for c in reachable:
		if c == cell:
			return true
	return false

func execute_player_move_to_cell(target_cell: Vector2i) -> bool:
	return set_player_planned_move_cell(target_cell)

func get_hazard_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in hazard_cells.keys():
		cells.append(cell)
	return cells

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
	if not hazard_cells.has(cell):
		return false
	phase = Phase.RESOLVED
	emit_signal("battle_updated", "Your ship strikes coastal hazards and is lost.")
	emit_signal("battle_finished", false, false)
	return true

func _check_collision_with_hazard_enemy(cell: Vector2i) -> bool:
	if not hazard_cells.has(cell):
		return false
	phase = Phase.RESOLVED
	emit_signal("battle_updated", "The enemy is thrown onto the shoals and breaks up.")
	emit_signal("battle_finished", true, false)
	return true

func _build_movement_states(
	start_pos: Vector2,
	start_heading: float,
	start_mp: int,
	ship_class: String,
	other_ship_pos: Vector2,
	start_cell: Vector2i
) -> Dictionary:
	var reachable: Dictionary = {}
	var forward_cells: Array[Vector2i] = []
	var open: Array[Dictionary] = [{
		"pos": start_pos,
		"heading_deg": start_heading,
		"mp": start_mp
	}]
	var all_states: Array[Dictionary] = [{
		"pos": start_pos,
		"heading_deg": start_heading,
		"mp": start_mp,
		"cell": start_cell
	}]
	var seen: Dictionary = {}
	var turn_cost: int = _turn_cost_for(ship_class)

	while not open.is_empty():
		var state: Dictionary = open.pop_front()
		var pos: Vector2 = state["pos"]
		var heading_deg: float = float(state["heading_deg"])
		var mp: int = int(state["mp"])
		var cell: Vector2i = Vector2i(int(round(pos.x)), int(round(pos.y)))
		var heading_bucket: int = int(round(fposmod(heading_deg, 360.0) / TURN_STEP_DEG))
		var key: String = "%d:%d:%d:%d" % [cell.x, cell.y, heading_bucket, mp]
		if seen.has(key):
			continue
		seen[key] = true
		reachable[cell] = true

		if mp >= 1:
			var step_cells: float = _forward_cells_per_step(ship_class, heading_deg)
			var next_pos: Vector2 = pos + _bearing_deg_to_vector(heading_deg) * step_cells
			if _is_valid_pos(next_pos) and next_pos.distance_to(other_ship_pos) >= 1.0:
				var next_state: Dictionary = {"pos": next_pos, "heading_deg": heading_deg, "mp": mp - 1}
				open.append(next_state)
				all_states.append({
					"pos": next_pos,
					"heading_deg": heading_deg,
					"mp": mp - 1,
					"cell": Vector2i(int(round(next_pos.x)), int(round(next_pos.y)))
				})
		if mp >= turn_cost:
			var left_heading_deg: float = fposmod(heading_deg - TURN_STEP_DEG, 360.0)
			var right_heading_deg: float = fposmod(heading_deg + TURN_STEP_DEG, 360.0)
			var turn_step: float = _turn_forward_cells(ship_class, heading_deg)
			var left_pos: Vector2 = pos + _bearing_deg_to_vector(left_heading_deg) * turn_step
			var right_pos: Vector2 = pos + _bearing_deg_to_vector(right_heading_deg) * turn_step
			if _is_valid_pos(left_pos) and left_pos.distance_to(other_ship_pos) >= 1.0:
				var left_state: Dictionary = {"pos": left_pos, "heading_deg": left_heading_deg, "mp": mp - turn_cost}
				open.append(left_state)
				all_states.append({
					"pos": left_pos,
					"heading_deg": left_heading_deg,
					"mp": mp - turn_cost,
					"cell": Vector2i(int(round(left_pos.x)), int(round(left_pos.y)))
				})
			if _is_valid_pos(right_pos) and right_pos.distance_to(other_ship_pos) >= 1.0:
				var right_state: Dictionary = {"pos": right_pos, "heading_deg": right_heading_deg, "mp": mp - turn_cost}
				open.append(right_state)
				all_states.append({
					"pos": right_pos,
					"heading_deg": right_heading_deg,
					"mp": mp - turn_cost,
					"cell": Vector2i(int(round(right_pos.x)), int(round(right_pos.y)))
				})

	var straight_pos: Vector2 = start_pos
	for _i in range(start_mp):
		straight_pos += _bearing_deg_to_vector(start_heading) * _forward_cells_per_step(ship_class, start_heading)
		if not _is_valid_pos(straight_pos) or straight_pos.distance_to(other_ship_pos) < 1.0:
			break
		forward_cells.append(Vector2i(int(round(straight_pos.x)), int(round(straight_pos.y))))

	return {
		"reachable": reachable,
		"forward_cells": forward_cells,
		"states": all_states
	}

func get_player_action_guidance() -> Dictionary:
	if phase != Phase.PLANNING:
		return {}
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
		var f_step: float = _forward_cells_per_step(player_ship_class, player_heading_deg)
		var f_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(player_heading_deg) * f_step
		if _is_valid_pos(f_pos) and f_pos.distance_to(enemy_cell_pos) >= 1.0:
			guidance["forward"] = {
				"label": "Forward",
				"cost": 1,
				"can_execute": true,
				"target_cell": Vector2i(int(round(f_pos.x)), int(round(f_pos.y))),
				"target_pos": f_pos
			}

	# Left turn+advance
	if player_move_points >= turn_cost:
		var left_heading: float = fposmod(player_heading_deg + TURN_STEP_DEG, 360.0)
		var l_step: float = _turn_forward_cells(player_ship_class, left_heading)
		var l_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(left_heading) * l_step
		if _is_valid_pos(l_pos) and l_pos.distance_to(enemy_cell_pos) >= 1.0:
			guidance["left"] = {
				"label": "Left Turn+Advance",
				"cost": turn_cost,
				"can_execute": true,
				"target_cell": Vector2i(int(round(l_pos.x)), int(round(l_pos.y))),
				"target_pos": l_pos
			}

	# Right turn+advance
	if player_move_points >= turn_cost:
		var right_heading: float = fposmod(player_heading_deg - TURN_STEP_DEG, 360.0)
		var r_step: float = _turn_forward_cells(player_ship_class, right_heading)
		var r_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(right_heading) * r_step
		if _is_valid_pos(r_pos) and r_pos.distance_to(enemy_cell_pos) >= 1.0:
			guidance["right"] = {
				"label": "Right Turn+Advance",
				"cost": turn_cost,
				"can_execute": true,
				"target_cell": Vector2i(int(round(r_pos.x)), int(round(r_pos.y))),
				"target_pos": r_pos
			}
	return guidance

func get_player_gun_range_preview_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if phase != Phase.PLANNING:
		return cells
	var att_norm: Vector2 = Vector2(
		player_plan_end_pos.x / float(max(1, combat_cols - 1)),
		player_plan_end_pos.y / float(max(1, combat_rows - 1))
	)
	var att_h: float = player_plan_end_heading
	var plan_cell: Vector2i = Vector2i(int(round(player_plan_end_pos.x)), int(round(player_plan_end_pos.y)))
	for y in range(combat_rows):
		for x in range(combat_cols):
			var cell := Vector2i(x, y)
			if cell == plan_cell:
				continue
			var target_pos := Vector2(float(x) / float(max(1, combat_cols - 1)), float(y) / float(max(1, combat_rows - 1)))
			var shot: Dictionary = _resolve_cannon_shot(att_norm, att_h, player_ship_class, target_pos, enemy_heading_deg)
			if bool(shot.get("can_fire", false)):
				cells.append(cell)
	return cells

func _sync_pose_from_positions() -> void:
	player_cell_pos.x = clampf(player_cell_pos.x, 0.0, float(combat_cols - 1))
	player_cell_pos.y = clampf(player_cell_pos.y, 0.0, float(combat_rows - 1))
	enemy_cell_pos.x = clampf(enemy_cell_pos.x, 0.0, float(combat_cols - 1))
	enemy_cell_pos.y = clampf(enemy_cell_pos.y, 0.0, float(combat_rows - 1))
	player_cell = Vector2i(int(round(player_cell_pos.x)), int(round(player_cell_pos.y)))
	enemy_cell = Vector2i(int(round(enemy_cell_pos.x)), int(round(enemy_cell_pos.y)))
	player_position = Vector2(
		player_cell_pos.x / float(max(1, combat_cols - 1)),
		player_cell_pos.y / float(max(1, combat_rows - 1))
	)
	enemy_position = Vector2(
		enemy_cell_pos.x / float(max(1, combat_cols - 1)),
		enemy_cell_pos.y / float(max(1, combat_rows - 1))
	)

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
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= float(combat_cols - 1) and pos.y <= float(combat_rows - 1)

func _grid_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _forward_cells_per_step(ship_class: String, heading_deg: float) -> float:
	var base: float = float(_ship_stats(ship_class).get("forward_cells", 1.2))
	var wind_to_deg: float = fposmod(wind_direction_deg + 180.0, 360.0)
	var diff: float = absf(_angle_delta_deg(heading_deg, wind_to_deg))
	var angle_factor: float = lerpf(1.18, 0.82, diff / 180.0)
	var wind_factor: float = clampf(0.86 + (wind_speed_m_s / 20.0), 0.8, 1.22)
	return clampf(base * angle_factor * wind_factor, 0.7, 2.1)

func _turn_forward_cells(ship_class: String, heading_deg: float) -> float:
	return _forward_cells_per_step(ship_class, heading_deg) * 0.72

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
			return {"hull": 14, "crew": 20, "maneuver": 0.06, "broadside": 4, "base_mp": 5, "turn_cost": 1, "forward_cells": 1.35}
		"Brig":
			return {"hull": 18, "crew": 28, "maneuver": 0.055, "broadside": 5, "base_mp": 4, "turn_cost": 1, "forward_cells": 1.2}
		"Frigate":
			return {"hull": 24, "crew": 40, "maneuver": 0.05, "broadside": 7, "base_mp": 3, "turn_cost": 2, "forward_cells": 1.05}
		"Merchantman":
			return {"hull": 20, "crew": 22, "maneuver": 0.045, "broadside": 3, "base_mp": 3, "turn_cost": 2, "forward_cells": 0.95}
		_:
			return {"hull": 16, "crew": 24, "maneuver": 0.055, "broadside": 4, "base_mp": 4, "turn_cost": 1, "forward_cells": 1.1}
