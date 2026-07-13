extends Node2D
class_name LegacyCombatRendererV2

var game: Node2D # Reference to game.gd
var ship_battle: LegacyShipBattle
var tactical_combat: TacticalCombatSystem
var grid: BattleGrid

func _init(p_game: Node2D) -> void:
	game = p_game
	ship_battle = game.ship_battle
	tactical_combat = game.tactical_combat
	grid = game.grid

func draw_ship_combat(ci: CanvasItem, viewport_size: Vector2) -> void:
	var layout: Dictionary = game._ship_combat_layout(viewport_size)
	var hud_rect: Rect2 = layout["hud_rect"]
	var combat_rect: Rect2 = layout["combat_rect"]
	var options_rect: Rect2 = layout["options_rect"]
	var grid_arena_rect: Rect2 = layout["grid_arena_rect"]
	var nav_dims: Vector2i = game._naval_combat_view_dims()
	var nav_vc: int = nav_dims.x
	var nav_vr: int = nav_dims.y
	var base_grid_rect: Rect2 = game._naval_grid_rect(grid_arena_rect, nav_vc, nav_vr)
	var grid_rect: Rect2 = game._ship_combat_view_rect(base_grid_rect)
	var nav_view_origin: Vector2 = game._ship_nav_view_origin(nav_vc, nav_vr)
	
	ci.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.08, 0.14, 0.2), true)
	ci.draw_rect(Rect2(Vector2(0.0, viewport_size.y * 0.62), Vector2(viewport_size.x, viewport_size.y * 0.38)), Color(0.06, 0.11, 0.18), true)
	ci.draw_rect(hud_rect, Color(0.02, 0.06, 0.1, 0.45), true)
	ci.draw_rect(combat_rect, Color(0.08, 0.16, 0.25, 0.45), false, 2.0)
	
	game._draw_naval_movement_water_background(grid_rect)
	game._draw_naval_battlefield_grid(grid_rect, nav_view_origin, nav_vc, nav_vr)
	_draw_ship_hazards(ci, grid_rect, nav_view_origin, nav_vc, nav_vr)
	
	if game.ship_combat_range_highlight >= 0:
		_draw_ship_gun_range_overlay(ci, grid_rect, nav_view_origin, nav_vc, nav_vr, game.ship_combat_range_highlight)
	
	if game.ship_battle.phase == LegacyShipBattle.Phase.PLANNING:
		_draw_ship_movement_preview(ci, grid_rect, nav_view_origin, nav_vc, nav_vr)
	
	_draw_ship_action_panel(ci, options_rect)
	
	var p_cell: Vector2 = game.ship_battle.get_player_display_cell_pos()
	var p_hdg: float = game.ship_battle.get_player_display_heading_deg()
	var e_cell: Vector2 = game.ship_battle.get_enemy_display_cell_pos()
	var e_hdg: float = game.ship_battle.get_enemy_display_heading_deg()
	
	var showing_plan_ghost: bool = (
		game.ship_battle.phase == LegacyShipBattle.Phase.PLANNING
		and game.ship_battle.is_player_movement_plotted()
	)
	
	if showing_plan_ghost:
		_cr_draw_ship_path(ci, grid_rect, nav_view_origin, nav_vc, nav_vr, game.ship_battle.get_player_plan_preview_path(), Color(0.92, 0.82, 0.45, 0.55), 2.0)
		
	if game.ship_battle.phase == LegacyShipBattle.Phase.MOVE_ANIM:
		var anim_side: String = game.ship_battle.get_active_move_anim_side()
		if anim_side == "player":
			_cr_draw_ship_path(ci, grid_rect, nav_view_origin, nav_vc, nav_vr, game.ship_battle.player_round_path, Color(0.55, 0.88, 1.0, 0.45), 2.5)
		elif anim_side == "enemy":
			_cr_draw_ship_path(ci, grid_rect, nav_view_origin, nav_vc, nav_vr, game.ship_battle.enemy_round_path, Color(1.0, 0.62, 0.42, 0.45), 2.5)

	var cc: int = game.ship_battle.combat_cols
	var rr: int = game.ship_battle.combat_rows
	var player_center: Vector2 = game._combat_to_screen(game._naval_combat_cell_pos_to_screen_norm(p_cell, cc, rr), grid_rect, cc, rr, nav_view_origin, nav_vc, nav_vr)
	var enemy_center: Vector2 = game._combat_to_screen(game._naval_combat_cell_pos_to_screen_norm(e_cell, cc, rr), grid_rect, cc, rr, nav_view_origin, nav_vc, nav_vr)
	var ship_cell_size: float = minf(grid_rect.size.x / float(nav_vc), grid_rect.size.y / float(nav_vr))
	
	var pr: int = game.ship_battle.get_player_port_cannon_reload_turns_remaining()
	var ps: int = game.ship_battle.get_player_starboard_cannon_reload_turns_remaining()
	var er: int = game.ship_battle.get_enemy_port_cannon_reload_turns_remaining()
	var es: int = game.ship_battle.get_enemy_starboard_cannon_reload_turns_remaining()
	
	_draw_ship_silhouette(ci, player_center, game.ship_battle.player_ship_class, p_hdg, Color(0.58, 0.44, 0.29), ship_cell_size, 1.0)
	if showing_plan_ghost:
		var ghost_center: Vector2 = game._combat_to_screen(game._naval_combat_cell_pos_to_screen_norm(game.ship_battle.player_plan_end_pos, cc, rr), grid_rect, cc, rr, nav_view_origin, nav_vc, nav_vr)
		_draw_ship_silhouette(ci, ghost_center, game.ship_battle.player_ship_class, game.ship_battle.player_plan_end_heading, Color(0.58, 0.44, 0.29), ship_cell_size, 0.38)
	_draw_ship_silhouette(ci, enemy_center, game.ship_battle.enemy_ship_class, e_hdg, Color(0.46, 0.33, 0.22), ship_cell_size, 1.0)

	# HUD Text
	var left_x: float = hud_rect.position.x + 18.0
	var middle_x: float = hud_rect.position.x + hud_rect.size.x * 0.43
	var right_limit_x: float = hud_rect.position.x + hud_rect.size.x - 20.0
	var player_hull_max: int = game.ship_battle.get_ship_max_hull(game.ship_battle.player_ship_class)
	var player_line := "Player Hull: %d/%d  Crew: %d (roster %d)" % [game.ship_battle.player_hull, player_hull_max, game.ship_battle.player_crew, game.crew_roster_size]
	var enemy_line := "Enemy Hull: %d  Crew: %d" % [game.ship_battle.enemy_hull, game.ship_battle.enemy_crew]
	ci.draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 26.0), player_line, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 20)
	ci.draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 52.0), enemy_line, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 20)

	var phase_text := "Phase: Your turn \u2014 plan orders"
	if game.ship_battle.phase == LegacyShipBattle.Phase.MOVE_ANIM:
		var anim_side: String = game.ship_battle.get_active_move_anim_side()
		phase_text = "Phase: " + ("Enemy" if anim_side == "enemy" else "Your") + " turn \u2014 executing"
	elif game.ship_battle.phase == LegacyShipBattle.Phase.RESOLVED:
		phase_text = "Phase: Resolved"
	ci.draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 26.0), phase_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 20)
	
	var mp_text := "Movement Points - You: %d | Enemy: %d" % [game.ship_battle.player_move_points, game.ship_battle.enemy_move_points]
	ci.draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 52.0), mp_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 18)
	
	var gun_reload_text := "Guns P/S \u2014 You: %s/%s  Enemy: %s/%s" % [
		game._gun_reload_hud_token(pr), game._gun_reload_hud_token(ps),
		game._gun_reload_hud_token(er), game._gun_reload_hud_token(es)
	]
	ci.draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 76.0), gun_reload_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 16)
	
	if game.ship_move_selected_cell.x >= 0 and game.ship_move_selected_heading_idx >= 0:
		var face_label: String = game.SHIP_HEADING_LABELS[posmod(game.ship_move_selected_heading_idx, 8)]
		var sel_text := "Move plan: (%d,%d) facing %s  Enter to set" % [game.ship_move_selected_cell.x, game.ship_move_selected_cell.y, face_label]
		ci.draw_string(ThemeDB.fallback_font, Vector2(middle_x, hud_rect.position.y + 100.0), sel_text, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - middle_x, 18)
	
	if game.ship_combat_range_highlight >= 0:
		var range_label: String = "Port" if game.ship_combat_range_highlight == 0 else "Starboard"
		ci.draw_string(ThemeDB.fallback_font, Vector2(left_x, hud_rect.position.y + 78.0), "Range highlight: %s \u2014 Fire Cannons to shoot" % range_label, HORIZONTAL_ALIGNMENT_LEFT, right_limit_x - left_x, 16)

