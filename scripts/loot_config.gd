extends Node

var drop_chance: float = 0.05
var rolls_per_chest: int = 20
var enemy_drop_chance: float = 0.4
var rare_chance: float = 0.15
var bonus_value_min: int = 1
var bonus_value_max: int = 3
var bonus_stats: Array[String] = ["strength", "agility", "vitality", "intelligence"]

func _ready() -> void:
	_load_loot_config()
	_load_rarity_config()

func _load_loot_config() -> void:
	var text := FileAccess.get_file_as_string("res://data/loot_config.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var cfg: Dictionary = parsed
		drop_chance = float(cfg.get("drop_chance", drop_chance))
		rolls_per_chest = int(cfg.get("rolls_per_chest", rolls_per_chest))
		enemy_drop_chance = float(cfg.get("enemy_drop_chance", enemy_drop_chance))

func _load_rarity_config() -> void:
	var text := FileAccess.get_file_as_string("res://data/rarity_config.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var cfg: Dictionary = parsed
		rare_chance = float(cfg.get("rare_chance", rare_chance))
		bonus_value_min = int(cfg.get("bonus_value_min", bonus_value_min))
		bonus_value_max = int(cfg.get("bonus_value_max", bonus_value_max))
		var raw_stats: Array = cfg.get("bonus_stats", [])
		if not raw_stats.is_empty():
			var typed_stats: Array[String] = []
			for s in raw_stats:
				typed_stats.append(str(s))
			bonus_stats = typed_stats

func roll_instance(id: String) -> Dictionary:
	var item: Dictionary = ItemDB.get_item(id)
	var item_type: String = str(item.get("type", ""))
	var is_rare := not bonus_stats.is_empty() and randf() < rare_chance
	if is_rare and item_type == "potion":
		var stat_name: String = bonus_stats[randi() % bonus_stats.size()]
		var value := randi_range(bonus_value_min, bonus_value_max)
		return ItemDB.make_instance(id, "rare", stat_name, value)
	return ItemDB.make_instance(id, "common")
