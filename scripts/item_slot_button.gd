extends Button

const STAT_LABELS: Dictionary = {
	"strength": "Силы",
	"agility": "Ловкости",
	"vitality": "Живучести",
	"intelligence": "Интеллекта"
}
const ELEMENT_LABELS: Dictionary = {
	"fire": "Огонь",
	"ice": "Лёд",
	"lightning": "Молния"
}
const ELEMENT_COLORS: Dictionary = {
	"fire": "#ff7a30",
	"ice": "#7ad4ff",
	"lightning": "#ffe23c"
}

var item_id: String = ""
var rarity: String = "common"
var bonus_stat: String = ""
var bonus_value: int = 0
var equipment_ref: Node = null
var inv_index: int = -1
var inventory_ref: Node = null

var _count: int = 1
var _current_instance: Dictionary = {}
var _count_label: Label = null

func _ready() -> void:
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 11)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_count_label.add_theme_constant_override("shadow_offset_x", 1)
	_count_label.add_theme_constant_override("shadow_offset_y", 1)
	_count_label.visible = false
	add_child(_count_label)

func set_instance(instance: Dictionary, equipment: Node, index: int = -1, inv: Node = null) -> void:
	item_id = str(instance.get("id", ""))
	rarity = str(instance.get("rarity", "common"))
	bonus_stat = str(instance.get("bonus_stat", ""))
	bonus_value = int(instance.get("bonus_value", 0))
	equipment_ref = equipment
	_count = int(instance.get("count", 1))
	_current_instance = instance
	inv_index = index
	inventory_ref = inv
	if _count_label != null:
		_count_label.text = str(_count)
		_count_label.visible = _count > 1 and item_id != ""

func _get_drag_data(at_position: Vector2) -> Variant:
	if item_id == "" or inv_index < 0:
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.custom_minimum_size = Vector2(40, 40)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"inv_index": inv_index, "item_id": item_id}

func _make_custom_tooltip(for_text: String) -> Object:
	if item_id == "":
		return null
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return null

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.38, 0.3)
	panel.add_theme_stylebox_override("panel", style)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(230, 0)
	rtl.text = _build_text(item)
	panel.add_child(rtl)
	return panel

func _build_text(item: Dictionary) -> String:
	var item_name: String = str(item.get("name", item_id))
	var rarity_color: String = "#4da6ff" if rarity == "rare" else "#d8d8d8"
	var rarity_label: String = "Редкое" if rarity == "rare" else "Обычное"
	var grade: String = str(item.get("grade", ""))
	var grade_color: String = GradeDB.get_color(grade) if grade != "" else "#999999"
	var grade_suffix: String = "  [color=%s][%s][/color]" % [grade_color, grade] if grade != "" else ""
	var text: String = "[b][color=%s]%s[/color][/b]%s" % [rarity_color, item_name, grade_suffix]
	text += "\n[color=#888888]%s[/color]" % rarity_label
	if grade != "":
		var req: int = GradeDB.get_level_req(grade)
		text += "  [color=%s]Грейд %s (ур. %d+)[/color]" % [grade_color, grade, req]

	if _count > 1:
		text += "\n[color=#cccccc]Количество: %d[/color]" % _count

	var item_type: String = str(item.get("type", ""))
	var equipped: Dictionary = {}
	if equipment_ref != null:
		var slot_name: String = str(item.get("slot", ""))
		if slot_name == "weapon":
			equipped = equipment_ref.get_weapon_data()
		elif slot_name != "":
			var eq_instance: Dictionary = equipment_ref.slots.get(slot_name, {})
			if not eq_instance.is_empty():
				equipped = ItemDB.get_item(str(eq_instance.get("id", "")))

	if item_type == "weapon":
		var weapon_type: String = str(item.get("weapon_type", "melee"))
		var kind: String = "ближний бой"
		if weapon_type == "ranged":
			kind = "дальний бой"
		elif weapon_type == "wand":
			kind = "жезл (мана)"
		text += "\nТип: %s" % kind
		if weapon_type == "wand":
			var element: String = str(item.get("element", ""))
			var element_label: String = str(ELEMENT_LABELS.get(element, element))
			var element_color: String = str(ELEMENT_COLORS.get(element, "#ffffff"))
			text += "\nСтихия: [color=%s]%s[/color]" % [element_color, element_label]
		text += _stat_line("Урон", str(int(item.get("damage", 0))), float(item.get("damage", 0)), float(equipped.get("damage", 0)), false)
		text += _stat_line("Дальность", str(int(item.get("attack_range", 0))), float(item.get("attack_range", 0)), float(equipped.get("attack_range", 0)), false)
		text += _stat_line("КД атаки", "%.2fс" % float(item.get("attack_cooldown", 0.0)), float(item.get("attack_cooldown", 0.0)), float(equipped.get("attack_cooldown", 0.0)), true)
		if weapon_type == "ranged" or weapon_type == "wand":
			text += _stat_line("Скорость снаряда", str(int(item.get("projectile_speed", 0))), float(item.get("projectile_speed", 0)), float(equipped.get("projectile_speed", 0)), false)
		if weapon_type == "wand":
			text += _stat_line("Цена маны", str(int(item.get("mana_cost", 0))), float(item.get("mana_cost", 0)), float(equipped.get("mana_cost", 0)), true)
	elif item_type == "armor":
		text += _stat_line("Броня", "+%d" % int(item.get("armor", 0)), float(item.get("armor", 0)), float(equipped.get("armor", 0)), false)
	elif item_type == "potion":
		var heal_amt: int = int(item.get("heal", 0))
		var mana_amt: int = int(item.get("mana", 0))
		if heal_amt > 0:
			text += "\nЛечение: +%d" % heal_amt
		if mana_amt > 0:
			text += "\n[color=#7ad4ff]Мана: +%d[/color]" % mana_amt

	if bonus_stat != "":
		var stat_label: String = str(STAT_LABELS.get(bonus_stat, bonus_stat))
		text += "\n[color=#b07fe0]+%d %s[/color]" % [bonus_value, stat_label]

	var desc: String = str(item.get("description", ""))
	if desc != "":
		text += "\n[color=#888888]%s[/color]" % desc
	return text

func _stat_line(label: String, display_value: String, value: float, equipped_value: float, lower_is_better: bool) -> String:
	var color := "white"
	var arrow := ""
	if value != equipped_value:
		var better: bool = (value < equipped_value) if lower_is_better else (value > equipped_value)
		if better:
			color = "#7CFC00"
			arrow = " ▲"
		else:
			color = "#FA8072"
			arrow = " ▼"
	return "\n%s: [color=%s]%s%s[/color]" % [label, color, display_value, arrow]
