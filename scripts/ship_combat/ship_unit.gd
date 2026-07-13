extends Node2D
class_name ShipUnit

var data: ShipData
var current_plan: TurnPlan
var grid_pos: Vector2
var heading: Vector2 = Vector2.RIGHT
var _start_pose: Dictionary
var _end_pose: Dictionary

# Ship silhouette dimensions (local space, bow pointing +X).
const HULL_LENGTH := 46.0
const HULL_WIDTH := 18.0

var hull_color: Color = Color(0.42, 0.29, 0.16)
var deck_color: Color = Color(0.62, 0.45, 0.27)
var sail_color: Color = Color(0.94, 0.93, 0.88)
var accent_color: Color = Color(0.85, 0.85, 0.85)

# World-space waypoints used to animate the ship during the execution phase.
var _exec_points: PackedVector2Array = PackedVector2Array()
var _exec_headings: Array = []
var _exec_seg_len: PackedFloat32Array = PackedFloat32Array()
var _exec_total_len: float = 0.0

func _ready() -> void:
	z_index = 10
	update_visuals()

func set_grid_pos(p: Vector2) -> void:
	grid_pos = p
	position = IsoHelper.grid_to_world(p)
	update_visuals()

# Converts the grid-space heading into a normalized world-space direction.
func _world_heading() -> Vector2:
	var wh: Vector2 = IsoHelper.grid_to_world(heading)
	if wh.length() < 0.001:
		return Vector2.RIGHT
	return wh.normalized()

func update_visuals() -> void:
	rotation = _world_heading().angle()
	queue_redraw()

func rotate_towards(p: Vector2) -> void:
	var dir: Vector2 = p - position
	if dir.length() > 0.001:
		rotation = dir.angle()

# Builds the world-space path (and per-segment headings/lengths) that the ship
# will follow while the turn resolves.
func prepare_resolution() -> void:
	_exec_points = PackedVector2Array()
	_exec_headings = []
	_exec_seg_len = PackedFloat32Array()
	_exec_total_len = 0.0

	var path: Array = []
	if current_plan and current_plan.path.size() > 0:
		for cell in current_plan.path:
			path.append(Vector2i(cell))
	else:
		path.append(Vector2i(grid_pos))

	for cell in path:
		_exec_points.append(IsoHelper.grid_to_world(Vector2(cell)))

	for i in range(_exec_points.size()):
		var h: Vector2
		if i < _exec_points.size() - 1:
			h = _exec_points[i + 1] - _exec_points[i]
		elif _exec_points.size() >= 2:
			h = _exec_points[i] - _exec_points[i - 1]
		else:
			h = _world_heading()
		if h.length() < 0.001:
			h = _world_heading()
		_exec_headings.append(h.normalized())

	for i in range(_exec_points.size() - 1):
		var seg: float = _exec_points[i].distance_to(_exec_points[i + 1])
		_exec_seg_len.append(seg)
		_exec_total_len += seg

	_start_pose = {"position": _exec_points[0], "rotation": float(_exec_headings[0].angle())}
	var last: int = _exec_points.size() - 1
	_end_pose = {"position": _exec_points[last], "rotation": float(_exec_headings[last].angle())}

# Moves the ship along its planned path. `t` is normalized turn progress (0..1).
func interpolate_pose(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	if _exec_points.is_empty():
		return
	if _exec_points.size() == 1 or _exec_total_len <= 0.001:
		position = _exec_points[0]
		rotation = _exec_headings[0].angle()
		queue_redraw()
		return

	var target_dist: float = t * _exec_total_len
	var accum: float = 0.0
	for i in range(_exec_seg_len.size()):
		var seg: float = _exec_seg_len[i]
		if accum + seg >= target_dist or i == _exec_seg_len.size() - 1:
			var local_t: float = 0.0
			if seg > 0.001:
				local_t = clampf((target_dist - accum) / seg, 0.0, 1.0)
			position = _exec_points[i].lerp(_exec_points[i + 1], local_t)
			rotation = _exec_headings[i + 1].angle()
			break
		accum += seg
	queue_redraw()

# Snaps the ship to the end of its planned path and syncs grid_pos/heading so the
# next planning phase starts from the correct cell.
func finalize_resolution() -> void:
	if current_plan and current_plan.path.size() > 0:
		var last_cell: Vector2i = current_plan.path.back()
		grid_pos = Vector2(last_cell)
		position = IsoHelper.grid_to_world(grid_pos)
		if current_plan.path.size() >= 2:
			var a: Vector2 = Vector2(current_plan.path[-2])
			var b: Vector2 = Vector2(current_plan.path[-1])
			if (b - a).length() > 0.001:
				heading = (b - a).normalized()
	update_visuals()

func _draw() -> void:
	var l: float = HULL_LENGTH
	var w: float = HULL_WIDTH

	var hull := PackedVector2Array([
		Vector2(l * 0.5, 0.0),
		Vector2(l * 0.18, -w * 0.5),
		Vector2(-l * 0.5, -w * 0.38),
		Vector2(-l * 0.5, w * 0.38),
		Vector2(l * 0.18, w * 0.5),
	])
	draw_colored_polygon(hull, hull_color)

	# Deck inset.
	var deck := PackedVector2Array([
		Vector2(l * 0.34, 0.0),
		Vector2(l * 0.1, -w * 0.34),
		Vector2(-l * 0.38, -w * 0.26),
		Vector2(-l * 0.38, w * 0.26),
		Vector2(l * 0.1, w * 0.34),
	])
	draw_colored_polygon(deck, deck_color)

	# Sail (triangle pointing toward the bow).
	var sail := PackedVector2Array([
		Vector2(-l * 0.12, -w * 0.32),
		Vector2(l * 0.26, 0.0),
		Vector2(-l * 0.12, w * 0.32),
	])
	draw_colored_polygon(sail, sail_color)

	# Accent outline (team color).
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, accent_color, 2.0)
