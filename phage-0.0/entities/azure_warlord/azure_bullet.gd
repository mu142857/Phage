extends Area2D

@export var projectile_gravity: float = 200.0
@export var ground_y: float = 80.0
@export var damage_amount: int = 5

const EFFECT_SCENE: PackedScene = preload("res://entities/azure_warlord/azure_bullet_effects.tscn")

var velocity: Vector2 = Vector2.ZERO
var active: bool = false
var damage_applied: bool = false
var effect_released: bool = false

func setup(start_pos: Vector2) -> void:
	$Trail.emitting = true
	$Sprite2D.modulate.a = 1
	global_position = start_pos
	velocity = Vector2.ZERO
	active = true
	effect_released = false

func _physics_process(delta: float) -> void:
	if not active:
		return
	velocity.y += projectile_gravity * delta
	global_position += velocity * delta
	if global_position.y >= ground_y:
		global_position.y = ground_y
		land()
	else:
		_try_damage_player()

func land():
	if !effect_released:
		_spawn_effect()
		effect_released = true
	$Trail.emitting = false
	$Sprite2D.modulate.a = 0
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _spawn_effect() -> void:
	if EFFECT_SCENE == null:
		return
	var eff := EFFECT_SCENE.instantiate()
	if eff == null:
		return
	if get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(eff)
	eff.global_position = global_position
	eff.emitting = true

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
