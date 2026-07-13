extends TileMapLayer
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
var deck_cells: Dictionary = {}

const GRID_COLOR := Color(0.28, 0.3, 0.36)
const WATER_COLOR := Color(0.04, 0.08, 0.12)
const MOVE_HIGHLIGHT := Color(0.3, 0.65, 1.0, 0.25)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const BLOCKED_COLOR := Color(0.2, 0.17, 0.12, 0.9)
const GANGPLANK_COLOR := Color(0.62, 0.47, 0.28, 0.75)
const OBJECTIVE_COLOR := Color(0.95, 0.8, 0.35, 0.8)
const CHOKEPOINT_COLOR := Color(0.4, 0.28, 0.16, 0.5)

var DECK_TEXTURE: Texture2D = null
var WATER_TEXTURE: Texture2D = null
var COBBLE_TEXTURE: Texture2D = null

func _ready() -> void:
	DECK_TEXTURE = load("res://assets/generated/tile_wood_deck.png") as Texture2D
	WATER_TEXTURE = load("res://assets/generated/tile_water.png") as Texture2D
	COBBLE_TEXTURE = load("res://assets/generated/tile_town_cobble.png") as Texture2D
	# Configure TileSet if not already set up
	if not tile_set:
		tile_set = TileSet.new()
		tile_set.tile_size = Vector2i(tile_size, tile_size)
	
	# We'll still use _draw for overlays like highlights and grid lines
	# but the base tiles will be in the TileMapLayer.
	z_index = -1

func update_grid_tiles() -> void:
	clear()
	# In a real app, we'd use atlas sources. For now, we'll stick to _draw 
	# if we don't want to overhaul the asset pipeline to use TileSetAtlasSource.
	# Actually, the user asked for efficiency. 
	# If we keep _draw but optimize the loops, it might be enough.
	# But let's stick to Node2D for now if TileSet setup is too complex to automate here
	# without existing atlas resources.
	queue_redraw()

func _draw() -> void:
	var board_size_vec := Vector2(width * tile_size, height * tile_size)
	if WATER_TEXTURE:
		draw_texture_rect(WATER_TEXTURE, Rect2(Vector2.ZERO, board_size_vec), true)

	var draw_cells_list: Array[Vector2i] = []
	if deck_cells.is_empty():
		for y in range(height):
			for x in range(width):
				draw_cells_list.append(Vector2i(x, y))
	else:
		for cell in deck_cells.keys():
			draw_cells_list.append(cell)

	for cell in draw_cells_list:
		var rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		var tex: Texture2D = DECK_TEXTURE
		if chokepoint_cells.has(cell): tex = COBBLE_TEXTURE
		if tex:
			draw_texture_rect(tex, rect, true)

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

	if is_in_bounds(hovered_cell) and is_cell_on_deck(hovered_cell):
		var hover_rect := Rect2(Vector2(hovered_cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(hover_rect, HOVER_COLOR, true)

	for cell in draw_cells_list:
		var rect := Rect2(Vector2(cell) * tile_size, Vector2.ONE * tile_size)
		draw_rect(rect, GRID_COLOR, false, 1.0)

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

func set_deck_cells(cells: Array[Vector2i]) -> void:
	deck_cells.clear()
	for cell in cells:
		deck_cells[cell] = true
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

func is_cell_on_deck(cell: Vector2i) -> bool:
	return deck_cells.is_empty() or deck_cells.has(cell)
