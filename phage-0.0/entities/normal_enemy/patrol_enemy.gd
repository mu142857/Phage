class_name PatrolEnemy
extends CharacterBody2D

signal died

@export var max_health: int = 20
@export var health: int = 20
@export var move_speed: float = 40.0
@export var patrol_distance: float = 72.0
@export var gravity: float = 1000.0
@export var collision_damage: int = 10
@export var contact_damage_cooldown: float = 0.35
@export var knockback_speed: float = 160.0
@export var knockback_vertical_speed: float = -120.0
@export var knockback_duration: float = 0.16
@export var edge_probe_forward: float = 10.0
@export var edge_probe_length: float = 20.0
@export var wall_probe_length: float = 8.0

var direct: int = 1
var _patrol_origin_x: float = 0.0
var _knockback_time_left: float = 0.0
var _contact_damage_time_left: float = 0.0
var _floor_probe: RayCast2D = null
var _wall_probe: RayCast2D = null

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	_patrol_origin_x = global_position.x
	_setup_body_collision()
	_setup_visual()
	_setup_probes()
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

	if is_on_wall():
		direct *= -1
		_update_facing_visual()

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
	var knockback_direction := -float(direct)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var candidate := players[0]
		if candidate is Node2D:
			var player_x := (candidate as Node2D).global_position.x
			knockback_direction = sign(global_position.x - player_x)
			if knockback_direction == 0.0:
				knockback_direction = -float(direct)
	_knockback_time_left = knockback_duration
	velocity.x = knockback_speed * knockback_direction
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
	var slide_count := get_slide_collision_count()
	for index in range(slide_count):
		var collision := get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider()
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
	if sprite.material is ShaderMaterial:
		var shader_mat := sprite.material as ShaderMaterial
		shader_mat.set_shader_parameter("Enabled", false)

func _setup_body_collision() -> void:
	if body_collision == null:
		return
	if body_collision.shape == null:
		var fallback_shape := RectangleShape2D.new()
		fallback_shape.size = Vector2(12.0, 14.0)
		body_collision.shape = fallback_shape
	if body_collision.shape is RectangleShape2D:
		var rect := body_collision.shape as RectangleShape2D
		if rect.size == Vector2.ZERO:
			rect.size = Vector2(12.0, 14.0)

func _setup_probes() -> void:
	_floor_probe = RayCast2D.new()
	_floor_probe.name = "FloorProbe"
	_floor_probe.enabled = true
	_floor_probe.exclude_parent = true
	_floor_probe.collision_mask = collision_mask
	add_child(_floor_probe)

	_wall_probe = RayCast2D.new()
	_wall_probe.name = "WallProbe"
	_wall_probe.enabled = true
	_wall_probe.exclude_parent = true
	_wall_probe.collision_mask = collision_mask
	add_child(_wall_probe)

func _update_probes() -> void:
	if _floor_probe == null or _wall_probe == null:
		return
	_floor_probe.position = Vector2(edge_probe_forward * float(direct), 8.0)
	_floor_probe.target_position = Vector2(0.0, edge_probe_length)
	_floor_probe.force_raycast_update()

	_wall_probe.position = Vector2(8.0 * float(direct), 0.0)
	_wall_probe.target_position = Vector2(wall_probe_length * float(direct), 0.0)
	_wall_probe.force_raycast_update()

func _should_turn_around() -> bool:
	_update_probes()
	if _wall_probe != null and _wall_probe.is_colliding():
		return true
	if _floor_probe != null and not _floor_probe.is_colliding():
		return true
	if direct < 0 and global_position.x <= _patrol_origin_x - patrol_distance:
		return true
	if direct > 0 and global_position.x >= _patrol_origin_x + patrol_distance:
		return true
	return false

func _update_facing_visual() -> void:
	if sprite == null:
		return
	var scale_x := absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(direct)