func draw_boarding_combat(ci: CanvasItem) -> void:
	game._draw_boarding_deck_surface(ci)
	game._draw_boarding_units_overlay(ci)
	_draw_boarding_crew_cards(ci)
	var panel_rect: Rect2 = game._boarding_action_panel_rect()
	_draw_boarding_action_panel(ci, panel_rect)

func _draw_boarding_crew_cards(ci: CanvasItem) -> void:
	if game.game_flow.current_mode != GameLogicState.Mode.TACTICAL_COMBAT:
		return
	if game.game_flow.tactical_type != GameLogicState.TacticalType.BOARDING:
		return
	if game.units.is_empty() or game.boarding_initiative_order.is_empty():
		return
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var metrics: Dictionary = game._ui_metrics(viewport_size)
	var sidebar_width: float = float(metrics["sidebar_width"])
	var map_height: float = float(metrics["map_height"])
	var panel_rect: Rect2 = game._boarding_action_panel_rect()
	var start_x: float = sidebar_width + 14.0
	var available_w: float = maxf(160.0, panel_rect.position.x - 12.0 - start_x)
	var card_gap: float = 8.0
	var ordered_units: Array[CombatUnit] = game._boarding_turn_sequence_units()
	var card_w: float = clampf((available_w - card_gap * float(max(0, ordered_units.size() - 1))) / float(max(1, ordered_units.size())), 64.0, 104.0)
	var card_h: float = 64.0
	var y: float = minf(map_height - card_h - 12.0, 16.0)
	var actor: CombatUnit = game._current_boarding_actor()
	for idx in range(ordered_units.size()):
		var unit: CombatUnit = ordered_units[idx]
		var x: float = start_x + float(idx) * (card_w + card_gap)
		var card: Rect2 = Rect2(Vector2(x, y), Vector2(card_w, card_h))
		var is_active: bool = unit == actor
		var bg: Color = Color(0.1, 0.22, 0.35, 0.9) if unit.team == CombatTurnManager.Team.PLAYER else Color(0.35, 0.13, 0.11, 0.9)
		if unit.has_acted:
			bg = bg.darkened(0.28)
		ci.draw_rect(card, bg, true)
		ci.draw_rect(card, Color(1.0, 0.88, 0.48, 0.95) if is_active else Color(0.72, 0.82, 0.9, 0.6), false, 2.0)
		ci.draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 19.0), "Crew %s" % game._crew_label(unit), HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 14)
		ci.draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 37.0), "HP %d" % unit.hp, HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13)
		ci.draw_string(ThemeDB.fallback_font, card.position + Vector2(8.0, 54.0), "Turn %d" % (idx + 1), HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13)


