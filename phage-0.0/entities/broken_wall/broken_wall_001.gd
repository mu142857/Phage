extends CharacterBody2D

const MAX_HEALTH: int = 280
const BREAK_EFFECT_LIFETIME: float = 0.8

@export var wall_state_id: StringName = MapElementCounting.BROKEN_WALL_001_ID

var health: int = MAX_HEALTH
var _is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var break_effect_template: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	add_to_group("monster")
	collision_layer = 1
	collision_mask = 2
	if is_instance_valid(attack_area):
		attack_area.add_to_group("breakable_wall")
		attack_area.collision_layer = 4
		attack_area.collision_mask = 0
	if not MapElementCounting.is_wall_intact(wall_state_id):
		_break_and_remove()


func take_damage(amount: int) -> void:
	if _is_broken:
		return
	health = max(0, health - amount)
	if health <= 0:
		_break_and_remove()


func _break_and_remove() -> void:
	if _is_broken:
		return
	_is_broken = true
	MapElementCounting.mark_wall_broken(wall_state_id)
	_spawn_break_effect()
	queue_free()


func _spawn_break_effect() -> void:
	if not is_instance_valid(break_effect_template):
		return
	if get_tree().current_scene == null:
		return
	var effect := break_effect_template.duplicate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	await get_tree().create_timer(maxf(effect.lifetime, BREAK_EFFECT_LIFETIME)).timeout
	if is_instance_valid(effect):
		effect.queue_free()
