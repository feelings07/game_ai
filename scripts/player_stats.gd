extends Node

signal stats_changed
signal leveled_up(new_level: int)
signal xp_changed(current_xp: int, needed_xp: int)

var _temp_buffs: Dictionary = {}   # stat -> {value: int, timer: float}

var base_stats: Dictionary = {
	"strength": 1,
	"agility": 1,
	"vitality": 1,
	"intelligence": 1
}
var per_point: Dictionary = {}

var level: int = 1
var xp: int = 0
var xp_to_next: int = 100
var stat_points: int = 0
var xp_base: float = 100.0
var xp_growth: float = 50.0

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/player_stats.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var cfg: Dictionary = parsed
		var base_cfg: Dictionary = cfg.get("base", {})
		for key: String in base_cfg.keys():
			base_stats[key] = int(base_cfg[key])
		per_point = cfg.get("per_point", {})
		xp_base = float(cfg.get("xp_base", xp_base))
		xp_growth = float(cfg.get("xp_growth", xp_growth))
	xp_to_next = _compute_xp_to_next()

func _process(delta: float) -> void:
	if _temp_buffs.is_empty():
		return
	var expired: Array[String] = []
	for stat: String in _temp_buffs:
		_temp_buffs[stat]["timer"] -= delta
		if float(_temp_buffs[stat]["timer"]) <= 0.0:
			expired.append(stat)
	if not expired.is_empty():
		for stat: String in expired:
			_temp_buffs.erase(stat)
		stats_changed.emit()

func apply_temp_buff(stat: String, value: int, duration: float) -> void:
	_temp_buffs[stat] = {"value": value, "timer": duration}
	stats_changed.emit()

func get_buff_remaining(stat: String) -> float:
	if not _temp_buffs.has(stat):
		return 0.0
	return float(_temp_buffs[stat].get("timer", 0.0))

func get_temp_buff_value(stat: String) -> int:
	if not _temp_buffs.has(stat):
		return 0
	return int(_temp_buffs[stat].get("value", 0))

func get_active_buffs() -> Dictionary:
	return _temp_buffs.duplicate(true)

func reset() -> void:
	_temp_buffs.clear()
	level = 1
	xp = 0
	stat_points = 0
	var text := FileAccess.get_file_as_string("res://data/player_stats.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var cfg: Dictionary = parsed
		var base_cfg: Dictionary = cfg.get("base", {})
		for key: String in base_cfg.keys():
			base_stats[key] = int(base_cfg[key])
	xp_to_next = _compute_xp_to_next()
	stats_changed.emit()
	xp_changed.emit(xp, xp_to_next)

func _compute_xp_to_next() -> int:
	return int(xp_base + float(level - 1) * xp_growth)

func add_xp(amount: int) -> void:
	var skills := _get_skill_tree()
	var bonus_amount := amount
	if skills != null:
		bonus_amount = roundi(float(amount) * (1.0 + float(skills.get_pct("xp_gain_pct")) / 100.0))
	xp += bonus_amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		stat_points += 1
		xp_to_next = _compute_xp_to_next()
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next)

func spend_point(stat_name: String) -> bool:
	if stat_points <= 0 or not base_stats.has(stat_name):
		return false
	stat_points -= 1
	base_stats[stat_name] = int(base_stats[stat_name]) + 1
	stats_changed.emit()
	return true

func get_base(stat_name: String) -> int:
	return int(base_stats.get(stat_name, 0))

func add_base(stat_name: String, amount: int = 1) -> void:
	if base_stats.has(stat_name):
		base_stats[stat_name] = int(base_stats[stat_name]) + amount
		stats_changed.emit()

func _get_equipment() -> Node:
	var p := get_parent()
	if p != null and p.has_node("Equipment"):
		return p.get_node("Equipment")
	return null

func _get_skill_tree() -> Node:
	var p := get_parent()
	if p != null and p.has_node("SkillTree"):
		return p.get_node("SkillTree")
	return null

func get_total(stat_name: String) -> int:
	var total := get_base(stat_name)
	var eq := _get_equipment()
	if eq != null:
		total += int(eq.get_stat_bonus(stat_name))
	total += get_temp_buff_value(stat_name)
	return total

func get_bonus_melee_damage() -> int:
	var coeff: float = float(per_point.get("strength_melee_damage", 0.0))
	return roundi(float(get_total("strength")) * coeff)

func get_bonus_ranged_damage() -> int:
	var coeff: float = float(per_point.get("agility_ranged_damage", 0.0))
	return roundi(float(get_total("agility")) * coeff)

func get_cooldown_mult() -> float:
	var coeff: float = float(per_point.get("agility_cooldown_reduction", 0.0))
	var reduction: float = clampf(float(get_total("agility")) * coeff, 0.0, 0.8)
	return 1.0 - reduction

func get_max_health_bonus() -> int:
	var coeff: float = float(per_point.get("vitality_max_health", 0.0))
	return roundi(float(get_total("vitality")) * coeff)

func get_potion_heal_bonus() -> int:
	var coeff: float = float(per_point.get("intelligence_potion_heal", 0.0))
	return roundi(float(get_total("intelligence")) * coeff)

func get_max_mana_bonus() -> int:
	var coeff: float = float(per_point.get("intelligence_max_mana", 0.0))
	return roundi(float(get_total("intelligence")) * coeff)

func get_bonus_wand_damage() -> int:
	var coeff: float = float(per_point.get("intelligence_wand_damage", 0.0))
	return roundi(float(get_total("intelligence")) * coeff)
