#Cox
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cox/cox_death.tscn")

@export var max_health: int = 1100
@export var health: int = 1100
@export var idle_hover_amplitude: float = 15.0
@export var idle_hover_speed: float = 2.2
@export var hover_follow_speed: float = 62.0
@export var chase_speed: float = 45.0
@export var collision_damage: int = 8
@export var contact_damage_cooldown: float = 0.35
@export var knockback_speed: float = 310.0
@export var knockback_vertical_speed: float = -40.0
@export var knockback_duration: float = 0.1

var _spawn_position: Vector2 = Vector2.ZERO
var _time_passed: float = 0.0
var _contact_damage_time_left: float = 0.0
var _knockback_time_left: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _player_detected: bool = false
var _attack_phase: int = 0
var _base_modulate: Color = Color.WHITE
var _base_sprite_scale_x: float = 1.0
var _glow_tween: Tween = null

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	_spawn_position = global_position
	if is_instance_valid(sprite):
		if sprite.material != null:
			sprite.material = sprite.material.duplicate()
		_base_modulate = sprite.modulate
		_base_sprite_scale_x = absf(sprite.scale.x)
		if _base_sprite_scale_x == 0.0:
			_base_sprite_scale_x = 1.0
	if is_instance_valid(hit_effect_player):
		hit_effect_player.active = true
	_set_player_detected(false, true)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if _knockback_time_left > 0.0:
		_knockback_time_left = maxf(0.0, _knockback_time_left - delta)
		global_position += _knockback_velocity * delta
		if _knockback_time_left <= 0.0:
			_knockback_velocity = Vector2.ZERO
		return

	_time_passed += delta
	_contact_damage_time_left = maxf(0.0, _contact_damage_time_left - delta)

	var detected_player := _get_detected_player()
	if detected_player != null:
		if not _player_detected:
			_set_player_detected(true)
		_update_facing_toward_player(detected_player.global_position.x)
		_update_attack_movement(detected_player, delta)
	else:
		if _player_detected:
			_set_player_detected(false)
			_attack_phase = 0
			_set_attack_glow(false, true)
		var hover_offset := sin(_time_passed * idle_hover_speed) * idle_hover_amplitude
		var hover_position := Vector2(_spawn_position.x, _spawn_position.y + hover_offset)
		global_position = global_position.move_toward(hover_position, hover_follow_speed * delta)

	_try_damage_player()

func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	_play_hit_flash()
	_start_knockback()
	if health <= 0:
		_spawn_death_effect()
		queue_free()

func _get_detected_player() -> Node2D:
	if not is_instance_valid(player_check):
		return null
	for body in player_check.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("player"):
			continue
		if body is Node2D:
			return body as Node2D
	return null

func _set_player_detected(enabled: bool, immediate: bool = false) -> void:
	if _player_detected == enabled and not immediate:
		return
	_player_detected = enabled

func _set_attack_glow(enabled: bool, immediate: bool = false) -> void:
	if not is_instance_valid(sprite):
		return
	if is_instance_valid(_glow_tween):
		_glow_tween.kill()
		_glow_tween = null

	var target_modulate := _base_modulate
	if enabled:
		target_modulate = Color(_base_modulate.r, _base_modulate.g, 3.0, _base_modulate.a)

	if immediate:
		sprite.modulate = target_modulate
		return

	_glow_tween = create_tween()
	_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(sprite, "modulate", target_modulate, 0.2)

func _update_attack_movement(player: Node2D, delta: float) -> void:
	_update_facing_toward_player(player.global_position.x)
	var hover_offset := sin(_time_passed * idle_hover_speed) * idle_hover_amplitude
	var target_above_player := Vector2(player.global_position.x, _spawn_position.y + hover_offset)
	var x_distance := absf(global_position.x - player.global_position.x)

	if _attack_phase == 0:
		global_position = global_position.move_toward(target_above_player, chase_speed * delta)
		if x_distance <= 10.0:
			_attack_phase = 1
			_set_attack_glow(true)
		return

	var attack_target := Vector2(player.global_position.x, player.global_position.y + hover_offset)
	global_position = global_position.move_toward(attack_target, chase_speed * delta)
	_set_attack_glow(true)

func _update_facing_toward_player(player_x: float) -> void:
	if not is_instance_valid(sprite):
		return
	var facing := 1.0
	if player_x > global_position.x:
		facing = -1.0
	var scale_x := _base_sprite_scale_x
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * facing

func _try_damage_player() -> void:
	if _contact_damage_time_left > 0.0:
		return
	if not is_instance_valid(attack_check):
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", collision_damage)
			_contact_damage_time_left = contact_damage_cooldown
			return

func _play_hit_flash() -> void:
	if is_instance_valid(hit_effect_player):
		hit_effect_player.play(&"HitFlash")

func _start_knockback() -> void:
	if Game.suppress_hit_knockback:
		return  # 召唤物等软伤害:掉血但不位移
	var knockback_direction := -1.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var candidate := players[0]
		if candidate is Node2D:
			knockback_direction = sign(global_position.x - (candidate as Node2D).global_position.x)
			if knockback_direction == 0.0:
				knockback_direction = -1.0
	_knockback_time_left = knockback_duration
	_knockback_velocity = Vector2(knockback_speed * knockback_direction, knockback_vertical_speed)

func _spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null:
		return
	if get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
