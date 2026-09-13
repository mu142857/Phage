# 喷射战士(sprayer,素材 2怪):定点炮台,无接触伤害,血厚(600=20 刀)。
# 主角进 PlayerCheck 就播 Attack,从第 spray_frame 帧起在 volley_duration 秒内朝主角那一侧
# 连喷 volley_count 颗浓雾弹(sprayer_fog),上下扇形铺满,空地上根本躲不掉——
# 只有钻到蚯蚓拱门底下,雾弹撞在蚯蚓身上就散了。
# 动画名:Idle(循环)、Attack(单次)。素材默认朝左,朝右整体 x 镜像。
extends CharacterBody2D

const FOG_SCENE: PackedScene = preload("res://entities/cradle_mobs/sprayer/sprayer_fog.tscn")
const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/sprayer/sprayer_death.tscn")

@export var max_health: int = 600
@export var health: int = 600
@export var gravity: float = 850.0

@export_group("Spray")
@export var spray_frame: int = 14          # Attack 动画从这帧开始喷(0 起数)
@export var volley_count: int = 14         # 一轮喷几颗
@export var volley_duration: float = 0.7   # 一轮喷多久
@export var spread_degrees: float = 32.0   # 上下扇形半角
@export var fog_speed: Vector2 = Vector2(48.0, 62.0)  # 每颗速度在这区间随机
@export var attack_cooldown: float = 2.6

enum Phase { IDLE, ATTACK }

var _phase: Phase = Phase.IDLE
var _cooldown := 0.0
var _spraying := false
var _spray_left := 0
var _spray_timer := 0.0
var _spray_dir := -1.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	add_to_group("monster")
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
			_process_attack(delta)


func _start_attack(player: Node2D) -> void:
	_phase = Phase.ATTACK
	_spraying = false
	_spray_dir = -1.0 if player.global_position.x < global_position.x else 1.0
	_face_towards(player.global_position.x)
	if _has_anim(&"Attack"):
		ani_2d.play(&"Attack")
	else:
		_begin_volley()   # 没导 Attack 帧也能喷,方便先测玩法


func _process_attack(delta: float) -> void:
	if not _spraying and _spray_left <= 0 and ani_2d != null \
			and ani_2d.animation == &"Attack" and ani_2d.frame >= spray_frame:
		_begin_volley()
	if _spraying:
		_spray_timer -= delta
		while _spraying and _spray_timer <= 0.0 and _spray_left > 0:
			_spawn_fog()
			_spray_left -= 1
			_spray_timer += volley_duration / maxf(float(volley_count), 1.0)
		if _spray_left <= 0:
			_spraying = false
	var anim_done := not _has_anim(&"Attack") or ani_2d.animation != &"Attack" or not ani_2d.is_playing()
	if anim_done and not _spraying:
		_phase = Phase.IDLE
		_cooldown = attack_cooldown


func _begin_volley() -> void:
	_spraying = true
	_spray_left = volley_count
	_spray_timer = 0.0


func _spawn_fog() -> void:
	if FOG_SCENE == null or get_tree().current_scene == null:
		return
	var start := muzzle.global_position if muzzle != null else global_position + Vector2(0, -8)
	var angle := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	var dir := Vector2(_spray_dir, 0.0).rotated(angle)
	var fog := FOG_SCENE.instantiate()
	get_tree().current_scene.add_child(fog)
	if fog.has_method("setup"):
		fog.call("setup", start, dir, randf_range(fog_speed.x, fog_speed.y))


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
