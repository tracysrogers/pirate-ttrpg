extends Node
class_name Pathfinder

static func reachable_cells(
	start: Vector2i,
	range_limit: int,
	grid_size: Vector2i,
	blocked_cells: Dictionary
) -> Array[Vector2i]:
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]
	var open: Array[Vector2i] = [start]
	var visited: Dictionary = {start: 0}
	var reachable: Array[Vector2i] = []

	while not open.is_empty():
		var current: Vector2i = open.pop_front()
		var cost: int = visited[current]

		for dir in directions:
			var next: Vector2i = current + dir
			if next.x < 0 or next.y < 0 or next.x >= grid_size.x or next.y >= grid_size.y:
				continue
			if blocked_cells.has(next):
				continue

			var new_cost := cost + 1
			if new_cost > range_limit:
				continue

			if not visited.has(next) or new_cost < visited[next]:
				visited[next] = new_cost
				open.push_back(next)

	for cell in visited.keys():
		if cell != start:
			reachable.append(cell)

	reachable.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	return reachable
