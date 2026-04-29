extends Node2D
class_name WorldMap

signal destination_arrived(port_name: String)
signal random_encounter_triggered
## Emitted once each time the calendar advances to a new month (year*12+month, month 1–12).
signal game_month_advanced(month_index: int)

@export var auto_sail_speed: float = 120.0
@export var encounter_check_interval: float = 2.0
@export var encounter_chance_per_check: float = 0.2
@export var in_game_hours_per_real_second: float = 8.0
@export var ship_speed_multiplier: float = 1.0
@export_enum("Sloop", "Brig", "Frigate", "Merchantman") var ship_class: String = "Sloop"
@export var auto_calibrate_historical_speed: bool = true
@export var player_time_scale: float = 2.0

var ports := {
	"Havana": {"pos": Vector2(1197, 684), "faction": "Spanish"},
	"Nassau": {"pos": Vector2(1499, 581), "faction": "English"},
	"Port Royal": {"pos": Vector2(1530, 958), "faction": "English"},
	"Tortuga": {"pos": Vector2(1778, 845), "faction": "French"},
	"Cartagena": {"pos": Vector2(1842, 1362), "faction": "Spanish"},
	"Santo Domingo": {"pos": Vector2(1952, 931), "faction": "Spanish"},
	"Veracruz": {"pos": Vector2(357, 892), "faction": "Spanish"},
	"Portobelo": {"pos": Vector2(1360, 1405), "faction": "Spanish"},
	"San Juan": {"pos": Vector2(2184, 931), "faction": "Spanish"},
	"Campeche": {"pos": Vector2(698, 858), "faction": "Spanish"},
	"Maracaibo": {"pos": Vector2(1848, 1346), "faction": "Spanish"},
	"Willemstad": {"pos": Vector2(2012, 1269), "faction": "Dutch"},
	"Santiago de Cuba": {"pos": Vector2(1592, 849), "faction": "Spanish"},
	"Port-au-Prince": {"pos": Vector2(1805, 927), "faction": "French"},
	"Bridgetown": {"pos": Vector2(2580, 1216), "faction": "English"},
	"St. Pierre": {"pos": Vector2(2485, 1129), "faction": "French"},
	"Basse-Terre": {"pos": Vector2(2451, 1062), "faction": "French"},
	"La Guaira": {"pos": Vector2(2135, 1349), "faction": "Spanish"},
	"St. Augustine": {"pos": Vector2(1259, 324), "faction": "Spanish"}
}

var current_position: Vector2 = Vector2(1197, 684)
var target_port_name: String = "Havana"
var target_position: Vector2 = Vector2(1197, 684)
var is_traveling: bool = false
var travel_accumulator: float = 0.0
var zoom_level: float = 0.9
var min_zoom: float = 0.65
var max_zoom: float = 4.0
var world_size: Vector2 = Vector2(2800, 1700)
var view_offset: Vector2 = Vector2(520, 120)
var is_panning: bool = false
var last_pan_screen_pos: Vector2 = Vector2.ZERO
var game_year: int = 1670
var game_month: int = 1
var game_day: float = 1.0
var wind_cols: int = 0
var wind_rows: int = 0
var wind_tiles: Dictionary = {}
var nav_cell_size: float = 34.0
var nav_cols: int = 0
var nav_rows: int = 0
var nav_blocked: Dictionary = {}
var route_points: Array[Vector2] = []
var route_segment_colors: Array[Color] = []
var route_index: int = 0
var hover_eta_hours: float = -1.0
var hover_world_pos: Vector2 = Vector2.ZERO
var hover_has_eta: bool = false
var last_hover_cell: Vector2i = Vector2i(-9999, -9999)
var next_hover_eta_msec: int = 0
var land_baked_texture: Texture2D
var use_vector_land: bool = true
## CPU copy of baked land for O(1) land tests (pathfinding, coast sampling). Null if no bake.
var _land_collision_image: Image
var _layer_under: Node2D
var _layer_dynamic: Node2D
var _layer_over: Node2D
## Runtime port controller; keys are port names, values faction strings. Filled from career save.
var port_owner_overrides: Dictionary = {}

const MAP_BG := Color(0.08, 0.2, 0.32)
const LAND_COLOR := Color(0.83, 0.76, 0.58)
const LAND_SHADE := Color(0.72, 0.66, 0.5)
const SHIP_COLOR := Color(0.95, 0.95, 1.0)
const WIND_GUIDE_RADIUS := 26.0
const FACTION_COLORS := {
	"Spanish": Color(0.93, 0.77, 0.26),
	"English": Color(0.88, 0.2, 0.2),
	"French": Color(0.3, 0.52, 0.9),
	"Dutch": Color(0.96, 0.56, 0.2)
}

var left_gutter_width: float = 96.0
var log_band_height: float = 220.0
const MAP_OUTSIDE_COLOR := Color(0.02, 0.03, 0.05)
const LAND_DATA_PATH := "res://data/caribbean_land.json"
const LAND_BAKED_PATH := "res://data/land_baked.png"
const WIND_DATA_PATH := "res://data/wind_tiles_monthly.json"
const _MapUnderLayer := preload("res://scripts/world_map_under_layer.gd")
const _MapDynamicLayer := preload("res://scripts/world_map_dynamic_layer.gd")
const _MapOverLayer := preload("res://scripts/world_map_over_layer.gd")

const HISTORICAL_BENCHMARKS := [
	{"from": "Nassau", "to": "Havana", "days": 4.0},
	{"from": "Nassau", "to": "Port Royal", "days": 7.0},
	{"from": "Nassau", "to": "Cartagena", "days": 12.0}
]

