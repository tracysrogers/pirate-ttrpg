extends Node
class_name ShipBattle

signal battle_updated(text: String)
signal boarding_started(attacker_is_player: bool)
signal battle_finished(player_won: bool)

enum Phase {
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVED
}

var phase: Phase = Phase.PLAYER_TURN
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
var combat_cols: int = 40
var combat_rows: int = 24
var player_cell: Vector2i = Vector2i(10, 17)
var enemy_cell: Vector2i = Vector2i(30, 6)
var player_cell_pos: Vector2 = Vector2(10.0, 17.0)
var enemy_cell_pos: Vector2 = Vector2(30.0, 6.0)
var player_heading_idx: int = 2
var enemy_heading_idx: int = 6
var player_move_points: int = 0
var enemy_move_points: int = 0
var player_navigator_skill: int = 2
var enemy_navigator_skill: int = 2
var player_fired_this_turn: bool = false
var enemy_fired_this_turn: bool = false
var player_moved_this_turn: bool = false
var enemy_behavior: String = "engage"
var hazard_cells: Dictionary = {}
const TURN_STEP_DEG := 15.0

func start_battle(context: Dictionary = {}) -> void:
	phase = Phase.PLAYER_TURN
	player_ship_class = str(context.get("player_ship_class", "Sloop"))
	enemy_ship_class = str(context.get("enemy_ship_class", "Brig"))

	var player_stats: Dictionary = _ship_stats(player_ship_class)
	var enemy_stats: Dictionary = _ship_stats(enemy_ship_class)
	player_hull = int(player_stats.get("hull", 16))
	enemy_hull = int(enemy_stats.get("hull", 16))
	player_crew = int(player_stats.get("crew", 24))
	enemy_crew = int(enemy_stats.get("crew", 24))
	player_has_boarding_advantage = false
	enemy_has_boarding_advantage = false
	player_cell_pos = Vector2(10.0, 17.0)
	enemy_cell_pos = Vector2(30.0, 6.0)
	player_cell = Vector2i(10, 17)
	enemy_cell = Vector2i(30, 6)
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
	_generate_hazards(bool(context.get("near_land", false)))
	_sync_pose_from_positions()
	_begin_player_turn()
	emit_signal(
		"battle_updated",
		"Enemy %s sighted. You command a %s. Controls: Up=Advance, Left/Right=Turn+Advance, Enter=Fire, Space=Board, Down=End Turn." % [
			enemy_ship_class,
			player_ship_class
		]
	)

func player_turn_rotate(delta_deg: float) -> void:
	if phase != Phase.PLAYER_TURN:
		return
	var turn_cost: int = _turn_cost_for(player_ship_class)
	if player_move_points < turn_cost:
		emit_signal("battle_updated", "No movement points left. Fire or end turn.")
		return
	var turn_dir: float = 1.0 if delta_deg > 0.0 else -1.0
	var next_heading_deg: float = fposmod(player_heading_deg + turn_dir * TURN_STEP_DEG, 360.0)
	var turn_forward: float = _turn_forward_cells(player_ship_class, next_heading_deg)
	var next_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(next_heading_deg) * turn_forward
	if not _is_valid_pos(next_pos) or next_pos.distance_to(enemy_cell_pos) < 1.0:
		emit_signal("battle_updated", "Cannot turn %s: forward arc blocked." % ("starboard" if turn_dir > 0 else "port"))
		return
	player_heading_deg = next_heading_deg
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	player_cell_pos = next_pos
	_sync_pose_from_positions()
	if _check_collision_with_hazard(player_cell):
		return
	player_moved_this_turn = true
	player_move_points -= turn_cost
	emit_signal(
		"battle_updated",
		"You turn %s and surge forward (cost %d MP). MP %d." % [
			("starboard" if turn_dir > 0 else "port"),
			turn_cost,
			player_move_points
		]
	)

