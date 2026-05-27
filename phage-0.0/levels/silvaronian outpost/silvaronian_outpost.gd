extends Node2D

@export var land_y: float = 80.0
@export var drop_duration: float = 0.1

@export var light_shake: float = 0.3
@export var medium_shake: float = 0.6
@export var heavy_shake: float = 1.0
@export var light_duration: float = 1.5
@export var medium_duration: float = 1.5
@export var heavy_duration: float = 1.0
@export var pause_duration: float = 0.4

@export var intro_lock_player: bool = false
@export var start_battlecry_state: bool = true
@export var landing_effect_offset: Vector2 = Vector2(0.0, 6.0)

func _ready() -> void:
	pass

func _start_intro() -> void:
	pass

func _shake_sequence() -> void:
	await _do_shake(light_shake, light_duration)
	await get_tree().create_timer(pause_duration).timeout
	await _do_shake(medium_shake, medium_duration)
	await get_tree().create_timer(pause_duration).timeout
	await _do_shake(heavy_shake, heavy_duration)

func _do_shake(amount: float, duration: float) -> void:
	var timer := get_tree().create_timer(duration)
	while timer.time_left > 0.0:
		Game.shake_camera(amount)
		await get_tree().process_frame


func _on_timer_timeout() -> void:
	call_deferred("_start_intro")