var americas_polygons: Array[PackedVector2Array] = [
	PackedVector2Array([
		# Southern North America + Gulf + Florida.
		Vector2(300, 170), Vector2(620, 145), Vector2(950, 150), Vector2(1220, 178),
		Vector2(1420, 220), Vector2(1550, 282), Vector2(1640, 360), Vector2(1700, 450),
		Vector2(1700, 540), Vector2(1660, 618), Vector2(1595, 670), Vector2(1550, 665),
		Vector2(1530, 625), Vector2(1518, 545), Vector2(1475, 490), Vector2(1385, 452),
		Vector2(1248, 432), Vector2(1082, 420), Vector2(930, 400), Vector2(780, 360),
		Vector2(652, 305), Vector2(500, 240)
	]),
	PackedVector2Array([
		# Mexico and Yucatan.
		Vector2(680, 505), Vector2(860, 522), Vector2(1020, 585), Vector2(1168, 698),
		Vector2(1260, 822), Vector2(1312, 952), Vector2(1298, 1066), Vector2(1242, 1130),
		Vector2(1170, 1116), Vector2(1125, 1030), Vector2(1078, 938), Vector2(1010, 858),
		Vector2(928, 802), Vector2(834, 748), Vector2(748, 676), Vector2(680, 592)
	]),
	PackedVector2Array([
		# Central America isthmus.
		Vector2(1248, 1142), Vector2(1330, 1160), Vector2(1422, 1196), Vector2(1516, 1248),
		Vector2(1602, 1308), Vector2(1630, 1364), Vector2(1588, 1414), Vector2(1496, 1430),
		Vector2(1398, 1402), Vector2(1302, 1356), Vector2(1242, 1278)
	]),
	PackedVector2Array([
		# Northern South America.
		Vector2(1540, 1286), Vector2(1690, 1308), Vector2(1870, 1368), Vector2(2030, 1468),
		Vector2(2160, 1604), Vector2(2230, 1740), Vector2(2218, 1864), Vector2(2140, 1956),
		Vector2(1986, 1990), Vector2(1812, 1948), Vector2(1668, 1868), Vector2(1552, 1738),
		Vector2(1474, 1580), Vector2(1466, 1418)
	]),
	PackedVector2Array([
		# Cuba.
		Vector2(1240, 742), Vector2(1350, 710), Vector2(1510, 708), Vector2(1650, 744),
		Vector2(1600, 796), Vector2(1440, 824), Vector2(1278, 808)
	]),
	PackedVector2Array([
		# Hispaniola (Haiti + DR).
		Vector2(1550, 920), Vector2(1645, 904), Vector2(1750, 942), Vector2(1726, 994),
		Vector2(1592, 1010)
	]),
	PackedVector2Array([
		# Jamaica.
		Vector2(1446, 1000), Vector2(1508, 988), Vector2(1560, 1016), Vector2(1540, 1042),
		Vector2(1462, 1048)
	]),
	PackedVector2Array([
		# Puerto Rico.
		Vector2(1800, 982), Vector2(1870, 970), Vector2(1920, 992), Vector2(1906, 1020),
		Vector2(1818, 1028)
	]),
	PackedVector2Array([
		# Bahamas bank.
		Vector2(1556, 662), Vector2(1615, 642), Vector2(1672, 678), Vector2(1632, 716),
		Vector2(1572, 706)
	]),
	PackedVector2Array([
		# Lesser Antilles starter arc.
		Vector2(1755, 815), Vector2(1780, 840), Vector2(1775, 870), Vector2(1748, 860)
	]),
	PackedVector2Array([
		Vector2(1790, 865), Vector2(1818, 892), Vector2(1810, 920), Vector2(1782, 905)
	])
]

func _ready() -> void:
	set_as_top_level(true)
	global_position = Vector2.ZERO
	_load_land_data()
	_load_land_baked()
	_load_wind_data()
	_build_navigation_grid()
	if auto_calibrate_historical_speed:
		_apply_historical_speed_calibration()
	_clamp_view_offset()
	_setup_canvas_layers()
	_refresh_view_canvases()

func _process(delta: float) -> void:
	var sim_delta := delta * player_time_scale
	if is_traveling:
		_advance_game_time(sim_delta * in_game_hours_per_real_second)

	if not is_traveling:
		return

	if route_points.is_empty() or route_index >= route_points.size() - 1:
		if not _segment_hits_land(current_position, target_position):
			current_position = target_position
		is_traveling = false
		emit_signal("destination_arrived", target_port_name)
		_refresh_dynamic_canvas()
		return

	var remaining_step := _current_travel_speed_map_units_per_second(_travel_heading_or_default()) * sim_delta
	while remaining_step > 0.0 and route_index < route_points.size() - 1:
		var segment_target := route_points[route_index + 1]
		var to_segment := segment_target - current_position
		var seg_dist := to_segment.length()
		if seg_dist <= 0.001:
			route_index += 1
			continue
		if remaining_step >= seg_dist:
			current_position = segment_target
			remaining_step -= seg_dist
			route_index += 1
		else:
			current_position += to_segment.normalized() * remaining_step
			remaining_step = 0.0

	if route_index >= route_points.size() - 1 and current_position.distance_to(target_position) <= nav_cell_size:
		if not _segment_hits_land(current_position, target_position):
			current_position = target_position
		is_traveling = false
		emit_signal("destination_arrived", target_port_name)
		_refresh_dynamic_canvas()
		return

	travel_accumulator += sim_delta

	if travel_accumulator >= encounter_check_interval:
		travel_accumulator = 0.0
		if randf() <= encounter_chance_per_check:
			is_traveling = false
			emit_signal("random_encounter_triggered")

	_refresh_dynamic_canvas()

func _setup_canvas_layers() -> void:
	var under := _MapUnderLayer.new()
	under.name = "MapUnder"
	under.world_map = self
	under.z_index = 0
	add_child(under)
	_layer_under = under

	var dyn := _MapDynamicLayer.new()
	dyn.name = "MapDynamic"
	dyn.world_map = self
	dyn.z_index = 1
	add_child(dyn)
	_layer_dynamic = dyn

	var over := _MapOverLayer.new()
	over.name = "MapOver"
	over.world_map = self
	over.z_index = 2
	add_child(over)
	_layer_over = over


func _refresh_dynamic_canvas() -> void:
	if _layer_dynamic != null:
		_layer_dynamic.queue_redraw()


func _refresh_view_canvases() -> void:
	if _layer_under != null:
		_layer_under.queue_redraw()
	if _layer_dynamic != null:
		_layer_dynamic.queue_redraw()
	if _layer_over != null:
		_layer_over.queue_redraw()


func draw_under_canvas(ci: CanvasItem) -> void:
	var map_rect := _map_rect()
	var map_poly := PackedVector2Array([
		map_rect.position,
		map_rect.position + Vector2(map_rect.size.x, 0.0),
		map_rect.position + map_rect.size,
		map_rect.position + Vector2(0.0, map_rect.size.y)
	])
	ci.draw_rect(map_rect, MAP_BG, true)
	if not use_vector_land and land_baked_texture != null:
		_draw_baked_land_layer(ci, map_rect)
	else:
		_draw_vector_land(ci, map_poly)

	for port_name in ports.keys():
		var pos: Vector2 = _world_to_screen(_port_position(port_name))
		if not map_rect.has_point(pos):
			continue
		var faction: String = _port_faction(port_name)
		var color: Color = FACTION_COLORS.get(faction, Color(0.9, 0.85, 0.55))
		ci.draw_circle(pos, 8.0, color)
		ci.draw_string(ThemeDB.fallback_font, pos + Vector2(12, 6), port_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)


