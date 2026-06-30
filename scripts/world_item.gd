extends Area2D

const PICKUP_TEXT := preload("res://scripts/pickup_text.gd")
const TEX_SHADOW := preload("res://assets/sprites/shadow_small.png")
const SPIN_SPEED := 3.0

var instance: Dictionary = {}
var _sprite: Sprite2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)

func setup(item_instance: Dictionary) -> void:
	instance = item_instance
	var id := str(instance.get("id", ""))
	var item: Dictionary = ItemDB.get_item(id)

	var shadow := Sprite2D.new()
	shadow.texture = TEX_SHADOW
	shadow.scale = Vector2(0.6, 0.6)
	shadow.position = Vector2(0, 6)
	add_child(shadow)

	var path := str(item.get("world_icon", item.get("icon", "")))
	_sprite = Sprite2D.new()
	_sprite.texture = load(path) as Texture2D
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

func _process(delta: float) -> void:
	if _sprite != null:
		_sprite.rotation += SPIN_SPEED * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or not body.has_node("Inventory"):
		return
	var inv: Node = body.get_node("Inventory")
	if inv.add_item(instance):
		var id := str(instance.get("id", ""))
		var rarity := str(instance.get("rarity", "common"))
		var item: Dictionary = ItemDB.get_item(id)
		PICKUP_TEXT.spawn(get_parent(), global_position, str(item.get("name", id)), rarity, 0)
		queue_free()
