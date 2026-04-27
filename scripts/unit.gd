extends Node2D
class_name Unit

enum Team {
	PLAYER,
	ENEMY
}

@export var team: Team = Team.PLAYER
@export var move_range: int = 6
@export var max_hp: int = 10
@export var melee_damage_min: int = 2
@export var melee_damage_max: int = 4

var hp: int = max_hp
var cell: Vector2i = Vector2i.ZERO
var has_acted: bool = false

const PLAYER_COLOR := Color(0.35, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const SELECTED_OUTLINE := Color(1.0, 1.0, 0.5)
const ACTIVE_OUTLINE := Color(1.0, 0.92, 0.45, 0.95)

var is_selected: bool = false
var is_active_actor: bool = false
var is_dimmed: bool = false
var tile_size: int = 64

func _ready() -> void:
	hp = max_hp
	z_index = 5
	queue_redraw()

func _draw() -> void:
	var half := float(tile_size) * 0.5
	var center := Vector2(half, half)
	var radius := float(tile_size) * 0.34
	var base_color := PLAYER_COLOR if team == Team.PLAYER else ENEMY_COLOR
	draw_circle(center, radius, base_color)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-6, 6),
		str(hp),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14
	)

	if is_selected:
		draw_arc(center, radius + 4.0, 0.0, TAU, 32, SELECTED_OUTLINE, 3.0)
	if is_active_actor:
		draw_arc(center, radius + 8.0, 0.0, TAU, 40, ACTIVE_OUTLINE, 3.0)

	if has_acted:
		var faded := Color(0, 0, 0, 0.4)
		draw_circle(center, radius, faded)
	if is_dimmed:
		draw_circle(center, radius + 1.0, Color(0.02, 0.03, 0.06, 0.55))

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func set_acted(value: bool) -> void:
	has_acted = value
	queue_redraw()

func set_active_actor(value: bool) -> void:
	is_active_actor = value
	queue_redraw()

func set_dimmed(value: bool) -> void:
	is_dimmed = value
	queue_redraw()

func take_damage(amount: int) -> bool:
	hp = max(0, hp - amount)
	queue_redraw()
	return hp <= 0
