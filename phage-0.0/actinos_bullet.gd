# res://entities/actinos/actinos_bullet.tscn
extends Node2D

@export var gravity: float = 900.0
@export var flight_time: float = 0.45

const SPIKE_SCENE: PackedScene = preload("res://entities/actinos/actinos_spike.tscn")

var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var active: bool = false

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
		gravity = gravity_override
	var t := maxf(flight_time, 0.01)
	velocity.x = (target_position.x - start_pos.x) / t
	velocity.y = (target_position.y - start_pos.y - 0.5 * gravity * t * t) / t
	elapsed = 0.0
	active = true

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	velocity.y += gravity * delta
	global_position += velocity * delta
	if elapsed >= flight_time:
		_spawn_spike()
		queue_free()

func _spawn_spike() -> void:
	if SPIKE_SCENE == null:
		return
	var spike := SPIKE_SCENE.instantiate() as Node2D
	if spike == null:
		return
	if get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(spike)
	spike.global_position = target_position
