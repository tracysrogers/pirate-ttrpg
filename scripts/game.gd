extends Node2D

@onready var grid: BattleGrid = $Grid
@onready var units_root: Node2D = $Units
@onready var turn_manager: TurnManager = $TurnManager
@onready var game_flow: GameFlow = $GameFlow
@onready var world_map: WorldMap = $WorldMap
@onready var ship_battle: ShipBattle = $ShipBattle
@onready var main_camera: Camera2D = $Camera2D

var selected_unit: Unit = null
var reachable_cells: Array[Vector2i] = []
var units: Array[Unit] = []
var current_boarding_is_player_attacking: bool = true
var current_boarding_template_name: String = "brig"
var boarding_objective_cell: Vector2i = Vector2i(7, 4)
var boarding_gangplank_cells: Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 4)]
var boarding_obstacle_cells: Array[Vector2i] = []
var boarding_chokepoint_cells: Array[Vector2i] = []
var boarding_attacker_spawn_cells: Array[Vector2i] = []
var boarding_defender_spawn_cells: Array[Vector2i] = []
var boarding_defender_hold_turns_required: int = 3
var boarding_defender_hold_progress: int = 0
var boarding_active: bool = false
var captain_log_lines: Array[String] = []
var last_arrived_port: String = ""
var can_start_town_assault: bool = false
var captain_log_layer: CanvasLayer
var captain_log_panel: ColorRect
var captain_log_title_label: Label
var captain_log_text_label: Label
var left_sidebar_layer: CanvasLayer
var left_sidebar_panel: ColorRect
var time_controls_layer: CanvasLayer
var time_controls_box: HBoxContainer
var time_buttons: Dictionary = {}
var escape_menu_layer: CanvasLayer
var escape_menu_overlay: ColorRect
var escape_menu_panel: PanelContainer
var escape_menu_status_label: Label
var escape_settings_panel: PanelContainer
var escape_volume_slider: HSlider
var escape_fullscreen_check: CheckBox
var is_escape_menu_open: bool = false
var encounter_layer: CanvasLayer
var encounter_panel: PanelContainer
var encounter_title_label: Label
var encounter_text_label: Label
var encounter_avoid_button: Button
var encounter_engage_button: Button
var encounter_pursue_button: Button
var pending_encounter: Dictionary = {}
var encounter_active: bool = false
var ship_move_selected_cell: Vector2i = Vector2i(-1, -1)
var ship_combat_selected_action: int = 0
var ship_end_turn_confirm_open: bool = false
var ship_combat_zoom: float = 1.0
var ship_combat_pan: Vector2 = Vector2.ZERO
var ship_combat_is_panning: bool = false
var ship_combat_last_pan_pos: Vector2 = Vector2.ZERO
var main_menu_layer: CanvasLayer
var main_menu_panel: PanelContainer
var main_menu_settings_panel: PanelContainer
var main_menu_status_label: Label
var main_menu_volume_slider: HSlider
var main_menu_fullscreen_check: CheckBox
var in_main_menu: bool = true
var last_viewport_size: Vector2 = Vector2(-1.0, -1.0)
var boarding_initiative_order: Array[Unit] = []
var boarding_initiative_index: int = 0
var boarding_round: int = 1
var boarding_selected_action: int = 0
var boarding_unit_labels: Dictionary = {}
var boarding_actor_moved: bool = false
var boarding_actor_attacked: bool = false

const UI_BASE_SIDEBAR_WIDTH := 96.0
const UI_MIN_SIDEBAR_WIDTH := 84.0
const UI_MAX_SIDEBAR_WIDTH := 120.0
const UI_BASE_LOG_HEIGHT := 220.0
const UI_MIN_LOG_HEIGHT := 140.0
const UI_MAX_LOG_HEIGHT := 240.0
const UI_MIN_MAP_HEIGHT := 180.0
const SAVE_FILE_PATH := "user://savegame.json"
const SHIP_CLASS_SPEED_KNOTS := {
	"Sloop": 5.2,
	"Brig": 4.8,
	"Frigate": 4.6,
	"Merchantman": 3.9
}
const CROWS_NEST_HEIGHT_FEET := {
	"Sloop": 36.0,
	"Brig": 48.0,
	"Frigate": 62.0,
	"Merchantman": 42.0
}
const PLAYER_NAVIGATOR_SKILL := 3
const SHIP_ACTION_MOVE := 0
const SHIP_ACTION_FIRE := 1
const SHIP_ACTION_BOARD := 2
const SHIP_ACTION_END_TURN := 3
const SHIP_COMBAT_MIN_ZOOM := 0.7
const SHIP_COMBAT_MAX_ZOOM := 2.2
const BOARDING_ACTION_MOVE := 0
const BOARDING_ACTION_RANGED := 1
const BOARDING_ACTION_MELEE := 2
const CREW_CARD_LABELS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

func _ready() -> void:
	randomize()
	last_viewport_size = get_viewport_rect().size
	_sync_camera_to_viewport()
	_setup_left_sidebar_ui()
	_setup_captains_log_ui()
	_setup_time_controls_ui()
	_setup_encounter_ui()
	_setup_escape_menu_ui()
	_setup_main_menu_ui()
	game_flow.mode_changed.connect(_on_mode_changed)
	game_flow.message_posted.connect(_on_message_posted)
	world_map.destination_arrived.connect(_on_destination_arrived)
	world_map.random_encounter_triggered.connect(_on_random_encounter)
	ship_battle.battle_updated.connect(_on_ship_battle_updated)
	ship_battle.boarding_started.connect(_on_boarding_started)
	ship_battle.battle_finished.connect(_on_ship_battle_finished)
	_setup_tactical_units()
	turn_manager.turn_started.connect(_on_turn_started)
	_on_mode_changed(game_flow.current_mode)
	_layout_worldmap_ui()
	call_deferred("_layout_worldmap_ui")

func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size != last_viewport_size:
		last_viewport_size = viewport_size
		_sync_camera_to_viewport()
		_layout_worldmap_ui()
		_layout_tactical_ui()
	# Keep HUD overlays responsive to combat state changes.
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_worldmap_ui()
		_layout_tactical_ui()

func _draw() -> void:
	if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT:
		_sync_ship_move_selection()
		var viewport_size: Vector2 = get_viewport_rect().size
		var layout: Dictionary = _ship_combat_layout(viewport_size)
		var hud_rect: Rect2 = layout["hud_rect"]
		var combat_rect: Rect2 = layout["combat_rect"]
		var options_rect: Rect2 = layout["options_rect"]
		var grid_arena_rect: Rect2 = layout["grid_arena_rect"]
		var base_grid_rect: Rect2 = _naval_grid_rect(grid_arena_rect, ship_battle.combat_cols, ship_battle.combat_rows)
		var grid_rect: Rect2 = _ship_combat_view_rect(base_grid_rect)
		var view_rect := Rect2(Vector2.ZERO, viewport_size)
		draw_rect(view_rect, Color(0.08, 0.14, 0.2), true)
		draw_rect(Rect2(Vector2(0.0, viewport_size.y * 0.62), Vector2(viewport_size.x, viewport_size.y * 0.38)), Color(0.06, 0.11, 0.18), true)
		draw_rect(hud_rect, Color(0.02, 0.06, 0.1, 0.45), true)
		draw_rect(combat_rect, Color(0.08, 0.16, 0.25, 0.45), false, 2.0)
		_draw_naval_grid(grid_rect, ship_battle.combat_cols, ship_battle.combat_rows)
		_draw_ship_hazards(grid_rect)
		if ship_combat_selected_action == SHIP_ACTION_MOVE:
			_draw_ship_movement_preview(grid_rect)
		else:
			_draw_ship_fire_preview(grid_rect)
		_draw_ship_action_panel(options_rect)

		var player_center := _combat_to_screen(ship_battle.player_position, grid_rect, ship_battle.combat_cols, ship_battle.combat_rows)
		var enemy_center := _combat_to_screen(ship_battle.enemy_position, grid_rect, ship_battle.combat_cols, ship_battle.combat_rows)
		_draw_ship_silhouette(player_center, ship_battle.player_ship_class, ship_battle.player_heading_deg, Color(0.58, 0.44, 0.29))
		_draw_ship_silhouette(enemy_center, ship_battle.enemy_ship_class, ship_battle.enemy_heading_deg, Color(0.46, 0.33, 0.22))
		draw_string(ThemeDB.fallback_font, player_center + Vector2(-64, 92), "Your %s" % ship_battle.player_ship_class, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(ThemeDB.fallback_font, enemy_center + Vector2(-74, 92), "Enemy %s" % ship_battle.enemy_ship_class, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

		var compass_center := Vector2(hud_rect.position.x + hud_rect.size.x - 66.0, hud_rect.position.y + 78.0)
		_draw_wind_compass(compass_center, ship_battle.wind_direction_deg, ship_battle.wind_speed_m_s)
		var left_x: float = hud_rect.position.x + 18.0
		var middle_x: float = hud_rect.position.x + hud_rect.size.x * 0.43
		var right_limit_x: float = compass_center.x - 120.0

		var status := "Ship Combat - Mouse/Arrows: Select square | Enter: Confirm | F: Fire | Space: Board | E: End Turn | Wheel: Zoom"
		draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 26.0), status, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 20)
		var action_name: String = "Move"
		if ship_combat_selected_action == SHIP_ACTION_FIRE:
			action_name = "Fire Cannons"
		elif ship_combat_selected_action == SHIP_ACTION_BOARD:
			action_name = "Board"
		draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 44.0), "Selected Action: %s" % action_name, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 16)

		var player_line := "Player Hull: %d  Crew: %d" % [ship_battle.player_hull, ship_battle.player_crew]
		var enemy_line := "Enemy Hull: %d  Crew: %d" % [ship_battle.enemy_hull, ship_battle.enemy_crew]
		draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 64.0), player_line, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 20)
		draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 90.0), enemy_line, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 20)

		var phase_text := "Turn: Player"
		if ship_battle.phase == ShipBattle.Phase.ENEMY_TURN:
			phase_text = "Turn: Enemy"
		elif ship_battle.phase == ShipBattle.Phase.RESOLVED:
			phase_text = "Turn: Resolved"
		draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 58.0), phase_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 20)
		var turn_cost_text := "Turn Cost - You: %d | Enemy: %d" % [
			ship_battle.get_player_turn_cost(),
			ship_battle.get_enemy_turn_cost()
		]
		draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 84.0), turn_cost_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 18)
		var mp_text := "Movement Points - You: %d | Enemy: %d" % [ship_battle.player_move_points, ship_battle.enemy_move_points]
		draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 108.0), mp_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 18)
		var forward_text := "Forward Move: %.1f squares/advance" % float(ship_battle.get_player_movement_preview().get("forward_step_cells", 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 130.0), forward_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 18)
		if ship_move_selected_cell.x >= 0:
			var sel_text := "Selected: (%d,%d)  Press Enter to move" % [ship_move_selected_cell.x, ship_move_selected_cell.y]
			draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 130.0), sel_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 18)
	elif game_flow.current_mode == GameFlow.Mode.TACTICAL_COMBAT and game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		_draw_boarding_crew_cards()
		var panel_rect: Rect2 = _boarding_action_panel_rect()
		_draw_boarding_action_panel(panel_rect)

