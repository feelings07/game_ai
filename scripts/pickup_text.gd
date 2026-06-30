extends Node

const FLOATING_TEXT_SCRIPT := preload("res://scripts/floating_text.gd")
const COMMON_COLOR := Color(1.0, 0.85, 0.3)
const RARE_COLOR := Color(0.3, 0.65, 1.0)

static func spawn(parent: Node, pos: Vector2, item_name: String, rarity: String, stack_index: int) -> void:
	var label := item_name
	var color := COMMON_COLOR
	if rarity == "rare":
		label = "[Редкое] " + item_name
		color = RARE_COLOR
	var txt := Node2D.new()
	txt.set_script(FLOATING_TEXT_SCRIPT)
	parent.add_child(txt)
	txt.global_position = pos + Vector2(-20.0, -24.0 - stack_index * 16.0)
	txt.setup("+ " + label, color)
