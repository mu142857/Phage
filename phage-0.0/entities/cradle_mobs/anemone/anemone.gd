# 弹幕葵(远程海葵):定点炮台,无接触伤害。主角进 PlayerCheck 就播 Attack,
# 到第 shoot_frame 帧(0 起数,用户导帧后定为 7)从 Muzzle 放出一颗大弹(anemone_bullet):
# 面朝上慢慢飘、渐显,然后弱追踪主角、越飞越快(有上限)。打中主角掉盾、打中长虫(worm_wall)碎墙、
# 打到别处爆掉——所以玩法是站在长虫和葵之间,等它追过来再闪开,让它转不过弯撞进墙。能打死,血厚;打死后换场景再刷新。
# 动画名:Idle(循环)、Attack(单次)。素材默认朝左,朝右射整体 x 镜像。
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://entities/cradle_mobs/anemone/anemone_bullet.tscn")
const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/anemone/anemone_death.tscn")

@export var max_health: int = 400
@export var health: int = 400
@export var gravity: float = 850.0

@export_group("Attack")
@export var shoot_frame: int = 7          # Attack 动画的出弹帧(0 起数)
@export var attack_cooldown: float = 5.0

enum Phase { IDLE, ATTACK }

var _phase: Phase = Phase.IDLE
var _cooldown := 0.0
var _shot_done := false

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	add_to_group("monster")
	collision_layer = collision_layer & ~1   # 只留怪物层:葵不挡主角(用户要求),主角能从它身上走过去
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	move_and_slide()
	_cooldown = maxf(0.0, _cooldown - delta)
	match _phase:
		Phase.IDLE:
			_play_anim(&"Idle")
			if _cooldown <= 0.0:
				var player := _get_detected_player()
				if player != null:
					_start_attack(player)
		Phase.ATTACK:
			_process_attack()


func _start_attack(player: Node2D) -> void:
	_phase = Phase.ATTACK
	_shot_done = false
	_face_towards(player.global_position.x)
	if _has_anim(&"Attack"):
		ani_2d.play(&"Attack")
	else:
		_shoot()   # 没导 Attack 帧也能出弹,方便先测玩法
		_end_attack()


func _process_attack() -> void:
	if not _shot_done and ani_2d != null and ani_2d.animation == &"Attack" and ani_2d.frame >= shoot_frame:
		_shoot()
	if ani_2d == null or not ani_2d.is_playing():
		_end_attack()


func _end_attack() -> void:
	_cooldown = attack_cooldown
	_phase = Phase.IDLE


func _shoot() -> void:
	_shot_done = true
	var player := _get_detected_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or BULLET_SCENE == null or get_tree().current_scene == null:
		return
	var start := muzzle.global_position if muzzle != null else global_position + Vector2(0, -12)
	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	if bullet.has_method("setup"):
		bullet.call("setup", start)


# 素材默认朝左;朝右=贴图和炮口一起 x 镜像(物理本体不缩放)
func _face_towards(target_x: float) -> void:
	var flip: float = -1.0 if target_x > global_position.x else 1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * flip
	if muzzle != null:
		muzzle.position.x = absf(muzzle.position.x) * -flip


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


func _has_anim(anim: StringName) -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(anim) \
		and ani_2d.sprite_frames.get_frame_count(anim) > 0


func _play_anim(anim: StringName) -> void:
	if not _has_anim(anim):
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