func draw_dynamic_canvas(ci: CanvasItem) -> void:
	var map_rect := _map_rect()
	var ship_screen := _world_to_screen(current_position)
	ci.draw_circle(ship_screen, 7.0, SHIP_COLOR)
	ci.draw_string(ThemeDB.fallback_font, ship_screen + Vector2(10, -10), "Player Ship", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	_draw_wind_at_ship_guide(ci, map_rect, ship_screen)

	if is_traveling:
		var prev_world := current_position
		for i in range(route_index + 1, route_points.size()):
			var next_world := route_points[i]
			var color_idx := i - 1
			var seg_color: Color = route_segment_colors[color_idx] if color_idx >= 0 and color_idx < route_segment_colors.size() else _route_segment_color(prev_world, next_world)
			ci.draw_line(_world_to_screen(prev_world), _world_to_screen(next_world), seg_color, 2.5, true)
			prev_world = next_world
		if prev_world.distance_to(target_position) > 0.5:
			var final_color := _route_segment_color(prev_world, target_position)
			ci.draw_line(_world_to_screen(prev_world), _world_to_screen(target_position), final_color, 2.5, true)

	var controls := "Map Controls: Middle/Right drag pan | Mouse wheel zoom"
	ci.draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(16, 24), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var date_line := "Date: %s %d, %d" % [_month_name(game_month), int(floor(game_day)), game_year]
	ci.draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(16, 48), date_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var speed_line := "Travel Speed: %.1f kn" % _current_travel_speed_knots(_travel_heading_or_default(), current_position)
	ci.draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(16, 72), speed_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if is_traveling:
		var remaining_nm := _remaining_route_nautical_miles()
		var remaining_hours := _remaining_route_hours()
		var eta_days := int(floor(remaining_hours / 24.0))
		var eta_hours := int(round(fposmod(remaining_hours, 24.0)))
		var trip_line := "To destination: %.1f nm | ETA: %dd %dh" % [remaining_nm, eta_days, eta_hours]
		ci.draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(16, 96), trip_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	elif hover_has_eta and hover_eta_hours >= 0.0:
		var eta_days := int(floor(hover_eta_hours / 24.0))
		var eta_hours := int(round(fposmod(hover_eta_hours, 24.0)))
		var eta_line := "Rough ETA to cursor: %dd %dh" % [eta_days, eta_hours]
		ci.draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(16, 96), eta_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


func _wind_guide_screen_center(ship_screen: Vector2, map_rect: Rect2) -> Vector2:
	var margin := WIND_GUIDE_RADIUS + 10.0
	var c := ship_screen + Vector2(12.0, 36.0)
	c.x = clampf(c.x, map_rect.position.x + margin, map_rect.position.x + map_rect.size.x - margin)
	c.y = clampf(c.y, map_rect.position.y + margin, map_rect.position.y + map_rect.size.y - margin)
	return c


func _draw_wind_at_ship_guide(ci: CanvasItem, map_rect: Rect2, ship_screen: Vector2) -> void:
	var wind_v: Variant = _sample_wind(current_position, game_month)
	var wind_from_deg: float = 90.0
	var wind_speed_m_s: float = 6.0
	if wind_v is Dictionary:
		var wd: Dictionary = wind_v
		wind_from_deg = float(wd.get("direction_deg", 90.0))
		wind_speed_m_s = float(wd.get("speed_m_s", 6.0))
	var center := _wind_guide_screen_center(ship_screen, map_rect)
	var radius := WIND_GUIDE_RADIUS
	ci.draw_circle(center, radius, Color(0.04, 0.08, 0.12, 0.82))
	ci.draw_arc(center, radius, 0.0, TAU, 40, Color(0.75, 0.88, 1.0, 0.45), 1.5, true)
	ci.draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(0.55, 0.68, 0.85, 0.35), 1.0)
	ci.draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(0.55, 0.68, 0.85, 0.35), 1.0)
	ci.draw_string(ThemeDB.fallback_font, center + Vector2(-5.0, -radius - 5.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	ci.draw_string(ThemeDB.fallback_font, center + Vector2(-4.0, radius + 10.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	ci.draw_string(ThemeDB.fallback_font, center + Vector2(radius + 4.0, 2.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	ci.draw_string(ThemeDB.fallback_font, center + Vector2(-radius - 12.0, 2.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var wind_to_deg: float = fposmod(wind_from_deg + 180.0, 360.0)
	var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(90.0 - wind_to_deg)).normalized()
	var tip: Vector2 = center + dir * (radius - 5.0)
	var tail: Vector2 = center - dir * (radius - 10.0)
	ci.draw_line(tail, tip, Color(0.42, 0.92, 0.76, 0.95), 2.0)
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var arrow_left: Vector2 = tip - dir * 7.0 + right * 3.5
	var arrow_right: Vector2 = tip - dir * 7.0 - right * 3.5
	ci.draw_colored_polygon(PackedVector2Array([tip, arrow_left, arrow_right]), Color(0.42, 0.92, 0.76, 0.95))
	var wind_kn: float = wind_speed_m_s * 1.94384
	var line1 := "Met. wind from %.0f°" % fposmod(wind_from_deg, 360.0)
	var line2 := "%.1f m/s (~%.0f kn)" % [wind_speed_m_s, wind_kn]
	var cap_x := clampf(center.x - 78.0, map_rect.position.x + 8.0, map_rect.position.x + map_rect.size.x - 168.0)
	var cap_y := center.y + radius + 12.0
	ci.draw_string(ThemeDB.fallback_font, Vector2(cap_x, cap_y), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	ci.draw_string(ThemeDB.fallback_font, Vector2(cap_x, cap_y + 14.0), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func draw_over_canvas(ci: CanvasItem) -> void:
	var map_rect := _map_rect()
	_draw_port_faction_legend(ci, map_rect)
	var viewport: Vector2 = get_viewport_rect().size
	var top_h: float = map_rect.position.y
	var left_w: float = map_rect.position.x
	var right_x: float = map_rect.position.x + map_rect.size.x
	var bottom_y: float = map_rect.position.y + map_rect.size.y
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(viewport.x, maxf(0.0, top_h))), MAP_OUTSIDE_COLOR, true)
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(maxf(0.0, left_w), viewport.y)), MAP_OUTSIDE_COLOR, true)
	ci.draw_rect(Rect2(Vector2(right_x, 0.0), Vector2(maxf(0.0, viewport.x - right_x), viewport.y)), MAP_OUTSIDE_COLOR, true)
	ci.draw_rect(Rect2(Vector2(0.0, bottom_y), Vector2(viewport.x, maxf(0.0, viewport.y - bottom_y))), MAP_OUTSIDE_COLOR, true)

func set_target_port(port_name: String) -> bool:
	if not ports.has(port_name):
		return false
	target_port_name = port_name
	target_position = _port_position(port_name)
	var route := _find_route_world(current_position, target_position)
	if route.is_empty():
		return false
	_set_route(route)
	route_index = 0
	is_traveling = true
	travel_accumulator = 0.0
	_refresh_dynamic_canvas()
	return true

func set_sail_to_world(world: Vector2) -> bool:
	world = Vector2(
		clampf(world.x, 0.0, world_size.x),
		clampf(world.y, 0.0, world_size.y)
	)
	target_port_name = ""
	target_position = world
	var route := _find_route_world(current_position, world)
	if route.is_empty():
		return false
	_set_route(route)
	route_index = 0
	is_traveling = true
	travel_accumulator = 0.0
	_refresh_dynamic_canvas()
	return true

func is_click_on_map(local_pos: Vector2) -> bool:
	return _map_rect().has_point(local_pos)

func get_world_from_map_click(local_pos: Vector2) -> Vector2:
	var w := _screen_to_world(local_pos)
	return Vector2(
		clampf(w.x, 0.0, world_size.x),
		clampf(w.y, 0.0, world_size.y)
	)

func pick_port_from_click(local_pos: Vector2) -> String:
	var map_rect := _map_rect()
	if not map_rect.has_point(local_pos):
		return ""
	var world_pos := _screen_to_world(local_pos)
	const SNAP_SCREEN_PX := 36.0
	const SNAP_WORLD := 52.0
	var best_name := ""
	var best_metric := INF
	for port_name in ports.keys():
		var port_pos: Vector2 = _port_position(port_name)
		var screen_pos := _world_to_screen(port_pos)
		if not map_rect.has_point(screen_pos):
			continue
		var d_screen := local_pos.distance_to(screen_pos)
		var d_world := world_pos.distance_to(port_pos)
		if d_screen > SNAP_SCREEN_PX and d_world > SNAP_WORLD:
			continue
		var metric := minf(d_screen, d_world)
		if metric < best_metric:
			best_metric = metric
			best_name = port_name
	return best_name

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.15)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.15)
			return true

	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT):
		is_panning = event.pressed
		last_pan_screen_pos = event.position
		return true

	if event is InputEventMouseMotion and is_panning:
		var motion_event: InputEventMouseMotion = event
		var delta: Vector2 = motion_event.position - last_pan_screen_pos
		last_pan_screen_pos = motion_event.position
		view_offset -= delta / zoom_level
		_clamp_view_offset()
		_refresh_view_canvases()
		return true

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		_update_hover_eta(motion_event.position)
		return false

	return false

func _map_rect() -> Rect2:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = maxf(1.0, viewport.x - left_gutter_width)
	var height: float = maxf(1.0, viewport.y - log_band_height)
	return Rect2(Vector2(left_gutter_width, 0.0), Vector2(width, height))

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var rect := _map_rect()
	return rect.position + ((world_pos - view_offset) * zoom_level)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var rect := _map_rect()
	return ((screen_pos - rect.position) / zoom_level) + view_offset

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before: Vector2 = _screen_to_world(screen_pos)
	zoom_level = clamp(zoom_level * factor, min_zoom, max_zoom)
	var after: Vector2 = _screen_to_world(screen_pos)
	view_offset += before - after
	_clamp_view_offset()
	_refresh_view_canvases()

func _clamp_view_offset() -> void:
	var rect: Rect2 = _map_rect()
	var visible_world: Vector2 = rect.size / zoom_level
	var max_offset: Vector2 = world_size - visible_world
	view_offset.x = clamp(view_offset.x, 0.0, max(0.0, max_offset.x))
	view_offset.y = clamp(view_offset.y, 0.0, max(0.0, max_offset.y))

func get_port_names() -> Array[String]:
	var names: Array[String] = []
	for port_name in ports.keys():
		names.append(port_name)
	names.sort()
	return names

func set_time_scale(time_scale_value: float) -> void:
	player_time_scale = clampf(time_scale_value, 0.25, 8.0)

func set_ui_layout(sidebar_width: float, log_height: float) -> void:
	left_gutter_width = maxf(0.0, sidebar_width)
	log_band_height = maxf(0.0, log_height)
	_clamp_view_offset()
	_refresh_view_canvases()

func get_current_heading_vector() -> Vector2:
	return _travel_heading_or_default()

func get_current_speed_knots() -> float:
	return _current_travel_speed_knots(_travel_heading_or_default(), current_position)

func get_current_wind() -> Dictionary:
	return _sample_wind(current_position, game_month)

func is_near_land(radius_world: float = 80.0) -> bool:
	var samples: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(radius_world, 0.0),
		Vector2(-radius_world, 0.0),
		Vector2(0.0, radius_world),
		Vector2(0.0, -radius_world),
		Vector2(radius_world * 0.7, radius_world * 0.7),
		Vector2(-radius_world * 0.7, radius_world * 0.7),
		Vector2(radius_world * 0.7, -radius_world * 0.7),
		Vector2(-radius_world * 0.7, -radius_world * 0.7)
	]
	for offset in samples:
		if _is_land(current_position + offset):
			return true
	return false

func resume_travel_to_target() -> void:
	if current_position.distance_to(target_position) > 0.01 and not route_points.is_empty():
		is_traveling = true
		_refresh_dynamic_canvas()

func get_save_state() -> Dictionary:
	return {
		"current_position": current_position,
		"target_port_name": target_port_name,
		"target_position": target_position,
		"is_traveling": is_traveling,
		"travel_accumulator": travel_accumulator,
		"zoom_level": zoom_level,
		"view_offset": view_offset,
		"game_year": game_year,
		"game_month": game_month,
		"game_day": game_day,
		"player_time_scale": player_time_scale,
		"route_points": route_points,
		"route_index": route_index
	}

func apply_save_state(state: Dictionary) -> void:
	if state.has("current_position") and state["current_position"] is Vector2:
		current_position = state["current_position"]
	if state.has("target_port_name"):
		target_port_name = str(state["target_port_name"])
	if state.has("target_position") and state["target_position"] is Vector2:
		target_position = state["target_position"]
	if state.has("is_traveling"):
		is_traveling = bool(state["is_traveling"])
	if state.has("travel_accumulator"):
		travel_accumulator = float(state["travel_accumulator"])
	if state.has("zoom_level"):
		zoom_level = clampf(float(state["zoom_level"]), min_zoom, max_zoom)
	if state.has("view_offset") and state["view_offset"] is Vector2:
		view_offset = state["view_offset"]
	if state.has("game_year"):
		game_year = int(state["game_year"])
	if state.has("game_month"):
		game_month = clampi(int(state["game_month"]), 1, 12)
	if state.has("game_day"):
		game_day = clampf(float(state["game_day"]), 1.0, 31.0)
	if state.has("player_time_scale"):
		set_time_scale(float(state["player_time_scale"]))
	if state.has("route_points") and state["route_points"] is Array:
		var restored_route: Array[Vector2] = []
		for point in state["route_points"]:
			if point is Vector2:
				restored_route.append(point)
		_set_route(restored_route)
	if state.has("route_index"):
		route_index = max(0, int(state["route_index"]))
	_clamp_view_offset()
	_refresh_view_canvases()

func _load_land_data() -> void:
	if not FileAccess.file_exists(LAND_DATA_PATH):
		return

	var file: FileAccess = FileAccess.open(LAND_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return

	var payload: Dictionary = parsed
	if payload.has("world_size") and payload["world_size"] is Array:
		var ws: Array = payload["world_size"]
		if ws.size() >= 2:
			world_size = Vector2(float(ws[0]), float(ws[1]))

	if not (payload.has("polygons") and payload["polygons"] is Array):
		return

	var polygons_variant: Array = payload["polygons"]
	var loaded: Array[PackedVector2Array] = []
	for polygon_variant in polygons_variant:
		if not (polygon_variant is Array):
			continue
		var polygon_points: Array = polygon_variant
		var poly := PackedVector2Array()
		for point_variant in polygon_points:
			if not (point_variant is Array):
				continue
			var point_arr: Array = point_variant
			if point_arr.size() < 2:
				continue
			poly.append(Vector2(float(point_arr[0]), float(point_arr[1])))
		if poly.size() >= 3:
			loaded.append(poly)

	if not loaded.is_empty():
		americas_polygons = loaded

func _load_land_baked() -> void:
	land_baked_texture = null
	use_vector_land = true
	_land_collision_image = null
	if not ResourceLoader.exists(LAND_BAKED_PATH):
		return
	var resource: Resource = load(LAND_BAKED_PATH)
	if resource is Texture2D:
		land_baked_texture = resource as Texture2D
		use_vector_land = false
		var img: Image = land_baked_texture.get_image()
		if img != null and img.get_width() > 0 and img.get_height() > 0:
			_land_collision_image = img

func _draw_baked_land_layer(ci: CanvasItem, map_rect: Rect2) -> void:
	if land_baked_texture == null:
		return
	var tw: float = float(land_baked_texture.get_width())
	var th: float = float(land_baked_texture.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var s: Vector2 = Vector2(tw / world_size.x, th / world_size.y)
	var vis: Vector2 = map_rect.size / zoom_level
	var v0: Vector2 = view_offset
	var src := Rect2(v0.x * s.x, v0.y * s.y, vis.x * s.x, vis.y * s.y)
	var tex_bounds := Rect2(0.0, 0.0, tw, th)
	var src_c: Rect2 = src.intersection(tex_bounds)
	if src_c.size.x <= 0.0 or src_c.size.y <= 0.0:
		return
	var rel_pos: Vector2 = (src_c.position - src.position) / src.size
	var rel_size: Vector2 = src_c.size / src.size
	var dest := Rect2(
		map_rect.position + rel_pos * map_rect.size,
		rel_size * map_rect.size
	)
	if dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	ci.draw_texture_rect_region(land_baked_texture, dest, src_c, Color(1, 1, 1, 1), false, false)

func _draw_vector_land(ci: CanvasItem, map_poly: PackedVector2Array) -> void:
	for polygon in americas_polygons:
		var transformed := PackedVector2Array()
		transformed.resize(polygon.size())
		for i in range(polygon.size()):
			transformed[i] = _world_to_screen(polygon[i])
		var clipped_parts: Array = Geometry2D.intersect_polygons(transformed, map_poly)
		for part_variant in clipped_parts:
			if not (part_variant is PackedVector2Array):
				continue
			var part: PackedVector2Array = part_variant
			if part.size() >= 3:
				ci.draw_colored_polygon(part, LAND_COLOR)
			if part.size() >= 2:
				ci.draw_polyline(part, LAND_SHADE, 2.0, true)

func _build_navigation_grid() -> void:
	nav_cols = int(ceil(world_size.x / nav_cell_size))
	nav_rows = int(ceil(world_size.y / nav_cell_size))
	nav_blocked.clear()
	for row in range(nav_rows):
		for col in range(nav_cols):
			var cell := Vector2i(col, row)
			if _cell_has_land(cell):
				nav_blocked[cell] = true

func _cell_has_land(cell: Vector2i) -> bool:
	var center := _cell_to_world(cell)
	var half := nav_cell_size * 0.45
	for gx in range(-1, 2):
		for gy in range(-1, 2):
			var p := center + Vector2(float(gx) * half, float(gy) * half)
			if _is_land(p):
				return true
	return false

func _is_land(world_pos: Vector2) -> bool:
	var img := _land_collision_image
	if img != null and img.get_width() > 0 and img.get_height() > 0:
		var iw := img.get_width()
		var ih := img.get_height()
		if iw > 0 and ih > 0:
			var ix := clampi(int(floor(world_pos.x / world_size.x * float(iw))), 0, iw - 1)
			var iy := clampi(int(floor(world_pos.y / world_size.y * float(ih))), 0, ih - 1)
			return img.get_pixel(ix, iy).get_luminance() > 0.2
	for polygon in americas_polygons:
		if Geometry2D.is_point_in_polygon(world_pos, polygon):
			return true
	return false

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(world_pos.x / nav_cell_size)), 0, max(0, nav_cols - 1)),
		clampi(int(floor(world_pos.y / nav_cell_size)), 0, max(0, nav_rows - 1))
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * nav_cell_size,
		(float(cell.y) + 0.5) * nav_cell_size
	)