func _cr_draw_ship_path(ci: CanvasItem, grid_rect: Rect2, view_origin: Vector2, view_cols: int, view_rows: int, path: Array[Dictionary], color: Color, width: float) -> void:
	if path.size() < 2: return
	var pts := PackedVector2Array()
	var cc: int = game.ship_battle.combat_cols
	var rr: int = game.ship_battle.combat_rows
	for step in path:
		var pos: Vector2 = step["pos"] as Vector2
		var n: Vector2 = game._naval_combat_cell_pos_to_screen_norm(pos, cc, rr)
		pts.append(game._combat_to_screen(n, grid_rect, cc, rr, view_origin, view_cols, view_rows))
	ci.draw_polyline(pts, color, width)

func _draw_ship_silhouette(ci: CanvasItem, center: Vector2, ship_class: String, heading_deg: float, hull_color: Color, cell_size: float = 0.0, alpha_mult: float = 1.0) -> void:
	var length_cells: float = float(game.ship_battle.get_ship_length_cells(ship_class))
	var width_cells: float = float(game.ship_battle.get_ship_width_cells(ship_class))
	var draw_scale: float = game._ship_draw_scale(ship_class)
	var hull_length: float = 260.0 * draw_scale
	var hull_beam: float = 48.0 * draw_scale
	if cell_size > 0.0:
		hull_length = maxf(length_cells * cell_size, 36.0)
		hull_beam = maxf(width_cells * cell_size, 12.0)
	var am: float = clampf(alpha_mult, 0.0, 1.0)
	var hull_fill: Color = Color(hull_color.r, hull_color.g, hull_color.b, hull_color.a * am)
	var heading_rad: float = deg_to_rad(90.0 - heading_deg)
	var basis := Transform2D(heading_rad, center)
	var half_length: float = hull_length * 0.5
	var half_beam: float = hull_beam * 0.5
	var hull_local := PackedVector2Array([
		Vector2(-half_length, half_beam * 0.42),
		Vector2(-half_length * 0.55, -half_beam * 0.62),
		Vector2(half_length * 0.42, -half_beam * 0.72),
		Vector2(half_length, 0.0),
		Vector2(half_length * 0.42, half_beam * 0.72),
		Vector2(-half_length * 0.72, half_beam * 0.62)
	])
	var hull := PackedVector2Array()
	for p in hull_local: hull.append(basis * p)
	ci.draw_colored_polygon(hull, hull_fill)
	ci.draw_polyline(hull, Color(0.18, 0.12, 0.07, 0.55 * am + 0.15 * (1.0 - am)), 2.0, true)

	var sail_color := Color(0.9, 0.89, 0.82, 0.9 * am)
	if ship_class == "Sloop":
		var mast_x: float = -half_length * 0.08
		var mast_height: float = maxf(hull_beam * 3.0, 38.0 * draw_scale)
		ci.draw_line(basis * Vector2(mast_x, half_beam * 0.2), basis * Vector2(mast_x, -mast_height), Color(0.86, 0.8, 0.65, 0.55 + 0.45 * am), 3.0)
		var main_sail := PackedVector2Array([basis * Vector2(mast_x, -mast_height * 0.88), basis * Vector2(mast_x + half_length * 0.58, -mast_height * 0.42), basis * Vector2(mast_x, -half_beam * 0.35)])
		var jib := PackedVector2Array([basis * Vector2(mast_x + half_length * 0.08, -mast_height * 0.48), basis * Vector2(half_length * 0.88, -half_beam * 0.12), basis * Vector2(mast_x + half_length * 0.08, -half_beam * 0.38)])
		ci.draw_colored_polygon(main_sail, sail_color)
		ci.draw_colored_polygon(jib, Color(0.92, 0.91, 0.84, 0.86 * am))
	else:
		var mast1_x: float = -half_length * 0.18
		var mast2_x: float = half_length * 0.18
		var mast_height_1: float = maxf(hull_beam * 3.0, 42.0 * draw_scale)
		var mast_height_2: float = maxf(hull_beam * 2.4, 34.0 * draw_scale)
		ci.draw_line(basis * Vector2(mast1_x, half_beam * 0.35), basis * Vector2(mast1_x, -mast_height_1), Color(0.86, 0.8, 0.65, 0.55 + 0.45 * am), 3.0)
		ci.draw_line(basis * Vector2(mast2_x, half_beam * 0.35), basis * Vector2(mast2_x, -mast_height_2), Color(0.86, 0.8, 0.65, 0.55 + 0.45 * am), 3.0)
		var fore_sail := PackedVector2Array([basis * Vector2(mast2_x, -mast_height_2 * 0.9), basis * Vector2(mast2_x + half_length * 0.28, -mast_height_2 * 0.42), basis * Vector2(mast2_x, -half_beam * 0.45)])
		var main_sail := PackedVector2Array([basis * Vector2(mast1_x, -mast_height_1 * 0.9), basis * Vector2(mast1_x + half_length * 0.38, -mast_height_1 * 0.48), basis * Vector2(mast1_x, -half_beam * 0.45)])
		ci.draw_colored_polygon(fore_sail, sail_color)
		ci.draw_colored_polygon(main_sail, sail_color)

