extends Area2D

@export var projectile_gravity: float = 500.0
@export var flight_time: float = 1.0
@export var damage_amount: int = 5

const IMPACT_EFFECT_SCENE: PackedScene = preload("res://entities/pop_tops/pop_tops_bullet_effects.tscn")

var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var active: bool = false
var damage_applied: bool = false

func _ready() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		sprite.play(&"default")

func setup(start_pos: Vector2, target_pos: Vector2, time_override: float = -1.0, gravity_override: float = -1.0) -> void:
	global_position = start_pos
	target_position = target_pos
	if time_override > 0.0:
		flight_time = time_override
	if gravity_override > 0.0:
		projectile_gravity = gravity_override
	var t := maxf(flight_time, 0.01)
	velocity.x = (target_position.x - start_pos.x) / t
	velocity.y = (target_position.y - start_pos.y - 0.5 * projectile_gravity * t * t) / t
	elapsed = 0.0
	active = true
	damage_applied = false

func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	velocity.y += projectile_gravity * delta
	global_position += velocity * delta
	_try_damage_player()
	if elapsed >= flight_time:
		_spawn_impact_effect()
		queue_free()

func _try_damage_player() -> void:
	if damage_applied:
		return
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage_amount)
		damage_applied = true
		break

func _spawn_impact_effect() -> void:
	if IMPACT_EFFECT_SCENE == null:
		return
	if get_tree().current_scene == null:
		return
	var effect := IMPACT_EFFECT_SCENE.instantiate()
	if effect == null:
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = target_position
