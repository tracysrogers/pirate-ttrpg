extends Node
class_name TurnManager

signal turn_started(team: int)
signal turn_ended(team: int)

enum Team {
	PLAYER,
	ENEMY
}

var current_team: Team = Team.PLAYER
var turn_number: int = 1

func begin_battle() -> void:
	current_team = Team.PLAYER
	turn_number = 1
	emit_signal("turn_started", current_team)

func end_turn() -> void:
	emit_signal("turn_ended", current_team)
	current_team = Team.ENEMY if current_team == Team.PLAYER else Team.PLAYER
	if current_team == Team.PLAYER:
		turn_number += 1
	emit_signal("turn_started", current_team)

func get_save_state() -> Dictionary:
	return {
		"current_team": int(current_team),
		"turn_number": turn_number
	}

func apply_save_state(state: Dictionary) -> void:
	current_team = int(state.get("current_team", Team.PLAYER)) as Team
	turn_number = maxi(1, int(state.get("turn_number", 1)))
