extends Node
class_name GameLogicState


signal mode_changed(new_mode: Mode)
signal combat_type_changed(new_type: TacticalType)
signal message_posted(text: String)

enum Mode {
	WORLD_MAP,
	SHIP_COMBAT,
	SHIP_COMBAT_V2,
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
	mode_changed.emit(current_mode)

func set_tactical_type(type: TacticalType) -> void:
	if tactical_type == type:
		return
	tactical_type = type
	combat_type_changed.emit(tactical_type)

func post_message(text: String) -> void:
	message_posted.emit(text)