func _draw_ship_hazards(ci: CanvasItem, grid_rect: Rect2, view_origin: Vector2, view_cols: int, view_rows: int) -> void:
	var color := Color(1.0, 0.35, 0.15, 0.32)
	for cell in game.ship_battle.hazard_cells.keys():
		var rect: Rect2 = game._naval_cell_rect(grid_rect, cell, view_origin, view_cols, view_rows)
		if rect.intersects(grid_rect.grow(2.0)):
			ci.draw_rect(rect, color, true)
			ci.draw_rect(rect, Color(1.0, 0.45, 0.2, 0.55), false, 1.0)

func _draw_ship_action_panel(ci: CanvasItem, panel_rect: Rect2) -> void:
	ci.draw_rect(panel_rect, Color(0.04, 0.08, 0.15, 0.8), true)
	ci.draw_rect(panel_rect, Color(0.3, 0.5, 0.8, 0.6), false, 2.0)
	var x: float = panel_rect.position.x + 12.0
	var y: float = panel_rect.position.y + 14.0
	ci.draw_string(ThemeDB.fallback_font, Vector2(x, y), "Actions", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	y += 24.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_RANGE_PORT, "Port Range", y)
	y += 42.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_RANGE_STARBOARD, "Starboard Range", y)
	y += 42.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_FIRE_CANNONS, "Fire Cannons", y)
	y += 42.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_BOARD, "Grapple", y)
	y += 42.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_DISENGAGE, "Disengage", y)
	y += 42.0
	_draw_ship_action_button(ci, panel_rect, game.SHIP_ACTION_END_TURN, "End Turn", y)

