extends CharacterBody2D

const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const TEX_ARROW      := preload("res://assets/sprites/arrow.png")
const TEX_MAGIC_BOLT := preload("res://assets/sprites/magic_bolt.png")
const TEX_FIREBALL   := preload("res://assets/sprites/fireball.png")
const WORLD_ITEM_SCRIPT := preload("res://scripts/world_item.gd")
const LEASH_MULT := 1.3
const BAR_WIDTH := 28.0
const BAR_HEIGHT := 4.0

var speed: float = 70.0
var damage: int = 10
var max_health: int = 30
var health: int = 30
var level: int = 1
var xp_reward: int = 10
var is_boss: bool = false
var enemy_type: String = "melee"
var attack_range: float = 120.0
var attack_cooldown: float = 0.6
var projectile_speed: float = 300.0

var _proj_tex: Texture2D = null
var _data: Dictionary = {}

var direction: Vector2 = Vector2.RIGHT
var _aware: bool = false
var _can_hit: bool = true
var _wander_timer: float = 0.0
var _attack_timer: float = 0.0
var _hp_fill: ColorRect = null

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	_pick_new_direction()
	$HitArea.body_entered.connect(_on_hit_area_body_entered)
	_build_status_ui()

func setup(data: Dictionary, enemy_level: int = 1) -> void:
	_data = data
	level = max(enemy_level, 1)
	var mult_health: float = 1.0 + float(level - 1) * 0.25
	var mult_damage: float = 1.0 + float(level - 1) * 0.2

	speed = float(data.get("speed", speed))
	max_health = roundi(float(data.get("health", max_health)) * mult_health)
	health = max_health
	damage = roundi(float(data.get("damage", damage)) * mult_damage)
	enemy_type = str(data.get("type", enemy_type))
	attack_range = float(data.get("attack_range", attack_range))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	projectile_speed = float(data.get("projectile_speed", projectile_speed))
	xp_reward = roundi(float(data.get("xp_reward", 10)) * float(level))
	match str(data.get("projectile_type", "arrow")):
		"magic_bolt": _proj_tex = TEX_MAGIC_BOLT
		"fireball":   _proj_tex = TEX_FIREBALL
		_:            _proj_tex = TEX_ARROW

func _build_status_ui() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.13, 0.13, 0.9)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.position = Vector2(-BAR_WIDTH / 2.0, -30.0)
	add_child(bar_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.8, 0.15, 0.15)
	_hp_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_fill.position = bar_bg.position
	add_child(_hp_fill)

	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.position = Vector2(-BAR_WIDTH / 2.0, -46.0)
	level_label.text = ("BOSS Lvl %d" % level) if is_boss else ("Lvl %d" % level)
	add_child(level_label)

	_update_health_bar()

func _update_health_bar() -> void:
	if _hp_fill == null:
		return
	var ratio: float = float(health) / float(max(max_health, 1))
	_hp_fill.size = Vector2(BAR_WIDTH * clampf(ratio, 0.0, 1.0), BAR_HEIGHT)
	_hp_fill.color = Color(0.8, 0.15, 0.15) if ratio > 0.3 else Color(0.9, 0.55, 0.1)

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	var player := _find_player()
	var engaged := false
	if player != null:
		var detect_mult: float = 1.8 if enemy_type == "ranged" else 1.0
		var leash: float = attack_range * detect_mult * (LEASH_MULT if _aware else 1.0)
		var dist := global_position.distance_to(player.global_position)
		if dist <= leash and _has_line_of_sight(player):
			engaged = true
			_aware = true
		else:
			_aware = false

	if engaged:
		direction = (player.global_position - global_position).normalized()
		if enemy_type == "ranged":
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_shoot(player.global_position)
				_attack_timer = attack_cooldown
		else:
			velocity = direction * speed
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_new_direction()
		velocity = direction * speed

	move_and_slide()

	if is_on_wall() and not engaged:
		_pick_new_direction()

	if velocity.length() > 0.0:
		$Sprite2D.rotation = velocity.angle()
	elif engaged:
		$Sprite2D.rotation = direction.angle()

