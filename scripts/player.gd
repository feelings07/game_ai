extends CharacterBody2D

signal health_changed(current: int, max_health: int)
signal mana_changed(current: int, max_mana: int)

const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const FLOATING_TEXT_SCRIPT := preload("res://scripts/floating_text.gd")
const TEX_ARROW := preload("res://assets/sprites/arrow.png")
const TEX_FIRE := preload("res://assets/sprites/proj_fire.png")
const TEX_ICE := preload("res://assets/sprites/proj_ice.png")
const TEX_LIGHTNING := preload("res://assets/sprites/proj_lightning.png")
const ANIM_UTILS := preload("res://scripts/anim_utils.gd")
const WALK_FRAMES: Array[String] = [
	"res://assets/sprites/player_walk_0.png",
	"res://assets/sprites/player_walk_1.png",
	"res://assets/sprites/player_walk_2.png",
	"res://assets/sprites/player_walk_3.png"
]
const MANA_REGEN_PER_SEC := 4.0

@export var speed: float = 220.0
@export var base_max_health: int = 100
@export var base_max_mana: int = 50

var max_health: int = 100
var health: int
var max_mana: int = 50
var mana: float = 50.0
var stun_timer: float = 0.0
var invuln_timer: float = 0.0
var attack_timer: float = 0.0
var spawn_point: Vector2 = Vector2.ZERO
var nearby_chest: Node = null
var ui_open: bool = false
var _ui_blockers: int = 0
var _last_mana_displayed: int = -1
var _hp_regen_accum: float = 0.0

@onready var inventory: Node = $Inventory
@onready var equipment: Node = $Equipment
@onready var stats: Node = $Stats
@onready var skill_tree: Node = $SkillTree

func _ready() -> void:
	$Sprite2D.sprite_frames = ANIM_UTILS.build_walk_frames(WALK_FRAMES)
	$Sprite2D.play("walk")
	add_to_group("player")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	_apply_max_stats(true)
	$InteractZone.area_entered.connect(_on_interact_area_entered)
	$InteractZone.area_exited.connect(_on_interact_area_exited)
	stats.stats_changed.connect(_on_stats_changed)
	stats.leveled_up.connect(_on_leveled_up)
	stats.leveled_up.connect(skill_tree.on_level_up)
	skill_tree.skill_unlocked.connect(_on_skill_unlocked)

func set_spawn_point(p: Vector2) -> void:
	spawn_point = p

func set_ui_open(open: bool) -> void:
	_ui_blockers += 1 if open else -1
	_ui_blockers = maxi(_ui_blockers, 0)
	ui_open = _ui_blockers > 0

