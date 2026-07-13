# Last Updated: 2026-07-05-192809
extends Node2D
class_name CombatUnit



enum UnitClass {
	SAILOR,
	MARINE,
	OFFICER
}

@export var team: CombatTurnManager.Team = CombatTurnManager.Team.PLAYER
@export var unit_class: UnitClass = UnitClass.SAILOR
@export var move_range: int = 6
@export var max_hp: int = 10
@export var melee_damage_min: int = 2
@export var melee_damage_max: int = 4
@export var initiative: int = 10

func setup_class_stats() -> void:
	match unit_class:
		UnitClass.SAILOR:
			max_hp = 10
			move_range = 6
			melee_damage_min = 2
			melee_damage_max = 4
			initiative = 12
		UnitClass.MARINE:
			max_hp = 15
			move_range = 4
			melee_damage_min = 3
			melee_damage_max = 5
			initiative = 8
		UnitClass.OFFICER:
			max_hp = 12
			move_range = 5
			melee_damage_min = 4
			melee_damage_max = 6
			initiative = 15
	hp = max_hp

var hp: int = 10
var cell: Vector2i = Vector2i.ZERO
const PLAYER_COLOR := Color(0.35, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const SELECTED_OUTLINE := Color(1.0, 1.0, 0.5)
const ACTIVE_OUTLINE := Color(1.0, 0.92, 0.45, 0.95)

var is_selected: bool = false
var is_active_actor: bool = false
var has_acted: bool = false
var is_dimmed: bool = false
var status_text: String = ""
var status_timer: float = 0.0

func _process(delta: float) -> void:
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0:
			status_text = ""
			queue_redraw()

func display_status(text: String) -> void:
	status_text = text
	status_timer = 2.0
	queue_redraw()
var tile_size: int = 64
var animated_sprite: AnimatedSprite2D

func _ready() -> void:
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	hp = max_hp
	z_index = 5
	setup_class_stats()
	_update_sprite_for_class()

func _update_sprite_for_class() -> void:
	if not animated_sprite: return
	
	match unit_class:
		UnitClass.SAILOR:
			animated_sprite.sprite_frames = preload("res://assets/generated/pirate_sailor_frames.tres")
		UnitClass.MARINE:
			animated_sprite.sprite_frames = preload("res://assets/generated/pirate_marine_frames.tres")
		UnitClass.OFFICER:
			animated_sprite.sprite_frames = preload("res://assets/generated/pirate_officer_frames.tres")
	
	animated_sprite.play("idle")

func _draw() -> void:
	# Keep health text, remove circle
	var half := float(tile_size) * 0.5
	var center := Vector2(half, half)
	var radius := float(tile_size) * 0.34
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-6, -tile_size * 0.4),
		str(hp),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color.WHITE
	)

	if is_selected:
		draw_arc(center, (float(tile_size) * 0.34) + 4.0, 0.0, TAU, 32, SELECTED_OUTLINE, 3.0)
	if is_active_actor:
		draw_arc(center, (float(tile_size) * 0.34) + 8.0, 0.0, TAU, 40, ACTIVE_OUTLINE, 3.0)

	if status_text != "":
		draw_string(ThemeDB.fallback_font, center + Vector2(-20, -tile_size * 0.6), status_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.YELLOW)
	if is_dimmed:
		draw_circle(center, (float(tile_size) * 0.34) + 1.0, Color(0.02, 0.03, 0.06, 0.55))

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

