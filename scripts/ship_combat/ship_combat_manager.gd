extends Node2D
class_name ShipCombatManager

signal combat_finished(player_won: bool)

enum Phase { PLANNING, EXECUTION }

const SHIP_UNIT := preload("res://scripts/ship_combat/ship_unit.gd")
const PROJECTILE := preload("res://scripts/ship_combat/projectile.gd")

const TURN_DURATION: float = 10.0
const PROJECTILE_SPEED: float = 300.0
const GRID_DRAW_EXTENT: int = 20
const CAMERA_ZOOM: Vector2 = Vector2(1.4, 1.4)

## Where to read the active wind from (a node exposing get_current_wind()).
@export var wind_source_path: NodePath = ^"../WorldMap"

var current_phase: Phase = Phase.PLANNING
var player_ship: ShipUnit
var enemy_ship: ShipUnit

var wind_direction: Vector2 = Vector2.UP
var wind_speed: float = 10.0 # knots

var simulation_time: float = 0.0
var turn_number: int = 1

var path_line: Line2D
var ghost_ship: ShipUnit
var ui_root: CanvasLayer

# Ships keep their positions between turns; only place them at the start of a battle.
var _battle_active: bool = false

# Player broadside intents queued during planning for the upcoming turn.
var player_fire_port: bool = false
var player_fire_starboard: bool = false

# UI references.
var player_status_label: Label
var enemy_status_label: Label
var info_label: Label
var fire_port_button: Button
var fire_starboard_button: Button
var speed_buttons: Dictionary = {}

func _ready():
	_init_background_rect()
	_init_ships()
	_setup_camera()
	_update_wind_from_world()
	set_process(false)
	set_process_unhandled_input(false)
	if get_parent() == get_tree().root:
		call_deferred("set_active", true)

func _init_background_rect():
	var rect = ColorRect.new()
	rect.color = Color(0.0, 0.5, 1.0)
	rect.size = Vector2(5000, 5000)
	rect.position = Vector2(-2500, -2500)
	rect.z_index = -100
	add_child(rect)

func _init_ships():
	if not player_ship:
		player_ship = SHIP_UNIT.new()
		player_ship.data = ShipData.new()
		add_child(player_ship)
	player_ship.accent_color = Color(0.35, 0.62, 1.0)

	if not enemy_ship:
		enemy_ship = SHIP_UNIT.new()
		enemy_ship.data = ShipData.new()
		add_child(enemy_ship)
	enemy_ship.accent_color = Color(1.0, 0.42, 0.36)

func _setup_camera():
	var cam = Camera2D.new()
	cam.name = "ShipCombatCamera"
	cam.enabled = false
	add_child(cam)

func set_active(active: bool):
	visible = active
	set_process(active)
	set_process_unhandled_input(active)
	var cam = get_node_or_null("ShipCombatCamera") as Camera2D
	if cam:
		cam.enabled = active
		if active:
			cam.make_current()
	if active:
		if not _battle_active:
			_start_battle()
			_battle_active = true
		_start_planning_phase()
	else:
		_battle_active = false
		_clear_all_projectiles()
		if ui_root: ui_root.visible = false

# Places both ships at their starting cells/headings. Called once per battle.
func _start_battle():
	_update_wind_from_world()
	turn_number = 1
	player_fire_port = false
	player_fire_starboard = false
	_reset_ship_condition(player_ship)
	_reset_ship_condition(enemy_ship)
	player_ship.set_grid_pos(Vector2(5, 5))
	player_ship.heading = Vector2(1, 0)
	player_ship.update_visuals()
	enemy_ship.set_grid_pos(Vector2(10, 5))
	enemy_ship.heading = Vector2(-1, 0)
	enemy_ship.update_visuals()

func _reset_ship_condition(ship: ShipUnit):
	ship.data.hull_hp = ship.data.max_hull
	ship.data.sails_hp = ship.data.max_sails
	ship.data.crew_hp = ship.data.max_crew
	ship.data.port_reload_turns = 0
	ship.data.starboard_reload_turns = 0

