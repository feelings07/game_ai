extends CanvasLayer

signal class_chosen(class_id: String)

const CLASSES: Array[Dictionary] = [
	{
		"id":          "warrior",
		"name":        "Воин",
		"stat":        "strength",
		"stat_label":  "+1 Сила",
		"weapon_id":   "sword_starter",
		"weapon_name": "Тренировочный меч",
		"desc":        "Мастер ближнего боя.\nКаждое очко Силы даёт +2 урона мечом.",
		"color":       Color(0.80, 0.25, 0.20),
	},
	{
		"id":          "archer",
		"name":        "Лучник",
		"stat":        "agility",
		"stat_label":  "+1 Ловкость",
		"weapon_id":   "bow_starter",
		"weapon_name": "Самодельный лук",
		"desc":        "Меткий стрелок.\nКаждое очко Ловкости даёт +1.5 урона луком.",
		"color":       Color(0.20, 0.65, 0.25),
	},
	{
		"id":          "mage",
		"name":        "Маг",
		"stat":        "intelligence",
		"stat_label":  "+1 Интеллект",
		"weapon_id":   "wand_starter",
		"weapon_name": "Учебный жезл",
		"desc":        "Повелитель магии.\nКаждый Интеллект даёт +1.5 урона жезлом.",
		"color":       Color(0.30, 0.35, 0.85),
	},
]

func _ready() -> void:
	layer = 20
	process_mode = PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	center.add_child(outer)

	var title := Label.new()
	title.text = "Выберите профессию"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	outer.add_child(cards_row)

	for cls: Dictionary in CLASSES:
		cards_row.add_child(_build_card(cls))

func _build_card(cls: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.13, 0.98)
	style.set_border_width_all(2)
	style.border_color = cls.get("color", Color(0.4, 0.4, 0.4))
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(190, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = str(cls.get("name", ""))
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", cls.get("color", Color(1, 1, 1)))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var bonus_lbl := Label.new()
	bonus_lbl.text = str(cls.get("stat_label", ""))
	bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bonus_lbl)

	var weapon_lbl := Label.new()
	weapon_lbl.text = "Оружие: " + str(cls.get("weapon_name", ""))
	weapon_lbl.add_theme_font_size_override("font_size", 11)
	weapon_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	weapon_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_lbl.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(weapon_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(cls.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(desc_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Выбрать"
	var class_id: String = str(cls.get("id", ""))
	btn.pressed.connect(func() -> void: _on_class_pressed(class_id))
	vbox.add_child(btn)

	return panel

func _on_class_pressed(class_id: String) -> void:
	class_chosen.emit(class_id)
	queue_free()
