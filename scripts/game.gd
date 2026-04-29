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
var boarding_deck_cells: Array[Vector2i] = []
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
var left_sidebar_menu_box: VBoxContainer
var main_map_info_layer: CanvasLayer
var main_map_info_overlay: ColorRect
var main_map_info_panel: PanelContainer
var main_map_info_title_label: Label
var main_map_info_text_label: Label
var main_map_info_close_button: Button
var main_map_info_x_button: Button
var retirement_pending_return_to_menu: bool = false
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
var last_ship_battle_enemy_faction: String = ""
var last_ship_battle_player_aggressor: bool = false
var port_menu_layer: CanvasLayer
var port_menu_panel: PanelContainer
var port_menu_title_label: Label
var port_menu_info_label: Label
var port_menu_status_label: Label
var port_menu_image_rect: ColorRect
var port_menu_image_label: Label
var port_menu_close_button: Button
var port_menu_primary_button: Button
var port_menu_secondary_button: Button
var port_menu_tertiary_button: Button
var port_menu_quaternary_button: Button
var port_menu_quinary_button: Button
var port_menu_active: bool = false
var port_menu_docked: bool = false
var current_port_menu_port: String = ""
var port_menu_screen: String = "arrival"
var cargo_manifest: Dictionary = {}
var player_piasters: int = 1800
var ship_supplies: int = 40
var ship_cargo: int = 18
var crew_roster_size: int = 42
var governor_favor: int = 0
var active_governor_task: String = ""
var career_state: Dictionary = {}
var port_trade_panel: VBoxContainer
var port_trade_supply_slider: HSlider
var port_trade_supply_value_label: Label
var port_trade_total_label: Label
var port_trade_buy_button: Button
var port_trade_cancel_button: Button
var port_trade_cargo_rows: Array = []
var port_hire_panel: VBoxContainer
var port_hire_slider: HSlider
var port_hire_value_label: Label
var port_hire_cost_label: Label
var port_hire_confirm_button: Button
var port_hire_cancel_button: Button
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
var crew_officers: Array[Dictionary] = []
var boarding_party_roster: Array[Dictionary] = []

const UI_BASE_SIDEBAR_WIDTH := 190.0
const UI_MIN_SIDEBAR_WIDTH := 170.0
const UI_MAX_SIDEBAR_WIDTH := 220.0
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
const CareerSystemScript := preload("res://scripts/career_system.gd")
const SUPPLY_UNIT_COST := 6
const RECRUIT_COST := 45
const FACTION_LIST := ["Spanish", "English", "French", "Dutch"]
const WORLD_POLITICS_INTERVAL_MONTHS := 5
const PORT_EXPORT_CARGO := {
	"Havana": ["Tobacco", "Sugar", "Molasses", "Citrus"],
	"Nassau": ["Salted Fish", "Timber", "Turtle Shell", "Rum"],
	"Port Royal": ["Sugar", "Rum", "Indigo", "Pimento"],
	"Tortuga": ["Coffee", "Hides", "Sugar", "Timber"],
	"Cartagena": ["Silver", "Cacao", "Tobacco", "Dye Wood"],
	"Santo Domingo": ["Sugar", "Coffee", "Cacao", "Cotton"],
	"Veracruz": ["Silver", "Cochineal", "Vanilla", "Tobacco"],
	"Portobelo": ["Silver", "Dyewood", "Cacao", "Pearls"],
	"San Juan": ["Sugar", "Ginger", "Hides", "Coffee"],
	"Campeche": ["Dyewood", "Salt", "Hides", "Cacao"],
	"Maracaibo": ["Cacao", "Hides", "Coffee", "Indigo"],
	"Willemstad": ["Salt", "Aloe", "Sugar", "Transit Goods"],
	"Santiago de Cuba": ["Copper", "Sugar", "Tobacco", "Coffee"],
	"Port-au-Prince": ["Sugar", "Coffee", "Indigo", "Cotton"],
	"Bridgetown": ["Sugar", "Rum", "Cotton", "Ginger"],
	"St. Pierre": ["Sugar", "Coffee", "Cocoa", "Rum"],
	"Basse-Terre": ["Sugar", "Coffee", "Cacao", "Timber"],
	"La Guaira": ["Cacao", "Coffee", "Indigo", "Hides"],
	"St. Augustine": ["Timber", "Hides", "Indigo", "Naval Stores"]
}
const CARGO_UNIT_COST := {
	"Sugar": 14,
	"Molasses": 11,
	"Rum": 19,
	"Tobacco": 22,
	"Coffee": 20,
	"Cacao": 23,
	"Cotton": 16,
	"Indigo": 25,
	"Silver": 44,
	"Cochineal": 38,
	"Vanilla": 33,
	"Dyewood": 21,
	"Dye Wood": 21,
	"Ginger": 18,
	"Citrus": 10,
	"Hides": 17,
	"Timber": 12,
	"Salt": 9,
	"Pearls": 36,
	"Copper": 28,
	"Aloe": 15,
	"Turtle Shell": 24,
	"Salted Fish": 10,
	"Naval Stores": 18,
	"Transit Goods": 20,
	"Pimento": 16
}

func _ready() -> void:
	randomize()
	_reset_career_state()
	last_viewport_size = get_viewport_rect().size
	_sync_camera_to_viewport()
	_setup_left_sidebar_ui()
	_setup_captains_log_ui()
	_setup_main_map_info_ui()
	_setup_time_controls_ui()
	_setup_encounter_ui()
	_setup_port_menu_ui()
	_setup_escape_menu_ui()
	_setup_main_menu_ui()
	game_flow.mode_changed.connect(_on_mode_changed)
	game_flow.message_posted.connect(_on_message_posted)
	world_map.destination_arrived.connect(_on_destination_arrived)
	world_map.random_encounter_triggered.connect(_on_random_encounter)
	world_map.game_month_advanced.connect(_on_world_map_month_advanced)
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
	# Ship combat / boarding HUD draws on this node; skip redundant invalidates on world map.
	if game_flow.current_mode == GameFlow.Mode.SHIP_COMBAT or (
		game_flow.current_mode == GameFlow.Mode.TACTICAL_COMBAT and game_flow.tactical_type == GameFlow.TacticalType.BOARDING
	):
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
		_draw_boarding_deck_surface()
		_draw_boarding_units_overlay()
		_draw_boarding_crew_cards()
		var panel_rect: Rect2 = _boarding_action_panel_rect()
		_draw_boarding_action_panel(panel_rect)

func _unhandled_input(event: InputEvent) -> void:
	if in_main_menu:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if port_menu_active:
				_close_port_menu()
				game_flow.post_message("Port menu closed.")
				get_viewport().set_input_as_handled()
				return
			if main_map_info_layer != null and main_map_info_layer.visible:
				_close_main_map_info()
				game_flow.post_message("Info panel closed.")
				get_viewport().set_input_as_handled()
				return
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

	if port_menu_active:
		return

	if main_map_info_layer != null and main_map_info_layer.visible:
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
	if port_name != "":
		if world_map.set_target_port(port_name):
			can_start_town_assault = false
			game_flow.post_message("Sailing automatically toward %s." % port_name)
		return
	if not world_map.is_click_on_map(local_pos):
		return
	var click_world := world_map.get_world_from_map_click(local_pos)
	if world_map.set_sail_to_world(click_world):
		can_start_town_assault = false
		game_flow.post_message("Course set for open water.")
	else:
		game_flow.post_message("No sea route to that point.")

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
	if not grid.is_cell_on_deck(clicked_cell):
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
	if game_flow.tactical_type == GameFlow.TacticalType.BOARDING:
		for x in range(grid.width):
			for y in range(grid.height):
				var deck_cell := Vector2i(x, y)
				if not grid.is_cell_on_deck(deck_cell):
					blocked[deck_cell] = true
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
	if port_menu_layer != null:
		port_menu_layer.visible = new_mode == GameFlow.Mode.WORLD_MAP and port_menu_active
	if main_map_info_layer != null and new_mode != GameFlow.Mode.WORLD_MAP:
		main_map_info_layer.visible = false
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
	_update_aging_and_career_pressure()
	if port_name != "":
		last_arrived_port = port_name
		can_start_town_assault = false
		_open_port_arrival_menu(port_name)
		if _can_launch_treasure_at_port(port_name):
			game_flow.post_message("The assembled chart marks hidden treasure near %s." % port_name)
		game_flow.post_message("Arrived off %s. Choose your approach." % port_name)
	else:
		last_arrived_port = ""
		can_start_town_assault = false
		game_flow.post_message("You have reached your plotted position.")

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
	var enemy_faction_snapshot := last_ship_battle_enemy_faction
	var was_aggressor_snapshot := last_ship_battle_player_aggressor
	_apply_ship_battle_faction_reputation(player_won)
	_try_progress_governor_mission_naval_win(player_won, enemy_faction_snapshot, was_aggressor_snapshot)
	if player_won:
		_award_career_fame(32, "Naval victory")
		_try_award_map_fragment(0.34, "Recovered complete treasure map from a defeated pirate captain")
		game_flow.post_message("Naval battle won. Back to Caribbean map.")
	else:
		game_flow.post_message("Your ship is beaten. Retreating to world map.")
	last_ship_battle_enemy_faction = ""
	last_ship_battle_player_aggressor = false
	_set_mode(GameFlow.Mode.WORLD_MAP)

func _resolve_enemy_ship_turn_if_needed() -> void:
	if game_flow.current_mode != GameFlow.Mode.SHIP_COMBAT:
		return
	if ship_battle.phase == ShipBattle.Phase.ENEMY_TURN:
		ship_battle.enemy_take_turn()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if main_map_info_layer != null and main_map_info_layer.visible:
				_close_main_map_info()
				game_flow.post_message("Info panel closed.")
				get_viewport().set_input_as_handled()
				return

	if port_menu_active:
		return

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
		var treasure_in_progress := bool(career_state.get("treasure_in_progress", false))
		if treasure_in_progress:
			_resolve_treasure_expedition_success()
		_award_career_fame(44, "Town assault victory")
		_advance_family_rescue_progress("Town assault intelligence recovered.")
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
	if not grid.is_cell_on_deck(cell):
		return false
	if grid.is_cell_blocked(cell):
		return false
	if boarding_chokepoint_cells.has(cell):
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
	# Sloop upper deck: 1-yard tactical cells, no sail surfaces, masts act as cover.
	grid.width = 25
	grid.height = 7
	current_boarding_template_name = "25-yard sloop upper deck"
	boarding_deck_cells = _sloop_upper_deck_cells()
	boarding_objective_cell = Vector2i(22, 3)
	boarding_gangplank_cells = [Vector2i(5, 0), Vector2i(5, 6)]
	boarding_chokepoint_cells = [Vector2i(13, 3)]
	boarding_obstacle_cells = [
		Vector2i(9, 3), # mainmast
		Vector2i(16, 3), # foremast
		Vector2i(2, 2), Vector2i(2, 4), # stern rail/cargo
		Vector2i(18, 1), Vector2i(19, 1),
		Vector2i(18, 5), Vector2i(19, 5), # hatch coamings
		Vector2i(21, 2), Vector2i(21, 4) # foredeck rigging
	]
	boarding_attacker_spawn_cells = [Vector2i(3, 2), Vector2i(3, 4), Vector2i(4, 3), Vector2i(5, 2)]
	boarding_defender_spawn_cells = [Vector2i(20, 3), Vector2i(21, 3), Vector2i(20, 2), Vector2i(20, 4)]

	grid.set_deck_cells(boarding_deck_cells)
	grid.set_blocked_cells(boarding_obstacle_cells)
	grid.set_gangplank_cells(boarding_gangplank_cells)
	grid.set_objective_cells([boarding_objective_cell])
	grid.set_chokepoint_cells(boarding_chokepoint_cells)

