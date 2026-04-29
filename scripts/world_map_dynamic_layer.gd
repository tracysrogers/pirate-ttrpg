extends Node2D
## Ship, route, and HUD text — redraw while sailing or when ETA/cursor state changes.

var world_map: WorldMap


func _draw() -> void:
	if world_map != null:
		world_map.draw_dynamic_canvas(self)
