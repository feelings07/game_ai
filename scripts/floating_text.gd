extends Node2D

var lifetime: float = 1.0
var rise_speed: float = 22.0

var _elapsed: float = 0.0
var _label: Label = null

func _ready() -> void:
	if _label == null:
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_label)

func setup(text: String, color: Color = Color.WHITE) -> void:
	if _label == null:
		_label = Label.new()
		add_child(_label)
	_label.text = text
	_label.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= rise_speed * delta
	modulate.a = clampf(1.0 - _elapsed / lifetime, 0.0, 1.0)
	if _elapsed >= lifetime:
		queue_free()
