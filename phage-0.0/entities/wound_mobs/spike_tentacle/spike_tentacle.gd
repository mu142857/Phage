# 尖刺触手：不可移动杂兵。玩家进 PlayerCheck 就转向玩家播 Attack，
# 只有 Attack 动画第 attack_frame 帧(0 起数，默认第 4 帧)有伤害判定；
# 没有接触伤害——不打人的时候蹭到它不掉血。
# 素材默认朝左；朝右打就把 AnimatedSprite2D 和 AttackHitBox 的 scale.x 一起
# 取反，碰撞多边形跟着贴图镜像。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/spike_tentacle/spike_tentacle_death.tscn")

@export var max_health: int = 500
@export var health: int = 500
@export var gravity: float = 850.0

@export_group("Attack")
@export var attack_damage: int = 10
@export var attack_frame: int = 4        # Attack 动画的伤害帧(0 起数)
@export var attack_cooldown: float = 1.5

enum Phase { IDLE, ATTACK }

var _phase: Phase = Phase.IDLE
var _cooldown: float = 0.0
var _hit_registered: bool = false

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitBox") as Area2D


func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	_set_hitbox_active(false)


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
				if player != null and _has_attack_anim():
					_start_attack(player)
		Phase.ATTACK:
			_process_attack()


func _start_attack(player: Node2D) -> void:
	_phase = Phase.ATTACK
	_hit_registered = false
	_face_towards(player.global_position.x)
	# monitoring 提前打开(set_deferred 下一帧生效)，伤害仍然只看 attack_frame
	_set_hitbox_active(true)
	ani_2d.play(&"Attack")


func _process_attack() -> void:
	# 只有伤害帧这一小段有判定
	if ani_2d != null and ani_2d.animation == &"Attack" and ani_2d.frame == attack_frame:
		_check_stab_hit()
	# 非循环动画播完 is_playing() 变 false → 收招进冷却
	if ani_2d == null or not ani_2d.is_playing():
		_set_hitbox_active(false)
		_cooldown = attack_cooldown
		_phase = Phase.IDLE


# 素材默认朝左；朝右=整体 x 镜像(贴图和攻击碰撞箱一起翻，物理本体不缩放)
func _face_towards(target_x: float) -> void:
	var flip: float = -1.0 if target_x > global_position.x else 1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * flip
	if attack_hitbox != null:
		attack_hitbox.scale.x = absf(attack_hitbox.scale.x) * flip


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _check_stab_hit() -> void:
	if _hit_registered or attack_hitbox == null:
		return
	for body in attack_hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", attack_damage)
		_hit_registered = true
		return


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


func _has_attack_anim() -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(&"Attack")


func _set_hitbox_active(active: bool) -> void:
	if attack_hitbox != null:
		attack_hitbox.set_deferred("monitoring", active)
		attack_hitbox.set_deferred("monitorable", active)


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
