# 血蛆(爬虫一样的血泥)：慢速地面爬行杂兵。巡逻 + 发现玩家追击 + 接触伤害。
# 皮糙血厚走得慢，靠身体蹭人。逻辑参考 entities/spider/spider.gd 去掉技能。
# 动画名约定：Walk(循环)、Idle(可选，没有就一直 Walk)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_maggot/blood_maggot_death.tscn")

@export var max_health: int = 120
@export var health: int = 120
@export var gravity: float = 850.0
@export var walk_speed: float = 10.0
@export var chase_speed: float = 20.0
@export var patrol_range: float = 25.0
@export var collision_damage: int = 8
@export var contact_damage_cooldown: float = 0.5
@export var knockback_speed: float = 80.0
@export var knockback_duration: float = 0.1
## 贴图默认头朝右；素材头朝左就勾上
@export var sprite_faces_left: bool = true

var _spawn_x: float = 0.0
var _dir: float = 1.0
var _contact_cd: float = 0.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0

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
		if absf(velocity.x) > 0.1:
			_play_anim(&"Walk")
		elif ani_2d != null and ani_2d.sprite_frames != null \
				and ani_2d.sprite_frames.has_animation(&"Idle"):
			_play_anim(&"Idle")
		else:
			_play_anim(&"Walk")
		_update_facing()

	move_and_slide()
	_try_contact_damage()


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
