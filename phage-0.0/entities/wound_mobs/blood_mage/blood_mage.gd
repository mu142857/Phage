# 血法师(红法师)：远程杂兵。和玩家保持距离——太近就退开，太远就凑近；
# 距离合适时停下蓄力(闪烁预警)，朝玩家位置抛一发抛物线血弹。
# 动画名约定：Idle(循环)、Walk(循环)、Cast(施法单次)。流程靠计时器推进。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_mage/blood_mage_death.tscn")
const BOLT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_mage/blood_mage_bolt.tscn")

@export var max_health: int = 60
@export var health: int = 60
@export var gravity: float = 850.0
@export var walk_speed: float = 22.0
@export var contact_damage: int = 4
@export var contact_damage_cooldown: float = 0.5
@export var knockback_speed: float = 120.0
@export var knockback_duration: float = 0.1
## 贴图默认面朝右；素材面朝左就勾上
@export var sprite_faces_left: bool = false

@export_group("Cast")
@export var cast_cooldown: float = 2.5
@export var cast_range: float = 70.0      # 超过这个距离就往前凑
@export var retreat_range: float = 25.0   # 近于这个距离就往后退
@export var windup_time: float = 0.5      # 蓄力(闪烁预警)时长
@export var recover_time: float = 0.4     # 施法后硬直
@export var bolt_flight_time: float = 0.8 # 血弹飞到玩家位置的时长
@export var cast_muzzle_offset: Vector2 = Vector2(0, -10)

enum Phase { MOVE, WINDUP, RECOVER }

var _phase: Phase = Phase.MOVE
var _phase_timer: float = 0.0
var _cooldown: float = 0.0
var _contact_cd: float = 0.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0
var _dir: float = 1.0
var _base_modulate: Color = Color.WHITE

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D


func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	if ani_2d != null:
		_base_modulate = ani_2d.modulate


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_phase_timer = maxf(0.0, _phase_timer - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match _phase:
			Phase.MOVE:
				_process_move()
			Phase.WINDUP:
				velocity.x = 0.0
				if ani_2d != null:
					var blink_on: bool = fmod(_phase_timer, 0.12) < 0.06
					ani_2d.modulate = Color(1.6, 1.6, 1.6, _base_modulate.a) if blink_on else _base_modulate
				if _phase_timer <= 0.0:
					if ani_2d != null:
						ani_2d.modulate = _base_modulate
					_cast()
					_phase = Phase.RECOVER
					_phase_timer = recover_time
			Phase.RECOVER:
				velocity.x = 0.0
				if _phase_timer <= 0.0:
					_cooldown = cast_cooldown
					_phase = Phase.MOVE

	move_and_slide()
	_try_contact_damage()


func _process_move() -> void:
	var player := _get_detected_player()
	if player == null:
		velocity.x = 0.0
		_play_anim(&"Idle")
		return
	var dx: float = player.global_position.x - global_position.x
	_dir = signf(dx) if dx != 0.0 else _dir
	_update_facing()
	if absf(dx) < retreat_range:
		# 太近了，边退边找机会
		velocity.x = -signf(dx) * walk_speed
		_play_anim(&"Walk")
	elif absf(dx) > cast_range:
		velocity.x = signf(dx) * walk_speed
		_play_anim(&"Walk")
	else:
		velocity.x = 0.0
		if _cooldown <= 0.0:
			_phase = Phase.WINDUP
			_phase_timer = windup_time
			_play_anim(&"Cast")
		else:
			_play_anim(&"Idle")


func _cast() -> void:
	var player := _get_detected_player()
	if player == null or BOLT_SCENE == null:
		return
	if get_tree().current_scene == null:
		return
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	if bolt.has_method("setup"):
		bolt.call("setup", global_position + cast_muzzle_offset, player.global_position, bolt_flight_time)


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
			body.call("take_damage", contact_damage)
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