func _is_cell_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= nav_cols or cell.y >= nav_rows:
		return false
	return not nav_blocked.has(cell)

func _nearest_walkable_cell(from_cell: Vector2i, max_radius: int = 6) -> Vector2i:
	if _is_cell_walkable(from_cell):
		return from_cell
	for radius in range(1, max_radius + 1):
		for y in range(from_cell.y - radius, from_cell.y + radius + 1):
			for x in range(from_cell.x - radius, from_cell.x + radius + 1):
				var cell := Vector2i(x, y)
				if _is_cell_walkable(cell):
					return cell
	return Vector2i(-1, -1)

func _nearest_walkable_cell_with_target_los(target_world: Vector2, max_radius: int = 12) -> Vector2i:
	var target_cell: Vector2i = _world_to_cell(target_world)
	var fallback := _nearest_walkable_cell(target_cell, max_radius)
	for radius in range(0, max_radius + 1):
		for y in range(target_cell.y - radius, target_cell.y + radius + 1):
			for x in range(target_cell.x - radius, target_cell.x + radius + 1):
				var cell := Vector2i(x, y)
				if not _is_cell_walkable(cell):
					continue
				if not _segment_hits_land(_cell_to_world(cell), target_world):
					return cell
	return fallback

func _find_route_world(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	if nav_cols <= 0 or nav_rows <= 0:
		return []
	var start: Vector2i = _nearest_walkable_cell(_world_to_cell(start_world))
	var goal: Vector2i = _nearest_walkable_cell_with_target_los(end_world)
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return []

	var open: Array[Vector2i] = [start]
	var came_from := {}
	var g_cost := {start: 0.0}
	var f_cost := {start: _heuristic_hours(start, goal)}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]

	while not open.is_empty():
		var current: Vector2i = _pop_lowest_f(open, f_cost)
		if current == goal:
			return _reconstruct_route(came_from, current, start_world, end_world)

		for dir in directions:
			var next: Vector2i = current + dir
			if not _is_cell_walkable(next):
				continue
			if absi(dir.x) == 1 and absi(dir.y) == 1:
				var adj_a: Vector2i = current + Vector2i(dir.x, 0)
				var adj_b: Vector2i = current + Vector2i(0, dir.y)
				if not _is_cell_walkable(adj_a) or not _is_cell_walkable(adj_b):
					continue

			var a: Vector2 = _cell_to_world(current)
			var b: Vector2 = _cell_to_world(next)
			if _segment_hits_land(a, b):
				continue
			var step_hours: float = _edge_hours(a, b)
			var tentative: float = float(g_cost[current]) + step_hours
			if (not g_cost.has(next)) or tentative < float(g_cost[next]):
				came_from[next] = current
				g_cost[next] = tentative
				f_cost[next] = tentative + _heuristic_hours(next, goal)
				if not open.has(next):
					open.append(next)

	return []

