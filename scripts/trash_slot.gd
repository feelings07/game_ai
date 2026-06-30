extends Button

var inventory_ref: Node = null
var _hovering: bool = false

func _ready() -> void:
	tooltip_text = "Перетащите предмет сюда для уничтожения"
	custom_minimum_size = Vector2(44, 44)
	_update_style(false)

func _update_style(hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.1, 0.1, 0.85) if hovered else Color(0.25, 0.1, 0.1, 0.75)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color(0.9, 0.2, 0.2) if hovered else Color(0.5, 0.2, 0.2)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_font_size_override("font_size", 22)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inv_index")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if inventory_ref == null:
		return
	var idx: int = int(data.get("inv_index", -1))
	if idx >= 0:
		inventory_ref.remove_all_at(idx)
	_update_style(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_update_style(false)