func _start_planning_phase():
	current_phase = Phase.PLANNING
	simulation_time = 0.0
	player_fire_port = false
	player_fire_starboard = false

	if not player_ship.current_plan:
		player_ship.current_plan = TurnPlan.new()

	player_ship.current_plan.path = [Vector2i(player_ship.grid_pos)]
	player_ship.current_plan.fire_orders = []

	var cam = get_node_or_null("ShipCombatCamera") as Camera2D
	if cam:
		cam.position = (player_ship.position + enemy_ship.position) * 0.5
		cam.zoom = CAMERA_ZOOM

	_update_path_visuals()
	queue_redraw()

func _update_wind_from_world():
	var world_map = get_node_or_null(wind_source_path)
	if world_map and world_map.has_method("get_current_wind"):
		var wind = world_map.get_current_wind()
		wind_direction = wind.get("dir", Vector2.RIGHT)
		wind_speed = wind.get("speed", 10.0)

func _process(delta: float):
	if current_phase == Phase.EXECUTION:
		_resolve_turn(delta)
	_update_hud()

func _resolve_turn(delta: float):
	simulation_time += delta
	var cam = get_node_or_null("ShipCombatCamera") as Camera2D
	if cam:
		cam.position = (player_ship.position + enemy_ship.position) * 0.5
	if simulation_time >= TURN_DURATION:
		_end_resolution()
		return
	_simulate_step(simulation_time)

func _simulate_step(time: float):
	var t = time / TURN_DURATION
	player_ship.interpolate_pose(t)
	enemy_ship.interpolate_pose(t)
	_check_fire_orders(player_ship, time)
	_check_fire_orders(enemy_ship, time)

func _check_fire_orders(ship: ShipUnit, current_time: float):
	for i in range(ship.current_plan.fire_orders.size() - 1, -1, -1):
		var order = ship.current_plan.fire_orders[i]
		if order.timestamp <= current_time:
			_fire_cannon(ship, order.battery)
			ship.current_plan.fire_orders.remove_at(i)

func _fire_cannon(ship: ShipUnit, battery: String):
	# Respect reload cooldowns carried over from previous turns.
	if battery == "port" and ship.data.port_reload_turns > 0:
		return
	if battery == "starboard" and ship.data.starboard_reload_turns > 0:
		return
	var p = PROJECTILE.new()
	p.source_ship = ship
	p.position = ship.position
	# Fire perpendicular to the ship's *current* screen orientation, so the broadside
	# always leaves square to the hull as it is drawn at the moment of firing.
	var facing := Vector2.RIGHT.rotated(ship.rotation)
	var fire_dir := facing.rotated(-PI / 2.0)
	if battery == "starboard":
		fire_dir = facing.rotated(PI / 2.0)
	p.velocity = fire_dir.normalized() * PROJECTILE_SPEED
	add_child(p)
	if battery == "port":
		ship.data.port_reload_turns = ship.data.cannon_cooldown_max
	else:
		ship.data.starboard_reload_turns = ship.data.cannon_cooldown_max

func _end_resolution():
	current_phase = Phase.PLANNING
	simulation_time = 0.0
	player_ship.finalize_resolution()
	enemy_ship.finalize_resolution()
	player_ship.data.advance_cooldowns()
	enemy_ship.data.advance_cooldowns()
	player_ship.data.speed_setting = player_ship.data.next_speed_setting
	enemy_ship.data.speed_setting = enemy_ship.data.next_speed_setting
	# Keep shots still capable of connecting; sweep away the misses.
	_clear_missed_projectiles()

	if _is_defeated(enemy_ship):
		_finish_combat(true)
		return
	if _is_defeated(player_ship):
		_finish_combat(false)
		return

	turn_number += 1
	_start_planning_phase()

func _is_defeated(ship: ShipUnit) -> bool:
	return ship.data.hull_hp <= 0.0 or ship.data.crew_hp <= 0.0

func _finish_combat(player_won: bool):
	current_phase = Phase.PLANNING
	_battle_active = false
	_clear_all_projectiles()
	if ui_root:
		ui_root.visible = false
	set_process(false)
	set_process_unhandled_input(false)
	combat_finished.emit(player_won)

