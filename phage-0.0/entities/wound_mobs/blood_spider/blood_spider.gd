# 血蛛：地面巡逻 + 发现玩家追击 + 近距离跳扑 + 接触伤害。
# 逻辑参考 entities/spider/spider.gd 的 POUNCE 变体，但用 AnimatedSprite2D 而非程序腿。
# 动画名约定：Walk(循环，巡逻/追击通用)、Attack(跳扑腾空时)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_spider/blood_spider_death.tscn")

@export var max_health: int = 70
@export var health: int = 70
@export var gravity: float = 850.0
@export var walk_speed: float = 18.0
@export var chase_speed: float = 32.0
@export var patrol_range: float = 30.0
@export var collision_damage: int = 6
@export var contact_damage_cooldown: float = 0.5
@export var knockback_speed: float = 120.0
@export var knockback_duration: float = 0.1
## 贴图默认头朝右；素材头朝左就勾上
@export var sprite_faces_left: bool = false

@export_group("Pounce")
@export var pounce_cooldown: float = 2.5
@export var pounce_range: float = 45.0
@export var pounce_speed_x_min: float = 40.0
@export var pounce_speed_x_max: float = 70.0
@export var pounce_jump_min: float = 160.0
@export var pounce_jump_max: float = 220.0

var _spawn_x: float = 0.0
var _dir: float = 1.0
var _contact_cd: float = 0.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0
var _pounce_cd: float = 0.0
var _pouncing: bool = false

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D


func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	_spawn_x = global_position.x
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_pounce_cd = maxf(0.0, _pounce_cd - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	elif _pouncing:
		# 腾空段：保持起跳时的速度，落地即结束
		_play_anim(&"Attack")
		if is_on_floor() and velocity.y >= 0.0:
			_pouncing = false
			velocity.x = 0.0
			_pounce_cd = pounce_cooldown
	else:
		var player := _get_detected_player()
		if player != null:
			var dx: float = player.global_position.x - global_position.x
			if _pounce_cd <= 0.0 and is_on_floor() and absf(dx) <= pounce_range:
				_start_pounce(dx)
			elif absf(dx) > 4.0:
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
		_play_anim(&"Walk")
		_update_facing()

	move_and_slide()
	_try_contact_damage()


func _start_pounce(dx: float) -> void:
	var jump_dir: float = signf(dx)
	if jump_dir == 0.0:
		jump_dir = _dir
	_dir = jump_dir
	_update_facing()
	_pouncing = true
	velocity = Vector2(
		jump_dir * randf_range(pounce_speed_x_min, pounce_speed_x_max),
		-randf_range(pounce_jump_min, pounce_jump_max))


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	_start_knockback()
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _try_contact_damage() -> void:
	if _contact_cd > 0.0 or attack_check == null:
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", collision_damage)
			_contact_cd = contact_damage_cooldown
			return


func _start_knockback() -> void:
	if Game.suppress_hit_knockback:
		return  # 召唤物等软伤害:掉血但不位移
	var direction: float = -1.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		direction = signf(global_position.x - (players[0] as Node2D).global_position.x)
		if direction == 0.0:
			direction = -1.0
	_knock_left = knockback_duration
	_knock_vx = knockback_speed * direction


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


func _update_facing() -> void:
	if ani_2d != null:
		ani_2d.flip_h = (_dir < 0.0) != sprite_faces_left


func _play_anim(anim: StringName) -> void:
	if ani_2d == null or ani_2d.sprite_frames == null:
		return
	if not ani_2d.sprite_frames.has_animation(anim):
		return
	if ani_2d.animation != anim or not ani_2d.is_playing():
		ani_2d.play(anim)


func _spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