func _sloop_upper_deck_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(25):
		var min_y := 0
		var max_y := 6
		if x == 0:
			min_y = 2
			max_y = 4
		elif x <= 2:
			min_y = 1
			max_y = 5
		elif x >= 24:
			min_y = 3
			max_y = 3
		elif x >= 22:
			min_y = 2
			max_y = 4
		elif x >= 20:
			min_y = 1
			max_y = 5
		for y in range(min_y, max_y + 1):
			cells.append(Vector2i(x, y))
	return cells

func _clear_special_tactical_layout() -> void:
	grid.width = 14
	grid.height = 10
	boarding_obstacle_cells.clear()
	boarding_chokepoint_cells.clear()
	boarding_deck_cells.clear()
	boarding_attacker_spawn_cells.clear()
	boarding_defender_spawn_cells.clear()
	grid.set_deck_cells([])
	grid.set_blocked_cells([])
	grid.set_gangplank_cells([])
	grid.set_objective_cells([])
	grid.set_chokepoint_cells([])

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _first_los_blocker(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var line_cells: Array[Vector2i] = _line_cells_between(from_cell, to_cell)
	for cell in line_cells:
		if game_flow.tactical_type == GameFlow.TacticalType.BOARDING and not grid.is_cell_on_deck(cell):
			return cell
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
	var draw_scale: float = _ship_draw_scale(ship_class)
	var heading_rad: float = deg_to_rad(90.0 - heading_deg)
	var basis := Transform2D(heading_rad, center)
	var hull_local := PackedVector2Array([
		Vector2(-130.0 * draw_scale, 18.0 * draw_scale),
		Vector2(-72.0 * draw_scale, -8.0 * draw_scale),
		Vector2(70.0 * draw_scale, -10.0 * draw_scale),
		Vector2(132.0 * draw_scale, 6.0 * draw_scale),
		Vector2(96.0 * draw_scale, 36.0 * draw_scale),
		Vector2(-94.0 * draw_scale, 38.0 * draw_scale)
	])
	var hull := PackedVector2Array()
	for p in hull_local:
		hull.append(basis * p)
	draw_colored_polygon(hull, hull_color)
	draw_polyline(hull, Color(0.18, 0.12, 0.07), 2.0, true)

	var mast1_x: float = -30.0 * draw_scale
	var mast2_x: float = 34.0 * draw_scale
	var mast_height_1: float = 110.0 * draw_scale
	var mast_height_2: float = 82.0 * draw_scale
	draw_line(basis * Vector2(mast1_x, 18.0 * draw_scale), basis * Vector2(mast1_x, -mast_height_1), Color(0.86, 0.8, 0.65), 3.0)
	draw_line(basis * Vector2(mast2_x, 20.0 * draw_scale), basis * Vector2(mast2_x, -mast_height_2), Color(0.86, 0.8, 0.65), 3.0)

	var sail_color := Color(0.9, 0.89, 0.82, 0.9)
	var fore_sail := PackedVector2Array([
		basis * Vector2(mast2_x, -74.0 * draw_scale),
		basis * Vector2(mast2_x + 50.0, -34.0 * draw_scale),
		basis * Vector2(mast2_x, -22.0 * draw_scale)
	])
	var main_sail := PackedVector2Array([
		basis * Vector2(mast1_x, -96.0 * draw_scale),
		basis * Vector2(mast1_x + 68.0, -48.0 * draw_scale),
		basis * Vector2(mast1_x, -18.0 * draw_scale)
	])
	draw_colored_polygon(fore_sail, sail_color)
	draw_colored_polygon(main_sail, sail_color)

	# Gun ports hint broadside strength by ship class.
	var gun_count: int = int(round(4.0 + draw_scale * 5.0))
	for i in range(gun_count):
		var t: float = float(i + 1) / float(gun_count + 1)
		var px: float = lerpf(-90.0 * draw_scale, 88.0 * draw_scale, t)
		draw_circle(basis * Vector2(px, 20.0 * draw_scale), 2.5, Color(0.1, 0.1, 0.1))

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

func _draw_boarding_deck_surface() -> void:
	if grid == null:
		return
	var tile := float(grid.tile_size)
	var board_rect := Rect2(grid.position, Vector2(float(grid.width) * tile, float(grid.height) * tile))
	draw_rect(board_rect, Color(0.04, 0.08, 0.12, 1.0), true)

	var deck_cells: Array[Vector2i] = boarding_deck_cells
	if deck_cells.is_empty():
		for y in range(grid.height):
			for x in range(grid.width):
				deck_cells.append(Vector2i(x, y))

	for cell in deck_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.2, 0.16, 0.1), true)

	for cell in boarding_chokepoint_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.4, 0.28, 0.16, 0.5), true)

	for cell in boarding_gangplank_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.62, 0.47, 0.28, 0.75), true)

	var objective_rect := Rect2(grid.position + Vector2(boarding_objective_cell) * tile, Vector2.ONE * tile)
	draw_rect(objective_rect, Color(0.95, 0.8, 0.35, 0.8), true)

	for cell in boarding_obstacle_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.2, 0.17, 0.12, 0.95), true)

	for cell in reachable_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.3, 0.65, 1.0, 0.25), true)

	if grid.is_in_bounds(grid.hovered_cell) and grid.is_cell_on_deck(grid.hovered_cell):
		var hover_rect := Rect2(grid.position + Vector2(grid.hovered_cell) * tile, Vector2.ONE * tile)
		draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.15), true)

	for cell in deck_cells:
		var cell_rect := Rect2(grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		draw_rect(cell_rect, Color(0.28, 0.3, 0.36), false, 1.0)

func _draw_boarding_units_overlay() -> void:
	if grid == null:
		return
	var tile := float(grid.tile_size)
	var actor: Unit = _current_boarding_actor()
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		var center := grid.position + Vector2(unit.cell) * tile + Vector2.ONE * tile * 0.5
		var radius := tile * 0.34
		var base_color := Color(0.35, 0.65, 1.0) if unit.team == Unit.Team.PLAYER else Color(1.0, 0.4, 0.35)
		draw_circle(center, radius, base_color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, 6.0), str(unit.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		if unit == selected_unit:
			draw_arc(center, radius + 4.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.5), 3.0)
		if unit == actor:
			draw_arc(center, radius + 8.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.45, 0.95), 3.0)
		if unit.has_acted:
			draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.4))

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
	title.position = Vector2(18, 16)
	title.add_theme_font_size_override("font_size", 18)
	left_sidebar_panel.add_child(title)

	left_sidebar_menu_box = VBoxContainer.new()
	left_sidebar_menu_box.position = Vector2(12.0, 52.0)
	left_sidebar_menu_box.size = Vector2(maxf(80.0, sidebar_width - 24.0), maxf(80.0, map_height - 64.0))
	left_sidebar_menu_box.add_theme_constant_override("separation", 7)
	left_sidebar_panel.add_child(left_sidebar_menu_box)
	left_sidebar_menu_box.add_child(_make_sidebar_button("Save", _on_map_save_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Load", _on_map_load_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Player / Captain", _on_map_captain_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Crew Management", _on_map_crew_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Captain's Log", _on_map_captains_log_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Port Information", _on_map_port_info_pressed))
	left_sidebar_menu_box.add_child(_make_sidebar_button("Retire", _on_map_retire_pressed))

func _make_sidebar_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button

func _setup_main_map_info_ui() -> void:
	main_map_info_layer = CanvasLayer.new()
	main_map_info_layer.layer = 92
	main_map_info_layer.visible = false
	add_child(main_map_info_layer)

	main_map_info_overlay = ColorRect.new()
	main_map_info_overlay.color = Color(0.0, 0.0, 0.0, 0.56)
	main_map_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main_map_info_layer.add_child(main_map_info_overlay)

	main_map_info_panel = PanelContainer.new()
	main_map_info_layer.add_child(main_map_info_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	main_map_info_panel.add_child(box)

	main_map_info_title_label = Label.new()
	main_map_info_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_map_info_title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(main_map_info_title_label)

	main_map_info_text_label = Label.new()
	main_map_info_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_map_info_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	main_map_info_text_label.custom_minimum_size = Vector2(620.0, 360.0)
	box.add_child(main_map_info_text_label)

	main_map_info_close_button = Button.new()
	main_map_info_close_button.text = "Close"
	main_map_info_close_button.custom_minimum_size = Vector2(180.0, 36.0)
	main_map_info_close_button.pressed.connect(_close_main_map_info)
	box.add_child(main_map_info_close_button)

	main_map_info_x_button = Button.new()
	main_map_info_x_button.text = "X"
	main_map_info_x_button.custom_minimum_size = Vector2(30.0, 30.0)
	main_map_info_x_button.pressed.connect(_close_main_map_info)
	main_map_info_panel.add_child(main_map_info_x_button)

func _open_main_map_info(title: String, body: String, close_label: String = "Close", return_to_main_menu_on_close: bool = false) -> void:
	if main_map_info_layer == null:
		return
	retirement_pending_return_to_menu = return_to_main_menu_on_close
	main_map_info_title_label.text = title
	main_map_info_text_label.text = body
	if main_map_info_close_button != null:
		main_map_info_close_button.text = close_label
	main_map_info_layer.visible = game_flow.current_mode == GameFlow.Mode.WORLD_MAP
	_layout_worldmap_ui()

func _close_main_map_info() -> void:
	var should_return_to_menu := retirement_pending_return_to_menu
	retirement_pending_return_to_menu = false
	if main_map_info_layer != null:
		main_map_info_layer.visible = false
	if should_return_to_menu:
		_on_escape_quit_to_menu_pressed()

func _setup_time_controls_ui() -> void:
	time_controls_layer = CanvasLayer.new()
	time_controls_layer.layer = 11
	add_child(time_controls_layer)

	time_controls_box = HBoxContainer.new()
	time_controls_box.position = Vector2(1700, 12)
	time_controls_box.add_theme_constant_override("separation", 6)
	time_controls_layer.add_child(time_controls_box)

	var group := ButtonGroup.new()
	for time_scale in [1.0, 2.0, 4.0]:
		var selected_scale: float = time_scale
		var button := Button.new()
		button.text = "%dx" % int(time_scale)
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

func _setup_port_menu_ui() -> void:
	port_menu_layer = CanvasLayer.new()
	port_menu_layer.layer = 95
	port_menu_layer.visible = false
	add_child(port_menu_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	port_menu_layer.add_child(overlay)

	port_menu_panel = PanelContainer.new()
	port_menu_panel.focus_mode = Control.FOCUS_NONE
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.07, 0.09, 0.12, 0.98)
	panel_bg.set_corner_radius_all(6)
	panel_bg.content_margin_left = 0
	panel_bg.content_margin_top = 0
	panel_bg.content_margin_right = 0
	panel_bg.content_margin_bottom = 0
	port_menu_panel.add_theme_stylebox_override("panel", panel_bg)

	port_menu_layer.add_child(port_menu_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 12)
	outer_margin.add_theme_constant_override("margin_top", 10)
	outer_margin.add_theme_constant_override("margin_right", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	port_menu_panel.add_child(outer_margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	outer_margin.add_child(box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	box.add_child(header_row)

	var title_left_pad := Control.new()
	title_left_pad.custom_minimum_size = Vector2(36.0, 1.0)
	title_left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_left_pad)

	port_menu_title_label = Label.new()
	port_menu_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_menu_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	port_menu_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_menu_title_label.add_theme_font_size_override("font_size", 24)
	header_row.add_child(port_menu_title_label)

	port_menu_close_button = Button.new()
	port_menu_close_button.text = "X"
	port_menu_close_button.custom_minimum_size = Vector2(36.0, 32.0)
	port_menu_close_button.focus_mode = Control.FOCUS_CLICK
	port_menu_close_button.flat = true
	port_menu_close_button.pressed.connect(_on_port_menu_close_pressed)
	header_row.add_child(port_menu_close_button)

	port_menu_image_rect = ColorRect.new()
	port_menu_image_rect.color = Color(0.16, 0.23, 0.33, 0.95)
	port_menu_image_rect.custom_minimum_size = Vector2(520.0, 170.0)
	port_menu_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(port_menu_image_rect)

	port_menu_image_label = Label.new()
	port_menu_image_label.text = "Port image placeholder"
	port_menu_image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_menu_image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	port_menu_image_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_menu_image_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	port_menu_image_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_menu_image_rect.add_child(port_menu_image_label)

	port_menu_info_label = Label.new()
	port_menu_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	port_menu_info_label.custom_minimum_size = Vector2(520.0, 92.0)
	port_menu_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(port_menu_info_label)

	port_menu_status_label = Label.new()
	port_menu_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	port_menu_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(port_menu_status_label)

	port_menu_primary_button = Button.new()
	port_menu_primary_button.custom_minimum_size = Vector2(360.0, 36.0)
	port_menu_primary_button.focus_mode = Control.FOCUS_CLICK
	port_menu_primary_button.pressed.connect(_on_port_menu_primary_pressed)
	box.add_child(port_menu_primary_button)

	port_menu_secondary_button = Button.new()
	port_menu_secondary_button.custom_minimum_size = Vector2(360.0, 36.0)
	port_menu_secondary_button.focus_mode = Control.FOCUS_CLICK
	port_menu_secondary_button.pressed.connect(_on_port_menu_secondary_pressed)
	box.add_child(port_menu_secondary_button)

	port_menu_tertiary_button = Button.new()
	port_menu_tertiary_button.custom_minimum_size = Vector2(360.0, 34.0)
	port_menu_tertiary_button.focus_mode = Control.FOCUS_CLICK
	port_menu_tertiary_button.pressed.connect(_on_port_menu_tertiary_pressed)
	box.add_child(port_menu_tertiary_button)

	port_menu_quaternary_button = Button.new()
	port_menu_quaternary_button.custom_minimum_size = Vector2(360.0, 34.0)
	port_menu_quaternary_button.focus_mode = Control.FOCUS_CLICK
	port_menu_quaternary_button.pressed.connect(_on_port_menu_quaternary_pressed)
	box.add_child(port_menu_quaternary_button)

	port_menu_quinary_button = Button.new()
	port_menu_quinary_button.custom_minimum_size = Vector2(360.0, 34.0)
	port_menu_quinary_button.focus_mode = Control.FOCUS_CLICK
	port_menu_quinary_button.pressed.connect(_on_port_menu_quinary_pressed)
	box.add_child(port_menu_quinary_button)

	port_trade_panel = VBoxContainer.new()
	port_trade_panel.visible = false
	port_trade_panel.add_theme_constant_override("separation", 6)
	box.add_child(port_trade_panel)

	var trade_title := Label.new()
	trade_title.text = "Trade Ledger"
	trade_title.add_theme_font_size_override("font_size", 18)
	port_trade_panel.add_child(trade_title)

	var supply_row := HBoxContainer.new()
	supply_row.add_theme_constant_override("separation", 8)
	port_trade_panel.add_child(supply_row)
	var supply_name := Label.new()
	supply_name.text = "Food Supplies"
	supply_name.custom_minimum_size = Vector2(180.0, 24.0)
	supply_row.add_child(supply_name)
	port_trade_supply_slider = HSlider.new()
	port_trade_supply_slider.min_value = 0
	port_trade_supply_slider.max_value = 40
	port_trade_supply_slider.step = 1
	port_trade_supply_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_trade_supply_slider.value_changed.connect(_on_port_trade_slider_changed)
	supply_row.add_child(port_trade_supply_slider)
	port_trade_supply_value_label = Label.new()
	port_trade_supply_value_label.custom_minimum_size = Vector2(130.0, 24.0)
	supply_row.add_child(port_trade_supply_value_label)

	port_trade_total_label = Label.new()
	port_trade_total_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	port_trade_panel.add_child(port_trade_total_label)

	var trade_btn_row := HBoxContainer.new()
	trade_btn_row.add_theme_constant_override("separation", 8)
	port_trade_panel.add_child(trade_btn_row)
	port_trade_buy_button = Button.new()
	port_trade_buy_button.text = "Confirm Purchase"
	port_trade_buy_button.custom_minimum_size = Vector2(180.0, 34.0)
	port_trade_buy_button.focus_mode = Control.FOCUS_CLICK
	port_trade_buy_button.pressed.connect(_on_port_trade_buy_pressed)
	trade_btn_row.add_child(port_trade_buy_button)
	port_trade_cancel_button = Button.new()
	port_trade_cancel_button.text = "Back"
	port_trade_cancel_button.custom_minimum_size = Vector2(120.0, 34.0)
	port_trade_cancel_button.focus_mode = Control.FOCUS_CLICK
	port_trade_cancel_button.pressed.connect(_on_port_trade_cancel_pressed)
	trade_btn_row.add_child(port_trade_cancel_button)

	port_hire_panel = VBoxContainer.new()
	port_hire_panel.visible = false
	port_hire_panel.add_theme_constant_override("separation", 8)
	box.add_child(port_hire_panel)
	var hire_title := Label.new()
	hire_title.text = "Tavern Hiring Board"
	hire_title.add_theme_font_size_override("font_size", 18)
	port_hire_panel.add_child(hire_title)
	var hire_row := HBoxContainer.new()
	hire_row.add_theme_constant_override("separation", 8)
	port_hire_panel.add_child(hire_row)
	var hire_label := Label.new()
	hire_label.text = "New Pirates"
	hire_label.custom_minimum_size = Vector2(180.0, 24.0)
	hire_row.add_child(hire_label)
	port_hire_slider = HSlider.new()
	port_hire_slider.min_value = 0
	port_hire_slider.max_value = 8
	port_hire_slider.step = 1
	port_hire_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_hire_slider.value_changed.connect(_on_port_hire_slider_changed)
	hire_row.add_child(port_hire_slider)
	port_hire_value_label = Label.new()
	port_hire_value_label.custom_minimum_size = Vector2(130.0, 24.0)
	hire_row.add_child(port_hire_value_label)
	port_hire_cost_label = Label.new()
	port_hire_panel.add_child(port_hire_cost_label)
	var hire_btn_row := HBoxContainer.new()
	hire_btn_row.add_theme_constant_override("separation", 8)
	port_hire_panel.add_child(hire_btn_row)
	port_hire_confirm_button = Button.new()
	port_hire_confirm_button.text = "Hire Crew"
	port_hire_confirm_button.custom_minimum_size = Vector2(180.0, 34.0)
	port_hire_confirm_button.focus_mode = Control.FOCUS_CLICK
	port_hire_confirm_button.pressed.connect(_on_port_hire_confirm_pressed)
	hire_btn_row.add_child(port_hire_confirm_button)
	port_hire_cancel_button = Button.new()
	port_hire_cancel_button.text = "Back"
	port_hire_cancel_button.custom_minimum_size = Vector2(120.0, 34.0)
	port_hire_cancel_button.focus_mode = Control.FOCUS_CLICK
	port_hire_cancel_button.pressed.connect(_on_port_hire_cancel_pressed)
	hire_btn_row.add_child(port_hire_cancel_button)

func _open_port_arrival_menu(port_name: String) -> void:
	current_port_menu_port = port_name
	port_menu_active = true
	port_menu_docked = false
	port_menu_screen = "arrival"
	can_start_town_assault = false

	port_menu_title_label.text = "%s - Off the Coast" % port_name
	port_menu_image_label.text = "Illustration: %s harbor approaches" % port_name
	port_menu_info_label.text = "Your ship rides offshore. You can bombard and launch a landing party, or sail into the harbor to dock."
	port_menu_status_label.text = "Choose your next move."
	port_menu_primary_button.text = "Attack the Port (Land Combat)"
	port_menu_secondary_button.text = "Sail Into Port"
	port_menu_tertiary_button.text = "Leave Port"
	port_menu_quaternary_button.text = "Launch Treasure Expedition"
	port_menu_primary_button.visible = true
	port_menu_secondary_button.visible = true
	port_menu_tertiary_button.visible = true
	port_menu_quaternary_button.visible = _can_launch_treasure_at_port(port_name)
	port_menu_quinary_button.visible = false
	port_trade_panel.visible = false
	port_hire_panel.visible = false

	port_menu_layer.visible = game_flow.current_mode == GameFlow.Mode.WORLD_MAP
	_layout_worldmap_ui()

func _open_port_docked_menu(port_name: String) -> void:
	current_port_menu_port = port_name
	port_menu_active = true
	port_menu_docked = true
	port_menu_screen = "docked"
	can_start_town_assault = false

	port_menu_title_label.text = "%s - Docked" % port_name
	port_menu_image_label.text = "Illustration: %s docks and quays" % port_name
	port_menu_info_label.text = "Your ship is secured at the quay. Provision, hire hands, or seek an audience with the governor."
	port_menu_status_label.text = _port_docked_status_text("Harbor master awaits your orders.")
	port_menu_primary_button.text = "Trade Supplies / Cargo"
	port_menu_secondary_button.text = "Recruit New Pirates"
	port_menu_tertiary_button.text = "Petition the Governor"
	port_menu_quaternary_button.text = "Attack the Port (Land Combat)"
	port_menu_quinary_button.text = "Leave Port (Return to Sea)"
	port_menu_primary_button.visible = true
	port_menu_secondary_button.visible = true
	port_menu_tertiary_button.visible = true
	port_menu_quaternary_button.visible = true
	port_menu_quinary_button.visible = true
	port_trade_panel.visible = false
	port_hire_panel.visible = false

	port_menu_layer.visible = game_flow.current_mode == GameFlow.Mode.WORLD_MAP
	_layout_worldmap_ui()
	_try_complete_governor_mission_on_docked(port_name)

func _close_port_menu() -> void:
	port_menu_active = false
	port_menu_docked = false
	port_menu_screen = "arrival"
	current_port_menu_port = ""
	if port_menu_layer != null:
		port_menu_layer.visible = false

func _on_port_menu_close_pressed() -> void:
	if not port_menu_active:
		return
	var port_name := current_port_menu_port
	_close_port_menu()
	if port_name != "":
		game_flow.post_message("Leaving %s port menu." % port_name)

func _on_port_menu_primary_pressed() -> void:
	if not port_menu_active:
		return
	if not port_menu_docked:
		var target_port := current_port_menu_port
		_close_port_menu()
		last_arrived_port = target_port
		can_start_town_assault = true
		_start_town_assault_demo()
		return
	if port_menu_screen == "docked":
		_open_port_trade_menu(current_port_menu_port)

func _on_port_menu_secondary_pressed() -> void:
	if not port_menu_active:
		return
	if not port_menu_docked:
		var port_name := current_port_menu_port
		_open_port_docked_menu(port_name)
		game_flow.post_message("You sail into %s and dock safely." % port_name)
		return
	if port_menu_screen == "docked":
		_open_port_hire_menu(current_port_menu_port)

func _on_port_menu_tertiary_pressed() -> void:
	if not port_menu_active:
		return
	if not port_menu_docked:
		var departed_port := current_port_menu_port
		_close_port_menu()
		game_flow.post_message("You leave %s astern and remain at sea." % departed_port)
		return
	var docked_port := current_port_menu_port
	var gift_cost := 120
	if player_piasters >= gift_cost and randf() < 0.65:
		player_piasters -= gift_cost
		governor_favor += 1
		if career_state.is_empty():
			_reset_career_state()
		if int(career_state.get("family_stage", 0)) < 3 and randf() < 0.5:
			active_governor_task = "Family lead near %s" % docked_port
			_advance_family_rescue_progress("Governor shared records tied to your missing family.")
		else:
			var sponsor_faction := _current_port_controller_faction(docked_port)
			_offer_governor_contract(docked_port, sponsor_faction)
			if not _governor_mission_is_active() and not active_governor_task.begins_with("Finish your"):
				active_governor_task = "Escort a treasury sloop near %s" % docked_port
		_award_career_fame(14, "Governor petition success")
		var port_faction := _current_port_controller_faction(docked_port)
		_apply_faction_reputation_delta(port_faction, 9, "successful governor mission")
		game_flow.post_message("At %s: petition accepted. Governor favor increased." % docked_port)
		port_menu_status_label.text = _port_docked_status_text("Governor grants a lead: %s." % active_governor_task)
	else:
		governor_favor = max(0, governor_favor - 1)
		game_flow.post_message("At %s: governor refuses your petition this visit." % docked_port)
		port_menu_status_label.text = _port_docked_status_text("Petition denied. Reputation with officials slips.")

func _on_port_menu_quaternary_pressed() -> void:
	if not port_menu_active:
		return
	if not port_menu_docked:
		if _can_launch_treasure_at_port(current_port_menu_port):
			_launch_treasure_expedition(current_port_menu_port)
		return
	var target_port := current_port_menu_port
	_close_port_menu()
	last_arrived_port = target_port
	can_start_town_assault = true
	_start_town_assault_demo()

func _on_port_menu_quinary_pressed() -> void:
	if not port_menu_active or not port_menu_docked:
		return
	var departed_port := current_port_menu_port
	_close_port_menu()
	game_flow.post_message("Casting off from %s. Back to open sea." % departed_port)

func _open_port_trade_menu(port_name: String) -> void:
	port_menu_screen = "trade"
	port_menu_title_label.text = "%s - Trade Ledger" % port_name
	port_menu_info_label.text = "Set food supplies and cargo quantities, then confirm one bulk purchase."
	port_menu_primary_button.visible = false
	port_menu_secondary_button.visible = false
	port_menu_tertiary_button.visible = false
	port_menu_quaternary_button.visible = false
	port_menu_quinary_button.visible = false
	port_trade_panel.visible = true
	port_hire_panel.visible = false
	_build_port_trade_rows(port_name)
	_on_port_trade_slider_changed(0.0)

func _open_port_hire_menu(port_name: String) -> void:
	port_menu_screen = "hire"
	port_menu_title_label.text = "%s - Hiring Board" % port_name
	port_menu_info_label.text = "Set how many pirates you want to recruit from the taverns and dockside crews."
	port_menu_primary_button.visible = false
	port_menu_secondary_button.visible = false
	port_menu_tertiary_button.visible = false
	port_menu_quaternary_button.visible = false
	port_menu_quinary_button.visible = false
	port_trade_panel.visible = false
	port_hire_panel.visible = true
	port_hire_slider.value = 0
	_on_port_hire_slider_changed(0.0)

func _return_to_port_docked_actions() -> void:
	_open_port_docked_menu(current_port_menu_port)

func _seed_port_market_quotes_into_career() -> void:
	var out: Dictionary = {}
	for port_key in PORT_EXPORT_CARGO.keys():
		var port_name: String = str(port_key)
		var per: Dictionary = {}
		var goods_variant: Variant = PORT_EXPORT_CARGO[port_key]
		if goods_variant is Array:
			for g in goods_variant as Array:
				var gn: String = str(g)
				per[gn] = lerpf(0.88, 1.2, randf())
		out[port_name] = per
	career_state["market_quotes"] = out

func _ensure_market_quotes_defaults() -> void:
	var mq_v: Variant = career_state.get("market_quotes", {})
	if not mq_v is Dictionary or (mq_v as Dictionary).is_empty():
		_seed_port_market_quotes_into_career()

func _trade_unit_buy_price(port_name: String, cargo_name: String) -> int:
	_ensure_career_state_defaults()
	_ensure_market_quotes_defaults()
	var base: int = int(CARGO_UNIT_COST.get(cargo_name, 18))
	var mult: float = 1.0
	var mq_v: Variant = career_state.get("market_quotes", {})
	if mq_v is Dictionary:
		var pm_v: Variant = (mq_v as Dictionary).get(port_name, {})
		if pm_v is Dictionary:
			mult = float((pm_v as Dictionary).get(cargo_name, 1.0))
	return maxi(4, int(round(float(base) * mult)))

func _tick_port_markets_for_month() -> void:
	_ensure_career_state_defaults()
	_ensure_market_quotes_defaults()
	var mq_v: Variant = career_state.get("market_quotes", {})
	if not mq_v is Dictionary:
		return
	var mq: Dictionary = mq_v as Dictionary
	for port_key in mq.keys():
		var pm_v: Variant = mq[port_key]
		if not pm_v is Dictionary:
			continue
		var pm: Dictionary = pm_v as Dictionary
		for cargo_key in pm.keys():
			var w: float = float(pm[cargo_key])
			w += randf_range(-0.045, 0.045)
			pm[cargo_key] = clampf(w, 0.72, 1.45)
	career_state["market_quotes"] = mq

func _governor_mission_is_active() -> bool:
	_ensure_career_state_defaults()
	var m: Variant = career_state.get("active_mission", {})
	if not m is Dictionary:
		return false
	var md: Dictionary = m as Dictionary
	return md.has("kind") and str(md.get("kind", "")) != ""

func _clear_active_governor_mission() -> void:
	career_state.erase("active_mission")
	active_governor_task = ""

func _pay_and_clear_governor_mission(md: Dictionary) -> void:
	var coin: int = int(md.get("reward_coin", 0))
	var fame: int = int(md.get("reward_fame", 0))
	var rf: String = str(md.get("rep_faction", ""))
	var ra: int = int(md.get("rep_amount", 0))
	player_piasters += coin
	if fame > 0:
		_award_career_fame(fame, "Governor commission")
	if rf != "" and ra != 0:
		_apply_faction_reputation_delta(rf, ra, "commission fulfilled")
	game_flow.post_message("Commission paid: +%d pieces of eight to the crew chest." % coin)
	_clear_active_governor_mission()

func _offer_governor_contract(offer_port: String, sponsor_faction: String) -> void:
	_ensure_career_state_defaults()
	if _governor_mission_is_active():
		active_governor_task = "Finish your current commission before taking a new one."
		return
	var names: Array[String] = world_map.get_port_names()
	if names.size() < 2:
		active_governor_task = "Escort a treasury sloop near %s" % offer_port
		return
	var other_ports: Array[String] = []
	for p in names:
		if p != offer_port:
			other_ports.append(p)
	other_ports.shuffle()
	var dest_port: String = other_ports[0]
	var roll := randi() % 3
	if roll == 0:
		career_state["active_mission"] = {
			"kind": "deliver",
			"destination": dest_port,
			"reward_coin": 200 + randi_range(0, 140),
			"reward_fame": 14,
			"rep_faction": sponsor_faction,
			"rep_amount": 7,
			"title": "Carry sealed dispatches to %s" % dest_port
		}
	elif roll == 1:
		var enemies: Array[String] = []
		for f in FACTION_LIST:
			if str(f) != sponsor_faction:
				enemies.append(str(f))
		enemies.shuffle()
		var victim: String = enemies[0] if not enemies.is_empty() else "English"
		career_state["active_mission"] = {
			"kind": "patrol_win",
			"victim_faction": victim,
			"reward_coin": 280 + randi_range(0, 160),
			"reward_fame": 24,
			"rep_faction": sponsor_faction,
			"rep_amount": 9,
			"title": "Letter of marque: hunt %s merchantmen" % victim
		}
	else:
		var exports_variant: Variant = PORT_EXPORT_CARGO.get(offer_port, ["Sugar", "Rum"])
		var cargo_pick := "Sugar"
		if exports_variant is Array and not (exports_variant as Array).is_empty():
			var ea: Array = exports_variant as Array
			cargo_pick = str(ea[randi() % ea.size()])
		var amt: int = 6 + randi_range(0, 7)
		var ship_dest: String = other_ports[0]
		if ship_dest == offer_port and other_ports.size() > 1:
			ship_dest = other_ports[1]
		career_state["active_mission"] = {
			"kind": "cargo_delivery",
			"cargo": cargo_pick,
			"amount": amt,
			"destination": ship_dest,
			"reward_coin": 180 + amt * 12,
			"reward_fame": 18,
			"rep_faction": sponsor_faction,
			"rep_amount": 6,
			"title": "Smuggle %d crates of %s into %s" % [amt, cargo_pick, ship_dest]
		}
	var md: Dictionary = career_state["active_mission"] as Dictionary
	active_governor_task = str(md.get("title", ""))

func _try_complete_governor_mission_on_docked(port_name: String) -> void:
	if not port_menu_active or not port_menu_docked:
		return
	if not _governor_mission_is_active():
		return
	var m: Variant = career_state.get("active_mission", {})
	if not m is Dictionary:
		return
	var md: Dictionary = m as Dictionary
	var kind: String = str(md.get("kind", ""))
	if kind == "deliver":
		if port_name == str(md.get("destination", "")):
			_pay_and_clear_governor_mission(md)
			port_menu_status_label.text = _port_docked_status_text("Dispatches delivered. Paymaster settles your share.")
	elif kind == "cargo_delivery":
		if port_name != str(md.get("destination", "")):
			return
		var cargo: String = str(md.get("cargo", ""))
		var need: int = int(md.get("amount", 0))
		var have: int = int(cargo_manifest.get(cargo, 0))
		if have < need:
			port_menu_status_label.text = _port_docked_status_text(
				"Contract open: land %d %s here (holding %d)." % [need, cargo, have]
			)
			return
		cargo_manifest[cargo] = have - need
		if int(cargo_manifest.get(cargo, 0)) <= 0:
			cargo_manifest.erase(cargo)
		ship_cargo = maxi(0, ship_cargo - need)
		_pay_and_clear_governor_mission(md)
		port_menu_status_label.text = _port_docked_status_text("Consignment landed. Bribes squared with the wharf.")

func _try_progress_governor_mission_naval_win(player_won: bool, enemy_faction: String, was_aggressor: bool) -> void:
	if not player_won or enemy_faction == "" or enemy_faction == "Unknown":
		return
	if not _governor_mission_is_active():
		return
	var m: Variant = career_state.get("active_mission", {})
	if not m is Dictionary:
		return
	var md: Dictionary = m as Dictionary
	if str(md.get("kind", "")) != "patrol_win":
		return
	if enemy_faction != str(md.get("victim_faction", "")):
		return
	if not was_aggressor:
		game_flow.post_message("Governor wanted an aggressive sweep against %s shipping, not a chance meeting." % enemy_faction)
		return
	_pay_and_clear_governor_mission(md)
	game_flow.post_message("Letter of marque satisfied: agents record your action against %s." % enemy_faction)

func _build_port_trade_rows(port_name: String) -> void:
	for row_data in port_trade_cargo_rows:
		if row_data is Dictionary:
			var row_node: HBoxContainer = row_data.get("row")
			if row_node != null and is_instance_valid(row_node):
				row_node.queue_free()
	port_trade_cargo_rows.clear()
	var cargo_list: Array = PORT_EXPORT_CARGO.get(port_name, ["Sugar", "Rum", "Tobacco"])
	for cargo_name_variant in cargo_list:
		var cargo_name := str(cargo_name_variant)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		port_trade_panel.add_child(row)
		port_trade_panel.move_child(row, 2 + port_trade_cargo_rows.size())
		var name_label := Label.new()
		var unit_px: int = _trade_unit_buy_price(port_name, cargo_name)
		name_label.text = "%s (%d ea.)" % [cargo_name, unit_px]
		name_label.custom_minimum_size = Vector2(200.0, 24.0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 20
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_port_trade_slider_changed)
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(130.0, 24.0)
		row.add_child(value_label)
		port_trade_cargo_rows.append({
			"row": row,
			"name": cargo_name,
			"name_label": name_label,
			"slider": slider,
			"value_label": value_label
		})

func _on_port_trade_slider_changed(_value: float) -> void:
	if port_trade_panel == null or not port_trade_panel.visible:
		return
	var supplies_units := int(round(port_trade_supply_slider.value))
	port_trade_supply_value_label.text = "%d units (%d pieces of eight)" % [supplies_units, supplies_units * SUPPLY_UNIT_COST]
	var cargo_units := 0
	var cargo_cost := 0
	for row_data in port_trade_cargo_rows:
		var cargo_name: String = row_data["name"]
		var slider: HSlider = row_data["slider"]
		var value_label: Label = row_data["value_label"]
		var selected_units := int(round(slider.value))
		var unit_cost: int = _trade_unit_buy_price(current_port_menu_port, cargo_name)
		value_label.text = "%d crates (%d pieces of eight)" % [selected_units, selected_units * unit_cost]
		if row_data.has("name_label"):
			var nl: Label = row_data["name_label"]
			nl.text = "%s (%d ea.)" % [cargo_name, unit_cost]
		cargo_units += selected_units
		cargo_cost += selected_units * unit_cost
	var total_cost := supplies_units * SUPPLY_UNIT_COST + cargo_cost
	port_trade_total_label.text = "Purchase: %d supply units, %d cargo crates | Total Cost: %d pieces of eight | Coin: %d pieces of eight" % [
		supplies_units,
		cargo_units,
		total_cost,
		player_piasters
	]
	port_trade_buy_button.disabled = total_cost <= 0 or total_cost > player_piasters

func _on_port_trade_buy_pressed() -> void:
	if not port_menu_active or port_menu_screen != "trade":
		return
	var supplies_units := int(round(port_trade_supply_slider.value))
	var cargo_total_units := 0
	var cargo_cost := 0
	var bought_details: Array[String] = []
	for row_data in port_trade_cargo_rows:
		var cargo_name: String = row_data["name"]
		var slider: HSlider = row_data["slider"]
		var selected_units := int(round(slider.value))
		if selected_units <= 0:
			continue
		var unit_cost: int = _trade_unit_buy_price(current_port_menu_port, cargo_name)
		cargo_cost += selected_units * unit_cost
		cargo_total_units += selected_units
		cargo_manifest[cargo_name] = int(cargo_manifest.get(cargo_name, 0)) + selected_units
		bought_details.append("%s x%d" % [cargo_name, selected_units])
	var total_cost := supplies_units * SUPPLY_UNIT_COST + cargo_cost
	if total_cost <= 0:
		port_menu_status_label.text = _port_docked_status_text("Select quantities before purchasing.")
		return
	if total_cost > player_piasters:
		port_menu_status_label.text = _port_docked_status_text("Insufficient coin for this manifest (%d pieces of eight needed)." % total_cost)
		return
	player_piasters -= total_cost
	ship_supplies += supplies_units
	ship_cargo += cargo_total_units
	_award_career_fame(10 + int(cargo_total_units * 0.5), "Port trade success")
	var details := ", ".join(bought_details) if not bought_details.is_empty() else "No cargo"
	game_flow.post_message("At %s: purchased %d supplies and cargo [%s] for %d pieces of eight." % [current_port_menu_port, supplies_units, details, total_cost])
	_return_to_port_docked_actions()
	port_menu_status_label.text = _port_docked_status_text("Trade complete.")

func _on_port_trade_cancel_pressed() -> void:
	if not port_menu_active or port_menu_screen != "trade":
		return
	_return_to_port_docked_actions()

func _on_port_hire_slider_changed(_value: float) -> void:
	if port_hire_panel == null or not port_hire_panel.visible:
		return
	var recruits := int(round(port_hire_slider.value))
	var total_cost := recruits * RECRUIT_COST
	port_hire_value_label.text = "%d hires" % recruits
	port_hire_cost_label.text = "Cost: %d pieces of eight | Coin: %d pieces of eight" % [total_cost, player_piasters]
	port_hire_confirm_button.disabled = recruits <= 0 or total_cost > player_piasters

func _on_port_hire_confirm_pressed() -> void:
	if not port_menu_active or port_menu_screen != "hire":
		return
	var recruits := int(round(port_hire_slider.value))
	var total_cost := recruits * RECRUIT_COST
	if recruits <= 0:
		port_menu_status_label.text = _port_docked_status_text("Set recruit count before hiring.")
		return
	if total_cost > player_piasters:
		port_menu_status_label.text = _port_docked_status_text("Not enough pieces of eight to hire %d recruits." % recruits)
		return
	player_piasters -= total_cost
	crew_roster_size += recruits
	_award_career_fame(8 + recruits * 2, "Expanded crew roster")
	game_flow.post_message("At %s: hired %d new pirates for %d pieces of eight." % [current_port_menu_port, recruits, total_cost])
	_return_to_port_docked_actions()
	port_menu_status_label.text = _port_docked_status_text("Recruitment complete.")

func _on_port_hire_cancel_pressed() -> void:
	if not port_menu_active or port_menu_screen != "hire":
		return
	_return_to_port_docked_actions()

func _port_docked_status_text(lead: String) -> String:
	if career_state.is_empty():
		_reset_career_state()
	var task_text := active_governor_task if active_governor_task != "" else "None"
	var cargo_lines: Array[String] = []
	for key in cargo_manifest.keys():
		var qty := int(cargo_manifest[key])
		if qty > 0:
			cargo_lines.append("%s:%d" % [str(key), qty])
	cargo_lines.sort()
	var cargo_text := ", ".join(cargo_lines) if not cargo_lines.is_empty() else "None"
	return "%s\nRank: %s | Fame: %d\nCoin: %d | Supplies: %d | Cargo: %d | Crew: %d | Governor Favor: %d | Task: %s\nManifest: %s" % [
		lead,
		str(career_state.get("rank_title", "Deckhand")),
		int(career_state.get("fame", 0)),
		player_piasters,
		ship_supplies,
		ship_cargo,
		crew_roster_size,
		governor_favor,
		task_text,
		cargo_text
	]

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
		"enemy_faction": _random_enemy_faction(),
		"player_is_aggressor": false,
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
		pending_encounter["player_is_aggressor"] = false
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
	pending_encounter["player_is_aggressor"] = true
	var chance: float = _encounter_pursuit_chance(pending_encounter)
	if randf() <= chance:
		_begin_ship_battle_from_encounter("You close the distance and force battle.")
	else:
		_finish_encounter_without_battle("The contact slips away before you can engage.")

func _on_encounter_engage_pressed() -> void:
	if pending_encounter.is_empty():
		return
	pending_encounter["player_is_aggressor"] = true
	_begin_ship_battle_from_encounter("You hoist battle colors and engage.")

func _on_main_menu_start_pressed() -> void:
	_begin_gameplay_from_main_menu()
	_reset_port_economy_state()
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
	_begin_gameplay_from_main_menu()
	if _load_game():
		main_menu_status_label.text = ""
		game_flow.post_message("Loaded saved game.")
	else:
		in_main_menu = true
		main_menu_layer.visible = true
		main_menu_status_label.text = "No save file found."

func _on_map_save_pressed() -> void:
	if game_flow.current_mode != GameFlow.Mode.WORLD_MAP:
		return
	if _save_game():
		game_flow.post_message("Game saved from the map menu.")
		_open_main_map_info("Save Game", "Game saved successfully.")
	else:
		_open_main_map_info("Save Game", "Save failed.")

func _on_map_load_pressed() -> void:
	if game_flow.current_mode != GameFlow.Mode.WORLD_MAP:
		return
	if _load_game():
		in_main_menu = false
		if main_menu_layer != null:
			main_menu_layer.visible = false
		game_flow.post_message("Game loaded from the map menu.")
		_open_main_map_info("Load Game", "Game loaded successfully.")
	else:
		_open_main_map_info("Load Game", "No save file found.")

func _on_map_captain_pressed() -> void:
	_open_main_map_info("Player / Captain", _captain_page_text())

func _on_map_crew_pressed() -> void:
	_open_main_map_info("Crew Management", _crew_management_text())

func _on_map_captains_log_pressed() -> void:
	var log_text := "\n".join(captain_log_lines)
	if log_text == "":
		log_text = "No entries yet."
	_open_main_map_info("Captain's Log", log_text)

func _on_map_port_info_pressed() -> void:
	_open_main_map_info("Port Information", _port_information_text())

func _on_map_retire_pressed() -> void:
	if game_flow.current_mode != GameFlow.Mode.WORLD_MAP:
		return
	if career_state.is_empty():
		_reset_career_state()
	var fame := int(career_state.get("fame", 0))
	var rank_title := str(career_state.get("rank_title", "Deckhand"))
	var wealth_score := int(round(float(player_piasters) * 0.25))
	var treasure_bonus := 450 if bool(career_state.get("treasure_completed", false)) else 0
	var favor_bonus := governor_favor * 18
	var total := int(CareerSystemScript.retirement_score(career_state, player_piasters)) + treasure_bonus + favor_bonus
	var legacy := "Legendary" if total >= 1600 else ("Distinguished" if total >= 1050 else ("Noted" if total >= 650 else "Obscure"))
	career_state["retired"] = true
	career_state["retirement_score"] = total
	var report := "Retirement Ledger\n\nFinal Rank: %s\nFame Score: %d\nWealth Score: %d\nTreasure Bonus: %d\nGovernor Favor Bonus: %d\nTotal Score: %d\nLegacy: %s\n\nClose this report to return to the main menu." % [
		rank_title,
		fame,
		wealth_score,
		treasure_bonus,
		favor_bonus,
		total,
		legacy
	]
	game_flow.post_message("Captain retired with a %s legacy (%d score)." % [legacy, total])
	_open_main_map_info("Retirement Complete", report, "Return to Main Menu", true)

func _captain_page_text() -> String:
	_ensure_career_state_defaults()
	var task_text := active_governor_task if active_governor_task != "" else "None"
	var rep_dict: Dictionary = _get_faction_reputation_dict_from_career()
	var rep_lines: Array[String] = []
	for faction_name in FACTION_LIST:
		rep_lines.append("%s %d" % [faction_name, int(rep_dict.get(faction_name, 0))])
	var rep_text := ", ".join(rep_lines)
	var map_name := str(career_state.get("treasure_map_name", "None"))
	var treasure_port := str(career_state.get("treasure_target_port", ""))
	var treasure_text := "Recovered" if bool(career_state.get("treasure_completed", false)) else (
		("Ready near %s" % treasure_port) if bool(career_state.get("treasure_ready", false)) and treasure_port != "" else "Not ready"
	)
	var family_stage := int(career_state.get("family_stage", 0))
	var family_rescued := bool(career_state.get("family_rescued", false))
	var family_text := "Rescued" if family_rescued else "Leads %d/4" % family_stage
	var captain_age := float(career_state.get("captain_age", 22.0))
	var aging_penalty_pct := int(round(float(career_state.get("aging_penalty", 0.0)) * 100.0))
	var morale := int(career_state.get("crew_morale", 70))
	var retirement := int(CareerSystemScript.retirement_score(career_state, player_piasters))
	return "Captain: Player Captain\nShip: %s\nCareer Rank: %s\nFame: %d\nAge: %.1f (Aging pressure: %d%%)\nCrew Morale: %d\nCoin: %d pieces of eight\nSupplies: %d\nCargo: %d crates\nCrew: %d\nGovernor Favor: %d\nFaction Reputation: %s\nCurrent Task: %s\nTreasure Map: %s\nTreasure Hunt: %s\nFamily Rescue: %s\nProjected Retirement Score: %d" % [
		world_map.ship_class,
		str(career_state.get("rank_title", "Deckhand")),
		int(career_state.get("fame", 0)),
		captain_age,
		aging_penalty_pct,
		morale,
		player_piasters,
		ship_supplies,
		ship_cargo,
		crew_roster_size,
		governor_favor,
		rep_text,
		task_text,
		map_name,
		treasure_text,
		family_text,
		retirement
	]

func _crew_management_text() -> String:
	_ensure_crew_roster()
	var lines: Array[String] = []
	lines.append("Crew Overview")
	lines.append("Total roster: %d pirates. Ship-duty specialists improve when their duty succeeds during travel, spotting, repairs, trade, or combat." % crew_roster_size)
	lines.append("")
	lines.append("Ship Duties")
	for officer in crew_officers:
		lines.append("%s - %s" % [str(officer.get("role", "Officer")), str(officer.get("name", "Unnamed"))])
		lines.append("  Stats: %s" % _stats_text(officer.get("stats", {})))
		lines.append("  Growth: %s" % str(officer.get("duty", "")))
	lines.append("")
	lines.append("Boarding Party")
	lines.append("These crew use combat stats during deck fights and can later equip improved swords, guns, and armor.")
	for crew in boarding_party_roster:
		lines.append("%s - %s" % [str(crew.get("name", "Unnamed")), str(crew.get("role", "Boarder"))])
		lines.append("  Combat: %s" % _stats_text(crew.get("stats", {})))
		lines.append("  Gear: %s" % _gear_text(crew.get("gear", {})))
	return "\n".join(lines)

func _port_information_text() -> String:
	var port_name := current_port_menu_port
	if port_name == "":
		port_name = last_arrived_port
	if port_name == "":
		port_name = world_map.target_port_name
	if port_name == "":
		return "No port selected. Click a port on the map or dock at one to review local information."
	if not world_map.ports.has(port_name):
		return "No port information available."
	var faction := _current_port_controller_faction(port_name)
	var rep_dict: Dictionary = _get_faction_reputation_dict_from_career()
	var rep_value := int(rep_dict.get(faction, 0))
	var wars_text := "None active"
	var war_src: Variant = career_state.get("active_wars", [])
	if war_src is Array and not (war_src as Array).is_empty():
		var war_parts: Array[String] = []
		for item in war_src as Array:
			if item is Dictionary:
				var wd: Dictionary = item
				war_parts.append("%s vs %s" % [str(wd.get("a", "?")), str(wd.get("b", "?"))])
		if not war_parts.is_empty():
			wars_text = ", ".join(war_parts)
	var exports: Array = []
	var export_variant: Variant = PORT_EXPORT_CARGO.get(port_name, [])
	if export_variant is Array:
		exports = export_variant
	var export_text := ", ".join(exports) if not exports.is_empty() else "Unknown"
	var status := "At sea"
	if port_menu_docked and current_port_menu_port == port_name:
		status = "Docked"
	elif current_port_menu_port == port_name:
		status = "Off the coast"
	elif last_arrived_port == port_name:
		status = "Last visited"
	return "%s\nControlling faction: %s\nFaction Reputation: %d\nRegional wars: %s\nStatus: %s\nExports: %s\n\nUse port menus to trade, recruit, petition the governor, attack, or return to sea." % [
		port_name,
		faction,
		rep_value,
		wars_text,
		status,
		export_text
	]

func _stats_text(stats: Variant) -> String:
	if not (stats is Dictionary):
		return "None"
	var parts: Array[String] = []
	for key in (stats as Dictionary).keys():
		parts.append("%s %d" % [str(key), int((stats as Dictionary)[key])])
	parts.sort()
	return ", ".join(parts)

func _gear_text(gear: Variant) -> String:
	if not (gear is Dictionary):
		return "None"
	var parts: Array[String] = []
	for key in (gear as Dictionary).keys():
		parts.append("%s: %s" % [str(key), str((gear as Dictionary)[key])])
	parts.sort()
	return ", ".join(parts)

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
	_close_port_menu()
	_close_main_map_info()
	_ensure_crew_roster()

func _reset_port_economy_state() -> void:
	player_piasters = 1800
	ship_supplies = 40
	ship_cargo = 18
	cargo_manifest.clear()
	crew_roster_size = 42
	governor_favor = 0
	active_governor_task = ""
	crew_officers.clear()
	boarding_party_roster.clear()
	_ensure_crew_roster()
	_reset_career_state()

func _reset_career_state() -> void:
	career_state = {
		"fame": 0,
		"rank_title": "Deckhand",
		"treasure_map_name": "",
		"family_stage": 0,
		"family_rescued": false,
		"treasure_target_port": "",
		"treasure_ready": false,
		"treasure_in_progress": false,
		"treasure_completed": false,
		"captain_start_age": 22.0,
		"captain_age": 22.0,
		"aging_penalty": 0.0,
		"crew_morale": 70,
		"last_pressure_month_index": world_map.game_year * 12 + world_map.game_month,
		"start_year": world_map.game_year,
		"start_month": world_map.game_month,
		"faction_reputation": {
			"Spanish": 0,
			"English": 0,
			"French": 0,
			"Dutch": 0
		},
		"port_ownership": _rebuild_port_ownership_from_world_map(),
		"active_wars": [],
		"world_politics_last_tick_month": world_map.game_year * 12 + world_map.game_month
	}
	_sync_port_ownership_to_world_map()

func _get_faction_reputation_dict_from_career() -> Dictionary:
	var v: Variant = career_state.get("faction_reputation", {})
	if v is Dictionary:
		return v as Dictionary
	return {}

func _ensure_career_state_defaults() -> void:
	if career_state.is_empty():
		_reset_career_state()
	if not career_state.has("captain_start_age"):
		career_state["captain_start_age"] = 22.0
	if not career_state.has("captain_age"):
		career_state["captain_age"] = float(career_state.get("captain_start_age", 22.0))
	if not career_state.has("aging_penalty"):
		career_state["aging_penalty"] = 0.0
	if not career_state.has("crew_morale"):
		career_state["crew_morale"] = 70
	if not career_state.has("start_year"):
		career_state["start_year"] = world_map.game_year
	if not career_state.has("start_month"):
		career_state["start_month"] = world_map.game_month
	if not career_state.has("last_pressure_month_index"):
		career_state["last_pressure_month_index"] = world_map.game_year * 12 + world_map.game_month
	if not career_state.has("faction_reputation"):
		career_state["faction_reputation"] = {}
	var rep_base: Dictionary = _get_faction_reputation_dict_from_career()
	var copy_rep: Dictionary = rep_base.duplicate(true)
	for faction_name in FACTION_LIST:
		if not copy_rep.has(faction_name):
			copy_rep[faction_name] = 0
	career_state["faction_reputation"] = copy_rep
	var po_variant: Variant = career_state.get("port_ownership", {})
	if not po_variant is Dictionary or (po_variant as Dictionary).is_empty():
		career_state["port_ownership"] = _rebuild_port_ownership_from_world_map()
	else:
		var po: Dictionary = (po_variant as Dictionary).duplicate(true)
		var rebuilt: Dictionary = _rebuild_port_ownership_from_world_map()
		for pname in rebuilt.keys():
			if not po.has(pname):
				po[pname] = rebuilt[pname]
		career_state["port_ownership"] = po
	if not career_state.has("active_wars") or not (career_state.get("active_wars") is Array):
		career_state["active_wars"] = []
	if not career_state.has("world_politics_last_tick_month"):
		career_state["world_politics_last_tick_month"] = world_map.game_year * 12 + world_map.game_month
	_ensure_market_quotes_defaults()
	_sync_port_ownership_to_world_map()

func _rebuild_port_ownership_from_world_map() -> Dictionary:
	var out: Dictionary = {}
	for port_name in world_map.ports.keys():
		var data_variant: Variant = world_map.ports[port_name]
		if data_variant is Dictionary:
			var pdata: Dictionary = data_variant
			if pdata.has("faction"):
				out[port_name] = str(pdata["faction"])
	return out

func _sync_port_ownership_to_world_map() -> void:
	if world_map == null:
		return
	var po_variant: Variant = career_state.get("port_ownership", {})
	if po_variant is Dictionary:
		world_map.set_port_owner_overrides(po_variant as Dictionary)

func _current_port_controller_faction(port_name: String) -> String:
	_ensure_career_state_defaults()
	var owners: Variant = career_state.get("port_ownership", {})
	if owners is Dictionary and (owners as Dictionary).has(port_name):
		return str((owners as Dictionary)[port_name])
	if world_map.ports.has(port_name):
		var pdata: Variant = world_map.ports[port_name]
		if pdata is Dictionary:
			return str((pdata as Dictionary).get("faction", "Unknown"))
	return "Unknown"

func _faction_pair_at_war(wars: Array, a: String, b: String) -> bool:
	for w in wars:
		if not w is Dictionary:
			continue
		var d: Dictionary = w as Dictionary
		var x := str(d.get("a", ""))
		var y := str(d.get("b", ""))
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false

func _roll_new_war_pair(existing: Array) -> Array:
	for _t in range(24):
		var fa: Array = FACTION_LIST.duplicate()
		fa.shuffle()
		var a := str(fa[0])
		var b := str(fa[1])
		if a == b:
			continue
		if _faction_pair_at_war(existing, a, b):
			continue
		return [a, b]
	return []

func _maybe_flip_port_from_war(wars: Array, owners: Dictionary) -> String:
	if wars.is_empty():
		return ""
	var w: Dictionary = wars[randi_range(0, wars.size() - 1)]
	var fa := str(w.get("a", ""))
	var fb := str(w.get("b", ""))
	if fa == "" or fb == "":
		return ""
	var port_names: Array[String] = world_map.get_port_names()
	port_names.shuffle()
	for port_name in port_names:
		var cur := str(owners.get(port_name, ""))
		if cur != fa and cur != fb:
			continue
		var attacker := fb if cur == fa else fa
		if randf() > 0.32:
			return ""
		owners[port_name] = attacker
		_apply_faction_reputation_delta(attacker, 3, "news: colors over %s" % port_name)
		_apply_faction_reputation_delta(cur, -4, "news: lost influence at %s" % port_name)
		return "Rumors say %s now answers to %s governors (war in the settlements)." % [port_name, attacker]
	return ""

func _roll_world_politics_pulse() -> void:
	_ensure_career_state_defaults()
	var po_v: Variant = career_state.get("port_ownership", {})
	var owners: Dictionary = (po_v as Dictionary).duplicate(true) if po_v is Dictionary else _rebuild_port_ownership_from_world_map()
	var wars: Array = []
	var war_src: Variant = career_state.get("active_wars", [])
	if war_src is Array:
		for item in war_src as Array:
			if item is Dictionary:
				wars.append((item as Dictionary).duplicate(true))
	var lines: Array[String] = []
	if wars.size() < 3 and randf() < 0.12:
		var pair: Array = _roll_new_war_pair(wars)
		if pair.size() == 2:
			wars.append({"a": str(pair[0]), "b": str(pair[1])})
			lines.append("War spreads: %s and %s are raiding each other's flags." % [str(pair[0]), str(pair[1])])
	if wars.size() > 0 and randf() < 0.09:
		var idx := randi_range(0, wars.size() - 1)
		var ended_v: Variant = wars[idx]
		wars.remove_at(idx)
		if ended_v is Dictionary:
			var ended: Dictionary = ended_v as Dictionary
			lines.append("Treaty: %s and %s sue for peace (for now)." % [str(ended.get("a", "?")), str(ended.get("b", "?"))])
	if wars.size() > 0 and randf() < 0.14:
		var flip_line := _maybe_flip_port_from_war(wars, owners)
		if flip_line != "":
			lines.append(flip_line)
	career_state["active_wars"] = wars
	career_state["port_ownership"] = owners
	_sync_port_ownership_to_world_map()
	for line in lines:
		game_flow.post_message(line)

func _tick_world_politics_if_due(month_index: int) -> void:
	_ensure_career_state_defaults()
	var last_tick := int(career_state.get("world_politics_last_tick_month", month_index))
	if month_index < last_tick:
		career_state["world_politics_last_tick_month"] = month_index
		return
	var max_pulses := 2
	var pulses := 0
	while month_index - last_tick >= WORLD_POLITICS_INTERVAL_MONTHS and pulses < max_pulses:
		last_tick += WORLD_POLITICS_INTERVAL_MONTHS
		_roll_world_politics_pulse()
		pulses += 1
	if last_tick > month_index:
		last_tick = month_index
	career_state["world_politics_last_tick_month"] = last_tick

func _on_world_map_month_advanced(month_index: int) -> void:
	if in_main_menu:
		return
	_tick_world_politics_if_due(month_index)
	_tick_port_markets_for_month()

func _award_career_fame(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	_ensure_career_state_defaults()
	var aging_penalty: float = clampf(float(career_state.get("aging_penalty", 0.0)), 0.0, 0.45)
	var morale_factor: float = clampf(0.7 + (float(int(career_state.get("crew_morale", 70))) / 100.0) * 0.5, 0.7, 1.2)
	var adjusted_amount: int = maxi(1, int(round(float(amount) * (1.0 - aging_penalty) * morale_factor)))
	var new_fame: int = int(career_state.get("fame", 0)) + adjusted_amount
	career_state["fame"] = new_fame
	var prior_rank: String = str(career_state.get("rank_title", "Deckhand"))
	var new_rank: String = str(CareerSystemScript.rank_for_fame(new_fame))
	career_state["rank_title"] = new_rank
	game_flow.post_message("Career: +%d fame (%s)." % [adjusted_amount, reason])
	if new_rank != prior_rank:
		game_flow.post_message("Promotion earned: %s." % new_rank)

func _try_award_map_fragment(chance: float, source_text: String = "Treasure map recovered") -> void:
	if chance <= 0.0 or randf() > chance:
		return
	if career_state.is_empty():
		_reset_career_state()
	if bool(career_state.get("treasure_ready", false)) or bool(career_state.get("treasure_in_progress", false)):
		return
	var map_name := "Admiral's Coded Chart"
	career_state["treasure_map_name"] = map_name
	_assign_treasure_hunt_destination()
	_award_career_fame(24, "Recovered complete treasure map")
	var treasure_port := str(career_state.get("treasure_target_port", "unknown waters"))
	game_flow.post_message("%s: %s. The chart points to hidden treasure near %s." % [source_text, map_name, treasure_port])

func _advance_family_rescue_progress(source_text: String) -> void:
	if career_state.is_empty():
		_reset_career_state()
	if bool(career_state.get("family_rescued", false)):
		return
	var stage := int(career_state.get("family_stage", 0))
	if stage >= 4:
		career_state["family_rescued"] = true
		_award_career_fame(120, "Family rescued")
		active_governor_task = "Family reunited"
		game_flow.post_message("Major milestone: your missing family has been rescued.")
		return
	stage += 1
	career_state["family_stage"] = stage
	_award_career_fame(22, "Family rescue lead")
	var stage_text := "Lead %d/4 toward family rescue." % stage
	game_flow.post_message("%s %s" % [source_text, stage_text])

func _update_aging_and_career_pressure() -> void:
	_ensure_career_state_defaults()
	var month_index: int = world_map.game_year * 12 + world_map.game_month
	var start_year: int = int(career_state.get("start_year", world_map.game_year))
	var start_month: int = int(career_state.get("start_month", world_map.game_month))
	var elapsed_months: int = maxi(0, month_index - (start_year * 12 + start_month))
	var base_age: float = float(career_state.get("captain_start_age", 22.0))
	var captain_age: float = base_age + (float(elapsed_months) / 12.0)
	career_state["captain_age"] = captain_age
	var penalty: float = clampf((captain_age - 36.0) / 40.0, 0.0, 0.45)
	career_state["aging_penalty"] = penalty

	var last_pressure_index: int = int(career_state.get("last_pressure_month_index", month_index))
	if month_index <= last_pressure_index:
		return
	var months_due: int = month_index - last_pressure_index
	var morale: int = int(career_state.get("crew_morale", 70))
	for _i in range(months_due):
		var monthly_wage: int = 35 + int(round(float(crew_roster_size) * 1.8))
		if player_piasters >= monthly_wage:
			player_piasters -= monthly_wage
			morale = mini(100, morale + 1)
		else:
			var missing: int = monthly_wage - player_piasters
			player_piasters = 0
			morale = maxi(0, morale - 6)
			if morale <= 24 and crew_roster_size > 12:
				crew_roster_size = maxi(12, crew_roster_size - 1)
				game_flow.post_message("Career pressure: one pirate deserted over unpaid shares.")
			career_state["fame"] = maxi(0, int(career_state.get("fame", 0)) - 2)
			game_flow.post_message("Career pressure: unpaid wages short by %d pieces of eight hurt morale." % missing)
	career_state["crew_morale"] = morale
	career_state["last_pressure_month_index"] = month_index
	if months_due > 0:
		game_flow.post_message("Monthly crew payroll settled for %d month(s). Morale now %d." % [months_due, morale])

func _random_enemy_faction() -> String:
	var candidates: Array = FACTION_LIST.duplicate()
	candidates.shuffle()
	return str(candidates[0])

func _apply_faction_reputation_delta(faction: String, delta: int, reason: String) -> void:
	if faction == "" or delta == 0:
		return
	_ensure_career_state_defaults()
	var rep_dict: Dictionary = _get_faction_reputation_dict_from_career()
	var current_value := int(rep_dict.get(faction, 0))
	var next_value := clampi(current_value + delta, -100, 100)
	rep_dict[faction] = next_value
	career_state["faction_reputation"] = rep_dict
	var delta_text := "+%d" % delta if delta > 0 else str(delta)
	game_flow.post_message("Faction reputation (%s): %s (%s). New standing %d." % [faction, delta_text, reason, next_value])

func _apply_ship_battle_faction_reputation(player_won: bool) -> void:
	var enemy_faction := last_ship_battle_enemy_faction
	if enemy_faction == "" or enemy_faction == "Unknown":
		return
	if last_ship_battle_player_aggressor:
		_apply_faction_reputation_delta(enemy_faction, -12, "attacked their shipping")
		if player_won:
			_apply_faction_reputation_delta(enemy_faction, -6, "sank or captured their ship")
	else:
		if player_won:
			_apply_faction_reputation_delta(enemy_faction, -3, "defeated one of their captains in self-defense")
			for faction_name in FACTION_LIST:
				if faction_name == enemy_faction:
					continue
				_apply_faction_reputation_delta(faction_name, 2, "eliminated a hostile raider")

func _can_launch_treasure_at_port(port_name: String) -> bool:
	if port_name == "":
		return false
	if career_state.is_empty():
		_reset_career_state()
	if bool(career_state.get("treasure_completed", false)):
		return false
	return bool(career_state.get("treasure_ready", false)) and str(career_state.get("treasure_target_port", "")) == port_name

func _assign_treasure_hunt_destination() -> void:
	if career_state.is_empty():
		_reset_career_state()
	var port_names: Array[String] = world_map.get_port_names()
	if port_names.is_empty():
		return
	port_names.shuffle()
	var chosen_port := port_names[0]
	career_state["treasure_target_port"] = chosen_port
	career_state["treasure_ready"] = true
	career_state["treasure_in_progress"] = false
	career_state["treasure_completed"] = false
	active_governor_task = "Treasure map assembled - search near %s" % chosen_port

func _launch_treasure_expedition(port_name: String) -> void:
	if not _can_launch_treasure_at_port(port_name):
		return
	career_state["treasure_in_progress"] = true
	_close_port_menu()
	last_arrived_port = port_name
	can_start_town_assault = true
	game_flow.post_message("Launching treasure expedition near %s. Secure the site." % port_name)
	_start_town_assault_demo()

func _resolve_treasure_expedition_success() -> void:
	if career_state.is_empty():
		_reset_career_state()
	career_state["treasure_in_progress"] = false
	career_state["treasure_ready"] = false
	career_state["treasure_completed"] = true
	career_state["treasure_target_port"] = ""
	career_state["treasure_map_name"] = ""
	var reward := randi_range(900, 1800)
	player_piasters += reward
	_award_career_fame(95, "Treasure expedition success")
	active_governor_task = "Treasure recovered"
	game_flow.post_message("Treasure secured: %d pieces of eight recovered from the hidden cache." % reward)

func _ensure_crew_roster() -> void:
	if crew_officers.is_empty():
		crew_officers = [
			{"role": "Pilot / Navigator", "name": "Elias Reed", "stats": {"Navigation": 3, "Charting": 2, "Weather Eye": 2}, "duty": "Raises Navigation by completing voyages, evasive maneuvers, and landfall approaches."},
			{"role": "Crow's Nest / Spotter", "name": "Mara Finch", "stats": {"Spotting": 3, "Signals": 2, "Night Watch": 1}, "duty": "Raises Spotting by detecting sails, reefs, and ambushes before they close."},
			{"role": "Quartermaster", "name": "Tom Vane", "stats": {"Rationing": 3, "Morale": 2, "Discipline": 2}, "duty": "Raises Rationing and Morale by keeping supplies stable and prize shares fair."},
			{"role": "Boatswain", "name": "Anne Pike", "stats": {"Rigging": 3, "Deck Drill": 2, "Repairs": 1}, "duty": "Raises Rigging through sail handling, storm work, and fast combat maneuvers."},
			{"role": "Master Gunner", "name": "Silas Crowe", "stats": {"Gunnery": 3, "Reload Drill": 2, "Powder Safety": 2}, "duty": "Raises Gunnery by firing broadsides, conserving powder, and drilling crews."},
			{"role": "Carpenter", "name": "Bea Hull", "stats": {"Carpentry": 3, "Patching": 2, "Salvage": 1}, "duty": "Raises Carpentry by repairing battle damage and keeping the hull seaworthy."},
			{"role": "Ship Doctor", "name": "Dr. Iris Fen", "stats": {"Medicine": 3, "Surgery": 2, "Recovery": 2}, "duty": "Raises Medicine by treating battle wounds, disease, and long-voyage exhaustion among the crew."}
		]
	if boarding_party_roster.is_empty():
		boarding_party_roster = [
			{"name": "Mateo Cruz", "role": "Cutlass Lead", "stats": {"Melee": 3, "Pistol": 2, "Grit": 3}, "gear": {"Melee": "Balanced cutlass", "Ranged": "Sea-service pistol", "Armor": "Leather jerkin"}},
			{"name": "Ivy Marsh", "role": "Pistolier", "stats": {"Melee": 2, "Pistol": 3, "Grit": 2}, "gear": {"Melee": "Boarding axe", "Ranged": "Pair of pistols", "Armor": "Heavy coat"}},
			{"name": "Jonah Flint", "role": "Breacher", "stats": {"Melee": 3, "Pistol": 1, "Grit": 4}, "gear": {"Melee": "Boarding axe", "Ranged": "Blunderbuss", "Armor": "Padded vest"}},
			{"name": "Nell Sharp", "role": "Skirmisher", "stats": {"Melee": 2, "Pistol": 3, "Grit": 2}, "gear": {"Melee": "Short sword", "Ranged": "Long pistol", "Armor": "Sash and coat"}}
		]

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
	last_ship_battle_enemy_faction = str(context.get("enemy_faction", "Unknown"))
	last_ship_battle_player_aggressor = bool(context.get("player_is_aggressor", false))
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
		"player_piasters": player_piasters,
		"ship_supplies": ship_supplies,
		"ship_cargo": ship_cargo,
		"cargo_manifest": cargo_manifest,
		"crew_roster_size": crew_roster_size,
		"crew_officers": crew_officers,
		"boarding_party_roster": boarding_party_roster,
		"governor_favor": governor_favor,
		"active_governor_task": active_governor_task,
		"career_state": career_state,
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
	if data.has("player_piasters"):
		player_piasters = int(data["player_piasters"])
	if data.has("ship_supplies"):
		ship_supplies = int(data["ship_supplies"])
	if data.has("ship_cargo"):
		ship_cargo = int(data["ship_cargo"])
	if data.has("cargo_manifest") and data["cargo_manifest"] is Dictionary:
		cargo_manifest = (data["cargo_manifest"] as Dictionary).duplicate(true)
	if data.has("crew_roster_size"):
		crew_roster_size = int(data["crew_roster_size"])
	if data.has("crew_officers") and data["crew_officers"] is Array:
		crew_officers.clear()
		for item in data["crew_officers"]:
			if item is Dictionary:
				crew_officers.append((item as Dictionary).duplicate(true))
	if data.has("boarding_party_roster") and data["boarding_party_roster"] is Array:
		boarding_party_roster.clear()
		for item in data["boarding_party_roster"]:
			if item is Dictionary:
				boarding_party_roster.append((item as Dictionary).duplicate(true))
	_ensure_crew_roster()
	if data.has("governor_favor"):
		governor_favor = int(data["governor_favor"])
	if data.has("active_governor_task"):
		active_governor_task = str(data["active_governor_task"])
	if data.has("career_state") and data["career_state"] is Dictionary:
		career_state = (data["career_state"] as Dictionary).duplicate(true)
		if not career_state.has("treasure_map_name"):
			career_state["treasure_map_name"] = ""
		if career_state.has("map_fragments"):
			career_state.erase("map_fragments")
	else:
		_reset_career_state()
	_ensure_career_state_defaults()
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

func _on_time_scale_selected(time_scale: float) -> void:
	world_map.set_time_scale(time_scale)
	for key in time_buttons.keys():
		var button: Button = time_buttons[key]
		button.button_pressed = int(key) == int(time_scale)

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

	if left_sidebar_menu_box != null:
		left_sidebar_menu_box.position = Vector2(12.0, 52.0)
		left_sidebar_menu_box.size = Vector2(maxf(80.0, sidebar_width - 24.0), maxf(80.0, map_height - 64.0))

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

	if main_map_info_overlay != null:
		main_map_info_overlay.position = Vector2.ZERO
		main_map_info_overlay.size = viewport_size

	if main_map_info_panel != null:
		var panel_width: float = minf(700.0, maxf(320.0, viewport_size.x - sidebar_width - 48.0))
		var panel_height: float = minf(520.0, maxf(280.0, map_height - 36.0))
		main_map_info_panel.custom_minimum_size = Vector2(panel_width, panel_height)
		main_map_info_panel.size = main_map_info_panel.custom_minimum_size
		main_map_info_panel.position = Vector2(
			sidebar_width + ((viewport_size.x - sidebar_width) - main_map_info_panel.size.x) * 0.5,
			maxf(18.0, (map_height - main_map_info_panel.size.y) * 0.5)
		)
		if main_map_info_text_label != null:
			main_map_info_text_label.custom_minimum_size = Vector2(panel_width - 40.0, maxf(160.0, panel_height - 118.0))
		if main_map_info_x_button != null:
			main_map_info_x_button.position = Vector2(main_map_info_panel.size.x - 38.0, 8.0)

	if port_menu_layer != null and port_menu_layer.get_child_count() > 0:
		var menu_overlay: Node = port_menu_layer.get_child(0)
		if menu_overlay is ColorRect:
			var overlay_rect: ColorRect = menu_overlay
			overlay_rect.position = Vector2.ZERO
			overlay_rect.size = viewport_size

	if port_menu_panel != null:
		port_menu_panel.custom_minimum_size = Vector2(620.0, 500.0)
		port_menu_panel.size = port_menu_panel.custom_minimum_size
		port_menu_panel.position = Vector2(
			sidebar_width + ((viewport_size.x - sidebar_width) - port_menu_panel.size.x) * 0.5,
			maxf(18.0, map_height * 0.08)
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