func _clear_missed_projectiles():
	for child in get_children():
		if child is Projectile and not child.could_still_hit():
			child.queue_free()

func _clear_all_projectiles():
	for child in get_children():
		if child is Projectile:
			child.queue_free()

func execute_turn():
	if current_phase != Phase.PLANNING:
		return
	_queue_player_fire_orders()
	_generate_ai_plan(enemy_ship)
	player_ship.prepare_resolution()
	enemy_ship.prepare_resolution()
	_hide_planning_visuals()
	current_phase = Phase.EXECUTION
	simulation_time = 0.0

func _queue_player_fire_orders():
	if not (player_fire_port or player_fire_starboard):
		return
	var t := _closest_approach_time(player_ship.current_plan.path, enemy_ship.position)
	if player_fire_port:
		player_ship.current_plan.fire_orders.append({"timestamp": t, "battery": "port"})
	if player_fire_starboard:
		player_ship.current_plan.fire_orders.append({"timestamp": t, "battery": "starboard"})

# Time (0..TURN_DURATION) at which a ship travelling `path` is nearest `target_pos`,
# so a queued broadside auto-times itself to the closest pass.
func _closest_approach_time(path: Array, target_pos: Vector2) -> float:
	if path.size() <= 1:
		return TURN_DURATION * 0.5
	var pts: Array[Vector2] = []
	for c in path:
		pts.append(IsoHelper.grid_to_world(Vector2(c)))
	var seg_len: Array[float] = []
	var total: float = 0.0
	for i in range(pts.size() - 1):
		var l: float = pts[i].distance_to(pts[i + 1])
		seg_len.append(l)
		total += l
	if total <= 0.001:
		return TURN_DURATION * 0.5
	var best_frac: float = 0.0
	var best_dist: float = INF
	var samples: int = 40
	for s in range(samples + 1):
		var frac: float = float(s) / float(samples)
		var dist_along: float = frac * total
		var acc: float = 0.0
		var pos: Vector2 = pts[pts.size() - 1]
		for i in range(seg_len.size()):
			if acc + seg_len[i] >= dist_along or i == seg_len.size() - 1:
				var lt: float = 0.0
				if seg_len[i] > 0.001:
					lt = clampf((dist_along - acc) / seg_len[i], 0.0, 1.0)
				pos = pts[i].lerp(pts[i + 1], lt)
				break
			acc += seg_len[i]
		var d: float = pos.distance_to(target_pos)
		if d < best_dist:
			best_dist = d
			best_frac = frac
	return clampf(best_frac * TURN_DURATION, 0.0, TURN_DURATION)

func _generate_ai_plan(ship: ShipUnit):
	ship.current_plan = TurnPlan.new()
	var start = Vector2i(ship.grid_pos)
	ship.current_plan.path = [start]
	var target_dist = 4.0
	var current = start
	var max_steps = _get_max_steps(ship)
	for i in range(max_steps):
		var to_player = Vector2(player_ship.grid_pos) - Vector2(current)
		var dist = to_player.length()
		var step = Vector2i.ZERO
		if dist > target_dist + 1:
			step = Vector2i(clampi(int(to_player.x), -1, 1), clampi(int(to_player.y), -1, 1))
		elif dist < target_dist - 1:
			step = Vector2i(clampi(int(-to_player.x), -1, 1), clampi(int(-to_player.y), -1, 1))
		else:
			var tangent = Vector2(-to_player.y, to_player.x).normalized()
			step = Vector2i(clampi(int(tangent.x * 1.5), -1, 1), clampi(int(tangent.y * 1.5), -1, 1))
		if step == Vector2i.ZERO: break
		current += step
		ship.current_plan.path.append(current)
	var last_pos = Vector2(ship.current_plan.path.back())
	var to_player_final = Vector2(player_ship.grid_pos) - last_pos
	var ship_heading = ship.heading
	if ship.current_plan.path.size() > 1:
		ship_heading = (Vector2(ship.current_plan.path[-1]) - Vector2(ship.current_plan.path[-2])).normalized()
	var side_dot = ship_heading.rotated(PI / 2).dot(to_player_final.normalized())
	if abs(side_dot) > 0.7:
		var battery = "port" if side_dot > 0 else "starboard"
		ship.current_plan.fire_orders.append({"timestamp": 5.0, "battery": battery})

