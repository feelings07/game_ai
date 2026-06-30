extends Node

signal choice_available(tier: int)
signal skill_unlocked(skill_id: String)

const LEVELS_PER_TIER := 5

var unlocked: Array[String] = []
var pending_tiers: Array[int] = []
var second_wind_used: bool = false

func on_level_up(new_level: int) -> void:
	if new_level % LEVELS_PER_TIER != 0:
		return
	var tier: int = new_level / LEVELS_PER_TIER
	if tier > SkillDB.max_tier():
		return
	if pending_tiers.has(tier) or _tier_already_chosen(tier):
		return
	pending_tiers.append(tier)
	choice_available.emit(tier)

func _tier_already_chosen(tier: int) -> bool:
	for id: String in unlocked:
		var sk: Dictionary = SkillDB.get_skill(id)
		if int(sk.get("tier", 0)) == tier:
			return true
	return false

func has_pending() -> bool:
	return not pending_tiers.is_empty()

func next_pending_tier() -> int:
	if pending_tiers.is_empty():
		return 0
	return pending_tiers[0]

func get_choices_for_tier(tier: int) -> Array[Dictionary]:
	return SkillDB.get_by_tier(tier)

func choose(skill_id: String) -> bool:
	var sk: Dictionary = SkillDB.get_skill(skill_id)
	if sk.is_empty():
		return false
	var tier: int = int(sk.get("tier", 0))
	if not pending_tiers.has(tier):
		return false
	pending_tiers.erase(tier)
	unlocked.append(skill_id)
	skill_unlocked.emit(skill_id)
	return true

func has_effect(effect_key: String) -> bool:
	for id: String in unlocked:
		var sk: Dictionary = SkillDB.get_skill(id)
		if str(sk.get("effect", "")) == effect_key:
			return true
	return false

func get_pct(effect_key: String) -> float:
	var total := 0.0
	for id: String in unlocked:
		var sk: Dictionary = SkillDB.get_skill(id)
		if str(sk.get("effect", "")) == effect_key:
			total += float(sk.get("value", 0.0))
	return total

func reset() -> void:
	unlocked.clear()
	pending_tiers.clear()
	second_wind_used = false
