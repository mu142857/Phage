
extends BasicState

@export var battlecry_duration: float = 0.9
@export var death_duration: float = 1.1

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/actinos/actinos_death_effect.tscn")

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var jump_hitbox: Area2D = $"../../JumpHitBox"
@onready var player_check: Area2D = $"../../PlayerCheck"
@onready var normal_collision: CollisionShape2D = $"../../NormalCollision"
@onready var jump_collision: CollisionShape2D = $"../../JumpCollision"

var is_active: bool = false

func enter() -> void:
	is_active = true
	if is_instance_valid(monster):
		monster.velocity = Vector2.ZERO
		monster.set_physics_process(false)
		_disable_collision_and_interaction()
		_play_sequence()

func exit() -> void:
	is_active = false

func _play_sequence() -> void:
	if not is_instance_valid(ani_2D):
		_queue_free_boss()
		return
	# 如果 host（monster）有隐藏血条的方法，先隐藏
	if is_instance_valid(monster) and monster.has_method("hide_health_ui"):
		monster.call("hide_health_ui")
	ani_2D.play(&"Battlecry")
	await get_tree().create_timer(battlecry_duration).timeout
	if not is_active or not is_instance_valid(ani_2D):
		return
	# Death 动画期间做轻微震动
	ani_2D.play(&"Death")
	Game.shake_camera(2)
	await get_tree().create_timer(death_duration).timeout
	if not is_active:
		return
	# 播放死亡粒子效果并做较强震动
	if DEATH_EFFECT_SCENE != null and is_instance_valid(monster):
		var eff := DEATH_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = monster.global_position
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	Game.shake_camera(6)
	_queue_free_boss()

func _disable_collision_and_interaction() -> void:
	if is_instance_valid(monster):
		monster.collision_layer = 0
		monster.collision_mask = 0
	if is_instance_valid(normal_collision):
		normal_collision.disabled = true
	if is_instance_valid(jump_collision):
		jump_collision.disabled = true
	if is_instance_valid(jump_hitbox):
		jump_hitbox.monitoring = false
		jump_hitbox.monitorable = false
		jump_hitbox.collision_layer = 0
		jump_hitbox.collision_mask = 0
	if is_instance_valid(player_check):
		player_check.monitoring = false
		player_check.monitorable = false
		player_check.collision_layer = 0
		player_check.collision_mask = 0

func _queue_free_boss() -> void:
	if is_instance_valid(monster):
		monster.queue_free()
