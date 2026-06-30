extends Area2D

var damage: int = 15
var _can_hit: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not _can_hit or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_can_hit = false
	await get_tree().create_timer(1.0).timeout
	_can_hit = true
