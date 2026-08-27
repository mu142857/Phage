# 血蛆(爬虫一样的血泥)：Idle 时也在极慢地左右巡逻(不会掉下平台，wowen 式
# 折返 + 向前探地射线双保险)；发现玩家就用 Move 冲过去，贴脸(AttackCheck 碰到
# 玩家)时播 Attack，只在第 attack_frame 帧(0 起数，默认 3)用 AttackCheck 判定
# 伤害。没有接触伤害——不咬人的时候蹭到它不掉血。
# 翻转包括一切判定：AnimatedSprite2D 和 AttackCheck 的 scale.x 一起取反。
# 动画名：Idle(巡逻循环)、Move(追击循环)、Attack(单次)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_maggot/blood_maggot_death.tscn")

@export var max_health: int = 80
@export var health: int = 80
@export var gravity: float = 850.0
@export var idle_speed: float = 4.0        # Idle 巡逻速度(极度缓慢)
@export var patrol_distance: float = 20.0  # 以出生点为中心的巡逻半径
@export var chase_speed: float = 26.0      # 追击速度(也不算快)
@export var edge_probe_distance: float = 8.0  # 向前探地的水平距离(防掉平台)
@export var knockback_speed: float = 80.0
@export var knockback_duration: float = 0.1
## 贴图默认头朝左；素材头朝右就取消勾选
@export var sprite_faces_left: bool = true

@export_group("Attack")
@export var attack_damage: int = 8
@export var attack_frame: int = 3          # Attack 动画的伤害帧(0 起数)
@export var attack_cooldown: float = 0.8

enum Phase { PATROL, CHASE, ATTACK }

var _phase: Phase = Phase.PATROL
var _dir: float = 1.0
var _spawn_x: float = 0.0
var _attack_cd: float = 0.0
var _hit_registered: bool = false
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
	_apply_facing()


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_attack_cd = maxf(0.0, _attack_cd - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match _phase:
			Phase.PATROL:
				_process_patrol()
			Phase.CHASE:
				_process_chase()
			Phase.ATTACK:
				_process_attack()

	move_and_slide()


func _process_patrol() -> void:
	_play_anim(&"Idle")
	# 到巡逻边界 / 撞墙 / 前面没地了 → 折返
	if (_dir > 0.0 and global_position.x >= _spawn_x + patrol_distance) \
			or (_dir < 0.0 and global_position.x <= _spawn_x - patrol_distance) \
			or is_on_wall() or not _floor_ahead(_dir):
		_dir = -_dir
	velocity.x = _dir * idle_speed
	_apply_facing()
	if _get_detected_player() != null:
		_phase = Phase.CHASE


func _process_chase() -> void:
	var player := _get_detected_player()
	if player == null:
		velocity.x = 0.0
		_phase = Phase.PATROL
		return
	# 贴脸且攻击好了 → 咬
	if _attack_cd <= 0.0 and _player_in_attack_box() and _has_attack_anim():
		_start_attack()
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		_dir = signf(dx)
		_apply_facing()
		# 前面没地就停住等，不跳崖
		velocity.x = _dir * chase_speed if _floor_ahead(_dir) else 0.0
	else:
		velocity.x = 0.0
	_play_anim(&"Move")


func _start_attack() -> void:
	_phase = Phase.ATTACK
	_hit_registered = false
	velocity.x = 0.0
	ani_2d.play(&"Attack")


func _process_attack() -> void:
	velocity.x = 0.0
	# 只有伤害帧这一小段有判定
	if ani_2d != null and ani_2d.animation == &"Attack" and ani_2d.frame == attack_frame:
		_check_bite_hit()
	if ani_2d == null or not ani_2d.is_playing():
		_attack_cd = attack_cooldown
		_phase = Phase.CHASE


func _check_bite_hit() -> void:
	if _hit_registered or attack_check == null:
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", attack_damage)
		_hit_registered = true
		return


func _player_in_attack_box() -> bool:
	if attack_check == null:
		return false
	for body in attack_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return true
	return false


# 向前下方打一条射线探地(只查世界层1)，探不到=前面是悬崖
func _floor_ahead(dir: float) -> bool:
	if not is_on_floor():
		return true
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = global_position + Vector2(dir * edge_probe_distance, -1.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, 6.0), 1)
	return not space.intersect_ray(query).is_empty()


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


# 翻转=贴图和攻击判定一起镜像(素材默认朝左)
func _apply_facing() -> void:
	var flip: float = _dir * (-1.0 if sprite_faces_left else 1.0)
	if flip == 0.0:
		flip = 1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * flip
	if attack_check != null:
		attack_check.scale.x = absf(attack_check.scale.x) * flip


func _has_attack_anim() -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(&"Attack")


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