func _draw_ship_action_button(ci: CanvasItem, panel_rect: Rect2, action: int, label: String, y_pos: float) -> void:
	var rect := Rect2(panel_rect.position.x + 8.0, y_pos, panel_rect.size.x - 16.0, 36.0)
	var is_hovered: bool = rect.has_point(game.get_global_mouse_position())
	var bg := Color(0.12, 0.18, 0.28)
	if is_hovered: bg = Color(0.2, 0.3, 0.5)
	if game.ship_combat_selected_action == action: bg = Color(0.4, 0.5, 0.8)
	ci.draw_rect(rect, bg, true)
	ci.draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _draw_ship_movement_preview(ci: CanvasItem, grid_rect: Rect2, view_origin: Vector2, view_cols: int, view_rows: int) -> void:
	var opts: Array = game.ship_battle.get_player_move_options()
	var base_color := Color(1.0, 1.0, 1.0, 0.25)
	var cell_w: float = grid_rect.size.x / float(max(1, view_cols))
	var indicator_size: float = cell_w * 0.38
	
	# Only draw one arrow per cell (pick the one matching the current player intention if possible)
	var cell_to_best_opt: Dictionary = {}
	for opt in opts:
		var cell: Vector2i = opt["cell"]
		var heading_idx: int = int(opt.get("heading_idx", -1))
		
		# If this is the hovered cell, we MUST show the correctly matching heading indicator
		if game.ship_move_selected_cell == cell and game.ship_move_selected_heading_idx == heading_idx:
			cell_to_best_opt[cell] = opt
		# Otherwise, if we haven't picked a best one for this cell yet, take this one
		elif not cell_to_best_opt.has(cell):
			cell_to_best_opt[cell] = opt
		# If we already have one, but it's not the selected one, don't overwrite if the one we have IS the selected one
		else:
			var current_best: Dictionary = cell_to_best_opt[cell]
			if not (game.ship_move_selected_cell == cell and game.ship_move_selected_heading_idx == int(current_best.get("heading_idx", -1))):
				cell_to_best_opt[cell] = opt
	
	for cell in cell_to_best_opt.keys():
		var opt: Dictionary = cell_to_best_opt[cell]
		var rect: Rect2 = game._naval_cell_rect(grid_rect, cell, view_origin, view_cols, view_rows)
		if not rect.intersects(grid_rect.grow(2.0)):
			continue
			
		var center: Vector2 = rect.position + rect.size * 0.5
		var heading_idx: int = int(opt.get("heading_idx", -1))
		
		if heading_idx >= 0:
			var dir_vec: Vector2 = game._naval_heading_vector(heading_idx)
			# Squash the direction vector for isometric view
			dir_vec.y *= 0.5
			dir_vec = dir_vec.normalized()
			
			var tip: Vector2 = center + dir_vec * indicator_size
			var side_vec: Vector2 = Vector2(-dir_vec.y, dir_vec.x) * 0.6
			var left_wing: Vector2 = center - dir_vec * (indicator_size * 0.3) + side_vec * (indicator_size * 0.65)
			var right_wing: Vector2 = center - dir_vec * (indicator_size * 0.3) - side_vec * (indicator_size * 0.65)
			
			var color: Color = base_color
			if game.ship_move_selected_cell == cell and game.ship_move_selected_heading_idx == heading_idx:
				color = Color(1.0, 0.9, 0.4, 0.9)
			
			ci.draw_colored_polygon(PackedVector2Array([tip, left_wing, center, right_wing]), color)
			ci.draw_polyline(PackedVector2Array([tip, left_wing, center, right_wing, tip]), Color(color.r, color.g, color.b, 0.85), 1.8, true)