func _physics_process(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer -= delta
		$Sprite2D.visible = int(invuln_timer * 10) % 2 == 0
	else:
		$Sprite2D.visible = true

	if attack_timer > 0.0:
		attack_timer -= delta

	var regen_mult: float = 1.0 + float(skill_tree.get_pct("mana_regen_pct")) / 100.0
	if mana < float(max_mana):
		mana = minf(mana + MANA_REGEN_PER_SEC * regen_mult * delta, float(max_mana))
		var displayed := int(mana)
		if displayed != _last_mana_displayed:
			_last_mana_displayed = displayed
			mana_changed.emit(displayed, max_mana)

	var hp_regen: float = float(skill_tree.get_pct("hp_regen_per_sec"))
	if hp_regen > 0.0 and health < max_health:
		_hp_regen_accum += hp_regen * delta
		if _hp_regen_accum >= 1.0:
			var add := int(_hp_regen_accum)
			_hp_regen_accum -= float(add)
			health = mini(health + add, max_health)
			health_changed.emit(health, max_health)

	if not ui_open:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			$Sprite2D.rotation = to_mouse.angle()

	if stun_timer > 0.0:
		stun_timer -= delta
	else:
		var input_vec := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		var speed_mult: float = 1.0 + float(skill_tree.get_pct("move_speed_pct")) / 100.0
		if input_vec.length() > 0.0:
			velocity = input_vec.normalized() * speed * speed_mult
		else:
			velocity = Vector2.ZERO

	move_and_slide()

	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and not ui_open:
		_attack()

	if Input.is_action_just_pressed("interact") and nearby_chest != null:
		nearby_chest.open(self)

func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_use_quick_potion("health")
				get_viewport().set_input_as_handled()
			KEY_2:
				_use_quick_potion("mana")
				get_viewport().set_input_as_handled()

func _use_quick_potion(potion_type: String) -> void:
	var idx: int = inventory.find_potion(potion_type)
	if idx >= 0:
		var instance: Dictionary = inventory.items[idx].duplicate()
		if use_potion(instance):
			inventory.remove_at(idx)

func _attack() -> void:
	var weapon: Dictionary = equipment.get_weapon_data()
	var weapon_type: String = str(weapon.get("weapon_type", "melee"))
	var dir := Vector2.RIGHT.rotated($Sprite2D.rotation)
	var dmg := int(weapon.get("damage", 5))
	var cooldown_skill_mult: float = 1.0 + float(skill_tree.get_pct("attack_cooldown_pct")) / 100.0
	var double_shot_chance: float = float(skill_tree.get_pct("double_shot_chance"))

	if weapon_type == "wand":
		var mana_cost: float = float(weapon.get("mana_cost", 10)) * (1.0 + float(skill_tree.get_pct("wand_mana_cost_pct")) / 100.0)
		if mana < mana_cost:
			attack_timer = 0.3
			_show_no_mana_text()
			return
		mana -= mana_cost
		_last_mana_displayed = int(mana)
		mana_changed.emit(int(mana), max_mana)
		dmg += int(stats.get_bonus_wand_damage())
		dmg = int(float(dmg) * (1.0 + float(skill_tree.get_pct("wand_damage_pct")) / 100.0))
		attack_timer = float(weapon.get("attack_cooldown", 0.5)) * float(stats.get_cooldown_mult()) * cooldown_skill_mult
		var proj_speed: float = float(weapon.get("projectile_speed", 350))
		var element := str(weapon.get("element", "fire"))
		_spawn_elemental_projectile(dir, dmg, proj_speed, element)
		if randf() * 100.0 < double_shot_chance:
			_spawn_elemental_projectile(dir, dmg, proj_speed, element)
	elif weapon_type == "ranged":
		dmg += int(stats.get_bonus_ranged_damage())
		dmg = int(float(dmg) * (1.0 + float(skill_tree.get_pct("ranged_damage_pct")) / 100.0))
		attack_timer = float(weapon.get("attack_cooldown", 0.4)) * float(stats.get_cooldown_mult()) * cooldown_skill_mult
		var proj_speed2: float = float(weapon.get("projectile_speed", 300))
		_spawn_projectile(dir, dmg, proj_speed2)
		if randf() * 100.0 < double_shot_chance:
			_spawn_projectile(dir, dmg, proj_speed2)
	else:
		dmg += int(stats.get_bonus_melee_damage())
		dmg = int(float(dmg) * (1.0 + float(skill_tree.get_pct("melee_damage_pct")) / 100.0))
		if float(health) < float(max_health) * 0.3:
			dmg = int(float(dmg) * (1.0 + float(skill_tree.get_pct("berserk_melee_damage_pct")) / 100.0))
		attack_timer = float(weapon.get("attack_cooldown", 0.4)) * float(stats.get_cooldown_mult()) * cooldown_skill_mult
		_melee_attack(dir, dmg, float(weapon.get("attack_range", 26)))

func _show_no_mana_text() -> void:
	_show_text("Нет маны!", Color(0.6, 0.6, 1.0))

func _show_dodge_text() -> void:
	_show_text("Уклонение!", Color(0.7, 0.9, 1.0))

func _show_second_wind_text() -> void:
	_show_text("Второе дыхание!", Color(1.0, 0.8, 0.2))

func _show_text(text: String, color: Color) -> void:
	var txt := Node2D.new()
	txt.set_script(FLOATING_TEXT_SCRIPT)
	get_parent().add_child(txt)
	txt.global_position = global_position + Vector2(-30.0, -30.0)
	txt.setup(text, color)

func _melee_attack(dir: Vector2, dmg: int, atk_range: float) -> void:
	var hitbox := Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.set_collision_mask_value(3, true)
	hitbox.global_position = global_position + dir * (atk_range * 0.5)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = atk_range * 0.5
	shape.shape = circle
	hitbox.add_child(shape)
	get_parent().add_child(hitbox)
	await get_tree().physics_frame
	var lifesteal_pct: float = float(skill_tree.get_pct("lifesteal_pct"))
	for body: Node2D in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(dmg, global_position)
			if lifesteal_pct > 0.0:
				var heal_amt := int(float(dmg) * lifesteal_pct / 100.0)
				if heal_amt > 0:
					health = mini(health + heal_amt, max_health)
					health_changed.emit(health, max_health)
	hitbox.queue_free()

func _spawn_projectile(dir: Vector2, dmg: int, proj_speed: float) -> void:
	var proj := Area2D.new()
	proj.set_script(PROJECTILE_SCRIPT)
	proj.collision_layer = 0
	proj.collision_mask = 0
	proj.velocity = dir * proj_speed
	proj.damage = dmg
	proj.target_group = "enemy"
	proj.pierce = bool(skill_tree.has_effect("piercing_arrows"))
	proj.set_collision_mask_value(1, true)
	proj.set_collision_mask_value(3, true)
	var spr := Sprite2D.new()
	spr.texture = TEX_ARROW
	proj.add_child(spr)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 8)
	shape.shape = rect
	proj.add_child(shape)
	get_parent().add_child(proj)
	proj.global_position = global_position

func _spawn_elemental_projectile(dir: Vector2, dmg: int, proj_speed: float, element: String) -> void:
	var proj := Area2D.new()
	proj.set_script(PROJECTILE_SCRIPT)
	proj.collision_layer = 0
	proj.collision_mask = 0
	proj.velocity = dir * proj_speed
	proj.damage = dmg
	proj.target_group = "enemy"
	proj.set_collision_mask_value(1, true)
	proj.set_collision_mask_value(3, true)
	var spr := Sprite2D.new()
	spr.texture = _element_texture(element)
	proj.add_child(spr)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	proj.add_child(shape)
	get_parent().add_child(proj)
	proj.global_position = global_position

