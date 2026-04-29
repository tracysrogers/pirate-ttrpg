extends Node2D
## Legend and viewport masks — redraw with zoom/pan/layout (not each travel frame).

var world_map: WorldMap


func _draw() -> void:
	if world_map != null:
		world_map.draw_over_canvas(self)