func player_turn_advance() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	if player_move_points <= 0:
		emit_signal("battle_updated", "No movement points left. Fire or end turn.")
		return
	var step_cells: float = _forward_cells_per_step(player_ship_class, player_heading_deg)
	var next_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(player_heading_deg) * step_cells
	if _is_valid_pos(next_pos) and next_pos.distance_to(enemy_cell_pos) >= 1.0:
		player_cell_pos = next_pos
		_sync_pose_from_positions()
		if _check_collision_with_hazard(player_cell):
			return
		player_moved_this_turn = true
		player_move_points -= 1
		emit_signal("battle_updated", "You advance %.1f squares. MP %d." % [step_cells, player_move_points])
	else:
		emit_signal("battle_updated", "Cannot advance: obstacle or map edge.")

func player_end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	if not player_moved_this_turn:
		var coast_cells: float = _forward_cells_per_step(player_ship_class, player_heading_deg) * 0.55
		var coast_pos: Vector2 = player_cell_pos + _bearing_deg_to_vector(player_heading_deg) * coast_cells
		if _is_valid_pos(coast_pos) and coast_pos.distance_to(enemy_cell_pos) >= 1.0:
			player_cell_pos = coast_pos
			_sync_pose_from_positions()
			if _check_collision_with_hazard(player_cell):
				return
			emit_signal("battle_updated", "Your ship coasts forward as the turn ends.")
		else:
			emit_signal("battle_updated", "Your ship attempts to coast, but cannot safely advance.")
	phase = Phase.ENEMY_TURN
	emit_signal("battle_updated", "You hold course and pass the turn.")

func player_fire_cannons() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	if player_fired_this_turn:
		emit_signal("battle_updated", "You already fired this turn.")
		return
	var shot: Dictionary = _resolve_cannon_shot(player_position, player_heading_deg, player_ship_class, enemy_position, enemy_heading_deg)
	if not bool(shot.get("can_fire", false)):
		emit_signal("battle_updated", "No firing solution. Bring target to broadside or chase-gun arc.")
		return
	var damage: int = int(shot.get("damage", 0))
	var shot_type: String = str(shot.get("shot_type", "broadside"))
	var raking_bonus: bool = bool(shot.get("raking", false))
	enemy_hull = max(0, enemy_hull - damage)
	player_has_boarding_advantage = true
	player_fired_this_turn = true
	var rake_text: String = " Raking hit!" if raking_bonus else ""
	emit_signal("battle_updated", "Player %s hits for %d hull damage.%s" % [shot_type, damage, rake_text])
	_check_resolution_only()
	if phase != Phase.RESOLVED:
		if player_move_points > 0:
			emit_signal("battle_updated", "Cannons fired. You may still maneuver with remaining movement points.")
		else:
			emit_signal("battle_updated", "Cannons fired. No movement points left; end turn when ready.")

func can_player_fire_now() -> bool:
	if phase != Phase.PLAYER_TURN or player_fired_this_turn:
		return false
	var shot: Dictionary = _resolve_cannon_shot(player_position, player_heading_deg, player_ship_class, enemy_position, enemy_heading_deg)
	return bool(shot.get("can_fire", false))

func player_attempt_boarding() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	if _grid_chebyshev_distance(player_cell, enemy_cell) > 1:
		emit_signal("battle_updated", "Too far to grapple. Close the distance first.")
		return
	var chance := 0.38
	var crew_ratio: float = float(player_crew) / float(max(1, enemy_crew))
	chance += clampf((crew_ratio - 1.0) * 0.2, -0.12, 0.2)
	if _is_target_stern_arc(player_position, enemy_position, enemy_heading_deg):
		chance += 0.08
	if player_has_boarding_advantage:
		chance += 0.25
	var success := randf() <= chance
	if success:
		emit_signal("battle_updated", "Player grapples enemy ship. Boarding begins!")
		emit_signal("boarding_started", true)
		return

	emit_signal("battle_updated", "Boarding failed. Enemy repels the assault.")
	phase = Phase.ENEMY_TURN
	enemy_has_boarding_advantage = true

func can_player_board_now() -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	return _grid_chebyshev_distance(player_cell, enemy_cell) <= 1