func _unhandled_input(event: InputEvent):
	if current_phase != Phase.PLANNING: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_grid_click(get_global_mouse_position())

func _get_max_steps(ship: ShipUnit) -> int:
	var base_steps = 3
	match ship.data.speed_setting:
		"Fast": base_steps = 4
		"Battle": base_steps = 3
		"Slow": base_steps = 2
	var alignment = ship.heading.dot(wind_direction)
	var mod = 0
	if alignment > 0.5: mod = 1
	elif alignment < -0.5: mod = -1
	# Torn sails cost speed.
	var sail_ratio := 1.0
	if ship.data.max_sails > 0.0:
		sail_ratio = clampf(ship.data.sails_hp / ship.data.max_sails, 0.25, 1.0)
	return clampi(roundi(float(base_steps + mod) * sail_ratio), 1, 5)

func _handle_grid_click(mouse_pos: Vector2):
	var grid_coord = IsoHelper.world_to_grid(mouse_pos)
	var cell = Vector2i(roundi(grid_coord.x), roundi(grid_coord.y))

	if not player_ship.current_plan or player_ship.current_plan.path.is_empty():
		_start_planning_phase()

	var last_cell = player_ship.current_plan.path.back()
	if _is_adjacent(last_cell, cell):
		var max_steps = _get_max_steps(player_ship)
		if player_ship.current_plan.path.size() <= max_steps:
			player_ship.current_plan.path.append(cell)
			player_ship.heading = (Vector2(cell) - Vector2(last_cell)).normalized()
			_update_path_visuals()

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) <= 1 and abs(a.y - b.y) <= 1 and a != b

func _update_path_visuals():
	if not path_line:
		path_line = Line2D.new()
		path_line.width = 4.0
		path_line.default_color = Color.YELLOW
		path_line.z_index = 5
		add_child(path_line)
	path_line.visible = true
	path_line.clear_points()
	for cell in player_ship.current_plan.path:
		path_line.add_point(IsoHelper.grid_to_world(Vector2(cell)))
	if not ghost_ship:
		ghost_ship = SHIP_UNIT.new()
		ghost_ship.modulate = Color(1, 1, 1, 0.5)
		add_child(ghost_ship)
	if player_ship.current_plan.path.size() > 0:
		var last_cell = player_ship.current_plan.path.back()
		ghost_ship.visible = true
		ghost_ship.set_grid_pos(Vector2(last_cell))
		if player_ship.current_plan.path.size() > 1:
			var prev_cell = player_ship.current_plan.path[-2]
			ghost_ship.heading = (Vector2(last_cell) - Vector2(prev_cell)).normalized()
		else:
			ghost_ship.heading = player_ship.heading
		ghost_ship.update_visuals()
	else:
		ghost_ship.visible = false
	_setup_ui()

func _hide_planning_visuals():
	if path_line: path_line.visible = false
	if ghost_ship: ghost_ship.visible = false

func _setup_ui():
	if not ui_root:
		ui_root = CanvasLayer.new()
		add_child(ui_root)
	if ui_root.get_child_count() == 0:
		_build_ui()
	ui_root.visible = true
	_refresh_fire_buttons()
	_refresh_speed_buttons()
	_update_hud()

func _build_ui():
	_add_button("EXECUTE TURN", Vector2(20, 20), execute_turn)
	_add_button("CLEAR PATH", Vector2(20, 56), _clear_path)

	fire_port_button = _add_button("Fire Port: off", Vector2(20, 104), _on_fire_port_pressed)
	fire_starboard_button = _add_button("Fire Starboard: off", Vector2(20, 140), _on_fire_starboard_pressed)

	var speed_label := Label.new()
	speed_label.text = "Next-turn speed"
	speed_label.position = Vector2(20, 188)
	ui_root.add_child(speed_label)
	var x := 20.0
	for setting in ["Slow", "Battle", "Fast"]:
		var b := _add_button(setting, Vector2(x, 214), _on_speed_pressed.bind(setting))
		speed_buttons[setting] = b
		x += 96.0

	player_status_label = _make_label(Vector2(20, 264))
	info_label = _make_label(Vector2(20, 330))
	enemy_status_label = _make_label(Vector2(20, 20))

