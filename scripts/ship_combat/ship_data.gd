extends Resource
class_name ShipData

@export var ship_name: String = "Sloop"
@export var hull_hp: float = 100.0
@export var sails_hp: float = 100.0
@export var crew_hp: float = 100.0

@export var max_hull: float = 100.0
@export var max_sails: float = 100.0
@export var max_crew: float = 100.0

@export var port_reload_turns: int = 0
@export var starboard_reload_turns: int = 0
@export var cannon_cooldown_max: int = 4

@export var speed_setting: String = "Battle" # Fast, Battle, Slow
@export var next_speed_setting: String = "Battle"

func take_damage(hull: float, sails: float, crew: float):
	hull_hp = max(0, hull_hp - hull)
	sails_hp = max(0, sails_hp - sails)
	crew_hp = max(0, crew_hp - crew)

func advance_cooldowns():
	if port_reload_turns > 0: port_reload_turns -= 1
	if starboard_reload_turns > 0: starboard_reload_turns -= 1
