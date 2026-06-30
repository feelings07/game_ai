extends Control

const TEX_HP := preload("res://assets/sprites/items/potion_health.png")
const TEX_MP := preload("res://assets/sprites/items/potion_mana.png")

var inventory_ref: Node = null
var _hp_count: Label = null
var _mp_count: Label = null

func setup(inv: Node) -> void:
	inventory_ref = inv
	inv.inventory_changed.connect(_refresh)
	_refresh()

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	var slot_h := _make_slot("[1]", TEX_HP, true)
	var slot_m := _make_slot("[2]", TEX_MP, false)
	hbox.add_child(slot_h)
	hbox.add_child(slot_m)

func _make_slot(key_text: String, tex: Texture2D, is_health: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.33, 0.28, 0.8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	key_lbl.add_theme_font_size_override("font_size", 10)
	key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(key_lbl)

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)

	var count_lbl := Label.new()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.text = "×0"
	count_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if is_health:
		_hp_count = count_lbl
	else:
		_mp_count = count_lbl
	vbox.add_child(count_lbl)

	return panel

func _refresh() -> void:
	if inventory_ref == null:
		return
	_update_count(_hp_count, "health")
	_update_count(_mp_count, "mana")

func _update_count(lbl: Label, potion_type: String) -> void:
	if lbl == null:
		return
	var total: int = 0
	for inst: Dictionary in inventory_ref.items:
		var id: String = str(inst.get("id", ""))
		var item: Dictionary = ItemDB.get_item(id)
		if str(item.get("type", "")) != "potion":
			continue
		if potion_type == "health" and int(item.get("heal", 0)) > 0:
			total += int(inst.get("count", 1))
		elif potion_type == "mana" and int(item.get("mana", 0)) > 0:
			total += int(inst.get("count", 1))
	lbl.text = "×%d" % total
	lbl.add_theme_color_override("font_color",
		Color.WHITE if total > 0 else Color(1, 0.3, 0.3))