func enemy_take_turn() -> void:
	if phase != Phase.ENEMY_TURN:
		return
	_begin_enemy_turn()

	if enemy_hull <= 5 and randf() < 0.45 and _grid_chebyshev_distance(enemy_cell, player_cell) <= 1:
		_enemy_attempt_boarding()
		return

	while enemy_move_points > 0:
		if enemy_behavior == "escape":
			_enemy_escape_step()
		else:
			_enemy_maneuver_step()
		enemy_move_points -= 1
		if _check_collision_with_hazard(enemy_cell):
			return

	var enemy_shot: Dictionary = _resolve_cannon_shot(enemy_position, enemy_heading_deg, enemy_ship_class, player_position, player_heading_deg)
	if bool(enemy_shot.get("can_fire", false)) and not enemy_fired_this_turn:
		var damage: int = int(enemy_shot.get("damage", 0))
		var shot_type: String = str(enemy_shot.get("shot_type", "broadside"))
		var raking_bonus: bool = bool(enemy_shot.get("raking", false))
		player_hull = max(0, player_hull - damage)
		enemy_has_boarding_advantage = true
		enemy_fired_this_turn = true
		var rake_text: String = " Raking hit!" if raking_bonus else ""
		emit_signal("battle_updated", "Enemy %s strikes for %d hull damage.%s" % [shot_type, damage, rake_text])
		_check_resolution_or_pass_turn()
		return

	emit_signal("battle_updated", "Enemy maneuvers for better wind and angle.")
	_check_resolution_or_pass_turn()

func resolve_boarding_result(defender_successful: bool) -> void:
	if defender_successful:
		emit_signal("battle_updated", "Defense held. You can counter-board now.")
		phase = Phase.PLAYER_TURN
		player_has_boarding_advantage = true
	else:
		enemy_hull = max(0, enemy_hull - 6)
		emit_signal("battle_updated", "Boarding assault succeeded. Enemy ship is crippled.")
		_check_resolution_or_pass_turn()

func _enemy_attempt_boarding() -> void:
	var chance := 0.34
	var crew_ratio: float = float(enemy_crew) / float(max(1, player_crew))
	chance += clampf((crew_ratio - 1.0) * 0.2, -0.12, 0.2)
	if enemy_has_boarding_advantage:
		chance += 0.2
	var success := randf() <= chance
	if success:
		emit_signal("battle_updated", "Enemy boards your ship. Defend the deck!")
		emit_signal("boarding_started", false)
		return
	emit_signal("battle_updated", "Enemy boarding attempt fails.")
	phase = Phase.PLAYER_TURN

func _check_resolution_or_pass_turn() -> void:
	if enemy_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Enemy ship sinks. Victory!")
		emit_signal("battle_finished", true)
		return

	if player_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Your ship is lost. Defeat.")
		emit_signal("battle_finished", false)
		return

	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_TURN
	else:
		_begin_player_turn()

func _check_resolution_only() -> void:
	if enemy_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Enemy ship sinks. Victory!")
		emit_signal("battle_finished", true)
		return

	if player_hull <= 0:
		phase = Phase.RESOLVED
		emit_signal("battle_updated", "Your ship is lost. Defeat.")
		emit_signal("battle_finished", false)

func _pass_turn_to_enemy() -> void:
	if phase == Phase.RESOLVED:
		return
	phase = Phase.ENEMY_TURN

