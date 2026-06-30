extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var target_group: String = "enemy"
var lifetime: float = 1.5
var pierce: bool = false
var _hit_bodies: Array = []

func _ready() -> void:
	rotation = velocity.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(target_group):
		if _hit_bodies.has(body):
			return
		_hit_bodies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		if not pierce:
			queue_free()
	elif body is StaticBody2D:
		queue_free()
