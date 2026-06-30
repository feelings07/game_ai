extends Area2D

const TEX_CLOSED := preload("res://assets/sprites/chest_closed.png")
const TEX_OPEN := preload("res://assets/sprites/chest_open.png")
const WORLD_ITEM_SCRIPT := preload("res://scripts/world_item.gd")

var is_open: bool = false
var loot_items: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(6, true)
	$Sprite2D.texture = TEX_CLOSED

func open(player: Node) -> void:
	if is_open:
		return
	is_open = true
	$Sprite2D.texture = TEX_OPEN
	for instance: Dictionary in loot_items:
		_spawn_world_item(instance)

func _spawn_world_item(instance: Dictionary) -> void:
	var wi := Area2D.new()
	wi.set_script(WORLD_ITEM_SCRIPT)
	wi.setup(instance)
	wi.position = global_position + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-16.0, 16.0))
	get_parent().add_child(wi)
