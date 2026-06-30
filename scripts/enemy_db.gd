extends Node

var enemies: Dictionary = {}
var _ids: Array[String] = []

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/enemies.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		var arr: Array = parsed
		for entry in arr:
			var item: Dictionary = entry
			var item_id: String = str(item.get("id", ""))
			enemies[item_id] = item
			if not bool(item.get("is_boss", false)):
				_ids.append(item_id)

func get_enemy(id: String) -> Dictionary:
	var result: Dictionary = enemies.get(id, {})
	return result

func random_id() -> String:
	if _ids.is_empty():
		return ""
	return _ids[randi() % _ids.size()]
