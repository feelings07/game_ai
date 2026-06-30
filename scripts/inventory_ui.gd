extends CanvasLayer

const SLOT_SIZE := 40
const ITEM_SLOT_BUTTON_SCRIPT := preload("res://scripts/item_slot_button.gd")
const TRASH_SLOT_SCRIPT := preload("res://scripts/trash_slot.gd")

const SLOT_ORDER: Array[String] = ["weapon", "helmet", "armor", "gloves", "pants", "boots"]
const SLOT_LABELS: Dictionary = {
	"weapon": "Оружие",
	"helmet": "Шлем",
	"armor": "Броня",
	"gloves": "Перчатки",
	"pants": "Штаны",
	"boots": "Сапоги"
}

const BONUS_STAT_LABELS: Dictionary = {
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

var player: Node = null
var inventory: Node = null
var equipment: Node = null
var stats_ref: Node = null

var slot_buttons: Array[Button] = []
var equip_buttons: Dictionary = {}
var inv_title_label: Label = null
var _trash_slot: Button = null

func _ready() -> void:
	layer = 10
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func setup(p: Node, inv: Node, eq: Node, st: Node, _sk: Node = null) -> void:
	player = p
	inventory = inv
	equipment = eq
	stats_ref = st
	inv.inventory_changed.connect(_refresh)
	eq.equipment_changed.connect(_refresh)
	st.stats_changed.connect(_refresh)
	if _trash_slot != null:
		_trash_slot.set("inventory_ref", inv)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_set_visible(not visible)
	elif event.is_action_pressed("ui_cancel") and visible:
		_set_visible(false)
		get_viewport().set_input_as_handled()

func _set_visible(v: bool) -> void:
	if v == visible:
		return
	visible = v
	if visible:
		GameEvents.open_ui()
		_refresh()
	else:
		GameEvents.close_ui()
	if player != null and player.has_method("set_ui_open"):
		player.set_ui_open(visible)

func force_close() -> void:
	if visible:
		visible = false
		GameEvents.close_ui()
		if player != null and player.has_method("set_ui_open"):
			player.set_ui_open(false)

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
	style.bg_color = Color(0.12, 0.11, 0.15, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.38, 0.3)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	hbox.add_child(_build_equip_column())
	hbox.add_child(_build_inventory_column())

func _build_equip_column() -> VBoxContainer:
	var equip_vbox := VBoxContainer.new()
	var equip_title := Label.new()
	equip_title.text = "Экипировка"
	equip_vbox.add_child(equip_title)
	for slot_name: String in SLOT_ORDER:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = str(SLOT_LABELS.get(slot_name, slot_name))
		lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.pressed.connect(_on_equip_slot_pressed.bind(slot_name))
		equip_buttons[slot_name] = btn
		row.add_child(btn)
		equip_vbox.add_child(row)
	return equip_vbox

func _build_inventory_column() -> VBoxContainer:
	var inv_vbox := VBoxContainer.new()

	var header := HBoxContainer.new()
	inv_title_label = Label.new()
	inv_title_label.text = "Инвентарь (0/100)"
	inv_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(inv_title_label)

	_trash_slot = Button.new()
	_trash_slot.set_script(TRASH_SLOT_SCRIPT)
	_trash_slot.text = "🗑"
	header.add_child(_trash_slot)
	inv_vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 360)
	var grid_node := GridContainer.new()
	grid_node.columns = 10
	for i in 100:
		var slot_btn := Button.new()
		slot_btn.set_script(ITEM_SLOT_BUTTON_SCRIPT)
		slot_btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_btn.pressed.connect(_on_inventory_slot_pressed.bind(i))
		grid_node.add_child(slot_btn)
		slot_buttons.append(slot_btn)
	scroll.add_child(grid_node)
	inv_vbox.add_child(scroll)
	return inv_vbox