func _unhandled_input(event: InputEvent) -> void:
	if in_main_menu:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if is_escape_menu_open:
				_close_escape_menu()
			else:
				_open_escape_menu()
			get_viewport().set_input_as_handled()
			return

	if is_escape_menu_open:
		return

	if encounter_active:
		return

	if game_flow.current_mode == GameFlow.Mode.WORLD_MAP and world_map.handle_input(event):
		return

	if event is InputEventMouseMotion and game_flow.current_mode == GameFlow.Mode.TACTICAL_COMBAT:
		var local_pos := grid.to_local(get_global_mouse_position())
		grid.set_hovered_cell(grid.local_to_cell(local_pos))

	if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT and event is InputEventMouseMotion and ship_combat_is_panning:
		var motion: InputEventMouseMotion = event
		var delta: Vector2 = motion.position - ship_combat_last_pan_pos
		ship_combat_pan += delta
		ship_combat_last_pan_pos = motion.position
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match game_flow.current_mode:
			GameFlow.Mode.WORLD_MAP:
				_handle_world_map_click(get_global_mouse_position())
			GameFlow.Mode.SHIP_COMBAT:
				_handle_ship_combat_click(get_global_mouse_position())
			GameFlow.Mode.TACTICAL_COMBAT:
				_handle_tactical_click(get_global_mouse_position())

	if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			ship_combat_is_panning = mb.pressed
			ship_combat_last_pan_pos = mb.position
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			ship_combat_zoom = clampf(ship_combat_zoom * 1.1, SHIP_COMBAT_MIN_ZOOM, SHIP_COMBAT_MAX_ZOOM)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ship_combat_zoom = clampf(ship_combat_zoom / 1.1, SHIP_COMBAT_MIN_ZOOM, SHIP_COMBAT_MAX_ZOOM)
			return

	if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT:
		if event.is_action_pressed("ui_left"):
			ship_combat_selected_action = SHIP_ACTION_MOVE
			ship_end_turn_confirm_open = false
			_move_ship_selection(Vector2i.LEFT)
			return
		if event.is_action_pressed("ui_right"):
			ship_combat_selected_action = SHIP_ACTION_MOVE
			ship_end_turn_confirm_open = false
			_move_ship_selection(Vector2i.RIGHT)
			return
		if event.is_action_pressed("ui_up"):
			ship_combat_selected_action = SHIP_ACTION_MOVE
			ship_end_turn_confirm_open = false
			_move_ship_selection(Vector2i.UP)
			return
		if event.is_action_pressed("ui_down"):
			ship_combat_selected_action = SHIP_ACTION_MOVE
			ship_end_turn_confirm_open = false
			_move_ship_selection(Vector2i.DOWN)
			return

	if event.is_action_pressed("ui_accept"):
		match game_flow.current_mode:
			GameFlow.Mode.SHIP_COMBAT:
				if ship_combat_selected_action == SHIP_ACTION_MOVE:
					_confirm_ship_move_selection()
				elif ship_combat_selected_action == SHIP_ACTION_FIRE:
					ship_battle.player_fire_cannons()
					_resolve_enemy_ship_turn_if_needed()
				elif ship_combat_selected_action == SHIP_ACTION_BOARD:
					if ship_battle.can_player_board_now():
						ship_battle.player_attempt_boarding()
						_resolve_enemy_ship_turn_if_needed()
					else:
						game_flow.post_message("Boarding unavailable: move adjacent to the enemy.")
			GameFlow.Mode.TACTICAL_COMBAT:
				if game_flow.tactical_type != GameFlow.TacticalType.BOARDING:
					_end_turn()

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT and key_event.keycode == KEY_F:
			ship_battle.player_fire_cannons()
			_resolve_enemy_ship_turn_if_needed()
		elif game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT and key_event.keycode == KEY_E:
			ship_battle.player_end_turn()
			_resolve_enemy_ship_turn_if_needed()

	if event.is_action_pressed("ui_select") and game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT:
		ship_battle.player_attempt_boarding()
		_resolve_enemy_ship_turn_if_needed()

	if event.is_action_pressed("ui_select") and game_flow.current_mode == GameFlow.Mode.TACTICAL_COMBAT:
		game_flow.post_message("Manual resolve removed. Win by combat/objectives.")

	if event.is_action_pressed("ui_cancel"):
		if game_flow.current_mode == GameFlow.Mode.TACTICAL_COMBAT:
			_clear_selection()

func _setup_tactical_units() -> void:
	for child in units_root.get_children():
		child.queue_free()
	units.clear()

	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		_configure_boarding_layout()
		if current_boarding_is_player_attacking:
			_spawn_units_from_cells(Unit.Team.PLAYER, boarding_attacker_spawn_cells)
			_spawn_units_from_cells(Unit.Team.ENEMY, boarding_defender_spawn_cells)
		else:
			_spawn_units_from_cells(Unit.Team.PLAYER, boarding_defender_spawn_cells)
			_spawn_units_from_cells(Unit.Team.ENEMY, boarding_attacker_spawn_cells)
	else:
		_clear_special_tactical_layout()
		_create_unit(Unit.Team.PLAYER, Vector2i(2, 2))
		_create_unit(Unit.Team.PLAYER, Vector2i(3, 4))
		_create_unit(Unit.Team.ENEMY, Vector2i(10, 3))
		_create_unit(Unit.Team.ENEMY, Vector2i(9, 6))
	_assign_boarding_unit_labels()
	_refresh_boarding_unit_visuals()
	_layout_tactical_ui()

