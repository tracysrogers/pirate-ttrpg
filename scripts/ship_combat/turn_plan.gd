extends Resource
class_name TurnPlan

@export var path: Array[Vector2i] = []
# Each entry: {"timestamp": float (0-10), "battery": "port" or "starboard"}
@export var fire_orders: Array[Dictionary] = []
@export var next_speed: String = "Battle"

@export var end_pos: Vector2
@export var end_angle: float