func _element_texture(element: String) -> Texture2D:
	if element == "ice":
		return TEX_ICE
	if element == "lightning":
		return TEX_LIGHTNING
	return TEX_FIRE

func _on_interact_area_entered(area: Node) -> void:
	if area.has_method("open"):
		nearby_chest = area

func _on_interact_area_exited(area: Node) -> void:
	if nearby_chest == area:
		nearby_chest = null

func get_thorns_pct() -> float:
	return float(skill_tree.get_pct("thorns_pct"))

func get_loot_chance_pct() -> float:
	return float(skill_tree.get_pct("loot_chance_pct"))

func take_damage(amount: int, from_position: Vector2 = global_position) -> void:
	if invuln_timer > 0.0:
		return
	if randf() * 100.0 < float(skill_tree.get_pct("dodge_chance")):
		_show_dodge_text()
		return
	var armor_total: int = int(equipment.get_total_armor()) + int(skill_tree.get_pct("armor_flat"))
	var reduced: int = max(amount - armor_total, 1)
	var new_health: int = health - reduced
	if new_health <= 0 and skill_tree.has_effect("second_wind") and not bool(skill_tree.second_wind_used):
		skill_tree.second_wind_used = true
		health = 1
		health_changed.emit(health, max_health)
		_show_second_wind_text()
	else:
		health = max(new_health, 0)
		health_changed.emit(health, max_health)
	invuln_timer = 0.6
	stun_timer = 0.25
	var away: Vector2 = (global_position - from_position)
	if away.length() == 0.0:
		away = Vector2.RIGHT
	velocity = away.normalized() * 260.0
	if health <= 0:
		_respawn()

func _respawn() -> void:
	full_reset()
	GameEvents.player_died.emit()

func full_reset() -> void:
	velocity = Vector2.ZERO
	inventory.clear()
	equipment.clear()
	stats.reset()
	skill_tree.reset()
	_apply_max_stats(true)
	inventory.add_item(ItemDB.make_instance("dagger_rusty"))
	inventory.add_item(ItemDB.make_instance("potion_health"))

func use_potion(instance: Dictionary) -> bool:
	var id := str(instance.get("id", ""))
	var item: Dictionary = ItemDB.get_item(id)
	if str(item.get("type", "")) != "potion":
		return false
	var heal_amount := int(item.get("heal", 0))
	var mana_amount := int(item.get("mana", 0))
	var used := false
	if heal_amount > 0:
		var total_heal := heal_amount + int(stats.get_potion_heal_bonus())
		health = min(health + total_heal, max_health)
		health_changed.emit(health, max_health)
		used = true
	if mana_amount > 0:
		mana = minf(mana + float(mana_amount), float(max_mana))
		_last_mana_displayed = int(mana)
		mana_changed.emit(int(mana), max_mana)
		used = true
	if str(instance.get("rarity", "common")) == "rare":
		var bonus_stat: String = str(instance.get("bonus_stat", ""))
		var bonus_value: int = int(instance.get("bonus_value", 0))
		if bonus_stat != "" and bonus_value > 0:
			var duration: float = randf_range(15.0, 60.0)
			stats.apply_temp_buff(bonus_stat, bonus_value, duration)
			used = true
	return used

func _on_stats_changed() -> void:
	_apply_max_stats(false)

func _on_skill_unlocked(_skill_id: String) -> void:
	_apply_max_stats(false)

func _on_leveled_up(new_level: int) -> void:
	_apply_max_stats(true)
	var txt := Node2D.new()
	txt.set_script(FLOATING_TEXT_SCRIPT)
	get_parent().add_child(txt)
	txt.global_position = global_position + Vector2(0, -48)
	txt.setup("Уровень %d!" % new_level, Color(1.0, 0.88, 0.1))

func _apply_max_stats(full_restore: bool) -> void:
	var base_hp := base_max_health + int(stats.get_max_health_bonus())
	var new_max_hp := int(float(base_hp) * (1.0 + float(skill_tree.get_pct("max_health_pct")) / 100.0))
	var hp_diff := new_max_hp - max_health
	max_health = new_max_hp
	if full_restore:
		health = max_health
	elif hp_diff > 0:
		health += hp_diff
	health = clampi(health, 0, max_health)
	health_changed.emit(health, max_health)

	var base_mp := base_max_mana + int(stats.get_max_mana_bonus())
	var new_max_mp := int(float(base_mp) * (1.0 + float(skill_tree.get_pct("max_mana_pct")) / 100.0))
	var mp_diff := new_max_mp - max_mana
	max_mana = new_max_mp
	if full_restore:
		mana = float(max_mana)
	elif mp_diff > 0:
		mana += float(mp_diff)
	mana = clampf(mana, 0.0, float(max_mana))
	_last_mana_displayed = int(mana)
	mana_changed.emit(int(mana), max_mana)