func _refresh() -> void:
	if inventory == null or equipment == null:
		return

	var items: Array = inventory.items
	for i in slot_buttons.size():
		var btn: Button = slot_buttons[i]
		if i < items.size():
			var instance: Dictionary = items[i]
			var id: String = str(instance.get("id", ""))
			var item: Dictionary = ItemDB.get_item(id)
			btn.icon = load(str(item.get("icon", ""))) as Texture2D
			btn.tooltip_text = str(item.get("name", id))
			btn.set_instance(instance, equipment, i, inventory)
		else:
			btn.icon = null
			btn.tooltip_text = ""
			btn.set_instance({}, equipment, i, inventory)
	if inv_title_label != null:
		inv_title_label.text = "Инвентарь (%d/100)" % items.size()

	for slot_name: String in SLOT_ORDER:
		var btn: Button = equip_buttons[slot_name]
		var instance: Dictionary = equipment.slots.get(slot_name, {})
		if not instance.is_empty():
			var id: String = str(instance.get("id", ""))
			var item: Dictionary = ItemDB.get_item(id)
			btn.icon = load(str(item.get("icon", ""))) as Texture2D
			btn.tooltip_text = _describe_item(item, id, instance)
		else:
			btn.icon = null
			btn.tooltip_text = str(SLOT_LABELS.get(slot_name, slot_name))

func _describe_item(item: Dictionary, fallback_id: String, instance: Dictionary = {}) -> String:
	var item_name: String = str(item.get("name", fallback_id))
	var item_type: String = str(item.get("type", ""))
	var grade: String = str(item.get("grade", ""))
	var text: String = item_name
	if grade != "":
		text += " [%s]" % grade
	if item_type == "weapon":
		var weapon_type: String = str(item.get("weapon_type", "melee"))
		var kind: String = "ближний бой"
		if weapon_type == "ranged":
			kind = "дальний бой"
		elif weapon_type == "wand":
			kind = "жезл (мана)"
		text += "\nТип: %s" % kind
		text += "\nУрон: %d" % int(item.get("damage", 0))
		text += "\nДальность: %d" % int(item.get("attack_range", 0))
		text += "\nСкорость атаки: %.2fс" % float(item.get("attack_cooldown", 0.0))
		if weapon_type == "wand":
			text += "\nЦена маны: %d" % int(item.get("mana_cost", 0))
	elif item_type == "armor":
		text += "\nБроня: +%d" % int(item.get("armor", 0))
	var bonus_stat: String = str(instance.get("bonus_stat", ""))
	if bonus_stat != "":
		text += "\n+%d %s" % [int(instance.get("bonus_value", 0)), str(BONUS_STAT_LABELS.get(bonus_stat, bonus_stat))]
	return text

func _on_inventory_slot_pressed(index: int) -> void:
	var items: Array = inventory.items
	if index >= items.size():
		return
	var instance: Dictionary = items[index]
	var id: String = str(instance.get("id", ""))
	var item: Dictionary = ItemDB.get_item(id)
	var item_type: String = str(item.get("type", ""))
	if item_type == "potion":
		if player.use_potion(instance):
			inventory.remove_at(index)
	elif item_type == "weapon" or item_type == "armor":
		var grade: String = str(item.get("grade", "NG"))
		var req_level: int = GradeDB.get_level_req(grade)
		var player_level: int = int(stats_ref.level) if stats_ref != null else 1
		if player_level < req_level:
			return
		var slot_name: String = str(item.get("slot", ""))
		var previous: Dictionary = equipment.equip(slot_name, instance)
		inventory.remove_at(index)
		if not previous.is_empty():
			inventory.add_item(previous)

func _on_equip_slot_pressed(slot_name: String) -> void:
	var instance: Dictionary = equipment.slots.get(slot_name, {})
	if instance.is_empty():
		return
	if inventory.is_full():
		return
	equipment.unequip(slot_name)
	inventory.add_item(instance)
