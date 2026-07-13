extends Node2D
class_name Projectile

const CANNONBALL_TEXTURE := preload("res://assets/generated/cannonball_frame_0.png")
const HIT_RADIUS := 20.0

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0
var damage: float = 10.0
var source_ship: ShipUnit

func _ready():
	var sprite = Sprite2D.new()
	sprite.texture = CANNONBALL_TEXTURE
	add_child(sprite)

func _process(delta):
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	_check_collision()

func _check_collision():
	var manager = get_parent() as ShipCombatManager
	if not manager: return

	var targets = [manager.player_ship, manager.enemy_ship]
	for target in targets:
		if target == null or target == source_ship: continue
		if position.distance_to(target.position) < HIT_RADIUS:
			_on_hit(target)
			break

func _on_hit(target: ShipUnit):
	# Distribute damage: 60% Hull, 30% Sails, 10% Crew
	target.data.take_damage(damage * 0.6, damage * 0.3, damage * 0.1)
	queue_free()

# True while the shot's forward trajectory can still reach an enemy target within
# its remaining lifetime. Used at turn end to keep live shots but clear misses.
func could_still_hit() -> bool:
	var manager = get_parent() as ShipCombatManager
	if manager == null: return false
	var speed := velocity.length()
	if speed <= 0.001: return false
	var remaining_travel := speed * lifetime
	var vdir := velocity / speed
	for target in [manager.player_ship, manager.enemy_ship]:
		if target == null or target == source_ship: continue
		if manager._is_defeated(target): continue
		var to_target: Vector2 = target.position - position
		var along: float = to_target.dot(vdir)
		if along <= 0.0: continue                       # target is behind the shot
		if along - HIT_RADIUS > remaining_travel: continue  # can't reach it in time
		var perp: float = (to_target - vdir * along).length()
		if perp <= HIT_RADIUS:
			return true
	return false