func _create_unit(team: Unit.Team, cell: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.team = team
	unit.tile_size = grid.tile_size
	unit.cell = cell
	unit.position = _unit_world_from_cell(cell)
	units_root.add_child(unit)
	units.append(unit)
	return unit

func _spawn_units_from_cells(team: Unit.Team, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var spawn_cell := _resolve_spawn_cell(cell)
		if spawn_cell == Vector2i(-1, -1):
			game_flow.post_message("Warning: no valid spawn tile found for %s unit." % _team_label(team))
			continue
		_create_unit(team, spawn_cell)

func _handle_world_map_click(world_pos: Vector2) -> void:
	var local_pos := world_map.to_local(world_pos)
	var port_name := world_map.pick_port_from_click(local_pos)
	if port_name == "":
		return
	if world_map.set_target_port(port_name):
		can_start_town_assault = false
		game_flow.post_message("Sailing automatically toward %s." % port_name)

func _handle_tactical_click(world_pos: Vector2) -> void:
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		var panel_rect: Rect2 = _boarding_action_panel_rect()
		if panel_rect.has_point(world_pos):
			if _boarding_action_button_rect(panel_rect, BOARDING_ACTION_MOVE).has_point(world_pos):
				boarding_selected_action = BOARDING_ACTION_MOVE
				var actor: Unit = _current_boarding_actor()
				if actor != null and actor.team == Unit.Team.PLAYER:
					_select_unit(actor)
			elif _boarding_action_button_rect(panel_rect, BOARDING_ACTION_RANGED).has_point(world_pos):
				boarding_selected_action = BOARDING_ACTION_RANGED
			elif _boarding_action_button_rect(panel_rect, BOARDING_ACTION_MELEE).has_point(world_pos):
				boarding_selected_action = BOARDING_ACTION_MELEE
			return

	var active_actor: Unit = _current_boarding_actor() if game_flow.tactical_type == GameFlow.TacticalType.BOARDING else null
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and (active_actor == null or active_actor.team != Unit.Team.PLAYER):
		return

	var local_pos := grid.to_local(world_pos)
	var clicked_cell := grid.local_to_cell(local_pos)
	if not grid.is_in_bounds(clicked_cell):
		_clear_selection()
		return
	if grid.is_cell_blocked(clicked_cell):
		_clear_selection()
		return
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and boarding_chokepoint_cells.has(clicked_cell):
		_clear_selection()
		return

	var clicked_unit := _get_unit_at(clicked_cell)
	if selected_unit != null and clicked_unit != null and clicked_unit.team != selected_unit.team:
		if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and boarding_selected_action == BOARDING_ACTION_RANGED:
			_perform_ranged_attack(selected_unit, clicked_unit)
			return
		if _can_melee_attack(selected_unit, clicked_unit):
			_perform_melee_attack(selected_unit, clicked_unit)
		return

	if clicked_unit != null and _unit_matches_current_team(clicked_unit):
		_select_unit(clicked_unit)
		return

	if selected_unit != null and reachable_cells.has(clicked_cell):
		_move_selected_unit(clicked_cell)
		return

	_clear_selection()

func _select_unit(unit: Unit) -> void:
	if game_flow.tactical_type != GameFlow.TacticalType.BOARDING and unit.has_acted:
		return
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and unit != _current_boarding_actor():
		return
	if selected_unit != null:
		selected_unit.set_selected(false)

	selected_unit = unit
	selected_unit.set_selected(true)

	reachable_cells.clear()
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and (boarding_selected_action != BOARDING_ACTION_MOVE or boarding_actor_moved):
		grid.set_highlighted([])
		return
	var blocked := _blocked_cells_for(unit)
	reachable_cells = Pathfinder.reachable_cells(unit.cell, unit.move_range, Vector2i(grid.width, grid.height), blocked)
	grid.set_highlighted(reachable_cells)

func _clear_selection() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = null
	reachable_cells.clear()
	grid.set_highlighted([])
	_refresh_boarding_unit_visuals()

func _move_selected_unit(target_cell: Vector2i) -> void:
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		if boarding_actor_moved:
			return
		if grid.is_cell_blocked(target_cell):
			return
	selected_unit.cell = target_cell
	selected_unit.position = _unit_world_from_cell(target_cell)
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		boarding_actor_moved = true
	else:
		selected_unit.set_acted(true)
	_clear_selection()
	_check_tactical_outcome()
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		if boarding_actor_attacked:
			_advance_boarding_turn()
		else:
			var actor: Unit = _current_boarding_actor()
			if actor != null and actor.team == Unit.Team.PLAYER:
				_select_unit(actor)
	else:
		_check_auto_end_turn()

func _end_turn() -> void:
	if game_flow.current_mode != GameFlow.Mode.TACTICAL_COMBAT:
		return
	_clear_selection()
	turn_manager.end_turn()

func _on_turn_started(team: int) -> void:
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		return
	for unit in units:
		if unit.team == team:
			unit.set_acted(false)

	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		_update_boarding_hold_progress()
		_check_tactical_outcome()

	if team == TurnManager.Team.ENEMY:
		_take_enemy_tactical_turn()

func _take_enemy_tactical_turn() -> void:
	for unit in units:
		if unit.team != Unit.Team.ENEMY:
			continue
		if unit.has_acted:
			continue

		var adjacent_target := _get_adjacent_enemy(unit)
		if adjacent_target != null:
			_perform_melee_attack(unit, adjacent_target, true)
			continue

		var move_target := _best_enemy_move_cell(unit)
		if move_target != unit.cell:
			unit.cell = move_target
			unit.position = _unit_world_from_cell(move_target)
			unit.set_acted(true)
			var post_move_target := _get_adjacent_enemy(unit)
			if post_move_target != null and not unit.has_acted:
				_perform_melee_attack(unit, post_move_target, true)
		else:
			unit.set_acted(true)

	_check_tactical_outcome()
	_end_turn()

func _check_auto_end_turn() -> void:
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		return
	for unit in units:
		if _unit_matches_current_team(unit) and not unit.has_acted:
			return
	_end_turn()

func _get_unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if unit.cell == cell:
			return unit
	return null

func _blocked_cells_for(active_unit: Unit) -> Dictionary:
	var blocked := {}
	for cell in boarding_obstacle_cells:
		blocked[cell] = true
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		for cell in boarding_chokepoint_cells:
			blocked[cell] = true
	for unit in units:
		if unit == active_unit:
			continue
		blocked[unit.cell] = true
	return blocked

func _unit_matches_current_team(unit: Unit) -> bool:
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		return unit == _current_boarding_actor()
	if turn_manager.current_team == TurnManager.Team.PLAYER:
		return unit.team == Unit.Team.PLAYER
	return unit.team == Unit.Team.ENEMY

func _set_mode(mode: GameFlow.Mode) -> void:
	game_flow.set_mode(mode)

func _on_mode_changed(new_mode: int) -> void:
	if in_main_menu:
		grid.visible = false
		units_root.visible = false
		world_map.visible = false
		_sync_camera_to_viewport()
		return
	var tactical_visible := new_mode == GameFlow.Mode.TACTICAL_COMBAT
	grid.visible = tactical_visible
	units_root.visible = tactical_visible
	world_map.visible = new_mode == GameFlow.Mode.WORLD_MAP
	if new_mode == GameFlow.Mode.SHIP_COMBAT:
		ship_combat_selected_action = SHIP_ACTION_MOVE
		ship_end_turn_confirm_open = false
		ship_combat_zoom = 1.0
		ship_combat_pan = Vector2.ZERO
		ship_combat_is_panning = false
		_sync_ship_move_selection()
	_sync_camera_to_viewport()
	_layout_tactical_ui()
	if world_map.visible:
		call_deferred("_layout_worldmap_ui")

func _on_message_posted(text: String) -> void:
	print("[Captain's Log] %s" % text)
	captain_log_lines.append(text)
	if captain_log_lines.size() > 5:
		captain_log_lines.pop_front()
	_refresh_captains_log_ui()

func _on_destination_arrived(port_name: String) -> void:
	last_arrived_port = port_name
	can_start_town_assault = true
	game_flow.post_message("Arrived at %s. Press T here to start a town assault scenario soon." % port_name)

func _on_random_encounter() -> void:
	can_start_town_assault = false
	_start_spotting_encounter()

func _on_ship_battle_updated(text: String) -> void:
	game_flow.post_message(text)

func _on_boarding_started(attacker_is_player: bool) -> void:
	current_boarding_is_player_attacking = attacker_is_player
	game_flow.set_tactical_type(GameFlow.TacticalType.BOARDING)
	boarding_active = true
	boarding_defender_hold_progress = 0
	_setup_tactical_units()
	_set_mode(GameFlow.Mode.TACTICAL_COMBAT)
	_start_boarding_initiative()

	if attacker_is_player:
		game_flow.post_message(
			"Board enemy %s deck: defeat crew or seize the helm at (%d,%d)." % [
				current_boarding_template_name,
				boarding_objective_cell.x,
				boarding_objective_cell.y
			]
		)
	else:
		game_flow.post_message("Defend your %s deck for 3 rounds or eliminate boarders." % current_boarding_template_name)

func _on_ship_battle_finished(player_won: bool) -> void:
	if player_won:
		game_flow.post_message("Naval battle won. Back to Caribbean map.")
	else:
		game_flow.post_message("Your ship is beaten. Retreating to world map.")
	_set_mode(GameFlow.Mode.WORLD_MAP)

func _resolve_enemy_ship_turn_if_needed() -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	if ship_battle.phase == ShipBattle.Phase.ENEMY_TURN:
		ship_battle.enemy_take_turn()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		if game_flow.current_mode == GameFlow.Mode.WORLD_MAP and can_start_town_assault:
			_start_town_assault_demo()
		elif game_flow.current_mode == GameFlow.Mode.WORLD_MAP:
			game_flow.post_message("Sail to a port first, then press T to begin a town assault.")

	if event.is_action_pressed("ui_page_down"):
		_start_town_assault_demo()

func _start_town_assault_demo() -> void:
	game_flow.set_tactical_type(GameFlow.TacticalType.TOWN_ASSAULT)
	boarding_active = false
	can_start_town_assault = false
	_setup_tactical_units()
	_set_mode(GameFlow.Mode.TACTICAL_COMBAT)
	turn_manager.begin_battle()
	if last_arrived_port != "":
		game_flow.post_message("Town assault at %s started (prototype)." % last_arrived_port)
	else:
		game_flow.post_message("Town assault started (prototype). Capture key structures next.")

func _can_melee_attack(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		if attacker != _current_boarding_actor():
			return false
		if boarding_actor_attacked:
			return false
	elif attacker.has_acted:
		return false
	return _manhattan(attacker.cell, defender.cell) == 1

func _perform_melee_attack(attacker: Unit, defender: Unit, silent: bool = false) -> void:
	var damage := randi_range(attacker.melee_damage_min, attacker.melee_damage_max)
	var died := defender.take_damage(damage)
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		boarding_actor_attacked = true
	else:
		attacker.set_acted(true)
	if not silent:
		game_flow.post_message("%s hits for %d damage." % [_unit_label(attacker), damage])

	if died:
		if not silent:
			game_flow.post_message("%s is defeated." % _unit_label(defender))
		_remove_unit(defender)

	_clear_selection()
	_check_tactical_outcome()
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		_advance_boarding_turn()
	else:
		_check_auto_end_turn()

func _perform_ranged_attack(attacker: Unit, defender: Unit, silent: bool = false) -> void:
	if attacker == null or defender == null:
		return
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		if attacker != _current_boarding_actor() or boarding_actor_attacked:
			return
	elif attacker.has_acted:
		return
	var distance: int = _manhattan(attacker.cell, defender.cell)
	if distance <= 1 or distance > 6:
		if not silent:
			game_flow.post_message("Ranged attack requires 2-6 tiles distance.")
		return
	var los_block: Vector2i = _first_los_blocker(attacker.cell, defender.cell)
	if los_block != Vector2i(-1, -1):
		if not silent:
			game_flow.post_message("Shot blocked by cover at (%d,%d)." % [los_block.x, los_block.y])
		return
	var cover_bonus: int = _cover_bonus_for(defender.cell)
	var hit_chance: float = clampf(0.78 - (float(distance - 2) * 0.07) - (float(cover_bonus) * 0.12), 0.25, 0.9)
	if randf() > hit_chance:
		if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
			boarding_actor_attacked = true
		else:
			attacker.set_acted(true)
		if not silent:
			game_flow.post_message("%s fires and misses (%d%% hit)." % [_unit_label(attacker), int(round(hit_chance * 100.0))])
		_clear_selection()
		_check_tactical_outcome()
		if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
			_advance_boarding_turn()
		else:
			_check_auto_end_turn()
		return
	var damage: int = randi_range(1, 3) - cover_bonus
	damage = max(1, damage)
	var died: bool = defender.take_damage(damage)
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		boarding_actor_attacked = true
	else:
		attacker.set_acted(true)
	if not silent:
		var cover_text: String = " (target in cover)" if cover_bonus > 0 else ""
		game_flow.post_message("%s fires and hits for %d damage.%s" % [_unit_label(attacker), damage, cover_text])
	if died:
		if not silent:
			game_flow.post_message("%s is defeated." % _unit_label(defender))
		_remove_unit(defender)
	_clear_selection()
	_check_tactical_outcome()
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		_advance_boarding_turn()
	else:
		_check_auto_end_turn()

func _remove_unit(unit: Unit) -> void:
	units.erase(unit)
	_prune_boarding_initiative()
	unit.queue_free()

func _alive_count(team: Unit.Team) -> int:
	var count := 0
	for unit in units:
		if unit.team == team:
			count += 1
	return count

func _start_boarding_initiative() -> void:
	boarding_initiative_order.clear()
	var players: Array[Unit] = []
	var enemies: Array[Unit] = []
	for unit in units:
		if unit != null and is_instance_valid(unit):
			unit.set_acted(false)
			if unit.team == Unit.Team.PLAYER:
				players.append(unit)
			else:
				enemies.append(unit)
	players.shuffle()
	enemies.shuffle()
	while not players.is_empty() or not enemies.is_empty():
		if not players.is_empty():
			boarding_initiative_order.append(players.pop_front())
		if not enemies.is_empty():
			boarding_initiative_order.append(enemies.pop_front())
	boarding_initiative_index = 0
	boarding_round = 1
	boarding_selected_action = BOARDING_ACTION_MOVE
	_begin_boarding_actor_turn()

func _current_boarding_actor() -> Unit:
	if game_flow.tactical_type != GameFlow.TacticalType.BOARDING:
		return null
	if boarding_initiative_order.is_empty():
		return null
	if boarding_initiative_index < 0 or boarding_initiative_index >= boarding_initiative_order.size():
		return null
	var actor: Unit = boarding_initiative_order[boarding_initiative_index]
	if actor == null or not is_instance_valid(actor):
		return null
	return actor

func _begin_boarding_actor_turn() -> void:
	var actor: Unit = _current_boarding_actor()
	if actor == null:
		return
	boarding_actor_moved = false
	boarding_actor_attacked = false
	_clear_selection()
	actor.set_acted(false)
	boarding_selected_action = BOARDING_ACTION_MOVE
	_refresh_boarding_unit_visuals()
	game_flow.post_message("Boarding turn: %s (Round %d)." % [_unit_label(actor), boarding_round])
	if actor.team == Unit.Team.PLAYER:
		_select_unit(actor)
	else:
		_take_enemy_boarding_action(actor)

func _advance_boarding_turn() -> void:
	if game_flow.tactical_type != GameFlow.TacticalType.BOARDING:
		return
	_prune_boarding_initiative()
	if game_flow.current_mode != GameFlow.Mode.TACTICAL_COMBAT:
		return
	if units.is_empty():
		return
	boarding_initiative_index += 1
	if boarding_initiative_index >= boarding_initiative_order.size():
		boarding_initiative_index = 0
		boarding_round += 1
		_rebuild_boarding_round_order()
	_begin_boarding_actor_turn()

func _prune_boarding_initiative() -> void:
	var actor_before: Unit = _current_boarding_actor()
	var pruned: Array[Unit] = []
	for unit in boarding_initiative_order:
		if unit != null and is_instance_valid(unit) and units.has(unit):
			pruned.append(unit)
	boarding_initiative_order = pruned
	if boarding_initiative_order.is_empty():
		return
	if actor_before != null and boarding_initiative_order.has(actor_before):
		boarding_initiative_index = boarding_initiative_order.find(actor_before)
	else:
		boarding_initiative_index = clampi(boarding_initiative_index, 0, boarding_initiative_order.size() - 1)

func _rebuild_boarding_round_order() -> void:
	var players: Array[Unit] = []
	var enemies: Array[Unit] = []
	for unit in boarding_initiative_order:
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.team == Unit.Team.PLAYER:
			players.append(unit)
		else:
			enemies.append(unit)
	players.shuffle()
	enemies.shuffle()
	var rebuilt: Array[Unit] = []
	while not players.is_empty() or not enemies.is_empty():
		if not players.is_empty():
			rebuilt.append(players.pop_front())
		if not enemies.is_empty():
			rebuilt.append(enemies.pop_front())
	boarding_initiative_order = rebuilt

func _take_enemy_boarding_action(unit: Unit) -> void:
	if unit == null or unit.team != Unit.Team.ENEMY:
		return
	boarding_actor_moved = false
	boarding_actor_attacked = false
	var adjacent_target: Unit = _get_adjacent_enemy(unit)
	if adjacent_target != null:
		_perform_melee_attack(unit, adjacent_target, true)
		return
	var ranged_target: Unit = _best_enemy_ranged_target(unit)
	if ranged_target != null and randf() < 0.5:
		_perform_ranged_attack(unit, ranged_target, true)
		if boarding_actor_attacked:
			return
	var move_target := _best_enemy_move_cell(unit)
	if move_target != unit.cell:
		unit.cell = move_target
		unit.position = _unit_world_from_cell(move_target)
		boarding_actor_moved = true
	adjacent_target = _get_adjacent_enemy(unit)
	if adjacent_target != null and not boarding_actor_attacked:
		_perform_melee_attack(unit, adjacent_target, true)
		return
	if not boarding_actor_attacked:
		ranged_target = _best_enemy_ranged_target(unit)
		if ranged_target != null:
			_perform_ranged_attack(unit, ranged_target, true)
			if boarding_actor_attacked:
				return
	if not boarding_actor_attacked:
		_advance_boarding_turn()

func _best_enemy_ranged_target(unit: Unit) -> Unit:
	var best: Unit = null
	var best_dist: int = 99999
	for other in units:
		if other.team == unit.team:
			continue
		var dist: int = _manhattan(unit.cell, other.cell)
		if dist < 2 or dist > 6:
			continue
		if _first_los_blocker(unit.cell, other.cell) != Vector2i(-1, -1):
			continue
		if dist < best_dist:
			best_dist = dist
			best = other
	return best

func _check_tactical_outcome() -> void:
	var player_alive := _alive_count(Unit.Team.PLAYER)
	var enemy_alive := _alive_count(Unit.Team.ENEMY)
	if player_alive <= 0:
		_handle_tactical_finished(false)
		return
	if enemy_alive <= 0:
		_handle_tactical_finished(true)
		return

	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and boarding_active:
		var attackers_on_objective := _has_attacker_on_objective()
		if attackers_on_objective:
			_handle_tactical_finished(true)
			return
		if boarding_defender_hold_progress >= boarding_defender_hold_turns_required:
			_handle_tactical_finished(false)

func _handle_tactical_finished(player_side_successful: bool) -> void:
	boarding_active = false
	_clear_selection()
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		var defender_successful := not player_side_successful
		if not current_boarding_is_player_attacking:
			defender_successful = player_side_successful
		ship_battle.resolve_boarding_result(defender_successful)
		_set_mode(GameFlow.Mode.SHIP_COMBAT)
		return

	if player_side_successful:
		game_flow.post_message("Town assault won. Returning to Caribbean travel.")
	else:
		game_flow.post_message("Town assault failed. Returning to Caribbean travel.")
	_set_mode(GameFlow.Mode.WORLD_MAP)

func _update_boarding_hold_progress() -> void:
	if not boarding_active:
		return
	if _attackers_team_has_objective_control():
		boarding_defender_hold_progress = 0
		return
	if turn_manager.current_team == TurnManager.Team.PLAYER and not current_boarding_is_player_attacking:
		boarding_defender_hold_progress += 1
	if turn_manager.current_team == TurnManager.Team.ENEMY and current_boarding_is_player_attacking:
		boarding_defender_hold_progress += 1

	if boarding_defender_hold_progress > 0:
		game_flow.post_message("Defenders held %d/%d turns." % [boarding_defender_hold_progress, boarding_defender_hold_turns_required])

func _attackers_team_has_objective_control() -> bool:
	var attackers_team := Unit.Team.PLAYER if current_boarding_is_player_attacking else Unit.Team.ENEMY
	for unit in units:
		if unit.team == attackers_team and unit.cell == boarding_objective_cell:
			return true
	return false

func _has_attacker_on_objective() -> bool:
	return _attackers_team_has_objective_control()

func _get_adjacent_enemy(unit: Unit) -> Unit:
	for candidate in units:
		if candidate.team == unit.team:
			continue
		if _manhattan(unit.cell, candidate.cell) == 1:
			return candidate
	return null

func _best_enemy_move_cell(unit: Unit) -> Vector2i:
	var blocked := _blocked_cells_for(unit)
	var reachable := Pathfinder.reachable_cells(
		unit.cell,
		unit.move_range,
		Vector2i(grid.width, grid.height),
		blocked
	)
	if reachable.is_empty():
		return unit.cell

	var targets: Array[Vector2i] = []
	for ally in units:
		if ally.team == Unit.Team.PLAYER:
			targets.append(ally.cell)
	if targets.is_empty():
		return unit.cell

	var best_cell := unit.cell
	var best_score := 999999
	for cell in reachable:
		var nearest := 999999
		for target in targets:
			nearest = min(nearest, _manhattan(cell, target))
		if nearest < best_score:
			best_score = nearest
			best_cell = cell
	return best_cell

func _resolve_spawn_cell(preferred: Vector2i) -> Vector2i:
	if _is_spawnable_cell(preferred):
		return preferred
	return _nearest_valid_cell(preferred)

func _is_spawnable_cell(cell: Vector2i) -> bool:
	if not grid.is_in_bounds(cell):
		return false
	if grid.is_cell_blocked(cell):
		return false
	return _get_unit_at(cell) == null

func _nearest_valid_cell(origin: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for x in range(grid.width):
		for y in range(grid.height):
			var cell := Vector2i(x, y)
			if _is_spawnable_cell(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _manhattan(a, origin)
		var db := _manhattan(b, origin)
		if da == db:
			return a.y < b.y if a.y != b.y else a.x < b.x
		return da < db
	)
	return candidates[0]

func _configure_boarding_layout() -> void:
	# First boarding prototype: 20-yard sloop deck with 1-yard tiles.
	grid.width = 20
	grid.height = 8
	current_boarding_template_name = "20-yard sloop"
	boarding_objective_cell = Vector2i(16, 4)
	boarding_gangplank_cells = [Vector2i(3, 3), Vector2i(3, 4)]
	boarding_chokepoint_cells = [Vector2i(7, 3), Vector2i(7, 4), Vector2i(8, 3), Vector2i(8, 4)]
	boarding_obstacle_cells = [
		Vector2i(6, 2), Vector2i(6, 5), # foremast
		Vector2i(12, 2), Vector2i(12, 5), # mainmast
		Vector2i(15, 1), Vector2i(16, 1), Vector2i(17, 1),
		Vector2i(15, 2), Vector2i(16, 2), Vector2i(17, 2) # stern cabin
	]
	boarding_attacker_spawn_cells = [Vector2i(1, 2), Vector2i(1, 4), Vector2i(2, 3), Vector2i(2, 5)]
	boarding_defender_spawn_cells = [Vector2i(18, 2), Vector2i(18, 4), Vector2i(17, 3), Vector2i(17, 5)]

	grid.set_blocked_cells(boarding_obstacle_cells)
	grid.set_gangplank_cells(boarding_gangplank_cells)
	grid.set_objective_cells([boarding_objective_cell])
	grid.set_chokepoint_cells(boarding_chokepoint_cells)

func _clear_special_tactical_layout() -> void:
	grid.width = 14
	grid.height = 10
	boarding_obstacle_cells.clear()
	boarding_chokepoint_cells.clear()
	boarding_attacker_spawn_cells.clear()
	boarding_defender_spawn_cells.clear()
	grid.set_blocked_cells([])
	grid.set_gangplank_cells([])
	grid.set_objective_cells([])
	grid.set_chokepoint_cells([])

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _first_los_blocker(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var line_cells: Array[Vector2i] = _line_cells_between(from_cell, to_cell)
	for cell in line_cells:
		if boarding_obstacle_cells.has(cell):
			return cell
		var blocker: Unit = _get_unit_at(cell)
		if blocker != null and blocker.cell != from_cell and blocker.cell != to_cell:
			return cell
	return Vector2i(-1, -1)

func _line_cells_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	while x0 != x1 or y0 != y1:
		var e2: int = err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
		var point: Vector2i = Vector2i(x0, y0)
		if point != to_cell:
			points.append(point)
	return points

func _cover_bonus_for(cell: Vector2i) -> int:
	var orthogonal: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for offset in orthogonal:
		if boarding_obstacle_cells.has(cell + offset):
			return 1
	return 0

func _unit_label(unit: Unit) -> String:
	return "Player crew" if unit.team == Unit.Team.PLAYER else "Enemy crew"

func _team_label(team: Unit.Team) -> String:
	return "player" if team == Unit.Team.PLAYER else "enemy"

func _to_vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not (value is Array):
		return result

	for item in value:
		if item is Vector2i:
			result.append(item)
	return result

func _draw_ship_silhouette(center: Vector2, ship_class: String, heading_deg: float, hull_color: Color) -> void:
	var scale: float = _ship_draw_scale(ship_class)
	var heading_rad: float = deg_to_rad(90.0 - heading_deg)
	var basis := Transform2D(heading_rad, center)
	var hull_local := PackedVector2Array([
		Vector2(-130.0 * scale, 18.0 * scale),
		Vector2(-72.0 * scale, -8.0 * scale),
		Vector2(70.0 * scale, -10.0 * scale),
		Vector2(132.0 * scale, 6.0 * scale),
		Vector2(96.0 * scale, 36.0 * scale),
		Vector2(-94.0 * scale, 38.0 * scale)
	])
	var hull := PackedVector2Array()
	for p in hull_local:
		hull.append(basis * p)
	draw_colored_polygon(hull, hull_color)
	draw_polyline(hull, Color(0.18, 0.12, 0.07), 2.0, true)

	var mast1_x: float = -30.0 * scale
	var mast2_x: float = 34.0 * scale
	var mast_height_1: float = 110.0 * scale
	var mast_height_2: float = 82.0 * scale
	draw_line(basis * Vector2(mast1_x, 18.0 * scale), basis * Vector2(mast1_x, -mast_height_1), Color(0.86, 0.8, 0.65), 3.0)
	draw_line(basis * Vector2(mast2_x, 20.0 * scale), basis * Vector2(mast2_x, -mast_height_2), Color(0.86, 0.8, 0.65), 3.0)

	var sail_color := Color(0.9, 0.89, 0.82, 0.9)
	var fore_sail := PackedVector2Array([
		basis * Vector2(mast2_x, -74.0 * scale),
		basis * Vector2(mast2_x + 50.0, -34.0 * scale),
		basis * Vector2(mast2_x, -22.0 * scale)
	])
	var main_sail := PackedVector2Array([
		basis * Vector2(mast1_x, -96.0 * scale),
		basis * Vector2(mast1_x + 68.0, -48.0 * scale),
		basis * Vector2(mast1_x, -18.0 * scale)
	])
	draw_colored_polygon(fore_sail, sail_color)
	draw_colored_polygon(main_sail, sail_color)

	# Gun ports hint broadside strength by ship class.
	var gun_count: int = int(round(4.0 + scale * 5.0))
	for i in range(gun_count):
		var t: float = float(i + 1) / float(gun_count + 1)
		var px: float = lerpf(-90.0 * scale, 88.0 * scale, t)
		draw_circle(basis * Vector2(px, 20.0 * scale), 2.5, Color(0.1, 0.1, 0.1))

func _combat_to_screen(point: Vector2, combat_rect: Rect2, cols: int, rows: int) -> Vector2:
	if cols <= 0 or rows <= 0:
		return combat_rect.position + Vector2(point.x * combat_rect.size.x, point.y * combat_rect.size.y)
	# `point` is normalized from a 0..(cols-1) grid (see ShipBattle player_position/enemy_position).
	# Map it to the center of the corresponding tile in a cols x rows grid.
	var gx: float = clampf(point.x, 0.0, 1.0) * float(max(1, cols - 1))
	var gy: float = clampf(point.y, 0.0, 1.0) * float(max(1, rows - 1))
	var centered_x: float = (gx + 0.5) / float(cols)
	var centered_y: float = (gy + 0.5) / float(rows)
	return combat_rect.position + Vector2(centered_x * combat_rect.size.x, centered_y * combat_rect.size.y)

func _naval_grid_rect(arena_rect: Rect2, cols: int, rows: int) -> Rect2:
	if cols <= 0 or rows <= 0:
		return arena_rect
	var cell_size: float = floor(minf(arena_rect.size.x / float(cols), arena_rect.size.y / float(rows)))
	cell_size = maxf(2.0, cell_size)
	var grid_size: Vector2 = Vector2(float(cols) * cell_size, float(rows) * cell_size)
	var origin: Vector2 = arena_rect.position + (arena_rect.size - grid_size) * 0.5
	origin.x = floor(origin.x)
	origin.y = floor(origin.y)
	return Rect2(origin, grid_size)

func _ship_combat_layout(viewport_size: Vector2) -> Dictionary:
	var hud_rect := Rect2(
		Vector2(viewport_size.x * 0.11, 18.0),
		Vector2(viewport_size.x * 0.78, 156.0)
	)
	var combat_rect := Rect2(
		Vector2(viewport_size.x * 0.12, hud_rect.position.y + hud_rect.size.y + 14.0),
		Vector2(viewport_size.x * 0.76, viewport_size.y * 0.62 - 24.0)
	)
	var options_width: float = minf(210.0, combat_rect.size.x * 0.24)
	var options_rect := Rect2(
		Vector2(combat_rect.position.x + combat_rect.size.x - options_width - 10.0, combat_rect.position.y + 10.0),
		Vector2(options_width, combat_rect.size.y - 20.0)
	)
	var grid_arena_rect := Rect2(
		combat_rect.position + Vector2(10.0, 10.0),
		Vector2(maxf(80.0, options_rect.position.x - combat_rect.position.x - 20.0), combat_rect.size.y - 20.0)
	)
	return {
		"hud_rect": hud_rect,
		"combat_rect": combat_rect,
		"grid_arena_rect": grid_arena_rect,
		"options_rect": options_rect
	}

func _ship_combat_view_rect(base_grid_rect: Rect2) -> Rect2:
	var center: Vector2 = base_grid_rect.position + base_grid_rect.size * 0.5 + ship_combat_pan
	var zoomed_size: Vector2 = base_grid_rect.size * ship_combat_zoom
	return Rect2(center - zoomed_size * 0.5, zoomed_size)

func _draw_naval_grid(combat_rect: Rect2, cols: int, rows: int) -> void:
	if cols <= 1 or rows <= 1:
		return
	draw_rect(combat_rect, Color(0.08, 0.16, 0.25, 0.24), true)
	var cell_w: float = combat_rect.size.x / float(cols)
	var cell_h: float = combat_rect.size.y / float(rows)
	for y in range(rows):
		for x in range(cols):
			var cell_rect := Rect2(
				Vector2(combat_rect.position.x + float(x) * cell_w, combat_rect.position.y + float(y) * cell_h),
				Vector2(cell_w, cell_h)
			)
			var major: bool = x % 4 == 0 or y % 4 == 0
			var border_color: Color = Color(0.82, 0.94, 1.0, 0.26) if major else Color(0.72, 0.86, 0.95, 0.17)
			draw_rect(cell_rect, border_color, false, 1.0)
	draw_rect(combat_rect, Color(0.9, 0.97, 1.0, 0.35), false, 2.0)

func _draw_ship_hazards(grid_rect: Rect2) -> void:
	var hazards: Array[Vector2i] = ship_battle.get_hazard_cells()
	for cell in hazards:
		var rect: Rect2 = _cell_rect(grid_rect, cell, ship_battle.combat_cols, ship_battle.combat_rows)
		draw_rect(rect, Color(0.74, 0.28, 0.22, 0.3), true)
		draw_rect(rect, Color(0.92, 0.45, 0.35, 0.75), false, 1.0)

func _draw_ship_action_panel(panel_rect: Rect2) -> void:
	draw_rect(panel_rect, Color(0.03, 0.07, 0.11, 0.82), true)
	draw_rect(panel_rect, Color(0.66, 0.8, 0.92, 0.42), false, 1.5)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(14.0, 24.0), "Turn Options", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

	var move_rect := _ship_action_button_rect(panel_rect, SHIP_ACTION_MOVE)
	var fire_rect := _ship_action_button_rect(panel_rect, SHIP_ACTION_FIRE)
	var board_rect := _ship_action_button_rect(panel_rect, SHIP_ACTION_BOARD)
	var end_turn_rect := _ship_action_button_rect(panel_rect, SHIP_ACTION_END_TURN)
	_draw_ship_action_button(move_rect, "Move", ship_combat_selected_action == SHIP_ACTION_MOVE, true)
	_draw_ship_action_button(fire_rect, "Fire Cannons", ship_combat_selected_action == SHIP_ACTION_FIRE, true)
	_draw_ship_action_button(board_rect, "Board", ship_combat_selected_action == SHIP_ACTION_BOARD, ship_battle.can_player_board_now())
	_draw_ship_action_button(end_turn_rect, "End Turn", false, true)
	if ship_end_turn_confirm_open:
		_draw_end_turn_confirm(panel_rect)

func _draw_ship_action_button(button_rect: Rect2, text: String, selected: bool, enabled: bool = true) -> void:
	var bg: Color = Color(0.2, 0.36, 0.52, 0.8) if selected else Color(0.1, 0.2, 0.3, 0.8)
	var border: Color = Color(0.85, 0.95, 1.0, 0.9) if selected else Color(0.62, 0.78, 0.9, 0.45)
	var text_color: Color = Color(1, 1, 1, 1)
	if not enabled:
		bg = Color(0.08, 0.12, 0.16, 0.75)
		border = Color(0.45, 0.55, 0.62, 0.35)
		text_color = Color(0.72, 0.76, 0.8, 0.6)
	draw_rect(button_rect, bg, true)
	draw_rect(button_rect, border, false, 2.0)
	draw_string(ThemeDB.fallback_font, button_rect.position + Vector2(12.0, 23.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

func _ship_action_button_rect(panel_rect: Rect2, action_id: int) -> Rect2:
	var idx: int = 0
	if action_id == SHIP_ACTION_FIRE:
		idx = 1
	elif action_id == SHIP_ACTION_BOARD:
		idx = 2
	elif action_id == SHIP_ACTION_END_TURN:
		idx = 3
	return Rect2(
		panel_rect.position + Vector2(12.0, 40.0 + float(idx) * 48.0),
		Vector2(panel_rect.size.x - 24.0, 36.0)
	)

func _draw_end_turn_confirm(panel_rect: Rect2) -> void:
	var dialog_rect := Rect2(
		panel_rect.position + Vector2(12.0, panel_rect.size.y - 118.0),
		Vector2(panel_rect.size.x - 24.0, 106.0)
	)
	draw_rect(dialog_rect, Color(0.03, 0.06, 0.09, 0.95), true)
	draw_rect(dialog_rect, Color(1.0, 0.83, 0.48, 0.8), false, 1.5)
	draw_string(ThemeDB.fallback_font, dialog_rect.position + Vector2(10.0, 20.0), "End turn now?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, dialog_rect.position + Vector2(10.0, 38.0), "Ship will coast if it did not move.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var yes_rect: Rect2 = _end_turn_confirm_button_rect(dialog_rect, true)
	var no_rect: Rect2 = _end_turn_confirm_button_rect(dialog_rect, false)
	_draw_ship_action_button(yes_rect, "Confirm", false)
	_draw_ship_action_button(no_rect, "Cancel", false)

func _end_turn_confirm_button_rect(dialog_rect: Rect2, yes: bool) -> Rect2:
	if yes:
		return Rect2(dialog_rect.position + Vector2(8.0, 58.0), Vector2((dialog_rect.size.x - 20.0) * 0.5, 36.0))
	return Rect2(dialog_rect.position + Vector2(dialog_rect.size.x * 0.5 + 2.0, 58.0), Vector2((dialog_rect.size.x - 20.0) * 0.5, 36.0))

func _draw_boarding_action_panel(panel_rect: Rect2) -> void:
	draw_rect(panel_rect, Color(0.03, 0.07, 0.11, 0.84), true)
	draw_rect(panel_rect, Color(0.66, 0.8, 0.92, 0.42), false, 1.5)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(14.0, 24.0), "Crew Actions", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var move_rect := _boarding_action_button_rect(panel_rect, BOARDING_ACTION_MOVE)
	var ranged_rect := _boarding_action_button_rect(panel_rect, BOARDING_ACTION_RANGED)
	var melee_rect := _boarding_action_button_rect(panel_rect, BOARDING_ACTION_MELEE)
	_draw_ship_action_button(move_rect, "Move", boarding_selected_action == BOARDING_ACTION_MOVE, true)
	_draw_ship_action_button(ranged_rect, "Ranged Attack", boarding_selected_action == BOARDING_ACTION_RANGED, true)
	_draw_ship_action_button(melee_rect, "Melee Attack", boarding_selected_action == BOARDING_ACTION_MELEE, true)
	var actor: Unit = _current_boarding_actor()
	var actor_text: String = "Current: -"
	if actor != null:
		actor_text = "Current: %s" % _unit_label(actor)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(12.0, panel_rect.size.y - 54.0), actor_text, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 14)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(12.0, panel_rect.size.y - 32.0), "Round %d" % boarding_round, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 14)

func _boarding_action_panel_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var panel_size := Vector2(220.0, 248.0)
	var top_y: float = 16.0
	var max_y: float = maxf(top_y, float(metrics["map_height"]) - panel_size.y - 16.0)
	return Rect2(Vector2(viewport_size.x - panel_size.x - 16.0, max_y), panel_size)

func _boarding_action_button_rect(panel_rect: Rect2, action_id: int) -> Rect2:
	return Rect2(
		panel_rect.position + Vector2(12.0, 40.0 + float(action_id) * 48.0),
		Vector2(panel_rect.size.x - 24.0, 36.0)
	)

func _draw_ship_movement_preview(grid_rect: Rect2) -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	if ship_battle.phase != ShipBattle.Phase.PLAYER_TURN:
		return
	var preview: Dictionary = ship_battle.get_player_movement_preview()
	if not preview.has("reachable_cells"):
		return
	var reachable: Variant = preview["reachable_cells"]
	var forward: Variant = preview.get("forward_cells", [])
	if not (reachable is Array):
		return
	var cols: int = ship_battle.combat_cols
	var rows: int = ship_battle.combat_rows
	var envelope_points := PackedVector2Array()

	for cell_variant in reachable:
		if not (cell_variant is Vector2i):
			continue
		var cell: Vector2i = cell_variant
		if cell == ship_battle.player_cell:
			continue
		var r: Rect2 = _cell_rect(grid_rect, cell, cols, rows)
		draw_rect(r, Color(0.34, 0.7, 0.95, 0.12), true)
		envelope_points.append(_cell_center(grid_rect, cell, cols, rows))

	if forward is Array:
		for cell_variant in forward:
			if not (cell_variant is Vector2i):
				continue
			var cell: Vector2i = cell_variant
			var r: Rect2 = _cell_rect(grid_rect, cell, cols, rows)
			draw_rect(r, Color(0.45, 0.95, 0.72, 0.22), true)

	# True movement envelope from the actual reachable cells this turn.
	if envelope_points.size() >= 3:
		var hull: PackedVector2Array = Geometry2D.convex_hull(envelope_points)
		if hull.size() >= 3:
			draw_colored_polygon(hull, Color(0.35, 0.95, 0.75, 0.09))
			draw_polyline(hull, Color(0.52, 0.98, 0.82, 0.45), 2.0, true)

	# Forward-facing cone for immediate heading intent.
	var ship_center: Vector2 = _cell_center(grid_rect, ship_battle.player_cell, cols, rows)
	var heading: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(90.0 - ship_battle.player_heading_deg)).normalized()
	var right: Vector2 = Vector2(-heading.y, heading.x)
	var cells_forward: int = max(1, ship_battle.player_move_points)
	var cone_length: float = float(cells_forward) * (grid_rect.size.y / float(rows))
	var cone_width: float = cone_length * 0.75
	var tip: Vector2 = ship_center + heading * cone_length
	var left_tip: Vector2 = ship_center + heading * cone_length * 0.75 + right * cone_width * 0.5
	var right_tip: Vector2 = ship_center + heading * cone_length * 0.75 - right * cone_width * 0.5
	draw_colored_polygon(PackedVector2Array([ship_center, left_tip, tip, right_tip]), Color(0.45, 0.98, 0.8, 0.08))
	draw_line(ship_center, tip, Color(0.58, 1.0, 0.86, 0.5), 2.0)

	_draw_action_destinations(grid_rect)
	_draw_selected_ship_move_cell(grid_rect)

func _draw_ship_fire_preview(grid_rect: Rect2) -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	if ship_battle.phase != ShipBattle.Phase.PLAYER_TURN:
		return
	var cells: Array[Vector2i] = ship_battle.get_player_fire_preview_cells()
	for cell in cells:
		var rect: Rect2 = _cell_rect(grid_rect, cell, ship_battle.combat_cols, ship_battle.combat_rows)
		draw_rect(rect, Color(0.95, 0.45, 0.35, 0.15), true)
	var enemy_rect: Rect2 = _cell_rect(grid_rect, ship_battle.enemy_cell, ship_battle.combat_cols, ship_battle.combat_rows)
	if cells.has(ship_battle.enemy_cell):
		draw_rect(enemy_rect, Color(1.0, 0.3, 0.25, 0.28), true)
		draw_rect(enemy_rect, Color(1.0, 0.8, 0.75, 0.9), false, 2.0)
		draw_string(ThemeDB.fallback_font, enemy_rect.position + Vector2(6.0, 16.0), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _draw_action_destinations(grid_rect: Rect2) -> void:
	if ship_battle.phase != ShipBattle.Phase.PLAYER_TURN:
		return
	var guidance: Dictionary = ship_battle.get_player_action_guidance()
	_draw_action_marker(grid_rect, guidance.get("left", {}), "L", Color(0.95, 0.72, 0.4, 0.95))
	_draw_action_marker(grid_rect, guidance.get("forward", {}), "F", Color(0.46, 0.96, 0.72, 0.95))
	_draw_action_marker(grid_rect, guidance.get("right", {}), "R", Color(0.45, 0.78, 0.98, 0.95))

func _draw_action_marker(grid_rect: Rect2, action_data: Dictionary, short_label: String, color: Color) -> void:
	if action_data.is_empty():
		return
	if not action_data.get("can_execute", false):
		return
	if not action_data.has("target_pos"):
		return
	var target_pos_variant: Variant = action_data["target_pos"]
	if not (target_pos_variant is Vector2):
		return
	var target_pos: Vector2 = target_pos_variant
	var center: Vector2 = _combat_to_screen(
		Vector2(
			target_pos.x / float(max(1, ship_battle.combat_cols - 1)),
			target_pos.y / float(max(1, ship_battle.combat_rows - 1))
		),
		grid_rect,
		ship_battle.combat_cols,
		ship_battle.combat_rows
	)
	draw_circle(center, 9.0, color)
	draw_circle(center, 11.0, Color(color.r, color.g, color.b, 0.35))
	draw_string(ThemeDB.fallback_font, center + Vector2(-4.0, 4.0), short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var cost: int = int(action_data.get("cost", 0))
	var long_label: String = str(action_data.get("label", short_label))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(14.0, -10.0),
		"%s (MP %d)" % [long_label, cost],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13
	)

func _draw_selected_ship_move_cell(grid_rect: Rect2) -> void:
	if ship_move_selected_cell.x < 0 or ship_move_selected_cell.y < 0:
		return
	if not ship_battle.can_player_move_to_cell(ship_move_selected_cell):
		return
	var rect: Rect2 = _cell_rect(grid_rect, ship_move_selected_cell, ship_battle.combat_cols, ship_battle.combat_rows)
	draw_rect(rect, Color(1.0, 0.96, 0.55, 0.22), true)
	draw_rect(rect, Color(1.0, 0.96, 0.55, 0.9), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6.0, 16.0), "SELECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _draw_wind_compass(center: Vector2, wind_from_deg: float, wind_speed_m_s: float) -> void:
	var radius: float = 28.0
	draw_circle(center, radius, Color(0.05, 0.1, 0.14, 0.75))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.8, 0.9, 1.0, 0.5), 2.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(0.6, 0.75, 0.9, 0.35), 1.0)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(0.6, 0.75, 0.9, 0.35), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-5.0, -radius - 6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(ThemeDB.fallback_font, center + Vector2(-4.0, radius + 14.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(ThemeDB.fallback_font, center + Vector2(radius + 6.0, 4.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius - 14.0, 4.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

	var wind_to_deg: float = fposmod(wind_from_deg + 180.0, 360.0)
	var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(90.0 - wind_to_deg)).normalized()
	var tip: Vector2 = center + dir * (radius - 6.0)
	var tail: Vector2 = center - dir * (radius - 12.0)
	draw_line(tail, tip, Color(0.44, 0.95, 0.78, 0.95), 2.0)
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var arrow_left: Vector2 = tip - dir * 8.0 + right * 4.0
	var arrow_right: Vector2 = tip - dir * 8.0 - right * 4.0
	draw_colored_polygon(PackedVector2Array([tip, arrow_left, arrow_right]), Color(0.44, 0.95, 0.78, 0.95))
	draw_string(ThemeDB.fallback_font, center + Vector2(-24.0, radius + 30.0), "Wind %.1f m/s" % wind_speed_m_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)

func _sync_ship_move_selection() -> void:
	var reachable: Array[Vector2i] = ship_battle.get_player_reachable_cells()
	if reachable.is_empty():
		ship_move_selected_cell = Vector2i(-1, -1)
		return
	if ship_battle.can_player_move_to_cell(ship_move_selected_cell):
		return
	ship_move_selected_cell = ship_battle.player_cell
	if not ship_battle.can_player_move_to_cell(ship_move_selected_cell):
		ship_move_selected_cell = reachable[0]

func _move_ship_selection(direction: Vector2i) -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	_sync_ship_move_selection()
	if ship_move_selected_cell.x < 0:
		return
	var reachable: Array[Vector2i] = ship_battle.get_player_reachable_cells()
	var best: Vector2i = ship_move_selected_cell
	var best_score: float = INF
	for cell in reachable:
		if cell == ship_move_selected_cell:
			continue
		var delta: Vector2 = Vector2(float(cell.x - ship_move_selected_cell.x), float(cell.y - ship_move_selected_cell.y))
		var dot: float = delta.dot(Vector2(direction))
		if dot <= 0.0:
			continue
		var forward_dist: float = absf(dot)
		var lateral: float = absf(delta.x * float(direction.y) - delta.y * float(direction.x))
		var score: float = forward_dist + lateral * 0.35
		if score < best_score:
			best_score = score
			best = cell
	ship_move_selected_cell = best

func _confirm_ship_move_selection() -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	_sync_ship_move_selection()
	if ship_move_selected_cell.x < 0:
		return
	if ship_battle.execute_player_move_to_cell(ship_move_selected_cell):
		game_flow.post_message("Helm set: moving to (%d,%d)." % [ship_move_selected_cell.x, ship_move_selected_cell.y])
		_sync_ship_move_selection()
	else:
		game_flow.post_message("Selected square is not reachable this turn.")

func _handle_ship_combat_click(screen_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var layout: Dictionary = _ship_combat_layout(viewport_size)
	var options_rect: Rect2 = layout["options_rect"]
	var grid_arena_rect: Rect2 = layout["grid_arena_rect"]
	var base_grid_rect: Rect2 = _naval_grid_rect(grid_arena_rect, ship_battle.combat_cols, ship_battle.combat_rows)
	var grid_rect: Rect2 = _ship_combat_view_rect(base_grid_rect)
	if options_rect.has_point(screen_pos):
		if _ship_action_button_rect(options_rect, SHIP_ACTION_MOVE).has_point(screen_pos):
			ship_combat_selected_action = SHIP_ACTION_MOVE
			ship_end_turn_confirm_open = false
		elif _ship_action_button_rect(options_rect, SHIP_ACTION_FIRE).has_point(screen_pos):
			ship_combat_selected_action = SHIP_ACTION_FIRE
			ship_end_turn_confirm_open = false
		elif _ship_action_button_rect(options_rect, SHIP_ACTION_BOARD).has_point(screen_pos):
			if ship_battle.can_player_board_now():
				ship_combat_selected_action = SHIP_ACTION_BOARD
			else:
				game_flow.post_message("Boarding unavailable: move adjacent to the enemy.")
			ship_end_turn_confirm_open = false
		elif _ship_action_button_rect(options_rect, SHIP_ACTION_END_TURN).has_point(screen_pos):
			ship_end_turn_confirm_open = true
		if ship_end_turn_confirm_open:
			var dialog_rect := Rect2(
				options_rect.position + Vector2(12.0, options_rect.size.y - 118.0),
				Vector2(options_rect.size.x - 24.0, 106.0)
			)
			var yes_rect: Rect2 = _end_turn_confirm_button_rect(dialog_rect, true)
			var no_rect: Rect2 = _end_turn_confirm_button_rect(dialog_rect, false)
			if yes_rect.has_point(screen_pos):
				ship_end_turn_confirm_open = false
				ship_battle.player_end_turn()
				_resolve_enemy_ship_turn_if_needed()
			elif no_rect.has_point(screen_pos):
				ship_end_turn_confirm_open = false
		return
	if not grid_rect.has_point(screen_pos):
		return
	var cell_w: float = grid_rect.size.x / float(ship_battle.combat_cols)
	var cell_h: float = grid_rect.size.y / float(ship_battle.combat_rows)
	var col: int = clampi(int(floor((screen_pos.x - grid_rect.position.x) / cell_w)), 0, ship_battle.combat_cols - 1)
	var row: int = clampi(int(floor((screen_pos.y - grid_rect.position.y) / cell_h)), 0, ship_battle.combat_rows - 1)
	var clicked: Vector2i = Vector2i(col, row)
	if ship_combat_selected_action == SHIP_ACTION_MOVE and ship_battle.can_player_move_to_cell(clicked):
		ship_move_selected_cell = clicked

func _cell_rect(grid_rect: Rect2, cell: Vector2i, cols: int, rows: int) -> Rect2:
	var cell_w: float = grid_rect.size.x / float(cols)
	var cell_h: float = grid_rect.size.y / float(rows)
	return Rect2(
		Vector2(grid_rect.position.x + float(cell.x) * cell_w, grid_rect.position.y + float(cell.y) * cell_h),
		Vector2(cell_w, cell_h)
	)

func _cell_center(grid_rect: Rect2, cell: Vector2i, cols: int, rows: int) -> Vector2:
	var rect: Rect2 = _cell_rect(grid_rect, cell, cols, rows)
	return rect.position + rect.size * 0.5

func _ship_draw_scale(ship_class: String) -> float:
	match ship_class:
		"Sloop":
			return 0.54
		"Brig":
			return 0.64
		"Frigate":
			return 0.74
		"Merchantman":
			return 0.68
		_:
			return 0.62

func _setup_captains_log_ui() -> void:
	var viewport_size := get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var log_height: float = float(metrics["log_height"])

	captain_log_layer = CanvasLayer.new()
	captain_log_layer.layer = 10
	add_child(captain_log_layer)

	captain_log_panel = ColorRect.new()
	captain_log_panel.color = Color(0.02, 0.03, 0.05, 1.0)
	captain_log_panel.clip_contents = true
	captain_log_panel.position = Vector2(0, viewport_size.y - log_height)
	captain_log_panel.size = Vector2(viewport_size.x, log_height)
	captain_log_layer.add_child(captain_log_panel)

	captain_log_title_label = Label.new()
	captain_log_title_label.text = "Captain's Log"
	captain_log_title_label.position = Vector2(16, 10)
	captain_log_title_label.add_theme_font_size_override("font_size", 20)
	captain_log_panel.add_child(captain_log_title_label)

	captain_log_text_label = Label.new()
	captain_log_text_label.position = Vector2(16, 42)
	captain_log_text_label.size = captain_log_panel.size - Vector2(32, 52)
	captain_log_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	captain_log_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	captain_log_text_label.add_theme_font_size_override("font_size", 18)
	captain_log_panel.add_child(captain_log_text_label)

	_refresh_captains_log_ui()

func _refresh_captains_log_ui() -> void:
	if captain_log_text_label == null:
		return
	captain_log_text_label.text = "\n".join(captain_log_lines)

func _setup_left_sidebar_ui() -> void:
	var viewport_size := get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var sidebar_width: float = float(metrics["sidebar_width"])
	var map_height: float = float(metrics["map_height"])

	left_sidebar_layer = CanvasLayer.new()
	left_sidebar_layer.layer = 9
	add_child(left_sidebar_layer)

	left_sidebar_panel = ColorRect.new()
	left_sidebar_panel.color = Color(0.02, 0.03, 0.05, 1.0)
	left_sidebar_panel.clip_contents = true
	left_sidebar_panel.position = Vector2(0, 0)
	left_sidebar_panel.size = Vector2(sidebar_width, map_height)
	left_sidebar_layer.add_child(left_sidebar_panel)

	var title := Label.new()
	title.text = "Menu"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 18)
	left_sidebar_panel.add_child(title)

func _setup_time_controls_ui() -> void:
	time_controls_layer = CanvasLayer.new()
	time_controls_layer.layer = 11
	add_child(time_controls_layer)

	time_controls_box = HBoxContainer.new()
	time_controls_box.position = Vector2(1700, 12)
	time_controls_box.add_theme_constant_override("separation", 6)
	time_controls_layer.add_child(time_controls_box)

	var group := ButtonGroup.new()
	for scale in [1.0, 2.0, 4.0]:
		var selected_scale: float = scale
		var button := Button.new()
		button.text = "%dx" % int(scale)
		button.custom_minimum_size = Vector2(56, 34)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void:
			_on_time_scale_selected(selected_scale)
		)
		time_controls_box.add_child(button)
		time_buttons[selected_scale] = button

	_on_time_scale_selected(world_map.player_time_scale)

func _setup_encounter_ui() -> void:
	encounter_layer = CanvasLayer.new()
	encounter_layer.layer = 90
	encounter_layer.visible = false
	add_child(encounter_layer)

	encounter_panel = PanelContainer.new()
	encounter_layer.add_child(encounter_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	encounter_panel.add_child(box)

	encounter_title_label = Label.new()
	encounter_title_label.text = "Sails on the Horizon"
	encounter_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(encounter_title_label)

	encounter_text_label = Label.new()
	encounter_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_text_label.custom_minimum_size = Vector2(420.0, 80.0)
	box.add_child(encounter_text_label)

	encounter_avoid_button = Button.new()
	encounter_avoid_button.text = "Attempt to Avoid"
	encounter_avoid_button.custom_minimum_size = Vector2(320.0, 34.0)
	encounter_avoid_button.pressed.connect(_on_encounter_avoid_pressed)
	box.add_child(encounter_avoid_button)

	encounter_pursue_button = Button.new()
	encounter_pursue_button.text = "Pursue"
	encounter_pursue_button.custom_minimum_size = Vector2(320.0, 34.0)
	encounter_pursue_button.pressed.connect(_on_encounter_pursue_pressed)
	box.add_child(encounter_pursue_button)

	encounter_engage_button = Button.new()
	encounter_engage_button.text = "Engage Immediately"
	encounter_engage_button.custom_minimum_size = Vector2(320.0, 34.0)
	encounter_engage_button.pressed.connect(_on_encounter_engage_pressed)
	box.add_child(encounter_engage_button)

func _setup_main_menu_ui() -> void:
	main_menu_layer = CanvasLayer.new()
	main_menu_layer.layer = 120
	add_child(main_menu_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.02, 0.04, 0.96)
	main_menu_layer.add_child(overlay)

	main_menu_panel = PanelContainer.new()
	main_menu_layer.add_child(main_menu_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	main_menu_panel.add_child(box)

	var title := Label.new()
	title.text = "Pirate TTRPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	box.add_child(_make_escape_menu_button("Start New Game", _on_main_menu_start_pressed))
	var dev_label := Label.new()
	dev_label.text = "Dev Testing"
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_label.add_theme_font_size_override("font_size", 16)
	box.add_child(dev_label)
	box.add_child(_make_escape_menu_button("Launch Ship Combat", _on_main_menu_dev_ship_combat_pressed))
	box.add_child(_make_escape_menu_button("Launch Crew Combat (Boarding)", _on_main_menu_dev_crew_combat_pressed))
	box.add_child(_make_escape_menu_button("Launch Town Combat", _on_main_menu_dev_town_combat_pressed))
	box.add_child(_make_escape_menu_button("Load Existing Game", _on_main_menu_load_pressed))
	box.add_child(_make_escape_menu_button("Settings", _on_main_menu_settings_pressed))
	box.add_child(_make_escape_menu_button("Quit to Desktop", _on_main_menu_quit_pressed))

	main_menu_status_label = Label.new()
	main_menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_menu_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(main_menu_status_label)

	main_menu_settings_panel = PanelContainer.new()
	main_menu_settings_panel.visible = false
	main_menu_layer.add_child(main_menu_settings_panel)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 8)
	main_menu_settings_panel.add_child(settings_box)

	var settings_title := Label.new()
	settings_title.text = "Settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 24)
	settings_box.add_child(settings_title)

	var volume_label := Label.new()
	volume_label.text = "Master Volume"
	settings_box.add_child(volume_label)

	main_menu_volume_slider = HSlider.new()
	main_menu_volume_slider.min_value = -40.0
	main_menu_volume_slider.max_value = 6.0
	main_menu_volume_slider.step = 1.0
	main_menu_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_menu_volume_slider.value_changed.connect(_on_escape_volume_changed)
	main_menu_volume_slider.value = AudioServer.get_bus_volume_db(0)
	settings_box.add_child(main_menu_volume_slider)

	main_menu_fullscreen_check = CheckBox.new()
	main_menu_fullscreen_check.text = "Fullscreen"
	main_menu_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	main_menu_fullscreen_check.toggled.connect(_on_escape_fullscreen_toggled)
	settings_box.add_child(main_menu_fullscreen_check)

	settings_box.add_child(_make_escape_menu_button("Back", _on_main_menu_settings_back_pressed))

	# Keep gameplay hidden until user starts a new session.
	world_map.visible = false
	grid.visible = false
	units_root.visible = false
	main_menu_layer.visible = true
	in_main_menu = true

func _start_spotting_encounter() -> void:
	var player_class: String = world_map.ship_class
	var enemy_class: String = _roll_enemy_ship_class()
	var enemy_navigator_skill: int = randi_range(1, 4)
	var player_heading: Vector2 = world_map.get_current_heading_vector().normalized()
	var player_speed: float = world_map.get_current_speed_knots()
	var enemy_speed: float = _ship_speed_knots(enemy_class) * randf_range(0.9, 1.1)
	var contact_distance_nm: float = randf_range(1.2, 11.0)
	var player_spot_nm: float = _horizon_distance_nm_for_ship(player_class) + _horizon_distance_nm_for_ship(enemy_class)
	var player_spots_first: bool = contact_distance_nm <= player_spot_nm
	var enemy_wants_pursuit: bool = randf() < 0.62
	var enemy_heading: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	if enemy_wants_pursuit:
		enemy_heading = player_heading

	pending_encounter = {
		"player_ship_class": player_class,
		"enemy_ship_class": enemy_class,
		"player_heading": player_heading,
		"enemy_heading": enemy_heading,
		"player_speed_knots": player_speed,
		"enemy_speed_knots": enemy_speed,
		"enemy_wants_pursuit": enemy_wants_pursuit,
		"contact_distance_nm": contact_distance_nm,
		"player_spot_nm": player_spot_nm,
		"wind": world_map.get_current_wind(),
		"near_land": world_map.is_near_land(),
		"player_navigator_skill": PLAYER_NAVIGATOR_SKILL,
		"enemy_navigator_skill": enemy_navigator_skill
	}

	if not player_spots_first:
		game_flow.post_message("You failed to spot the contact before they closed. Enemy ship engages!")
		_begin_ship_battle_from_encounter("Enemy gains initiative.")
		return

	encounter_active = true
	encounter_layer.visible = true
	var pursuit_text: String = "looks eager to chase." if enemy_wants_pursuit else "appears cautious."
	encounter_text_label.text = (
		"Crow's nest reports a %s at %.1f nm. Spotting range: %.1f nm. Your speed %.1f kn, target speed %.1f kn. The other captain %s" % [
			enemy_class,
			contact_distance_nm,
			player_spot_nm,
			player_speed,
			enemy_speed,
			pursuit_text
		]
	)
	_layout_worldmap_ui()
	game_flow.post_message("Sails spotted early. Choose avoid, pursue, or engage.")

func _on_encounter_avoid_pressed() -> void:
	if pending_encounter.is_empty():
		return
	var enemy_wants: bool = bool(pending_encounter.get("enemy_wants_pursuit", true))
	if not enemy_wants:
		_finish_encounter_without_battle("You alter course and the contact does not pursue.")
		return
	var chance: float = _encounter_escape_chance(pending_encounter)
	if randf() <= chance:
		_finish_encounter_without_battle("You evade the pursuer and disappear downwind.")
	else:
		_begin_ship_battle_from_encounter("They run you down despite your evasive maneuvers.")

func _on_encounter_pursue_pressed() -> void:
	if pending_encounter.is_empty():
		return
	var chance: float = _encounter_pursuit_chance(pending_encounter)
	if randf() <= chance:
		_begin_ship_battle_from_encounter("You close the distance and force battle.")
	else:
		_finish_encounter_without_battle("The contact slips away before you can engage.")

func _on_encounter_engage_pressed() -> void:
	if pending_encounter.is_empty():
		return
	_begin_ship_battle_from_encounter("You hoist battle colors and engage.")

func _on_main_menu_start_pressed() -> void:
	_begin_gameplay_from_main_menu()
	_set_mode(GameFlow.Mode.WORLD_MAP)
	_on_mode_changed(game_flow.current_mode)
	_layout_worldmap_ui()
	game_flow.post_message("World map ready. Click a port to auto-sail.")

func _on_main_menu_dev_ship_combat_pressed() -> void:
	_begin_gameplay_from_main_menu()
	var context: Dictionary = {
		"player_ship_class": world_map.ship_class,
		"enemy_ship_class": _roll_enemy_ship_class(),
		"player_heading": Vector2.RIGHT,
		"enemy_heading": Vector2.LEFT,
		"wind": world_map.get_current_wind(),
		"near_land": world_map.is_near_land(),
		"player_navigator_skill": PLAYER_NAVIGATOR_SKILL,
		"enemy_navigator_skill": randi_range(1, 4)
	}
	_set_mode(GameFlow.Mode.SHIP_COMBAT)
	ship_battle.start_battle(context)
	game_flow.post_message("Dev test: ship combat launched.")

func _on_main_menu_dev_crew_combat_pressed() -> void:
	_begin_gameplay_from_main_menu()
	current_boarding_is_player_attacking = true
	game_flow.set_tactical_type(GameFlow.TacticalType.BOARDING)
	boarding_active = true
	boarding_defender_hold_progress = 0
	_setup_tactical_units()
	_set_mode(GameFlow.Mode.TACTICAL_COMBAT)
	_start_boarding_initiative()
	game_flow.post_message("Dev test: boarding crew combat launched.")

func _on_main_menu_dev_town_combat_pressed() -> void:
	_begin_gameplay_from_main_menu()
	_start_town_assault_demo()
	game_flow.post_message("Dev test: town combat launched.")

func _on_main_menu_load_pressed() -> void:
	main_menu_status_label.text = "Load Existing Game is not implemented yet."

func _on_main_menu_settings_pressed() -> void:
	main_menu_panel.visible = false
	main_menu_settings_panel.visible = true

func _on_main_menu_settings_back_pressed() -> void:
	main_menu_settings_panel.visible = false
	main_menu_panel.visible = true

func _on_main_menu_quit_pressed() -> void:
	get_tree().quit()

func _begin_gameplay_from_main_menu() -> void:
	in_main_menu = false
	main_menu_layer.visible = false
	main_menu_settings_panel.visible = false
	main_menu_panel.visible = true
	main_menu_status_label.text = ""
	captain_log_lines.clear()
	_refresh_captains_log_ui()
	is_escape_menu_open = false
	escape_menu_layer.visible = false
	encounter_active = false
	encounter_layer.visible = false

func _encounter_escape_chance(data: Dictionary) -> float:
	var player_speed: float = float(data.get("player_speed_knots", 4.5))
	var enemy_speed: float = float(data.get("enemy_speed_knots", 4.5))
	var player_heading: Vector2 = data.get("player_heading", Vector2.RIGHT)
	var enemy_heading: Vector2 = data.get("enemy_heading", Vector2.RIGHT)
	var speed_adv: float = player_speed - enemy_speed
	var heading_sep: float = clampf((1.0 - player_heading.normalized().dot(enemy_heading.normalized())) * 0.5, 0.0, 1.0)
	var chance: float = 0.32 + speed_adv * 0.11 + heading_sep * 0.28
	return clampf(chance, 0.08, 0.9)

func _encounter_pursuit_chance(data: Dictionary) -> float:
	var player_speed: float = float(data.get("player_speed_knots", 4.5))
	var enemy_speed: float = float(data.get("enemy_speed_knots", 4.5))
	var speed_adv: float = player_speed - enemy_speed
	var chance: float = 0.45 + speed_adv * 0.1
	return clampf(chance, 0.12, 0.92)

func _finish_encounter_without_battle(log_text: String) -> void:
	encounter_active = false
	encounter_layer.visible = false
	pending_encounter.clear()
	game_flow.post_message(log_text)
	world_map.resume_travel_to_target()

func _begin_ship_battle_from_encounter(log_text: String) -> void:
	var context: Dictionary = pending_encounter.duplicate()
	encounter_active = false
	encounter_layer.visible = false
	pending_encounter.clear()
	game_flow.post_message(log_text)
	_set_mode(GameFlow.Mode.SHIP_COMBAT)
	ship_battle.start_battle(context)

func _roll_enemy_ship_class() -> String:
	var r: float = randf()
	if r < 0.28:
		return "Sloop"
	if r < 0.58:
		return "Brig"
	if r < 0.83:
		return "Frigate"
	return "Merchantman"

func _ship_speed_knots(ship_class: String) -> float:
	return float(SHIP_CLASS_SPEED_KNOTS.get(ship_class, 4.6))

func _horizon_distance_nm_for_ship(ship_class: String) -> float:
	var mast_height: float = float(CROWS_NEST_HEIGHT_FEET.get(ship_class, 45.0))
	# Nautical horizon approximation: d_nm = 1.17 * sqrt(height_ft)
	return 1.17 * sqrt(mast_height)

func _setup_escape_menu_ui() -> void:
	escape_menu_layer = CanvasLayer.new()
	escape_menu_layer.layer = 100
	escape_menu_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	escape_menu_layer.visible = false
	add_child(escape_menu_layer)

	escape_menu_overlay = ColorRect.new()
	escape_menu_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	escape_menu_layer.add_child(escape_menu_overlay)

	escape_menu_panel = PanelContainer.new()
	escape_menu_layer.add_child(escape_menu_panel)
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	escape_menu_panel.add_child(panel_box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	panel_box.add_child(title)

	panel_box.add_child(_make_escape_menu_button("Resume", _close_escape_menu))
	panel_box.add_child(_make_escape_menu_button("Save Game", _on_escape_save_pressed))
	panel_box.add_child(_make_escape_menu_button("Load Game", _on_escape_load_pressed))
	panel_box.add_child(_make_escape_menu_button("Settings", _on_escape_settings_pressed))
	panel_box.add_child(_make_escape_menu_button("Quit to Menu", _on_escape_quit_to_menu_pressed))
	panel_box.add_child(_make_escape_menu_button("Quit to Desktop", _on_escape_quit_to_desktop_pressed))

	escape_menu_status_label = Label.new()
	escape_menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_menu_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(escape_menu_status_label)

	escape_settings_panel = PanelContainer.new()
	escape_settings_panel.visible = false
	escape_menu_layer.add_child(escape_settings_panel)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 8)
	escape_settings_panel.add_child(settings_box)

	var settings_title := Label.new()
	settings_title.text = "Settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 22)
	settings_box.add_child(settings_title)

	var volume_label := Label.new()
	volume_label.text = "Master Volume"
	settings_box.add_child(volume_label)

	escape_volume_slider = HSlider.new()
	escape_volume_slider.min_value = -40.0
	escape_volume_slider.max_value = 6.0
	escape_volume_slider.step = 1.0
	escape_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	escape_volume_slider.value_changed.connect(_on_escape_volume_changed)
	settings_box.add_child(escape_volume_slider)

	escape_fullscreen_check = CheckBox.new()
	escape_fullscreen_check.text = "Fullscreen"
	escape_fullscreen_check.toggled.connect(_on_escape_fullscreen_toggled)
	settings_box.add_child(escape_fullscreen_check)

	settings_box.add_child(_make_escape_menu_button("Back", _on_escape_settings_back_pressed))

	escape_volume_slider.value = AudioServer.get_bus_volume_db(0)
	escape_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _make_escape_menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 36.0)
	button.pressed.connect(action)
	return button

func _open_escape_menu() -> void:
	is_escape_menu_open = true
	get_tree().paused = true
	escape_menu_layer.visible = true
	escape_menu_status_label.text = ""
	escape_settings_panel.visible = false
	_layout_worldmap_ui()

func _close_escape_menu() -> void:
	is_escape_menu_open = false
	get_tree().paused = false
	escape_menu_layer.visible = false
	escape_settings_panel.visible = false
	escape_menu_status_label.text = ""

func _on_escape_save_pressed() -> void:
	if _save_game():
		escape_menu_status_label.text = "Game saved."
	else:
		escape_menu_status_label.text = "Save failed."

func _on_escape_load_pressed() -> void:
	if _load_game():
		escape_menu_status_label.text = "Game loaded."
		_close_escape_menu()
	else:
		escape_menu_status_label.text = "No save file found."

func _on_escape_settings_pressed() -> void:
	escape_settings_panel.visible = true

func _on_escape_settings_back_pressed() -> void:
	escape_settings_panel.visible = false

func _on_escape_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	_close_escape_menu()
	in_main_menu = true
	if main_menu_layer != null:
		main_menu_layer.visible = true
	if main_menu_panel != null:
		main_menu_panel.visible = true
	if main_menu_status_label != null:
		main_menu_status_label.text = ""
	if main_menu_settings_panel != null:
		main_menu_settings_panel.visible = false
	if world_map != null:
		world_map.visible = false
	grid.visible = false
	units_root.visible = false

func _on_escape_quit_to_desktop_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _on_escape_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)

func _on_escape_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_game() -> bool:
	var data: Dictionary = {
		"world_map": world_map.get_save_state(),
		"captain_log_lines": captain_log_lines,
		"last_arrived_port": last_arrived_port,
		"can_start_town_assault": can_start_town_assault,
		"mode": game_flow.current_mode,
		"tactical_type": game_flow.tactical_type
	}
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	if data.has("world_map") and data["world_map"] is Dictionary:
		world_map.apply_save_state(data["world_map"])
	if data.has("captain_log_lines") and data["captain_log_lines"] is Array:
		var lines: Array[String] = []
		for item in data["captain_log_lines"]:
			lines.append(str(item))
		captain_log_lines = lines
		_refresh_captains_log_ui()
	if data.has("last_arrived_port"):
		last_arrived_port = str(data["last_arrived_port"])
	if data.has("can_start_town_assault"):
		can_start_town_assault = bool(data["can_start_town_assault"])
	if data.has("tactical_type"):
		game_flow.set_tactical_type(int(data["tactical_type"]))
	if data.has("mode"):
		var saved_mode: int = int(data["mode"])
		if saved_mode == GameFlow.Mode.SHIP_COMBAT:
			_set_mode(GameFlow.Mode.SHIP_COMBAT)
		elif saved_mode == GameFlow.Mode.TACTICAL_COMBAT:
			_set_mode(GameFlow.Mode.TACTICAL_COMBAT)
		else:
			_set_mode(GameFlow.Mode.WORLD_MAP)
	else:
		_set_mode(GameFlow.Mode.WORLD_MAP)
	_layout_worldmap_ui()
	return true

func _on_time_scale_selected(scale: float) -> void:
	world_map.set_time_scale(scale)
	for key in time_buttons.keys():
		var button: Button = time_buttons[key]
		button.button_pressed = int(key) == int(scale)

func _layout_worldmap_ui() -> void:
	var viewport_size := get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var sidebar_width: float = float(metrics["sidebar_width"])
	var safe_log_height: float = float(metrics["log_height"])
	var map_height: float = float(metrics["map_height"])

	if world_map != null:
		world_map.set_ui_layout(sidebar_width, safe_log_height)

	if left_sidebar_panel != null:
		left_sidebar_panel.position = Vector2(0, 0)
		left_sidebar_panel.size = Vector2(sidebar_width, map_height)

	if captain_log_panel != null:
		captain_log_panel.position = Vector2(0.0, viewport_size.y - safe_log_height)
		captain_log_panel.size = Vector2(viewport_size.x, safe_log_height)

	if captain_log_text_label != null and captain_log_panel != null:
		captain_log_text_label.size = Vector2(
			maxf(0.0, captain_log_panel.size.x - 32.0),
			maxf(0.0, captain_log_panel.size.y - 52.0)
		)

	if time_controls_box != null:
		var controls_size: Vector2 = time_controls_box.get_combined_minimum_size()
		var map_right_x: float = viewport_size.x - 12.0
		var map_left_x: float = sidebar_width + 8.0
		var desired_x: float = map_right_x - controls_size.x
		var safe_x: float = clampf(desired_x, map_left_x, maxf(map_left_x, map_right_x - controls_size.x))
		var safe_y: float = clampf(12.0, 8.0, maxf(8.0, map_height - controls_size.y - 8.0))
		time_controls_box.position = Vector2(safe_x, safe_y)

	if escape_menu_overlay != null:
		escape_menu_overlay.position = Vector2.ZERO
		escape_menu_overlay.size = viewport_size

	if escape_menu_panel != null:
		escape_menu_panel.custom_minimum_size = Vector2(320.0, 320.0)
		escape_menu_panel.size = escape_menu_panel.custom_minimum_size
		escape_menu_panel.position = (viewport_size - escape_menu_panel.size) * 0.5

	if escape_settings_panel != null:
		escape_settings_panel.custom_minimum_size = Vector2(320.0, 220.0)
		escape_settings_panel.size = escape_settings_panel.custom_minimum_size
		escape_settings_panel.position = (viewport_size - escape_settings_panel.size) * 0.5

	if encounter_panel != null:
		encounter_panel.custom_minimum_size = Vector2(460.0, 250.0)
		encounter_panel.size = encounter_panel.custom_minimum_size
		encounter_panel.position = Vector2(
			sidebar_width + ((viewport_size.x - sidebar_width) - encounter_panel.size.x) * 0.5,
			maxf(20.0, map_height * 0.18)
		)

	if main_menu_layer != null and main_menu_layer.get_child_count() > 0:
		var overlay: Node = main_menu_layer.get_child(0)
		if overlay is ColorRect:
			var color_overlay: ColorRect = overlay
			color_overlay.position = Vector2.ZERO
			color_overlay.size = viewport_size

	if main_menu_panel != null:
		main_menu_panel.custom_minimum_size = Vector2(420.0, 320.0)
		main_menu_panel.size = main_menu_panel.custom_minimum_size
		main_menu_panel.position = (viewport_size - main_menu_panel.size) * 0.5

	if main_menu_settings_panel != null:
		main_menu_settings_panel.custom_minimum_size = Vector2(360.0, 220.0)
		main_menu_settings_panel.size = main_menu_settings_panel.custom_minimum_size
		main_menu_settings_panel.position = (viewport_size - main_menu_settings_panel.size) * 0.5

func _layout_tactical_ui() -> void:
	if grid == null:
		return
	if game_flow.current_mode != GameFlow.Mode.TACTICAL_COMBAT:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var sidebar_width: float = float(metrics["sidebar_width"])
	var map_height: float = float(metrics["map_height"])
	var panel_rect: Rect2 = _boarding_action_panel_rect() if game_flow.tactical_type == GameFlow.TacticalType.BOARDING else Rect2()
	var left: float = sidebar_width + 14.0
	var top: float = 90.0 if game_flow.tactical_type == GameFlow.TacticalType.BOARDING else 14.0
	var right: float = viewport_size.x - 14.0
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		right = panel_rect.position.x - 12.0
	var bottom: float = map_height - 14.0
	var area_w: float = maxf(120.0, right - left)
	var area_h: float = maxf(120.0, bottom - top)
	var tile_size: int = int(floor(minf(area_w / float(max(1, grid.width)), area_h / float(max(1, grid.height)))))
	grid.tile_size = clampi(tile_size, 26, 64)
	var board_size: Vector2 = Vector2(float(grid.width * grid.tile_size), float(grid.height * grid.tile_size))
	grid.position = Vector2(left + (area_w - board_size.x) * 0.5, top + (area_h - board_size.y) * 0.5)
	grid.queue_redraw()
	for unit in units:
		unit.tile_size = grid.tile_size
		unit.position = _unit_world_from_cell(unit.cell)
		unit.queue_redraw()

func _unit_world_from_cell(cell: Vector2i) -> Vector2:
	return grid.position + grid.cell_to_local(cell)

func _refresh_boarding_unit_visuals() -> void:
	if game_flow.tactical_type != GameFlow.TacticalType.BOARDING:
		for unit in units:
			unit.set_active_actor(false)
			unit.set_dimmed(false)
		return
	var actor: Unit = _current_boarding_actor()
	for unit in units:
		var is_actor: bool = unit == actor
		unit.set_active_actor(is_actor)
		unit.set_dimmed(actor != null and not is_actor)

func _assign_boarding_unit_labels() -> void:
	boarding_unit_labels.clear()
	if units.is_empty():
		return
	for idx in range(units.size()):
		var unit: Unit = units[idx]
		var label: String = _crew_label_for_index(idx)
		boarding_unit_labels[unit.get_instance_id()] = label

func _crew_label_for_index(idx: int) -> String:
	if idx < CREW_CARD_LABELS.length():
		return CREW_CARD_LABELS.substr(idx, 1)
	return "C%d" % (idx + 1)

func _crew_label(unit: Unit) -> String:
	if unit == null:
		return "-"
	var key: int = unit.get_instance_id()
	if boarding_unit_labels.has(key):
		return str(boarding_unit_labels[key])
	return "?"

func _draw_boarding_crew_cards() -> void:
	if game_flow.current_mode != GameFlow.Mode.TACTICAL_COMBAT:
		return
	if game_flow.tactical_type != GameFlow.TacticalType.BOARDING:
		return
	if units.is_empty() or boarding_initiative_order.is_empty():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var metrics: Dictionary = _ui_metrics(viewport_size)
	var sidebar_width: float = float(metrics["sidebar_width"])
	var map_height: float = float(metrics["map_height"])
	var panel_rect: Rect2 = _boarding_action_panel_rect()
	var start_x: float = sidebar_width + 14.0
	var available_w: float = maxf(160.0, panel_rect.position.x - 12.0 - start_x)
	var card_gap: float = 8.0
	var ordered_units: Array[Unit] = _boarding_turn_sequence_units()
	var card_w: float = clampf((available_w - card_gap * float(max(0, ordered_units.size() - 1))) / float(max(1, ordered_units.size())), 64.0, 104.0)
	var card_h: float = 64.0
	var y: float = minf(map_height - card_h - 12.0, 16.0)
	var actor: Unit = _current_boarding_actor()
	for idx in range(ordered_units.size()):
		var unit: Unit = ordered_units[idx]
		var x: float = start_x + float(idx) * (card_w + card_gap)
		var card: Rect2 = Rect2(Vector2(x, y), Vector2(card_w, card_h))
		var is_active: bool = unit == actor
		var bg: Color = Color(0.1, 0.22, 0.35, 0.9) if unit.team == Unit.Team.PLAYER else Color(0.35, 0.13, 0.11, 0.9)
		if unit.has_acted:
			bg = bg.darkened(0.28)
		draw_rect(card, bg, true)
		draw_rect(card, Color(1.0, 0.88, 0.48, 0.95) if is_active else Color(0.72, 0.82, 0.9, 0.6), false, 2.0)
		draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 19.0), "Crew %s" % _crew_label(unit), HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 14)
		draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 37.0), "HP %d" % unit.hp, HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13)
		draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 54.0), "Turn %d" % (idx + 1), HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13)

