extends BasicState

@export var jump_y: float = -180.0
@export var gravity: float = 350.0
@export var max_horizontal_speed: float = 70.0
@export var ground_y: float = 80.0
@export var screen_min_x: float = 0.0
@export var screen_max_x: float = 160.0
@export var jump_damage: int = 20
@export var hit_filter_amount: float = 0.45
@export var hit_filter_color: Color = Color(0.9, 0.1, 0.1, 0.6)
@export var effect_offset: Vector2 = Vector2(0.0, 6.0)

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var player_check: Area2D = $"../../PlayerCheck"
@onready var jump_hitbox: Area2D = $"../../JumpHitBox"
@onready var normal_collision: CollisionShape2D = $"../../NormalCollision"
@onready var jump_collision: CollisionShape2D = $"../../JumpCollision"

const JUMP_EFFECT_SCENE: PackedScene = preload("res://entities/actinos/actinos_jump_effect.tscn")

var target_x: float = 0.0
var started_jump: bool = false
var landing_started: bool = false
var hit_registered: bool = false

func enter() -> void:
	started_jump = false
	landing_started = false
	hit_registered = false
	monster.velocity = Vector2.ZERO
	_set_collision_mode(true)
	_set_jump_hitbox_active(true)
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Prejump")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)
	_set_target_x()
	_set_jump_facing()

func process(delta: float) -> void:
	if not started_jump:
		return
	if landing_started:
		_check_jump_hit()
		return

	monster.velocity.y += gravity * delta
	monster.move_and_slide()
	if monster.global_position.x < screen_min_x or monster.global_position.x > screen_max_x:
		monster.global_position.x = clampf(monster.global_position.x, screen_min_x, screen_max_x)
		monster.velocity.x = 0.0
	var landed := monster.is_on_floor()
	if monster.global_position.y >= ground_y:
		monster.global_position = Vector2(monster.global_position.x, ground_y)
		if monster.velocity.y > 0.0:
			monster.velocity.y = 0.0
		landed = true

	if landed and monster.velocity.y >= 0.0:
		monster.velocity = Vector2.ZERO
		_spawn_jump_effect(monster.global_position + effect_offset)
		landing_started = true
		if is_instance_valid(ani_2D):
			ani_2D.play(&"Afterjump")
		_check_jump_hit()

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)
	if is_instance_valid(ani_2D):
		var scale_x := absf(ani_2D.scale.x)
		ani_2D.scale.x = maxf(scale_x, 1.0)
	if is_instance_valid(jump_hitbox):
		var hitbox_scale_x := absf(jump_hitbox.scale.x)
		jump_hitbox.scale.x = maxf(hitbox_scale_x, 1.0)
	_set_jump_hitbox_active(false)
	_set_collision_mode(false)

func _on_animation_finished() -> void:
	if ani_2D.animation == &"Prejump":
		ani_2D.play(&"Jump")
		started_jump = true
		monster.velocity.y = jump_y
		var dx := target_x - monster.global_position.x
		var speed_x := clampf(dx / 0.6, -max_horizontal_speed, max_horizontal_speed)
		monster.velocity.x = speed_x
		return
	if ani_2D.animation == &"Afterjump":
		change_state(1)

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

func _set_jump_facing() -> void:
	if not is_instance_valid(ani_2D) or monster == null:
		return
	var scale_x := maxf(absf(ani_2D.scale.x), 1.0)
	if target_x > monster.global_position.x:
		ani_2D.scale.x = -scale_x
		if is_instance_valid(jump_hitbox):
			jump_hitbox.scale.x = -maxf(absf(jump_hitbox.scale.x), 1.0)
	else:
		ani_2D.scale.x = scale_x
		if is_instance_valid(jump_hitbox):
			jump_hitbox.scale.x = maxf(absf(jump_hitbox.scale.x), 1.0)

func _set_collision_mode(use_jump: bool) -> void:
	if is_instance_valid(normal_collision):
		normal_collision.disabled = use_jump
	if is_instance_valid(jump_collision):
		jump_collision.disabled = not use_jump

func _set_jump_hitbox_active(active: bool) -> void:
	if is_instance_valid(jump_hitbox):
		jump_hitbox.monitoring = active
		jump_hitbox.monitorable = active

func _check_jump_hit() -> void:
	if hit_registered:
		return
	if not is_instance_valid(jump_hitbox):
		return
	for body in jump_hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", jump_damage)
			Game.filter(hit_filter_amount, hit_filter_color)
		hit_registered = true
		break

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
