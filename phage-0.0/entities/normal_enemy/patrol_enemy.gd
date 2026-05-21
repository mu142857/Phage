class_name Wowen
extends CharacterBody2D

signal died

@export var max_health: int = 1800
@export var health: int = 280
@export var move_speed: float = 40.0
@export var patrol_distance: float = 72.0
@export var use_custom_patrol_range: bool = false
@export var patrol_min_x: float = 0.0
@export var patrol_max_x: float = 0.0
@export var gravity: float = 1000.0
@export var collision_damage: int = 10
@export var contact_damage_cooldown: float = 0.35
@export var knockback_speed: float = 160.0
@export var knockback_vertical_speed: float = -120.0
@export var knockback_duration: float = 0.16
@export var knockback_edge_falloff_distance: float = 48.0
@export var min_knockback_factor: float = 0.15

var direct: int = 1
var _patrol_origin_x: float = 0.0
var _knockback_time_left: float = 0.0
var _contact_damage_time_left: float = 0.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	_patrol_origin_x = global_position.x
	if not use_custom_patrol_range:
		patrol_min_x = _patrol_origin_x - patrol_distance
		patrol_max_x = _patrol_origin_x + patrol_distance
	elif patrol_min_x > patrol_max_x:
		var temp_x = patrol_min_x
		patrol_min_x = patrol_max_x
		patrol_max_x = temp_x
	_setup_body_collision()
	_setup_visual()
	if hit_effect_player != null:
		hit_effect_player.active = true
	_update_facing_visual()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	_contact_damage_time_left = maxf(0.0, _contact_damage_time_left - delta)

	if _knockback_time_left > 0.0:
		_knockback_time_left = maxf(0.0, _knockback_time_left - delta)
		_apply_gravity(delta)
		move_and_slide()
		_try_damage_player_from_collision()
		return

	if _should_turn_around():
		direct *= -1
		_update_facing_visual()

	velocity.x = move_speed * float(direct)
	_apply_gravity(delta)
	move_and_slide()
	_try_damage_player_from_collision()

func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	_play_hit_flash()
	_start_knockback()
	if health <= 0:
		died.emit()
		queue_free()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _start_knockback() -> void:
	var knockback_direction = -float(direct)
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var candidate = players[0]
		if candidate is Node2D:
			var player_x = (candidate as Node2D).global_position.x
			knockback_direction = sign(global_position.x - player_x)
			if knockback_direction == 0.0:
				knockback_direction = -float(direct)
	# Compute horizontal knockback scaling near patrol edges to avoid being knocked off platforms
	var hk_dir = knockback_direction
	var horiz_factor = 1.0
	if patrol_max_x != patrol_min_x:
		var dist_to_min = absf(global_position.x - patrol_min_x)
		var dist_to_max = absf(global_position.x - patrol_max_x)
		var nearest = min(dist_to_min, dist_to_max)
		horiz_factor = clampf(nearest / knockback_edge_falloff_distance, min_knockback_factor, 1.0)

	_knockback_time_left = knockback_duration
	velocity.x = knockback_speed * hk_dir * horiz_factor
	velocity.y = knockback_vertical_speed
	if knockback_direction != 0.0:
		direct = int(sign(knockback_direction))
		_update_facing_visual()

func _play_hit_flash() -> void:
	if hit_effect_player == null:
		return
	hit_effect_player.play(&"HitFlash")

func _try_damage_player_from_collision() -> void:
	if _contact_damage_time_left > 0.0:
		return
	# Prefer Area2D-based attack check if present (prevents physics push issues)
	if attack_check != null and attack_check.get_overlapping_bodies().size() > 0:
		for body in attack_check.get_overlapping_bodies():
			if body == null:
				continue
			if not body.is_in_group("player"):
				continue
			if body.has_method("take_damage"):
				body.call("take_damage", collision_damage)
				_contact_damage_time_left = contact_damage_cooldown
				return

	# Fallback: use slide collisions (legacy behavior)
	var slide_count = get_slide_collision_count()
	for index in range(slide_count):
		var collision = get_slide_collision(index)
		if collision == null:
			continue
		var collider = collision.get_collider()
		if collider == null:
			continue
		if not (collider is Node):
			continue
		if not (collider as Node).is_in_group("player"):
			continue
		if collider.has_method("take_damage"):
			collider.call("take_damage", collision_damage)
			_contact_damage_time_left = contact_damage_cooldown
			return

func _setup_visual() -> void:
	if sprite == null:
		return
	# Ensure each instance has a unique material so animation toggles don't affect others
	if sprite.material != null:
		var new_mat = sprite.material.duplicate()
		sprite.material = new_mat
	if sprite.material is ShaderMaterial:
		var shader_mat = sprite.material as ShaderMaterial
		shader_mat.set_shader_parameter("Enabled", false)

func _setup_body_collision() -> void:
	if body_collision == null:
		return
	if body_collision.shape == null:
		var fallback_shape = RectangleShape2D.new()
		fallback_shape.size = Vector2(12.0, 14.0)
		body_collision.shape = fallback_shape
	if body_collision.shape is RectangleShape2D:
		var rect = body_collision.shape as RectangleShape2D
		if rect.size == Vector2.ZERO:
			rect.size = Vector2(12.0, 14.0)

func _should_turn_around() -> bool:
	if direct < 0 and global_position.x <= patrol_min_x:
		return true
	if direct > 0 and global_position.x >= patrol_max_x:
		return true
	return false

func _update_facing_visual() -> void:
	if sprite == null:
		return
	var scale_x = absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(direct)
