extends Node
class_name GameFlow

signal mode_changed(new_mode: int)
signal combat_type_changed(new_type: int)
signal message_posted(text: String)

enum Mode {
	WORLD_MAP,
	SHIP_COMBAT,
	TACTICAL_COMBAT
}

enum TacticalType {
	BOARDING,
	TOWN_ASSAULT
}

var current_mode: Mode = Mode.WORLD_MAP
var tactical_type: TacticalType = TacticalType.BOARDING

func set_mode(mode: Mode) -> void:
	if current_mode == mode:
		return
	current_mode = mode
	emit_signal("mode_changed", current_mode)

func set_tactical_type(type: TacticalType) -> void:
	if tactical_type == type:
		return
	tactical_type = type
	emit_signal("combat_type_changed", tactical_type)

func post_message(text: String) -> void:
	emit_signal("message_posted", text)
