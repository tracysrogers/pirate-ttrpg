extends RefCounted
class_name CareerSystem

const RANK_TABLE := [
	{"fame": 0, "title": "Deckhand"},
	{"fame": 80, "title": "Buccaneer"},
	{"fame": 180, "title": "Captain"},
	{"fame": 320, "title": "Commodore"},
	{"fame": 520, "title": "Pirate Lord"}
]

const MAP_FRAGMENT_NAMES := [
	"Santiago Fragment",
	"Yucatan Fragment",
	"Darien Fragment",
	"Bermuda Fragment"
]

static func rank_for_fame(fame: int) -> String:
	var title := "Deckhand"
	for row_variant in RANK_TABLE:
		if not row_variant is Dictionary:
			continue
		var row: Dictionary = row_variant as Dictionary
		if fame >= int(row.get("fame", 0)):
			title = str(row.get("title", title))
	return title

static func next_fragment_name(current_fragments: Array) -> String:
	var idx := current_fragments.size()
	if idx < 0:
		return ""
	if idx >= MAP_FRAGMENT_NAMES.size():
		return ""
	return MAP_FRAGMENT_NAMES[idx]

static func retirement_score(career_state: Dictionary, player_wealth: int) -> int:
	var fame: int = int(career_state.get("fame", 0))
	var fragments := 0
	var fragment_variant: Variant = career_state.get("map_fragments", [])
	if fragment_variant is Array:
		fragments = (fragment_variant as Array).size()
	var family_stage: int = int(career_state.get("family_stage", 0))
	var family_rescued: bool = bool(career_state.get("family_rescued", false))
	var score := fame
	score += int(round(float(player_wealth) * 0.25))
	score += fragments * 85
	score += family_stage * 60
	if family_rescued:
		score += 450
	return score
