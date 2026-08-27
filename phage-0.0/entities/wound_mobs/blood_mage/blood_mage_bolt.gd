# 血法师的血弹：抛物线飞向目标点，打中玩家掉血后播 Hit 动画消失。
# 动画名约定：default(飞行循环)、Hit(命中，可选)。
# setup 约定: setup(start_pos, target_pos, flight_time) —— 与 spider_spit 同款签名
extends Area2D

@export var damage_amount: int = 8
@export var lifetime: float = 4.0
## 下落重力。别叫 gravity——Area2D 有同名原生成员(区域重力覆盖)会报重定义。
@export var fall_gravity: float = 300.0

var fly_velocity: Vector2 = Vector2.ZERO
var _active: bool = false
var _exploded: bool = false
var _elapsed: float = 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	if ani_2d != null and ani_2d.sprite_frames != null:
		if ani_2d.sprite_frames.has_animation(&"default"):
			ani_2d.play(&"default")


func setup(start_pos: Vector2, target_pos: Vector2, flight_time: float) -> void:
	global_position = start_pos
	var t: float = maxf(flight_time, 0.05)
	# 抛物线初速：水平匀速，竖直按重力反解
	fly_velocity = Vector2(
		(target_pos.x - start_pos.x) / t,
		(target_pos.y - start_pos.y) / t - 0.5 * fall_gravity * t)
	_elapsed = 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active or _exploded:
		return
	_elapsed += delta
	fly_velocity.y += fall_gravity * delta
	global_position += fly_velocity * delta
	_try_damage_player()
	if _elapsed >= lifetime:
		queue_free()


func _try_damage_player() -> void:
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage_amount)
		_explode()
		return


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	fly_velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	# 有 Hit 动画就播一下再消失；没有(或帧没导入)就等 0.4s 兜底消失
	if ani_2d != null and ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Hit"):
		ani_2d.play(&"Hit")
	else:
		if ani_2d != null:
			ani_2d.visible = false
	await get_tree().create_timer(0.4).timeout
	queue_free()