func _draw_ship_gun_range_overlay(ci: CanvasItem, grid_rect: Rect2, view_origin: Vector2, view_cols: int, view_rows: int, battery: int) -> void:
	var cells: Array = game.ship_battle.get_player_gun_range_overlay_cells(battery)
	var color := Color(0.8, 0.2, 0.2, 0.18)
	for cell_data in cells:
		var cell: Vector2i = cell_data["cell"]
		var rect: Rect2 = game._naval_cell_rect(grid_rect, cell, view_origin, view_cols, view_rows)
		if rect.intersects(grid_rect.grow(2.0)):
			ci.draw_rect(rect, color, true)
			ci.draw_rect(rect, color, true)

func _draw_boarding_action_panel(ci: CanvasItem, panel_rect: Rect2) -> void:
	ci.draw_rect(panel_rect, Color(0.02, 0.04, 0.08, 0.85), true)
	ci.draw_rect(panel_rect, Color(0.4, 0.6, 0.9, 0.45), false, 2.0)
	var y := panel_rect.position.y + 12.0
	var btn_h := 38.0
	_draw_boarding_button(ci, panel_rect, game.BOARDING_ACTION_MOVE, "Move", y)
	y += btn_h + 8.0
	_draw_boarding_button(ci, panel_rect, game.BOARDING_ACTION_RANGED, "Ranged", y)
	y += btn_h + 8.0
	_draw_boarding_button(ci, panel_rect, game.BOARDING_ACTION_MELEE, "Melee", y)
	y += btn_h + 16.0
	_draw_boarding_button(ci, panel_rect, game.BOARDING_ACTION_END_TURN, "End Turn", y)

func _draw_boarding_button(ci: CanvasItem, panel_rect: Rect2, action: int, label: String, y: float) -> void:
	var rect := Rect2(panel_rect.position.x + 10.0, y, panel_rect.size.x - 20.0, 38.0)
	var is_hovered := rect.has_point(game.get_global_mouse_position())
	var bg := Color(0.1, 0.15, 0.25)
	if is_hovered: bg = Color(0.2, 0.3, 0.5)
	if game.boarding_selected_action == action: bg = Color(0.3, 0.4, 0.7)
	ci.draw_rect(rect, bg, true)
	ci.draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)


func _draw_ship_footprint_cells(ci: CanvasItem, 
	grid_rect: Rect2,
	view_origin: Vector2,
	view_cols: int,
	view_rows: int,
	cells: Array[Vector2i],
	color: Color
) -> void:
	for cell in cells:
		var rect: Rect2 = game._naval_cell_rect(grid_rect, cell, view_origin, view_cols, view_rows)
		if not rect.intersects(grid_rect.grow(2.0)):
			continue
		ci.draw_rect(rect, color, true)
		ci.draw_rect(rect, Color(color.r, color.g, color.b, minf(0.85, color.a + 0.28)), false, 1.0)


func _draw_heading_chevron(ci: CanvasItem, center: Vector2, heading_idx: int, size: float, color: Color) -> void:
	var dir: Vector2 = game._naval_heading_vector(heading_idx)
	var tip: Vector2 = center + dir * size
	var wing: Vector2 = Vector2(-dir.y, dir.x) * size * 0.52
	var base: Vector2 = center - dir * size * 0.22
	ci.draw_colored_polygon(
		PackedVector2Array([tip, base + wing, base - wing]),
		color
	)


func _draw_heading_tick(ci: CanvasItem, center: Vector2, heading_idx: int, radius: float, color: Color) -> void:
	var dir: Vector2 = game._naval_heading_vector(heading_idx)
	var tick_center: Vector2 = center + dir * radius
	_draw_heading_chevron(ci, tick_center, heading_idx, radius * 0.38, color)


