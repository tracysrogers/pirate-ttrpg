class_name IsoHelper

# 2:1 isometric tiles. Half-dimensions are what the transforms actually use.
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_TILE_WIDTH := TILE_WIDTH * 0.5
const HALF_TILE_HEIGHT := TILE_HEIGHT * 0.5

static func grid_to_world(grid_pos: Vector2) -> Vector2:
	# screen_x = (grid_x - grid_y) * half_width
	# screen_y = (grid_x + grid_y) * half_height
	var x = (grid_pos.x - grid_pos.y) * HALF_TILE_WIDTH
	var y = (grid_pos.x + grid_pos.y) * HALF_TILE_HEIGHT
	return Vector2(x, y)

static func world_to_grid(world_pos: Vector2) -> Vector2:
	# Inverse transformation
	var gx = (world_pos.x / HALF_TILE_WIDTH + world_pos.y / HALF_TILE_HEIGHT) / 2.0
	var gy = (world_pos.y / HALF_TILE_HEIGHT - world_pos.x / HALF_TILE_WIDTH) / 2.0
	return Vector2(gx, gy)

static func get_bearing_angle(heading: Vector2) -> float:
	return rad_to_deg(heading.angle())

static func get_direction_index(angle_deg: float) -> int:
	# 0:N, 1:NE, 2:E, 3:SE, 4:S, 5:SW, 6:W, 7:NW
	var normalized = fposmod(angle_deg + 22.5, 360.0)
	return int(normalized / 45.0)

static func get_direction_string(index: int) -> String:
	var dirs = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
	return dirs[index % 8]
