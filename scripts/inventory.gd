extends Node

const MAX_SLOTS := 100

var items: Array[Dictionary] = []

signal inventory_changed

func _stackable(instance: Dictionary) -> bool:
	if str(instance.get("rarity", "common")) != "common":
		return false
	var item: Dictionary = ItemDB.get_item(str(instance.get("id", "")))
	return str(item.get("type", "")) == "potion"

func add_item(instance: Dictionary) -> bool:
	if _stackable(instance):
		var id: String = str(instance.get("id", ""))
		for i in items.size():
			if str(items[i].get("id", "")) == id:
				items[i]["count"] = int(items[i].get("count", 1)) + 1
				inventory_changed.emit()
				return true
	if items.size() >= MAX_SLOTS:
		return false
	var new_instance := instance.duplicate()
	if not new_instance.has("count"):
		new_instance["count"] = 1
	items.append(new_instance)
	inventory_changed.emit()
	return true

func remove_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var instance: Dictionary = items[index]
	var count: int = int(instance.get("count", 1))
	if count > 1:
		items[index]["count"] = count - 1
		inventory_changed.emit()
		var single := instance.duplicate()
		single["count"] = 1
		return single
	items.remove_at(index)
	inventory_changed.emit()
	return instance

func remove_all_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var instance: Dictionary = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	return instance

func find_potion(potion_type: String) -> int:
	for i in items.size():
		var id: String = str(items[i].get("id", ""))
		var item: Dictionary = ItemDB.get_item(id)
		if str(item.get("type", "")) != "potion":
			continue
		if potion_type == "health" and int(item.get("heal", 0)) > 0:
			return i
		if potion_type == "mana" and int(item.get("mana", 0)) > 0:
			return i
	return -1

func is_full() -> bool:
	return items.size() >= MAX_SLOTS

func clear() -> void:
	items.clear()
	inventory_changed.emit()
