extends Node

var skills: Dictionary = {}
var _by_tier: Dictionary = {}

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/skills.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		var arr: Array = parsed
		for entry in arr:
			var sk: Dictionary = entry
			var id: String = str(sk.get("id", ""))
			skills[id] = sk
			var tier: int = int(sk.get("tier", 0))
			var list: Array = _by_tier.get(tier, [])
			list.append(id)
			_by_tier[tier] = list

func get_skill(id: String) -> Dictionary:
	var result: Dictionary = skills.get(id, {})
	return result

func get_by_tier(tier: int) -> Array[Dictionary]:
	var ids: Array = _by_tier.get(tier, [])
	var result: Array[Dictionary] = []
	for id: String in ids:
		result.append(get_skill(id))
	return result

func max_tier() -> int:
	var best := 0
	for key in _by_tier.keys():
		best = max(best, int(key))
	return best