func _enemy_maneuver_step() -> void:
	var to_player: Vector2 = (player_position - enemy_position).normalized()
	var bearing_to_player: float = _vector_to_bearing_deg(to_player)
	var target_heading_a: float = fposmod(bearing_to_player + 90.0, 360.0)
	var target_heading_b: float = fposmod(bearing_to_player - 90.0, 360.0)
	var delta_a: float = absf(_angle_delta_deg(enemy_heading_deg, target_heading_a))
	var delta_b: float = absf(_angle_delta_deg(enemy_heading_deg, target_heading_b))
	var chosen_target: float = target_heading_a if delta_a < delta_b else target_heading_b
	var turn_delta: float = _angle_delta_deg(enemy_heading_deg, chosen_target)
	if absf(turn_delta) > 12.0 and randf() < 0.7:
		var signed_turn: float = clampf(turn_delta, -TURN_STEP_DEG, TURN_STEP_DEG)
		var new_heading_deg: float = fposmod(enemy_heading_deg + signed_turn, 360.0)
		var turn_forward: float = _turn_forward_cells(enemy_ship_class, new_heading_deg)
		var turn_next: Vector2 = enemy_cell_pos + _bearing_deg_to_vector(new_heading_deg) * turn_forward
		if _is_valid_pos(turn_next) and turn_next.distance_to(player_cell_pos) >= 1.0:
			enemy_heading_deg = new_heading_deg
			enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
			enemy_cell_pos = turn_next
		else:
			var fallback: Vector2 = enemy_cell_pos + _bearing_deg_to_vector(enemy_heading_deg) * _forward_cells_per_step(enemy_ship_class, enemy_heading_deg)
			if _is_valid_pos(fallback) and fallback.distance_to(player_cell_pos) >= 1.0:
				enemy_cell_pos = fallback
	else:
		var next: Vector2 = enemy_cell_pos + _bearing_deg_to_vector(enemy_heading_deg) * _forward_cells_per_step(enemy_ship_class, enemy_heading_deg)
		if _is_valid_pos(next) and next.distance_to(player_cell_pos) >= 1.0:
			enemy_cell_pos = next
	_sync_pose_from_positions()

func _enemy_escape_step() -> void:
	var away: Vector2 = (enemy_position - player_position).normalized()
	if away.length() <= 0.001:
		away = _bearing_deg_to_vector(enemy_heading_deg)
	var desired_heading: float = _vector_to_bearing_deg(away)
	var turn_delta: float = _angle_delta_deg(enemy_heading_deg, desired_heading)
	var signed_turn: float = clampf(turn_delta, -TURN_STEP_DEG, TURN_STEP_DEG)
	enemy_heading_deg = fposmod(enemy_heading_deg + signed_turn, 360.0)
	enemy_heading_idx = _bearing_to_heading_idx(enemy_heading_deg)
	var next: Vector2 = enemy_cell_pos + _bearing_deg_to_vector(enemy_heading_deg) * _forward_cells_per_step(enemy_ship_class, enemy_heading_deg)
	if _is_valid_pos(next) and next.distance_to(player_cell_pos) >= 1.0:
		enemy_cell_pos = next
	_sync_pose_from_positions()

func _advance_position(start: Vector2, heading_deg: float, ship_class: String) -> Vector2:
	var heading_vec: Vector2 = _bearing_deg_to_vector(heading_deg)
	var move_dist: float = _move_distance_units(ship_class, heading_deg)
	var next: Vector2 = start + heading_vec * move_dist
	next.x = clampf(next.x, 0.06, 0.94)
	next.y = clampf(next.y, 0.12, 0.88)
	return next

func _move_distance_units(ship_class: String, heading_deg: float) -> float:
	var base: float = _ship_stats(ship_class).get("maneuver", 0.055)
	var wind_to_deg: float = fposmod(wind_direction_deg + 180.0, 360.0)
	var diff: float = absf(_angle_delta_deg(heading_deg, wind_to_deg))
	var angle_factor: float = lerpf(1.25, 0.5, diff / 180.0)
	var wind_knots: float = wind_speed_m_s * 1.94384
	var wind_factor: float = clampf(0.75 + (wind_knots / 30.0), 0.65, 1.3)
	return base * angle_factor * wind_factor

func _has_cannon_solution(attacker_pos: Vector2, attacker_heading_deg: float, attacker_class: String, target_pos: Vector2) -> bool:
	var dist: float = attacker_pos.distance_to(target_pos)
	if dist > _cannon_range(attacker_class):
		return false
	var bearing_to_target: float = _vector_to_bearing_deg((target_pos - attacker_pos).normalized())
	var rel: float = absf(_angle_delta_deg(attacker_heading_deg, bearing_to_target))
	return absf(rel - 90.0) <= 42.0

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

func _begin_player_turn() -> void:
	phase = Phase.PLAYER_TURN
	player_move_points = _movement_points_for(player_ship_class, player_navigator_skill, player_heading_deg)
	player_fired_this_turn = false
	player_moved_this_turn = false

