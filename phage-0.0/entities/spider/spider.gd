#Spider 粉丝蜘蛛基础脚本：地面巡逻 + 发现玩家追击 + 接触伤害
extends CharacterBody2D

@export var max_health: int = 100
@export var health: int = 100
@export var gravity: float = 850.0
@export var walk_speed: float = 20.0
@export var chase_speed: float = 35.0
@export var patrol_range: float = 30.0
@export var collision_damage: int = 6
@export var contact_damage_cooldown: float = 0.5
@export var knockback_speed: float = 120.0
@export var knockback_duration: float = 0.1

var _spawn_x: float = 0.0
var _dir: float = 1.0
var _contact_cd: float = 0.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0

@onready var body_sprite: Sprite2D = get_node_or_null("Body") as Sprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	_spawn_x = global_position.x
	if body_sprite != null and body_sprite.material != null:
		body_sprite.material = body_sprite.material.duplicate()
	if hit_effect_player != null:
		hit_effect_player.active = true

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_contact_cd = maxf(0.0, _contact_cd - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		var player := _get_detected_player()
		if player != null:
			var dx: float = player.global_position.x - global_position.x
			if absf(dx) > 4.0:
				_dir = signf(dx)
				velocity.x = _dir * chase_speed
			else:
				velocity.x = 0.0
		else:
			if global_position.x > _spawn_x + patrol_range:
				_dir = -1.0
			elif global_position.x < _spawn_x - patrol_range:
				_dir = 1.0
			elif is_on_wall():
				_dir = -_dir
			velocity.x = _dir * walk_speed
		_update_facing()

	move_and_slide()
	_try_damage_player()

func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		hit_effect_player.play(&"HitFlash")
	_start_knockback()
	if health <= 0:
		queue_free()

func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("player"):
			continue
		if body is Node2D:
			return body as Node2D
	return null

func _try_damage_player() -> void:
	if _contact_cd > 0.0:
		return
	if attack_check == null:
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", collision_damage)
			_contact_cd = contact_damage_cooldown
			return

func _start_knockback() -> void:
	var direction: float = -1.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		direction = signf(global_position.x - (players[0] as Node2D).global_position.x)
		if direction == 0.0:
			direction = -1.0
	_knock_left = knockback_duration
	_knock_vx = knockback_speed * direction

func _update_facing() -> void:
	if body_sprite != null:
		body_sprite.flip_h = _dir < 0.0
