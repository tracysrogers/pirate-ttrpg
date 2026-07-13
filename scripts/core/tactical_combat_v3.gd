extends Node
# Tactical combat logic
class_name TacticalCombatSystem

signal tactical_finished(success: bool)
signal log_message(text: String)

enum ActionType { MOVE, MELEE, RANGED, ABILITY, END_TURN }

var grid: BattleGrid
var units: Array[CombatUnit] = []
var active_actor: CombatUnit = null
var initiative_order: Array[CombatUnit] = []
var current_idx: int = 0
var round_number: int = 1

var momentum_points: int = 0
const MAX_MOMENTUM = 10

func setup_boarding(ship_class: String) -> void:
	var layout: Dictionary = _get_ship_layout(ship_class)
	grid.width = layout.width
	grid.height = layout.height
	grid.set_deck_cells(layout.deck)
	grid.set_blocked_cells(layout.blocked)
	grid.set_objective_cells(layout.objective)
	grid.set_gangplank_cells(layout.gangplanks)
	grid.queue_redraw()

func _get_ship_layout(ship_class: String) -> Dictionary:
	match ship_class:
		"Sloop":
			return {
				"width": 10, "height": 8,
				"deck": _rect_to_cells(2, 2, 6, 4),
				"blocked": [Vector2i(4, 3), Vector2i(5, 3)],
				"objective": [Vector2i(7, 4)],
				"gangplanks": [Vector2i(4, 1), Vector2i(5, 1)]
			}
		"Brig":
			return {
				"width": 14, "height": 10,
				"deck": _rect_to_cells(2, 2, 10, 6),
				"blocked": [Vector2i(5, 5), Vector2i(9, 5), Vector2i(7, 4)],
				"objective": [Vector2i(11, 5)],
				"gangplanks": [Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1)]
			}
		"Frigate":
			return {
				"width": 18, "height": 12,
				"deck": _rect_to_cells(2, 2, 14, 8),
				"blocked": [Vector2i(5, 6), Vector2i(9, 6), Vector2i(13, 6), Vector2i(8, 4), Vector2i(10, 4)],
				"objective": [Vector2i(15, 6)],
				"gangplanks": [Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1)]
			}
	return _get_ship_layout("Brig")

func setup_town_assault() -> void:
	grid.width = 16
	grid.height = 12
	var ground_cells: Array[Vector2i] = _rect_to_cells(0, 0, 16, 12)
	grid.set_deck_cells(ground_cells)
	var buildings: Array[Vector2i] = []
	buildings.append_array(_rect_to_cells(2, 2, 3, 3))
	buildings.append_array(_rect_to_cells(11, 2, 3, 3))
	buildings.append_array(_rect_to_cells(2, 7, 3, 3))
	buildings.append_array(_rect_to_cells(11, 7, 3, 3))
	grid.set_blocked_cells(buildings)
	grid.set_objective_cells([Vector2i(14, 5), Vector2i(14, 6)])
	grid.queue_redraw()

func setup_combat(p_grid: BattleGrid, p_units: Array[CombatUnit]) -> void:
	grid = p_grid
	units = p_units
	momentum_points = 0
	_build_initiative()
	_start_actor_turn()

func _build_initiative() -> void:
	initiative_order = units.duplicate()
	initiative_order.sort_custom(func(a, b): return a.initiative > b.initiative)
	current_idx = 0

func _start_actor_turn() -> void:
	if initiative_order.is_empty(): return
	active_actor = initiative_order[current_idx]
	active_actor.set_active_actor(true)
	active_actor.set_acted(false)
	log_message.emit("Turn: %s (%s)" % [active_actor.name, _get_class_name(active_actor.unit_class)])
	if active_actor.team == CombatTurnManager.Team.ENEMY:
		_execute_ai_turn()

