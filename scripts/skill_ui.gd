extends CanvasLayer

var player: Node = null
var skill_tree: Node = null

func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(p: Node, st: Node) -> void:
	player = p
	skill_tree = st
	st.choice_available.connect(_on_choice_available)
	if bool(st.has_pending()):
		_show_tier(int(st.next_pending_tier()))

func _on_choice_available(tier: int) -> void:
	_show_tier(tier)

func _show_tier(tier: int) -> void:
	for c: Node in get_children():
		c.queue_free()
	visible = true
	get_tree().paused = true
	if player != null:
		player.set_ui_open(true)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.15, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.42, 0.18)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Уровень %d — выберите способность" % (tier * 5)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var choices: Array[Dictionary] = skill_tree.get_choices_for_tier(tier)
	for sk: Dictionary in choices:
		row.add_child(_build_card(sk))

func _build_card(sk: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 180)
	btn.pressed.connect(_on_card_pressed.bind(str(sk.get("id", ""))))

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect := TextureRect.new()
	var icon_path := str(sk.get("icon", ""))
	if icon_path != "":
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inner.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = str(sk.get("name", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(sk.get("description", ""))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(130, 0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	inner.add_child(desc_lbl)

	btn.add_child(inner)
	return btn

func _on_card_pressed(skill_id: String) -> void:
	skill_tree.choose(skill_id)
	visible = false
	if player != null:
		player.set_ui_open(false)
	get_tree().paused = false
	if bool(skill_tree.has_pending()):
		_show_tier(int(skill_tree.next_pending_tier()))