func _begin_enemy_turn() -> void:
	phase = Phase.ENEMY_TURN
	enemy_move_points = _movement_points_for(enemy_ship_class, enemy_navigator_skill, enemy_heading_deg)
	enemy_fired_this_turn = false

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
	var built: Dictionary = _build_player_movement_states()
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
	if phase != Phase.PLAYER_TURN:
		return false
	var built: Dictionary = _build_player_movement_states()
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
	player_cell_pos = selected["pos"]
	player_heading_deg = float(selected["heading_deg"])
	player_heading_idx = _bearing_to_heading_idx(player_heading_deg)
	player_move_points = int(selected["mp"])
	player_moved_this_turn = true
	_sync_pose_from_positions()
	if _check_collision_with_hazard(player_cell):
		return true
	return true

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
	emit_signal("battle_finished", false)
	return true

func _build_player_movement_states() -> Dictionary:
	var reachable: Dictionary = {}
	var forward_cells: Array[Vector2i] = []
	var open: Array[Dictionary] = [{
		"pos": player_cell_pos,
		"heading_deg": player_heading_deg,
		"mp": player_move_points
	}]
	var all_states: Array[Dictionary] = [{
		"pos": player_cell_pos,
		"heading_deg": player_heading_deg,
		"mp": player_move_points,
		"cell": player_cell
	}]
	var seen: Dictionary = {}
	var turn_cost: int = _turn_cost_for(player_ship_class)

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
			var step_cells: float = _forward_cells_per_step(player_ship_class, heading_deg)
			var next_pos: Vector2 = pos + _bearing_deg_to_vector(heading_deg) * step_cells
			if _is_valid_pos(next_pos) and next_pos.distance_to(enemy_cell_pos) >= 1.0:
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
			var turn_step: float = _turn_forward_cells(player_ship_class, heading_deg)
			var left_pos: Vector2 = pos + _bearing_deg_to_vector(left_heading_deg) * turn_step
			var right_pos: Vector2 = pos + _bearing_deg_to_vector(right_heading_deg) * turn_step
			if _is_valid_pos(left_pos) and left_pos.distance_to(enemy_cell_pos) >= 1.0:
				var left_state: Dictionary = {"pos": left_pos, "heading_deg": left_heading_deg, "mp": mp - turn_cost}
				open.append(left_state)
				all_states.append({
					"pos": left_pos,
					"heading_deg": left_heading_deg,
					"mp": mp - turn_cost,
					"cell": Vector2i(int(round(left_pos.x)), int(round(left_pos.y)))
				})
			if _is_valid_pos(right_pos) and right_pos.distance_to(enemy_cell_pos) >= 1.0:
				var right_state: Dictionary = {"pos": right_pos, "heading_deg": right_heading_deg, "mp": mp - turn_cost}
				open.append(right_state)
				all_states.append({
					"pos": right_pos,
					"heading_deg": right_heading_deg,
					"mp": mp - turn_cost,
					"cell": Vector2i(int(round(right_pos.x)), int(round(right_pos.y)))
				})

	var straight_pos: Vector2 = player_cell_pos
	for _i in range(player_move_points):
		straight_pos += _bearing_deg_to_vector(player_heading_deg) * _forward_cells_per_step(player_ship_class, player_heading_deg)
		if not _is_valid_pos(straight_pos) or straight_pos.distance_to(enemy_cell_pos) < 1.0:
			break
		forward_cells.append(Vector2i(int(round(straight_pos.x)), int(round(straight_pos.y))))

	return {
		"reachable": reachable,
		"forward_cells": forward_cells,
		"states": all_states
	}

func get_player_action_guidance() -> Dictionary:
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

func get_player_fire_preview_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if phase != Phase.PLAYER_TURN:
		return cells
	for y in range(combat_rows):
		for x in range(combat_cols):
			var cell := Vector2i(x, y)
			if cell == player_cell:
				continue
			var target_pos := Vector2(float(x) / float(max(1, combat_cols - 1)), float(y) / float(max(1, combat_rows - 1)))
			var shot: Dictionary = _resolve_cannon_shot(player_position, player_heading_deg, player_ship_class, target_pos, enemy_heading_deg)
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