func _get_class_name(u_class: CombatUnit.UnitClass) -> String:
	match u_class:
		CombatUnit.UnitClass.SAILOR: return "Sailor"
		CombatUnit.UnitClass.MARINE: return "Marine"
		CombatUnit.UnitClass.OFFICER: return "Officer"
	return "CombatUnit"

func _rect_to_cells(x: int, y: int, w: int, h: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			cells.append(Vector2i(ix, iy))
	return cells

func _execute_ai_turn() -> void:
	await get_tree().create_timer(0.5).timeout
	var target: CombatUnit = null
	var min_dist: float = 999.0
	for u in units:
		if u.team == CombatTurnManager.Team.PLAYER:
			var d: float = float(_manhattan(active_actor.cell, u.cell))
			if d < min_dist:
				min_dist = d
				target = u
	if target:
		log_message.emit("AI %s eyes %s" % [active_actor.name, target.name])
	_next_turn()

func _next_turn() -> void:
	active_actor.set_active_actor(false)
	active_actor.set_acted(true)
	current_idx += 1
	if current_idx >= initiative_order.size():
		current_idx = 0
		round_number += 1
		log_message.emit("Round %d" % round_number)
	_start_actor_turn()

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func check_flanking(defender: CombatUnit) -> bool:
	var attacker := active_actor
	var dir := defender.cell - attacker.cell
	var opposite := defender.cell + dir
	for u in units:
		if u.team == attacker.team and u.cell == opposite: return true
	return false

func add_momentum(amount: int) -> void:
	momentum_points = clampi(momentum_points + amount, 0, MAX_MOMENTUM)

func perform_shove(pusher: CombatUnit, target: CombatUnit) -> void:
	var dir := target.cell - pusher.cell
	var landing := target.cell + dir
	if not grid.is_cell_on_deck(landing):
		target.take_damage(5)
		target.display_status("Overboard!")
		log_message.emit("Overboard!")
		_remove_unit(target)
	else:
		target.cell = landing
		target.position = grid.cell_to_local(landing)
		target.take_damage(2)
		target.display_status("Crushed!")
		log_message.emit("Crushed!")
	add_momentum(2)

func perform_attack(attacker: CombatUnit, defender: CombatUnit) -> void:
	var damage := randi_range(attacker.melee_damage_min, attacker.melee_damage_max)
	if check_flanking(defender):
		damage += 2
		log_message.emit("Flanking bonus!")
		add_momentum(1)
	
	# Sailor Ability: Low Kick
	if attacker.unit_class == CombatUnit.UnitClass.SAILOR and momentum_points >= 2:
		momentum_points -= 2
		perform_shove(attacker, defender)
		damage += 1
		log_message.emit("Low Kick!")
	
	# Officer Ability: Adrenaline
	if attacker.unit_class == CombatUnit.UnitClass.OFFICER and momentum_points >= 5:
		momentum_points -= 5
		damage *= 2
		log_message.emit("Adrenaline Burst!")
	
	# Marine Ability: Fire Volley
	if attacker.unit_class == CombatUnit.UnitClass.MARINE and momentum_points >= 4:
		momentum_points -= 4
		log_message.emit("Fire Volley!")
		for u in units.duplicate():
			if u != attacker and _manhattan(u.cell, defender.cell) <= 1:
				u.take_damage(4)
				u.display_status("Blast!")
				if u.hp <= 0: _remove_unit(u)
		return # Volley replaces standard attack sequence for the target if used this way or acts as AOE


	var died := defender.take_damage(damage)
	if died: 
		add_momentum(2)
		_remove_unit(defender)

func _remove_unit(unit: CombatUnit) -> void:
	units.erase(unit)
	initiative_order.erase(unit)
	unit.queue_free()
	_check_victory()

func _check_victory() -> void:
	var players := 0
	var enemies := 0
	for u in units:
		if u.team == CombatTurnManager.Team.PLAYER: players += 1
		else: enemies += 1
	if enemies == 0: tactical_finished.emit(true)
	elif players == 0: tactical_finished.emit(false)