func _draw_naval_movement_water_background(ci: CanvasItem, combat_rect: Rect2) -> void:
	ci.draw_rect(combat_rect, Color(0.08, 0.16, 0.25, 0.24), true)


func _draw_naval_battlefield_grid(ci: CanvasItem, 
	grid_rect: Rect2,
	view_origin: Vector2,
	view_cols: int,
	view_rows: int
) -> void:
	var combat_cols: int = game.ship_battle.combat_cols
	var combat_rows: int = game.ship_battle.combat_rows
	if combat_cols <= 0 or combat_rows <= 0 or view_cols <= 0 or view_rows <= 0:
		return
	
	var minor_color := Color(0.72, 0.86, 0.95, 0.18)
	var major_color := Color(0.82, 0.94, 1.0, 0.3)
	
	# Draw Iso lines for X-axis (from y=0 to y=combat_rows)
	for xi in range(combat_cols + 1):
		var major: bool = xi % 4 == 0
		var v1: Vector2 = game._naval_cell_center_from_float(Vector2(float(xi), 0.0), grid_rect, view_origin, view_cols, view_rows)
		var v2: Vector2 = game._naval_cell_center_from_float(Vector2(float(xi), float(combat_rows)), grid_rect, view_origin, view_cols, view_rows)
		ci.draw_line(
			v1,
			v2,
			major_color if major else minor_color,
			2.0 if major else 1.0
		)
		
	# Draw Iso lines for Y-axis (from x=0 to x=combat_cols)
	for yi in range(combat_rows + 1):
		var major: bool = yi % 4 == 0
		var v1: Vector2 = game._naval_cell_center_from_float(Vector2(0.0, float(yi)), grid_rect, view_origin, view_cols, view_rows)
		var v2: Vector2 = game._naval_cell_center_from_float(Vector2(float(combat_cols), float(yi)), grid_rect, view_origin, view_cols, view_rows)
		ci.draw_line(
			v1,
			v2,
			major_color if major else minor_color,
			2.0 if major else 1.0
		)
	
	# For isometric, the "rect" of the whole battlefield isn't a simple Rect2 in screen space,
	# but we can draw a bounding box or just rely on the grid lines.
	# The previous code tried to draw a rect, which is usually for Cartesian grids.


func _draw_naval_reachable_cell_grid(ci: CanvasItem, 
	grid_rect: Rect2,
	view_origin: Vector2,
	view_cols: int,
	view_rows: int,
	cells: Array[Vector2i]
) -> void:
	if view_cols <= 1 or view_rows <= 1:
		return
	# Cartesian cell size for fallback/border (not true Iso)
	var cw: float = grid_rect.size.x / float(max(1, view_cols))
	var ch: float = grid_rect.size.y / float(max(1, view_rows))
	
	for c in cells:
		if c.x < int(view_origin.x) or c.y < int(view_origin.y):
			continue
		if c.x >= int(view_origin.x) + view_cols or c.y >= int(view_origin.y) + view_rows:
			continue
		var cell_rect: Rect2 = game._naval_cell_rect(grid_rect, c, view_origin, view_cols, view_rows)
		if not cell_rect.intersects(grid_rect.grow(1.0)):
			continue
		var major: bool = c.x % 4 == 0 or c.y % 4 == 0
		var border_color: Color = Color(0.82, 0.94, 1.0, 0.26) if major else Color(0.72, 0.86, 0.95, 0.17)
		# Draw the isometric diamond border
		var p1: Vector2 = game._naval_cell_center_from_float(Vector2(float(c.x), float(c.y)), grid_rect, view_origin, view_cols, view_rows)
		var p2: Vector2 = game._naval_cell_center_from_float(Vector2(float(c.x + 1), float(c.y)), grid_rect, view_origin, view_cols, view_rows)
		var p3: Vector2 = game._naval_cell_center_from_float(Vector2(float(c.x + 1), float(c.y + 1)), grid_rect, view_origin, view_cols, view_rows)
		var p4: Vector2 = game._naval_cell_center_from_float(Vector2(float(c.x), float(c.y + 1)), grid_rect, view_origin, view_cols, view_rows)
		ci.draw_line(p1, p2, border_color, 1.0)
		ci.draw_line(p2, p3, border_color, 1.0)
		ci.draw_line(p3, p4, border_color, 1.0)
		ci.draw_line(p4, p1, border_color, 1.0)
	
	var border_rect: Rect2 = Rect2(grid_rect.position, Vector2(float(view_cols) * cw, float(view_rows) * ch))
	if border_rect.intersects(grid_rect.grow(1.0)):
		ci.draw_rect(border_rect, Color(0.9, 0.97, 1.0, 0.35), false, 2.0)


