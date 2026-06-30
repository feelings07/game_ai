extends CanvasLayer

const STAT_ORDER: Array[String] = ["strength", "agility", "vitality", "intelligence"]
const STAT_LABELS: Dictionary = {
	"strength":     "Сила",
	"agility":      "Ловкость",
	"vitality":     "Живучесть",
	"intelligence": "Интеллект"
}
const STAT_DESCS: Dictionary = {
	"strength":     "+2 урона в ближнем бою",
	"agility":      "+1.5 урона дальним / -2% КД атаки",
	"vitality":     "+8 к макс. HP",
	"intelligence": "+3 лечение / +5 мана / +1.5 жезл",
}
const STAT_TOOLTIPS: Dictionary = {
	"strength":     "Сила\nУрон в ближнем бою: +2 за каждое очко\n\nПовышайте чтобы наносить больше урона мечом, топором и другим оружием ближнего боя.",
	"agility":      "Ловкость\nУрон дальним оружием: +1.5 за каждое очко\nСкорость атаки: −2% КД за каждое очко (макс. −80%)\n\nПовышайте чтобы стрелять сильнее и быстрее.",
	"vitality":     "Живучесть\nМакс. HP: +8 за каждое очко\n\nПовышайте чтобы переносить больше ударов.",
	"intelligence": "Интеллект\nЛечение зельем: +3 за каждое очко\nМакс. мана: +5 за каждое очко\nУрон жезлом: +1.5 за каждое очко\n\nПовышайте для магического стиля игры.",
}
const BONUS_STAT_LABELS: Dictionary = {
	"strength": "Силы",
	"agility":  "Ловкости",
	"vitality": "Живучести",
	"intelligence": "Интеллекта"
}
const ELEMENT_LABELS: Dictionary = {
	"fire": "Огонь",
	"ice": "Лёд",
	"lightning": "Молния"
}

var stats_ref: Node = null
var equipment_ref: Node = null
var skill_tree_ref: Node = null
var player_ref: Node = null

var _lbl_level: Label = null
var _lbl_xp: Label = null
var _lbl_points: Label = null
var _lbl_hp: Label = null
var _lbl_armor: Label = null
var _lbl_dmg: Label = null
var _stat_rows: Dictionary = {}
var _stat_plus_buttons: Dictionary = {}
var _skills_grid: GridContainer = null

func _ready() -> void:
	layer = 12
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func setup(st: Node, eq: Node, sk: Node, player: Node = null) -> void:
	stats_ref = st
	equipment_ref = eq
	skill_tree_ref = sk
	player_ref = player
	if st != null:
		st.stats_changed.connect(_refresh)
		st.leveled_up.connect(func(_l): _refresh())
	if eq != null:
		eq.equipment_changed.connect(_refresh)
	if sk != null:
		sk.skill_unlocked.connect(func(_id): _refresh())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		_toggle()
	elif event.is_action_pressed("ui_cancel") and visible:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if visible:
		visible = false
		GameEvents.close_ui()
	else:
		visible = true
		GameEvents.open_ui()
		_refresh()

func _on_stat_plus_pressed(stat_name: String) -> void:
	if stats_ref == null:
		return
	if stats_ref.spend_point(stat_name):
		_refresh()

func force_close() -> void:
	if visible:
		visible = false
		GameEvents.close_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.13, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.32, 0.45)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	panel.add_child(hbox)

	hbox.add_child(_build_stats_column())
	_add_separator(hbox)
	hbox.add_child(_build_skills_column())

func _add_separator(parent: HBoxContainer) -> void:
	var sep := VSeparator.new()
	parent.add_child(sep)

func _build_stats_column() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 0)

	var title := Label.new()
	title.text = "Характеристики"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	_lbl_level = Label.new()
	vbox.add_child(_lbl_level)
	_lbl_xp = Label.new()
	vbox.add_child(_lbl_xp)
	_lbl_points = Label.new()
	_lbl_points.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	vbox.add_child(_lbl_points)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for stat_name: String in STAT_ORDER:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = str(STAT_LABELS.get(stat_name, stat_name)) + ":"
		name_lbl.custom_minimum_size = Vector2(110, 0)
		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(40, 0)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
		var desc_lbl := Label.new()
		desc_lbl.text = str(STAT_DESCS.get(stat_name, ""))
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 0)
		plus_btn.visible = false
		var sn := stat_name
		plus_btn.pressed.connect(func() -> void: _on_stat_plus_pressed(sn))
		_stat_plus_buttons[stat_name] = plus_btn

		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = str(STAT_TOOLTIPS.get(stat_name, ""))
		row.add_child(plus_btn)
		row.add_child(name_lbl)
		row.add_child(val_lbl)
		row.add_child(desc_lbl)
		vbox.add_child(row)
		_stat_rows[stat_name] = val_lbl

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var derived_title := Label.new()
	derived_title.text = "Производные"
	derived_title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(derived_title)

	_lbl_hp    = Label.new(); vbox.add_child(_lbl_hp)
	_lbl_armor = Label.new(); vbox.add_child(_lbl_armor)
	_lbl_dmg   = Label.new(); vbox.add_child(_lbl_dmg)

	var hint := Label.new()
	hint.text = "[O] закрыть"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	vbox.add_child(hint)

	return vbox