func _add_button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.pressed.connect(cb)
	ui_root.add_child(b)
	return b

func _make_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	ui_root.add_child(l)
	return l

func _on_fire_port_pressed():
	player_fire_port = not player_fire_port
	_refresh_fire_buttons()

func _on_fire_starboard_pressed():
	player_fire_starboard = not player_fire_starboard
	_refresh_fire_buttons()

func _refresh_fire_buttons():
	if is_instance_valid(fire_port_button):
		fire_port_button.text = "Fire Port: ON" if player_fire_port else "Fire Port: off"
		fire_port_button.modulate = Color(0.6, 1.0, 0.6) if player_fire_port else Color.WHITE
	if is_instance_valid(fire_starboard_button):
		fire_starboard_button.text = "Fire Starboard: ON" if player_fire_starboard else "Fire Starboard: off"
		fire_starboard_button.modulate = Color(0.6, 1.0, 0.6) if player_fire_starboard else Color.WHITE

func _on_speed_pressed(setting: String):
	if player_ship and player_ship.data:
		player_ship.data.next_speed_setting = setting
	_refresh_speed_buttons()

func _refresh_speed_buttons():
	var sel := ""
	if player_ship and player_ship.data:
		sel = player_ship.data.next_speed_setting
	for setting in speed_buttons.keys():
		var b: Button = speed_buttons[setting]
		if is_instance_valid(b):
			b.modulate = Color(0.6, 1.0, 0.6) if setting == sel else Color.WHITE

func _update_hud():
	if not is_instance_valid(player_status_label):
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	player_status_label.text = _ship_status_text("PLAYER", player_ship)
	enemy_status_label.text = _ship_status_text("ENEMY", enemy_ship)
	enemy_status_label.position = Vector2(maxf(20.0, viewport.x - 260.0), 20.0)
	var phase_name := "PLANNING" if current_phase == Phase.PLANNING else "EXECUTING"
	info_label.text = "Turn %d    Wind %.0f kts %s    %s" % [turn_number, wind_speed, _wind_arrow(), phase_name]

func _ship_status_text(label: String, ship: ShipUnit) -> String:
	if ship == null or ship.data == null:
		return label
	var d = ship.data
	return "%s\nHull %d/%d   Sails %d   Crew %d\nSpeed: %s" % [
		label, roundi(d.hull_hp), roundi(d.max_hull), roundi(d.sails_hp), roundi(d.crew_hp), d.speed_setting
	]

func _wind_arrow() -> String:
	var idx := IsoHelper.get_direction_index(IsoHelper.get_bearing_angle(wind_direction))
	return IsoHelper.get_direction_string(idx).to_upper()

func _clear_path():
	if current_phase == Phase.PLANNING:
		player_ship.current_plan.path = [Vector2i(player_ship.grid_pos)]
		_update_path_visuals()

func _draw():
	if not visible: return
	var grid_color = Color(1.0, 1.0, 1.0, 0.5)
	var line_width = 1.0
	for i in range(-GRID_DRAW_EXTENT, GRID_DRAW_EXTENT + 1):
		var start_v = IsoHelper.grid_to_world(Vector2(i, -GRID_DRAW_EXTENT))
		var end_v = IsoHelper.grid_to_world(Vector2(i, GRID_DRAW_EXTENT))
		draw_line(start_v, end_v, grid_color, line_width)
		var start_h = IsoHelper.grid_to_world(Vector2(-GRID_DRAW_EXTENT, i))
		var end_h = IsoHelper.grid_to_world(Vector2(GRID_DRAW_EXTENT, i))
		draw_line(start_h, end_h, grid_color, line_width)
