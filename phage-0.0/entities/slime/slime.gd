#Slime —— 基础史莱姆：落地静止 -> 朝主角随机方向/高度跳跃 -> 落地静止……
#贴图是灰色，靠 tint(modulate) 上色成不同变体。离主角太远则自我消除。
class_name Slime
extends CharacterBody2D

## 重力；比主角(1000)低一些，让史莱姆跳跃更飘、横向飞得更远
@export var gravity: float = 850.0

## 死亡粒子特效场景，各体型在各自 .tscn 里指定不同的
@export var death_effect_scene: PackedScene

@export var max_health: int = 5
@export var health: int = 5
## 灰色贴图上色用；白色=保持原灰。ff9484 红 / 69cabb 青 / a6affc 蓝紫
@export var tint: Color = Color.WHITE
@export var contact_damage: int = 4
@export var contact_damage_cooldown: float = 0.5

## 每次跳跃的竖直初速度（负=向上），随机取区间。越小的史莱姆填越大的值 -> 跳得越高
@export var jump_speed_y_min: float = 240.0
@export var jump_speed_y_max: float = 320.0
## 每次跳跃的水平速度，随机取区间；方向朝向主角
@export var jump_speed_x_min: float = 30.0
@export var jump_speed_x_max: float = 70.0
## 每次落地后静止的时间，随机取区间
@export var rest_time_min: float = 0.5
@export var rest_time_max: float = 1.1

## 离主角超过这个像素距离就消除自己
@export var despawn_distance: float = 160.0

var _rest_time_left: float = 0.0
var _in_air: bool = false
var _contact_damage_time_left: float = 0.0
var _base_scale_x: float = 1.0

@onready var sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var hit_box: Area2D = get_node_or_null("HitBox") as Area2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer

func _ready() -> void:
	add_to_group("monster")
	add_to_group("slime")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if is_instance_valid(sprite):
		sprite.modulate = tint
		# 复制材质，避免所有实例共用同一份 ShaderMaterial（受击闪白会互相串）
		if sprite.material != null:
			sprite.material = sprite.material.duplicate()
		_base_scale_x = absf(sprite.scale.x)
		if _base_scale_x == 0.0:
			_base_scale_x = 1.0
	if is_instance_valid(hit_effect_player):
		hit_effect_player.active = true
	_rest_time_left = randf_range(rest_time_min, rest_time_max)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	_contact_damage_time_left = maxf(0.0, _contact_damage_time_left - delta)

	# 落地摩擦：水平速度归零
	if is_on_floor():
		if _in_air:
			_in_air = false
			_rest_time_left = randf_range(rest_time_min, rest_time_max)
		velocity.x = 0.0
	else:
		velocity.y += gravity * delta

	var player := _get_player()

	# 离主角太远 -> 消除自己
	if player != null and global_position.distance_to(player.global_position) > despawn_distance:
		queue_free()
		return

	# 落地静止时，若检测到主角则倒计时后起跳
	if is_on_floor() and not _in_air:
		if player != null:
			_rest_time_left -= delta
			if _rest_time_left <= 0.0:
				_jump_toward(player)

	move_and_slide()
	_try_damage_player()

func _jump_toward(player: Node2D) -> void:
	var dir := signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	velocity.y = -randf_range(jump_speed_y_min, jump_speed_y_max)
	velocity.x = dir * randf_range(jump_speed_x_min, jump_speed_x_max)
	_in_air = true
	if is_instance_valid(sprite):
		sprite.scale.x = _base_scale_x * dir

func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	_play_hit_flash()
	if health <= 0:
		_spawn_death_effect()
		queue_free()

func _get_player() -> Node2D:
	# 优先用 PlayerCheck 内的玩家；范围外则回退到 group（用于计算消除距离）
	if is_instance_valid(player_check):
		for body in player_check.get_overlapping_bodies():
			if body != null and body.is_in_group("player") and body is Node2D:
				return body as Node2D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null

func _try_damage_player() -> void:
	if contact_damage <= 0 or _contact_damage_time_left > 0.0:
		return
	if not is_instance_valid(hit_box):
		return
	for body in hit_box.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
			_contact_damage_time_left = contact_damage_cooldown
			return

func _play_hit_flash() -> void:
	if is_instance_valid(hit_effect_player) and hit_effect_player.has_animation(&"HitFlash"):
		hit_effect_player.play(&"HitFlash")

func _spawn_death_effect() -> void:
	if death_effect_scene == null or get_tree().current_scene == null:
		return
	var effect := death_effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