func _build_skills_column() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 0)

	var title := Label.new()
	title.text = "Способности"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 360)
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 1
	scroll.add_child(_skills_grid)
	vbox.add_child(scroll)
	return vbox

func _refresh() -> void:
	if stats_ref == null:
		return

	var lvl: int = int(stats_ref.level)
	var cur_xp: int = int(stats_ref.xp)
	var need_xp: int = int(stats_ref.xp_to_next)
	var points: int = int(stats_ref.stat_points)
	if _lbl_level != null:
		_lbl_level.text = "Уровень: %d" % lvl
	if _lbl_xp != null:
		_lbl_xp.text = "XP: %d / %d" % [cur_xp, need_xp]
	if _lbl_points != null:
		_lbl_points.text = "Очки характеристик: %d" % points if points > 0 else ""
	for sn: String in _stat_plus_buttons:
		var btn: Button = _stat_plus_buttons[sn]
		btn.visible = points > 0

	for stat_name: String in STAT_ORDER:
		var total: int = int(stats_ref.get_total(stat_name))
		var base: int = stats_ref.get_base(stat_name) if stats_ref.has_method("get_base") else total
		var eq_bonus: int = 0
		if equipment_ref != null and equipment_ref.has_method("get_stat_bonus"):
			eq_bonus = int(equipment_ref.get_stat_bonus(stat_name))
		var buff_bonus: int = 0
		if stats_ref.has_method("get_temp_buff_value"):
			buff_bonus = int(stats_ref.get_temp_buff_value(stat_name))
		var lbl: Label = _stat_rows.get(stat_name, null)
		if lbl != null:
			var detail := ""
			if eq_bonus != 0: detail += " +%d eq" % eq_bonus
			if buff_bonus != 0: detail += " +%d buff" % buff_bonus
			lbl.text = "%d%s" % [total, detail]

	if _lbl_hp != null:
		var max_hp: int = int(player_ref.max_health) if player_ref != null else 100
		_lbl_hp.text = "Макс. HP: %d" % max_hp

	if _lbl_armor != null and equipment_ref != null:
		_lbl_armor.text = "Броня: %d" % int(equipment_ref.get_total_armor())

	if _lbl_dmg != null and equipment_ref != null:
		var weapon: Dictionary = equipment_ref.get_weapon_data()
		var base_dmg: int = int(weapon.get("damage", 0))
		var wtype: String = str(weapon.get("weapon_type", "melee"))
		var bonus: int = 0
		if wtype == "melee" and stats_ref.has_method("get_bonus_melee_damage"):
			bonus = int(stats_ref.get_bonus_melee_damage())
		elif wtype == "ranged" and stats_ref.has_method("get_bonus_ranged_damage"):
			bonus = int(stats_ref.get_bonus_ranged_damage())
		elif wtype == "wand" and stats_ref.has_method("get_bonus_wand_damage"):
			bonus = int(stats_ref.get_bonus_wand_damage())
		_lbl_dmg.text = "Урон: %d  (+%d бонус)" % [base_dmg + bonus, bonus]

	if _skills_grid != null and skill_tree_ref != null:
		for c: Node in _skills_grid.get_children():
			c.queue_free()
		var unlocked: Array = skill_tree_ref.unlocked
		if unlocked.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "Нет активных способностей"
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_skills_grid.add_child(empty_lbl)
		for skill_id: String in unlocked:
			var sk: Dictionary = SkillDB.get_skill(skill_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var icon_rect := TextureRect.new()
			var icon_path := str(sk.get("icon", ""))
			if icon_path != "":
				icon_rect.texture = load(icon_path) as Texture2D
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon_rect)
			var text_vbox := VBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = str(sk.get("name", skill_id))
			name_lbl.add_theme_font_size_override("font_size", 13)
			var desc_lbl := Label.new()
			desc_lbl.text = str(sk.get("description", ""))
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.custom_minimum_size = Vector2(210, 0)
			text_vbox.add_child(name_lbl)
			text_vbox.add_child(desc_lbl)
			row.add_child(text_vbox)
			_skills_grid.add_child(row)
