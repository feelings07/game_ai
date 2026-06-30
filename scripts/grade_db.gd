extends Node

var _grades: Dictionary = {}

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/grade_config.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_grades = parsed

func get_level_req(grade: String) -> int:
	var g: Dictionary = _grades.get(grade, {})
	return int(g.get("level_req", 1))

func get_color(grade: String) -> String:
	var g: Dictionary = _grades.get(grade, {})
	return str(g.get("color", "#999999"))

func get_drop_mult(grade: String) -> float:
	if grade == "":
		return 1.0
	var g: Dictionary = _grades.get(grade, {})
	return float(g.get("drop_mult", 1.0))
