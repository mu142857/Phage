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
## 贴图默认头朝右；素材头朝左的(如盾蛛)勾上这个
@export var sprite_faces_left: bool = false
## 死亡粒子爆炸(与 wowen 同款做法)，三个变体各配一套配色
@export var death_effect_scene: PackedScene = null

enum Skill { NONE, POUNCE, SPIT, SHIELD }

@export_group("Skill")
@export var skill: Skill = Skill.NONE
@export var skill_cooldown: float = 3.0
@export var skill_range: float = 55.0
@export var windup_time: float = 0.35
@export var pounce_speed_x_min: float = 40.0
@export var pounce_speed_x_max: float = 70.0
@export var pounce_jump_min: float = 180.0
@export var pounce_jump_max: float = 240.0
## 跳扑腾空时的重力倍率，<1 滞空更久更好躲
@export var pounce_gravity_scale: float = 1.0
@export var spit_scene: PackedScene = null
@export var spit_flight_time: float = 0.9
@export var spit_muzzle_offset: Vector2 = Vector2(0, -6)
@export var shield_duration: float = 3.0
@export var shield_heal_ratio: float = 1.0

var _spawn_x: float = 0.0
var _dir: float = 1.0
var _contact_cd: float = 0.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0
var _skill_cd: float = 0.0
var _skill_phase: int = 0
var _skill_timer: float = 0.0
var _skill_dir: float = 1.0
var _base_modulate: Color = Color.WHITE
var _base_flash_tint: Color = Color(0.784, 0.501, 0.495)

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
	if body_sprite != null:
		_base_modulate = body_sprite.modulate
	if body_sprite != null and body_sprite.material is ShaderMaterial:
		var tint: Variant = (body_sprite.material as ShaderMaterial).get_shader_parameter("Tint")
		if tint is Color:
			_base_flash_tint = tint
	if hit_effect_player != null:
		hit_effect_player.active = true

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		var gravity_scale: float = 1.0
		if _skill_phase == 2 and skill == Skill.POUNCE:
			gravity_scale = pounce_gravity_scale
		velocity.y += gravity * gravity_scale * delta
	_contact_cd = maxf(0.0, _contact_cd - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	elif _skill_phase != 0:
		_process_skill(delta)
	else:
		_skill_cd = maxf(0.0, _skill_cd - delta)
		var player := _get_detected_player()
		if player != null:
			var dx: float = player.global_position.x - global_position.x
			if skill != Skill.NONE and _skill_cd <= 0.0 and is_on_floor() and absf(dx) <= skill_range:
				_start_skill(player)
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
		_update_facing()

	move_and_slide()
	_try_damage_player()

# ---- 技能：统一"蓄力(闪烁预警)→释放→冷却"流程 ----

func _start_skill(player: Node2D) -> void:
	_skill_dir = signf(player.global_position.x - global_position.x)
	if _skill_dir == 0.0:
		_skill_dir = _dir
	_dir = _skill_dir
	_update_facing()
	velocity.x = 0.0
	# 跳扑学史莱姆：不蓄力，直接朝玩家随机力度跳一下
	if skill == Skill.POUNCE:
		_skill_phase = 2
		_skill_timer = 0.15
		velocity = Vector2(
			_skill_dir * randf_range(pounce_speed_x_min, pounce_speed_x_max),
			-randf_range(pounce_jump_min, pounce_jump_max))
		return
	_skill_phase = 1
	_skill_timer = windup_time

func _process_skill(delta: float) -> void:
	_skill_timer -= delta
	if _skill_phase == 1:
		velocity.x = 0.0
		if body_sprite != null:
			var blink_on: bool = fmod(_skill_timer, 0.12) < 0.06
			body_sprite.modulate = Color(1.6, 1.6, 1.6, _base_modulate.a) if blink_on else _base_modulate
		if _skill_timer <= 0.0:
			_execute_skill()
		return
	match skill:
		Skill.POUNCE:
			if _skill_timer <= 0.0 and is_on_floor():
				_end_skill()
		Skill.SHIELD:
			velocity.x = 0.0
			if body_sprite != null:
				body_sprite.modulate = Color(1.6, 1.6, 1.6, _base_modulate.a)
			if _skill_timer <= 0.0:
				_end_skill()
		_:
			_end_skill()

func _execute_skill() -> void:
	if body_sprite != null:
		body_sprite.modulate = _base_modulate
	match skill:
		Skill.SPIT:
			_spawn_spit()
			_end_skill()
		Skill.SHIELD:
			_skill_phase = 2
			_skill_timer = shield_duration
		_:
			_end_skill()

func _end_skill() -> void:
	if body_sprite != null:
		body_sprite.modulate = _base_modulate
	_skill_phase = 0
	_skill_cd = skill_cooldown

func _spawn_spit() -> void:
	if spit_scene == null:
		return
	if get_tree().current_scene == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or not (players[0] is Node2D):
		return
	var target: Vector2 = (players[0] as Node2D).global_position
	var bullet := spit_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	if bullet.has_method("setup"):
		bullet.call("setup", global_position + spit_muzzle_offset, target, spit_flight_time)

func take_damage(value: int) -> void:
	# 开盾期间：免疫伤害，挨打反而回血，受击闪光变绿
	if _skill_phase == 2 and skill == Skill.SHIELD:
		health = clampi(health + int(round(float(value) * shield_heal_ratio)), 0, max_health)
		_set_flash_tint(Color(0.35, 0.9, 0.45))
		if hit_effect_player != null:
			hit_effect_player.play(&"HitFlash")
		return
	_set_flash_tint(_base_flash_tint)
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		hit_effect_player.play(&"HitFlash")
	_start_knockback()
	if health <= 0:
		_spawn_death_effect()
		queue_free()

func _spawn_death_effect() -> void:
	if death_effect_scene == null:
		return
	if get_tree().current_scene == null:
		return
	var effect := death_effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

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

func _update_facing() -> void:
	if body_sprite != null:
		body_sprite.flip_h = (_dir < 0.0) != sprite_faces_left

func _set_flash_tint(color: Color) -> void:
	if body_sprite != null and body_sprite.material is ShaderMaterial:
		(body_sprite.material as ShaderMaterial).set_shader_parameter("Tint", color)
