extends Node

var items: Dictionary = {}
var _ids: Array[String] = []

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/items.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		var arr: Array = parsed
		for entry in arr:
			var item: Dictionary = entry
			var item_id: String = str(item.get("id", ""))
			items[item_id] = item
			if not bool(item.get("no_drop", false)):
				_ids.append(item_id)

func get_item(id: String) -> Dictionary:
	var result: Dictionary = items.get(id, {})
	return result

func random_id() -> String:
	if _ids.is_empty():
		return ""
	return _ids[randi() % _ids.size()]

func make_instance(id: String, rarity: String = "common", bonus_stat: String = "", bonus_value: int = 0) -> Dictionary:
	return {
		"id": id,
		"rarity": rarity,
		"bonus_stat": bonus_stat,
		"bonus_value": bonus_value
	}
