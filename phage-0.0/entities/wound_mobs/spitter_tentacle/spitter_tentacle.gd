# 喷吐触手：不可移动的炮台杂兵。玩家进入 PlayerCheck 就播 Attack，
# 到第 shoot_frame 帧(0 起数)朝玩家所在方向喷一发子弹。
# 弹道(先扬起后滑翔)全在子弹脚本里调，这里只管什么时候朝哪边喷。
# 没有接触伤害。动画名约定：Idle(循环)、Attack(单次)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/spitter_tentacle/spitter_tentacle_death.tscn")
const BULLET_SCENE: PackedScene = preload("res://entities/wound_mobs/spitter_tentacle/spitter_tentacle_bullet.tscn")

@export var max_health: int = 300
@export var health: int = 300
@export var gravity: float = 850.0
## 打死后同一次运行内不复活(重进房间不刷新)——和 boss 门同一套
## MapElementCounting 记账，重新做梦(记账重置)才回来。取消勾选=每次都刷新。
@export var persist_defeat: bool = true

@export_group("Shoot")
@export var shoot_frame: int = 4          # Attack 动画的出弹帧(0 起数)
@export var shoot_cooldown: float = 2.0

enum Phase { IDLE, ATTACK }

var _phase: Phase = Phase.IDLE
var _cooldown: float = 0.0
var _shot_fired: bool = false
var _persist_id: StringName = &""

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	if persist_defeat:
		_persist_id = _make_persist_id()
		if not MapElementCounting.is_wall_intact(_persist_id):
			queue_free()
			return
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
			if _cooldown <= 0.0 and _get_detected_player() != null:
				_start_attack()
		Phase.ATTACK:
			_process_attack()


func _start_attack() -> void:
	if ani_2d != null and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Attack"):
		_phase = Phase.ATTACK
		_shot_fired = false
		ani_2d.play(&"Attack")
	else:
		# 没有 Attack 动画的兜底：直接出弹进冷却
		_shoot()
		_cooldown = shoot_cooldown


func _process_attack() -> void:
	# 到出弹帧喷一发(>= 加标记，防物理帧跳过精确那一帧)
	if not _shot_fired and ani_2d != null \
			and ani_2d.animation == &"Attack" and ani_2d.frame >= shoot_frame:
		_shot_fired = true
		_shoot()
	# 非循环动画播完 is_playing() 变 false → 进冷却
	if ani_2d == null or not ani_2d.is_playing():
		_cooldown = shoot_cooldown
		_phase = Phase.IDLE


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if health <= 0:
		if _persist_id != &"":
			MapElementCounting.mark_wall_broken(_persist_id)
		_spawn_death_effect()
		queue_free()


# 按"场景+节点名+坐标"自动生成唯一记账ID，摆多少个都不用手填
func _make_persist_id() -> StringName:
	var scene_path: String = "unknown"
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	return StringName("%s/%s@%d,%d" % [scene_path, name,
		roundi(global_position.x), roundi(global_position.y)])


func _shoot() -> void:
	var player := _get_detected_player()
	if player == null or BULLET_SCENE == null:
		return
	if get_tree().current_scene == null:
		return
	var start: Vector2 = muzzle.global_position if muzzle != null else global_position
	var dir: float = signf(player.global_position.x - start.x)
	if dir == 0.0:
		dir = -1.0
	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	if bullet.has_method("setup"):
		bullet.call("setup", start, dir)


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


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