func _draw_selected_ship_move_cell(ci: CanvasItem, grid_rect: Rect2, view_origin: Vector2, view_cols: int, view_rows: int) -> void:
	if game.ship_move_selected_cell.x < 0 or game.ship_move_selected_cell.y < 0:
		return
	if game.ship_move_selected_heading_idx < 0:
		return
	if not game.ship_battle.can_player_move_to_option(game.ship_move_selected_cell, game.ship_move_selected_heading_idx):
		return
	var rect: Rect2 = game._naval_cell_rect(grid_rect, game.ship_move_selected_cell, view_origin, view_cols, view_rows)
	ci.draw_rect(rect, Color(1.0, 0.96, 0.55, 0.16), true)
	ci.draw_rect(rect, Color(1.0, 0.96, 0.55, 0.9), false, 2.0)


func _draw_boarding_deck_surface(ci: CanvasItem) -> void:
	if game.grid == null:
		return
	var tile := float(game.grid.tile_size)
	var board_rect := Rect2(game.grid.position, Vector2(float(game.grid.width) * tile, float(game.grid.height) * tile))
	ci.draw_rect(board_rect, Color(0.04, 0.08, 0.12, 1.0), true)

	var deck_cells: Array[Vector2i] = game.boarding_deck_cells
	if deck_cells.is_empty():
		for y in range(game.grid.height):
			for x in range(game.grid.width):
				deck_cells.append(Vector2i(x, y))

	for cell in deck_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.2, 0.16, 0.1), true)

	for cell in game.boarding_chokepoint_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.4, 0.28, 0.16, 0.5), true)

	for cell in game.boarding_gangplank_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.62, 0.47, 0.28, 0.75), true)

	var objective_rect := Rect2(game.grid.position + Vector2(game.boarding_objective_cell) * tile, Vector2.ONE * tile)
	ci.draw_rect(objective_rect, Color(0.95, 0.8, 0.35, 0.8), true)

	for cell in game.boarding_obstacle_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.2, 0.17, 0.12, 0.95), true)

	for cell in game.reachable_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.3, 0.65, 1.0, 0.25), true)

	if game.grid.is_in_bounds(game.grid.hovered_cell) and game.grid.is_cell_on_deck(game.grid.hovered_cell):
		var hover_rect := Rect2(game.grid.position + Vector2(game.grid.hovered_cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.15), true)

	for cell in deck_cells:
		var cell_rect := Rect2(game.grid.position + Vector2(cell) * tile, Vector2.ONE * tile)
		ci.draw_rect(cell_rect, Color(0.28, 0.3, 0.36), false, 1.0)


func _draw_boarding_units_overlay(ci: CanvasItem) -> void:
	if game.grid == null:
		return
	var tile := float(game.grid.tile_size)
	var actor: CombatUnit = game._current_boarding_actor()
	for unit in game.units:
		if unit == null or not is_instance_valid(unit):
			continue
		var _center: Vector2 = game.grid.position + Vector2(unit.cell) * tile + Vector2.ONE * tile * 0.5
		var _unit_radius := tile * 0.34
		var base_color := Color(0.35, 0.65, 1.0) if unit.team == CombatTurnManager.Team.PLAYER else Color(1.0, 0.4, 0.35)
		ci.draw_circle(_center, _unit_radius, base_color)
		ci.draw_string(ThemeDB.fallback_font, _center + Vector2(-6.0, 6.0), str(unit.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		if unit == game.selected_unit:
			ci.draw_arc(_center, _unit_radius + 4.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.5), 3.0)
		if unit == actor:
			ci.draw_arc(_center, _unit_radius + 8.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.45, 0.95), 3.0)
		if unit.has_acted:
			ci.draw_circle(_center, _unit_radius, Color(0.0, 0.0, 0.0, 0.4))
		if unit.is_dimmed:
			ci.draw_circle(_center, _unit_radius + 1.0, Color(0.02, 0.03, 0.06, 0.55))

# Moved to CombatRendererV2
