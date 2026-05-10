
extends BasicState

@export var battlecry_duration: float = 0.9
@export var death_duration: float = 1.1

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/actinos/actinos_death_effect.tscn")

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false

func enter() -> void:
	is_active = true
	if is_instance_valid(monster):
		monster.velocity = Vector2.ZERO
		monster.set_physics_process(false)
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
	if Engine.has_singleton("Game"):
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
	if Engine.has_singleton("Game"):
		Game.shake_camera(6)
	_queue_free_boss()

func _queue_free_boss() -> void:
	if is_instance_valid(monster):
		monster.queue_free()
