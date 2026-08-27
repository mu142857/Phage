# 血蛛：本关的接触伤害坦克(450血)。Idle 时完全不动；发现玩家后不停地小步
# 走位——每段 2/3 概率朝玩家走、1/3 概率反向走，段与段之间不停顿，一直摇。
# 速度不快(主角跑速的 1/3 左右)，靠血厚和贴身蹭人恶心人。
# 翻转包括一切判定：AnimatedSprite2D 和 AttackCheck 的 scale.x 一起取反。
# 动画名：Idle(站定循环)、Move(移动循环)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_spider/blood_spider_death.tscn")

@export var max_health: int = 450
@export var health: int = 450
@export var gravity: float = 850.0
@export var move_speed: float = 23.0       # 约主角 RUN_SPEED(70) 的 1/3
@export var collision_damage: int = 6
@export var contact_damage_cooldown: float = 0.5
@export var knockback_speed: float = 120.0
@export var knockback_duration: float = 0.1
@export var edge_probe_distance: float = 7.0  # 向前探地的水平距离(防走下平台/悬空)
@export var wander_distance: float = 60.0  # 离出生点的最远游荡距离(防走出场景边缘)
## 贴图默认头朝左；素材头朝右就取消勾选
@export var sprite_faces_left: bool = true

@export_group("Move Cycle")
@export var approach_chance: float = 0.667  # 朝玩家走的概率(其余是反向走)
@export var move_time_min: float = 0.6      # 每段位移的时长区间(段间不停顿)
@export var move_time_max: float = 1.2

enum Phase { IDLE, MOVE }

var _phase: Phase = Phase.IDLE
var _dir: float = 1.0
var _spawn_x: float = 0.0
var _phase_timer: float = 0.0
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
	_phase_timer = maxf(0.0, _phase_timer - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match _phase:
			Phase.IDLE:
				velocity.x = 0.0
				_play_anim(&"Idle")
				if _get_detected_player() != null:
					_decide_move()
			Phase.MOVE:
				# 前面没地/超出游荡范围就原地站住等这段走完——
				# 绝不把身子探出平台，也绝不溜出场景边缘
				var out_of_range: bool = (_dir > 0.0 and global_position.x >= _spawn_x + wander_distance) \
					or (_dir < 0.0 and global_position.x <= _spawn_x - wander_distance)
				if _floor_ahead(_dir) and not out_of_range:
					velocity.x = _dir * move_speed
					_play_anim(&"Move")
				else:
					velocity.x = 0.0
					_play_anim(&"Idle")
				# 一段走完(或撞墙)直接摇下一段，不停顿
				if is_on_wall() or _phase_timer <= 0.0:
					if _get_detected_player() != null:
						_decide_move()
					else:
						_phase = Phase.IDLE

	move_and_slide()
	_try_contact_damage()


# 2/3 朝玩家走，1/3 反向走，走一段
func _decide_move() -> void:
	var player := _get_detected_player()
	if player == null:
		_phase = Phase.IDLE
		return
	var to_player: float = signf(player.global_position.x - global_position.x)
	if to_player == 0.0:
		to_player = 1.0
	_dir = to_player if randf() < approach_chance else -to_player
	_apply_facing()
	_phase = Phase.MOVE
	_phase_timer = randf_range(move_time_min, move_time_max)


# 向前下方打一条射线探地(只查世界层1)，探不到=前面是悬崖
func _floor_ahead(dir: float) -> bool:
	if dir == 0.0 or not is_on_floor():
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


# 翻转=贴图和判定一起镜像(素材默认朝左)
func _apply_facing() -> void:
	var flip: float = _dir * (-1.0 if sprite_faces_left else 1.0)
	if flip == 0.0:
		flip = 1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * flip
	if attack_check != null:
		attack_check.scale.x = absf(attack_check.scale.x) * flip


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