func _has_line_of_sight(player: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	return result.is_empty()

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D

func _pick_new_direction() -> void:
	var angle: float = randf() * TAU
	direction = Vector2.RIGHT.rotated(angle)
	_wander_timer = randf_range(1.0, 2.5)

func _shoot(target_pos: Vector2) -> void:
	var dir := (target_pos - global_position).normalized()
	var proj := Area2D.new()
	proj.set_script(PROJECTILE_SCRIPT)
	proj.collision_layer = 0
	proj.collision_mask = 0
	proj.velocity = dir * projectile_speed
	proj.damage = damage
	proj.target_group = "player"
	proj.set_collision_mask_value(1, true)
	proj.set_collision_mask_value(2, true)
	var spr := Sprite2D.new()
	spr.texture = _proj_tex if _proj_tex != null else TEX_ARROW
	proj.add_child(spr)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 8)
	shape.shape = rect
	proj.add_child(shape)
	get_parent().add_child(proj)
	proj.global_position = global_position
	$Sprite2D.rotation = dir.angle()
	_play_attack_anim()

func _on_hit_area_body_entered(body: Node) -> void:
	if not _can_hit or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	if body.has_method("get_thorns_pct"):
		var thorns_pct: float = float(body.get_thorns_pct())
		if thorns_pct > 0.0:
			var reflect := roundi(float(damage) * thorns_pct / 100.0)
			if reflect > 0:
				take_damage(reflect)
	_play_attack_anim()
	_start_cooldown()

func _play_attack_anim() -> void:
	var frames: SpriteFrames = $Sprite2D.sprite_frames
	if frames == null or not frames.has_animation("attack"):
		return
	$Sprite2D.play("attack")
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree():
		$Sprite2D.play("walk")

func _start_cooldown() -> void:
	_can_hit = false
	await get_tree().create_timer(0.6).timeout
	_can_hit = true

func take_damage(amount: int, from_position: Vector2 = global_position) -> void:
	health -= amount
	_aware = true
	_update_health_bar()
	if health <= 0:
		_grant_xp_and_die()

func _grant_xp_and_die() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node = players[0]
		if p.has_node("Stats"):
			var st: Node = p.get_node("Stats")
			var diff: int = int(st.level) - level
			var xp_mult: float
			if diff > 5:
				xp_mult = 0.0
			elif diff > 0:
				xp_mult = maxf(0.1, 1.0 - float(diff) * 0.18)
			else:
				xp_mult = 1.0
			if xp_mult > 0.0:
				st.add_xp(roundi(float(xp_reward) * xp_mult))
	_drop_loot()
	if is_boss:
		GameEvents.boss_defeated.emit()
	queue_free()

func _drop_loot() -> void:
	var drop_level_min: int = int(_data.get("drop_level_min", 1))
	if level < drop_level_min:
		return
	var drop_table: Array = _data.get("drop_table", [])
	if drop_table.is_empty():
		return
	var loot_mult: float = 1.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node = players[0]
		if p.has_method("get_loot_chance_pct"):
			loot_mult += float(p.get_loot_chance_pct()) / 100.0
	for entry in drop_table:
		var chance: float = float(entry.get("chance", 0.0)) * loot_mult
		if randf() < chance:
			var id: String = str(entry.get("id", ""))
			if id != "":
				_spawn_world_item(LootConfig.roll_instance(id))

func _spawn_world_item(instance: Dictionary) -> void:
	var wi := Area2D.new()
	wi.set_script(WORLD_ITEM_SCRIPT)
	wi.setup(instance)
	wi.position = _find_safe_drop_pos(global_position)
	get_parent().add_child(wi)

func _find_safe_drop_pos(from: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var candidates: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20),
		Vector2(14, 14), Vector2(-14, 14), Vector2(14, -14), Vector2(-14, -14),
	]
	for off: Vector2 in candidates:
		var pos := from + off
		var query := PhysicsPointQueryParameters2D.new()
		query.position = pos
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if space.intersect_point(query).is_empty():
			return pos
	return from
