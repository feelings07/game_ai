extends Node

const SLOTS: Array[String] = ["weapon", "helmet", "armor", "gloves", "pants", "boots"]
const FISTS_TEMPLATE: Dictionary = {
	"id": "fists",
	"name": "Кулаки",
	"type": "weapon",
	"weapon_type": "melee",
	"damage": 5,
	"attack_range": 26,
	"attack_cooldown": 0.4,
	"projectile_speed": 0,
	"armor": 0
}

var slots: Dictionary = {}

signal equipment_changed

func _ready() -> void:
	for s: String in SLOTS:
		slots[s] = {}

func equip(slot: String, instance: Dictionary) -> Dictionary:
	var previous: Dictionary = slots.get(slot, {})
	slots[slot] = instance
	equipment_changed.emit()
	return previous

func unequip(slot: String) -> Dictionary:
	var previous: Dictionary = slots.get(slot, {})
	slots[slot] = {}
	equipment_changed.emit()
	return previous

func get_total_armor() -> int:
	var total := 0
	for s: String in SLOTS:
		var instance: Dictionary = slots.get(s, {})
		if not instance.is_empty():
			var item: Dictionary = ItemDB.get_item(str(instance.get("id", "")))
			total += int(item.get("armor", 0))
	return total

func get_weapon_data() -> Dictionary:
	var instance: Dictionary = slots.get("weapon", {})
	if instance.is_empty():
		return FISTS_TEMPLATE
	var item: Dictionary = ItemDB.get_item(str(instance.get("id", "")))
	if item.is_empty():
		return FISTS_TEMPLATE
	return item

func get_stat_bonus(stat_name: String) -> int:
	var total := 0
	for s: String in SLOTS:
		var instance: Dictionary = slots.get(s, {})
		if not instance.is_empty() and str(instance.get("bonus_stat", "")) == stat_name:
			total += int(instance.get("bonus_value", 0))
	return total

func clear() -> void:
	for s: String in SLOTS:
		slots[s] = {}
	equipment_changed.emit()