func _pop_lowest_f(open: Array[Vector2i], f_cost: Dictionary) -> Vector2i:
	var best_i := 0
	var best_f := float(f_cost[open[0]])
	for i in range(1, open.size()):
		var node := open[i]
		var f := float(f_cost[node])
		if f < best_f:
			best_f = f
			best_i = i
	var best_node := open[best_i]
	open.remove_at(best_i)
	return best_node

func _heuristic_hours(a: Vector2i, b: Vector2i) -> float:
	var dist_nm := _nautical_miles_between_world(_cell_to_world(a), _cell_to_world(b))
	var best_speed_knots := maxf(3.0, _base_ship_knots() * ship_speed_multiplier * 1.5)
	return dist_nm / best_speed_knots

func _edge_hours(a: Vector2, b: Vector2) -> float:
	var heading := (b - a).normalized()
	var speed_knots := _current_travel_speed_knots(heading, (a + b) * 0.5)
	var dist_nm := _nautical_miles_between_world(a, b)
	return dist_nm / maxf(0.5, speed_knots)

func _segment_hits_land(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var spacing: float = maxf(5.0, nav_cell_size / 8.0)
	var steps := maxi(4, int(ceil(dist / spacing)))
	var tangent := b - a
	var normal := Vector2.ZERO
	if tangent.length_squared() > 0.0001:
		normal = Vector2(-tangent.y, tangent.x).normalized()
	var lateral: float = nav_cell_size * 0.42
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		var offsets: Array[float] = [0.0]
		if lateral > 0.01 and normal.length_squared() > 0.0001:
			offsets = [-lateral, 0.0, lateral]
		for off in offsets:
			var sample := p if off == 0.0 else p + normal * off
			if _is_land(sample):
				return true
	return false

func _reconstruct_route(came_from: Dictionary, current: Vector2i, start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	var cells: Array[Vector2i] = [current]
	var node := current
	while came_from.has(node):
		node = came_from[node]
		cells.append(node)
	cells.reverse()

	var points: Array[Vector2] = []
	var start_cell_world := _cell_to_world(cells[0])
	var first := start_world
	if _segment_hits_land(start_world, start_cell_world):
		first = start_cell_world
	points.append(first)
	for cell in cells:
		var cw := _cell_to_world(cell)
		if points[points.size() - 1].distance_to(cw) > 0.5:
			points.append(cw)
	var goal_cell_world := _cell_to_world(cells[cells.size() - 1])
	var last := end_world
	if _segment_hits_land(goal_cell_world, end_world):
		last = goal_cell_world
	if points[points.size() - 1].distance_to(last) > 0.5:
		points.append(last)
	return points

func _heuristic_hover_travel_hours(from_world: Vector2, to_world: Vector2) -> float:
	var dist_nm := _nautical_miles_between_world(from_world, to_world)
	var knots := maxf(2.2, _base_ship_knots() * ship_speed_multiplier * 0.88)
	return (dist_nm / knots) * 1.28

func _update_hover_eta(screen_pos: Vector2) -> void:
	if is_traveling:
		if hover_has_eta or hover_eta_hours >= 0.0:
			hover_has_eta = false
			hover_eta_hours = -1.0
		last_hover_cell = Vector2i(-9999, -9999)
		next_hover_eta_msec = 0
		return

	var map_rect := _map_rect()
	if not map_rect.has_point(screen_pos):
		last_hover_cell = Vector2i(-9999, -9999)
		next_hover_eta_msec = 0
		if hover_has_eta or hover_eta_hours >= 0.0:
			hover_has_eta = false
			hover_eta_hours = -1.0
			_refresh_dynamic_canvas()
		return

	var world := _screen_to_world(screen_pos)
	hover_world_pos = world
	if _is_land(world):
		if hover_has_eta or hover_eta_hours >= 0.0:
			hover_has_eta = false
			hover_eta_hours = -1.0
			_refresh_dynamic_canvas()
		return
	var hover_cell := _world_to_cell(world)
	var now_msec: int = Time.get_ticks_msec()
	if hover_cell == last_hover_cell and now_msec < next_hover_eta_msec:
		return
	last_hover_cell = hover_cell
	next_hover_eta_msec = now_msec + (120 if is_traveling else 120)
	# Full A* on hover was the main map bottleneck; distance heuristic is enough for cursor preview.
	var hours := _heuristic_hover_travel_hours(current_position, world)
	var changed := (not hover_has_eta) or absf(hover_eta_hours - hours) > 1.25
	hover_has_eta = true
	hover_eta_hours = hours
	if changed:
		_refresh_dynamic_canvas()

func _set_route(route: Array[Vector2]) -> void:
	route_points = route
	_rebuild_route_segment_colors()

func _rebuild_route_segment_colors() -> void:
	route_segment_colors.clear()
	if route_points.size() < 2:
		return
	for i in range(route_points.size() - 1):
		route_segment_colors.append(_route_segment_color(route_points[i], route_points[i + 1]))

func _remaining_route_nautical_miles() -> float:
	if not is_traveling:
		return 0.0
	var total_nm := 0.0
	var prev := current_position
	for i in range(route_index + 1, route_points.size()):
		var next_world := route_points[i]
		total_nm += _nautical_miles_between_world(prev, next_world)
		prev = next_world
	if prev.distance_to(target_position) > 0.5:
		total_nm += _nautical_miles_between_world(prev, target_position)
	return total_nm

func _remaining_route_hours() -> float:
	if not is_traveling:
		return 0.0
	var total_hours := 0.0
	var prev := current_position
	for i in range(route_index + 1, route_points.size()):
		var next_world := route_points[i]
		total_hours += _edge_hours(prev, next_world)
		prev = next_world
	if prev.distance_to(target_position) > 0.5:
		total_hours += _edge_hours(prev, target_position)
	return total_hours

func _load_wind_data() -> void:
	if not FileAccess.file_exists(WIND_DATA_PATH):
		return

	var file: FileAccess = FileAccess.open(WIND_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var payload: Dictionary = parsed

	if payload.has("grid") and payload["grid"] is Dictionary:
		var grid: Dictionary = payload["grid"]
		if grid.has("cols"):
			wind_cols = int(grid["cols"])
		if grid.has("rows"):
			wind_rows = int(grid["rows"])

	if not (payload.has("tiles") and payload["tiles"] is Array):
		return

	wind_tiles.clear()
	var tiles_arr: Array = payload["tiles"]
	for tile_variant in tiles_arr:
		if not (tile_variant is Dictionary):
			continue
		var tile: Dictionary = tile_variant
		if not (tile.has("col") and tile.has("row") and tile.has("monthly")):
			continue
		var key := Vector2i(int(tile["col"]), int(tile["row"]))
		wind_tiles[key] = tile["monthly"]

func _current_travel_speed_knots(heading: Vector2, sample_world: Vector2) -> float:
	var base_speed := _base_ship_knots() * ship_speed_multiplier
	var wind := _sample_wind(sample_world, game_month)
	var wind_speed: float = wind["speed_m_s"]
	var wind_from_deg: float = wind["direction_deg"]
	var wind_to_deg := fposmod(wind_from_deg + 180.0, 360.0)
	var heading_deg := _vector_to_bearing_deg(heading)
	var diff := absf(_angle_delta_deg(heading_deg, wind_to_deg))

	# Angle factor: downwind faster, upwind slower.
	var angle_factor := lerpf(1.35, 0.45, diff / 180.0)
	# 1 m/s ~ 1.94 knots; apply bounded wind-strength modifier.
	var wind_knots := wind_speed * 1.94384
	var speed_factor := clampf(0.75 + (wind_knots / 24.0), 0.55, 1.35)
	return maxf(1.5, base_speed * angle_factor * speed_factor)

func _current_travel_speed_map_units_per_second(heading: Vector2) -> float:
	var knots := _current_travel_speed_knots(heading, current_position)
	var nm_per_real_second := knots * in_game_hours_per_real_second
	return nm_per_real_second * _map_units_per_nautical_mile_near(current_position)

func _sample_wind(world_pos: Vector2, month: int) -> Dictionary:
	if wind_cols <= 0 or wind_rows <= 0 or wind_tiles.is_empty():
		return {"speed_m_s": 6.0, "direction_deg": 90.0}

	var tile_w: float = world_size.x / float(wind_cols)
	var tile_h: float = world_size.y / float(wind_rows)
	var col := int(floor(world_pos.x / tile_w))
	var row := int(floor(world_pos.y / tile_h))
	col = clampi(col, 0, wind_cols - 1)
	row = clampi(row, 0, wind_rows - 1)

	var key := Vector2i(col, row)
	if not wind_tiles.has(key):
		return {"speed_m_s": 6.0, "direction_deg": 90.0}

	var monthly_variant: Variant = wind_tiles[key]
	if not (monthly_variant is Dictionary):
		return {"speed_m_s": 6.0, "direction_deg": 90.0}
	var monthly: Dictionary = monthly_variant

	var mkey := "%02d" % month
	if not monthly.has(mkey):
		return {"speed_m_s": 6.0, "direction_deg": 90.0}

	var wind_variant: Variant = monthly[mkey]
	if not (wind_variant is Dictionary):
		return {"speed_m_s": 6.0, "direction_deg": 90.0}
	return wind_variant

func _advance_game_time(hours: float) -> void:
	game_day += hours / 24.0
	while game_day > float(_days_in_month(game_month)):
		game_day -= float(_days_in_month(game_month))
		game_month += 1
		if game_month > 12:
			game_month = 1
			game_year += 1
		var month_index := game_year * 12 + game_month
		emit_signal("game_month_advanced", month_index)

func _days_in_month(month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 28
		_:
			return 30

func _month_name(month: int) -> String:
	var names := [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	if month < 1 or month > 12:
		return "Unknown"
	return names[month - 1]

func _vector_to_bearing_deg(v: Vector2) -> float:
	# 0 = north, 90 = east, matching meteorological bearings.
	return fposmod(90.0 - rad_to_deg(atan2(v.y, v.x)), 360.0)

func _angle_delta_deg(a: float, b: float) -> float:
	var d := fposmod(b - a + 540.0, 360.0) - 180.0
	return d

func _travel_heading_or_default() -> Vector2:
	if is_traveling:
		# Must match the segment we're actually sailing (next waypoint), not bearing to the
		# final port — otherwise zig-zag routes swing "heading" each frame and wind speed jitters.
		if route_points.size() >= 2 and route_index < route_points.size() - 1:
			var ahead: Vector2 = route_points[route_index + 1] - current_position
			if ahead.length_squared() > 0.000001:
				return ahead.normalized()
		var to_dest := target_position - current_position
		if to_dest.length_squared() > 0.000001:
			return to_dest.normalized()
	return Vector2.RIGHT

func _route_segment_color(a: Vector2, b: Vector2) -> Color:
	var heading := (b - a).normalized()
	var midpoint := (a + b) * 0.5
	var wind := _sample_wind(midpoint, game_month)
	var wind_to_deg := fposmod(float(wind["direction_deg"]) + 180.0, 360.0)
	var heading_deg := _vector_to_bearing_deg(heading)
	var diff := absf(_angle_delta_deg(heading_deg, wind_to_deg))

	# 0 deg = fully with wind, 180 = directly against.
	if diff <= 55.0:
		return Color(0.35, 0.95, 0.45, 0.9)
	if diff <= 120.0:
		return Color(0.95, 0.85, 0.35, 0.9)
	return Color(0.95, 0.4, 0.35, 0.9)

func _base_ship_knots() -> float:
	match ship_class:
		"Sloop":
			return 5.2
		"Brig":
			return 4.8
		"Frigate":
			return 4.6
		"Merchantman":
			return 3.9
		_:
			return 4.6

func _apply_historical_speed_calibration() -> void:
	var ratios: Array[float] = []
	for entry_variant in HISTORICAL_BENCHMARKS:
		var entry: Dictionary = entry_variant
		var from_name: String = entry["from"]
		var to_name: String = entry["to"]
		var target_days: float = float(entry["days"])
		if target_days <= 0.0:
			continue
		if not ports.has(from_name) or not ports.has(to_name):
			continue
		var route := _find_route_world(_port_position(from_name), _port_position(to_name))
		if route.is_empty():
			continue
		var predicted_hours := 0.0
		for i in range(route.size() - 1):
			predicted_hours += _edge_hours(route[i], route[i + 1])
		var target_hours := target_days * 24.0
		if target_hours > 0.0:
			ratios.append(predicted_hours / target_hours)

	if ratios.is_empty():
		return

	var avg_ratio := 0.0
	for r in ratios:
		avg_ratio += r
	avg_ratio /= float(ratios.size())
	ship_speed_multiplier = clampf(ship_speed_multiplier * avg_ratio, 0.4, 3.5)

func _world_to_lonlat(world_pos: Vector2) -> Vector2:
	var lon := -102.0 + (world_pos.x / world_size.x) * 46.0
	var lat := 36.0 - (world_pos.y / world_size.y) * 32.0
	return Vector2(lon, lat)

func _nautical_miles_between_world(a: Vector2, b: Vector2) -> float:
	var ll_a := _world_to_lonlat(a)
	var ll_b := _world_to_lonlat(b)
	return _haversine_nm(ll_a.y, ll_a.x, ll_b.y, ll_b.x)

func _haversine_nm(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var lat1 := deg_to_rad(lat1_deg)
	var lon1 := deg_to_rad(lon1_deg)
	var lat2 := deg_to_rad(lat2_deg)
	var lon2 := deg_to_rad(lon2_deg)
	var dlat := lat2 - lat1
	var dlon := lon2 - lon1
	var s := sin(dlat * 0.5)
	var c := sin(dlon * 0.5)
	var h := s * s + cos(lat1) * cos(lat2) * c * c
	var earth_radius_nm := 3440.065
	return 2.0 * earth_radius_nm * asin(sqrt(maxf(0.0, minf(1.0, h))))

func _map_units_per_nautical_mile_near(world_pos: Vector2) -> float:
	var p0 := world_pos
	var p1 := world_pos + Vector2(80.0, 0.0)
	var nm := _nautical_miles_between_world(p0, p1)
	if nm <= 0.001:
		return 1.0
	return 80.0 / nm

func set_port_owner_overrides(owners: Dictionary) -> void:
	port_owner_overrides = owners.duplicate(true)
	_refresh_view_canvases()

func _port_position(port_name: String) -> Vector2:
	var data_variant: Variant = ports[port_name]
	if data_variant is Dictionary:
		var data: Dictionary = data_variant
		if data.has("pos"):
			return data["pos"]
	return Vector2.ZERO

func _port_faction(port_name: String) -> String:
	if port_owner_overrides.has(port_name):
		return str(port_owner_overrides[port_name])
	var data_variant: Variant = ports[port_name]
	if data_variant is Dictionary:
		var data: Dictionary = data_variant
		if data.has("faction"):
			return str(data["faction"])
	return "Unknown"

func _draw_port_faction_legend(ci: CanvasItem, map_rect: Rect2) -> void:
	var legend_size: Vector2 = Vector2(206.0, 104.0)
	var margin: Vector2 = Vector2(8.0, 6.0)
	# Keep this on the map's left side to avoid right-edge clipping on narrow windows.
	var desired_panel_pos: Vector2 = map_rect.position + Vector2(12.0, 108.0)
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var safe_rect: Rect2 = map_rect.intersection(viewport_rect)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return
	var min_pos: Vector2 = safe_rect.position + margin
	var max_pos: Vector2 = safe_rect.position + safe_rect.size - legend_size - margin
	var panel_pos: Vector2 = Vector2(
		clampf(desired_panel_pos.x, min_pos.x, maxf(min_pos.x, max_pos.x)),
		clampf(desired_panel_pos.y, min_pos.y, maxf(min_pos.y, max_pos.y))
	)
	var panel_rect: Rect2 = Rect2(panel_pos, legend_size)
	ci.draw_rect(panel_rect, Color(0, 0, 0, 0.35), true)
	var base: Vector2 = panel_rect.position + Vector2(8.0, 8.0)
	ci.draw_string(ThemeDB.fallback_font, base + Vector2(0, 14), "Port Factions", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var factions: Array[String] = ["Spanish", "English", "French", "Dutch"]
	for i in range(factions.size()):
		var faction: String = factions[i]
		var y: float = base.y + 34.0 + float(i) * 16.0
		var color: Color = FACTION_COLORS[faction]
		ci.draw_circle(Vector2(base.x + 7.0, y - 4.0), 4.0, color)
		ci.draw_string(ThemeDB.fallback_font, Vector2(base.x + 18.0, y), faction, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
