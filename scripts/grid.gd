extends Node2D
class_name BattleGrid

@export var width: int = 14
@export var height: int = 10
@export var tile_size: int = 64

var highlighted_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = Vector2i(-1, -1)
var blocked_cells: Dictionary = {}
var gangplank_cells: Dictionary = {}
var objective_cells: Dictionary = {}
var chokepoint_cells: Dictionary = {}

const GRID_COLOR := Color(0.28, 0.3, 0.36)
const BG_COLOR := Color(0.12, 0.13, 0.16)
const MOVE_HIGHLIGHT := Color(0.3, 0.65, 1.0, 0.25)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const BLOCKED_COLOR := Color(0.2, 0.17, 0.12, 0.9)
const GANGPLANK_COLOR := Color(0.62, 0.47, 0.28, 0.75)
const OBJECTIVE_COLOR := Color(0.95, 0.8, 0.35, 0.8)
const CHOKEPOINT_COLOR := Color(0.4, 0.28, 0.16, 0.5)

func _draw() -> void:
	var board_size := Vector2(width * tile_size, height * tile_size)
	draw_rect(Rect2(Vector2.ZERO, board_size), BG_COLOR, true)

	for cell in chokepoint_cells.keys():
		var choke_rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(choke_rect, CHOKEPOINT_COLOR, true)

	for cell in gangplank_cells.keys():
		var plank_rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(plank_rect, GANGPLANK_COLOR, true)

	for cell in objective_cells.keys():
		var obj_rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(obj_rect, OBJECTIVE_COLOR, true)

	for cell in blocked_cells.keys():
		var obstacle_rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(obstacle_rect, BLOCKED_COLOR, true)

	for cell in highlighted_cells:
		var rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(rect, MOVE_HIGHLIGHT, true)

	if is_in_bounds(hovered_cell):
		var hover_rect := Rect2(Vector2(hovered_cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(hover_rect, HOVER_COLOR, true)

	for x in range(width + 1):
		var from := Vector2(x * tile_size, 0)
		var to := Vector2(x * tile_size, height * tile_size)
		draw_line(from, to, GRID_COLOR, 1.0)

	for y in range(height + 1):
		var from := Vector2(0, y * tile_size)
		var to := Vector2(width * tile_size, y * tile_size)
		draw_line(from, to, GRID_COLOR, 1.0)

func local_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(local_pos.x / tile_size)),
		int(floor(local_pos.y / tile_size))
	)

func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell) * tile_size

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(cell_to_local(cell))

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func set_hovered_cell(cell: Vector2i) -> void:
	if hovered_cell == cell:
		return
	hovered_cell = cell
	queue_redraw()

func set_highlighted(cells: Array[Vector2i]) -> void:
	highlighted_cells = cells
	queue_redraw()

func set_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells.clear()
	for cell in cells:
		blocked_cells[cell] = true
	queue_redraw()

func set_gangplank_cells(cells: Array[Vector2i]) -> void:
	gangplank_cells.clear()
	for cell in cells:
		gangplank_cells[cell] = true
	queue_redraw()

func set_objective_cells(cells: Array[Vector2i]) -> void:
	objective_cells.clear()
	for cell in cells:
		objective_cells[cell] = true
	queue_redraw()

func set_chokepoint_cells(cells: Array[Vector2i]) -> void:
	chokepoint_cells.clear()
	for cell in cells:
		chokepoint_cells[cell] = true
	queue_redraw()

func is_cell_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)