func _boarding_turn_sequence_units() -> Array[Unit]:
	var ordered: Array[Unit] = []
	if boarding_initiative_order.is_empty():
		return ordered
	var start: int = clampi(boarding_initiative_index, 0, boarding_initiative_order.size() - 1)
	for step in range(boarding_initiative_order.size()):
		var idx: int = (start + step) % boarding_initiative_order.size()
		var unit: Unit = boarding_initiative_order[idx]
		if unit == null or not is_instance_valid(unit):
			continue
		if not units.has(unit):
			continue
		ordered.append(unit)
	return ordered

func _boarding_turn_position(unit: Unit) -> int:
	if unit == null or boarding_initiative_order.is_empty():
		return 0
	var idx: int = boarding_initiative_order.find(unit)
	if idx < 0:
		return 0
	if idx >= boarding_initiative_index:
		return idx - boarding_initiative_index + 1
	return boarding_initiative_order.size() - boarding_initiative_index + idx + 1

func _sync_camera_to_viewport() -> void:
	if main_camera == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	main_camera.position = viewport_size * 0.5

func _ui_metrics(viewport_size: Vector2) -> Dictionary:
	var sidebar_width: float = clampf(UI_BASE_SIDEBAR_WIDTH, UI_MIN_SIDEBAR_WIDTH, UI_MAX_SIDEBAR_WIDTH)
	sidebar_width = minf(sidebar_width, maxf(0.0, viewport_size.x - 120.0))
	var desired_log_height: float = clampf(UI_BASE_LOG_HEIGHT, UI_MIN_LOG_HEIGHT, UI_MAX_LOG_HEIGHT)
	var max_log_by_view: float = maxf(0.0, viewport_size.y - UI_MIN_MAP_HEIGHT)
	var log_height: float = minf(desired_log_height, max_log_by_view)
	var map_height: float = maxf(0.0, viewport_size.y - log_height)
	return {
		"sidebar_width": sidebar_width,
		"log_height": log_height,
		"map_height": map_height
	}
