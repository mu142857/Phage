extends BasicState

@export var jump_y: float = -450.0
@export var gravity: float = 30.0
@export var max_horizontal_speed: float = 120.0
@export var effect_offset: Vector2 = Vector2(0.0, 6.0)

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var player_check: Area2D = $"../../PlayerCheck"

const JUMP_EFFECT_SCENE: PackedScene = preload("res://entities/actinos/actinos_jump_effect.tscn")

var target_x: float = 0.0
var started_jump: bool = false

func enter() -> void:
	started_jump = false
	monster.velocity = Vector2.ZERO
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Prejump")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)
	_set_target_x()

func process(_delta: float) -> void:
	if not started_jump:
		return

	monster.velocity.y += gravity
	monster.move_and_slide()

	if monster.is_on_floor() and monster.velocity.y >= 0.0:
		_spawn_jump_effect(monster.global_position + effect_offset)
		change_state(1)

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	if ani_2D.animation == &"Prejump":
		ani_2D.play(&"Jump")
		started_jump = true
		monster.velocity.y = jump_y
		var dx := target_x - monster.global_position.x
		var speed_x := clampf(dx / 0.6, -max_horizontal_speed, max_horizontal_speed)
		monster.velocity.x = speed_x

func _set_target_x() -> void:
	var found := false
	if is_instance_valid(player_check):
		for body in player_check.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				target_x = body.global_position.x
				found = true
				break
	if not found:
		target_x = monster.global_position.x

func _spawn_jump_effect(pos: Vector2) -> void:
	if JUMP_EFFECT_SCENE == null:
		return
	var effect := JUMP_EFFECT_SCENE.instantiate()
	if effect == null:
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = pos
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
