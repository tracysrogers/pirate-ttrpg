extends Node2D
## Ocean, land, and ports — redraw only when zoom/pan/layout/view changes.

var world_map: MapSystem


func _draw() -> void:
	if world_map != null:
		world_map.draw_under_canvas(self)

