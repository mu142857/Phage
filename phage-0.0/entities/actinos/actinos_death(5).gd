extends BasicState

@export var battlecry_duration: float = 0.9
@export var death_duration: float = 1.1

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
	ani_2D.play(&"Battlecry")
	await get_tree().create_timer(battlecry_duration).timeout
	if not is_active or not is_instance_valid(ani_2D):
		return
	ani_2D.play(&"Death")
	await get_tree().create_timer(death_duration).timeout
	if not is_active:
		return
	_queue_free_boss()

func _queue_free_boss() -> void:
	if is_instance_valid(monster):
		monster.queue_free()
