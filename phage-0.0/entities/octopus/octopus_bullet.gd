# res://entities/octopus/octopus_bullet.tscn
# 大章鱼的子弹,从 Actinos 子弹复制过来改的:贴图还是 actinos_bullet.png,
# 颜色靠 AnimatedSprite2D 的 modulate 换,尾迹粒子也换了色;落地炸 octopus_bullet_land(同样换色)。
# 两种用法:
# - setup():平时天上掉的,直直往下(从静止开始加速,正好 fall_time 秒落地),可以先原地悬停 hover 秒;
# - launch():砸地甩出去的,走抛物线(和 Actinos 的一样:给起点、落点、飞行时间、重力,正好 flight_time 秒落到落点)。
# 落地不长刺。
extends Area2D

@export var damage_amount: int = 5
## 落地震屏(0 = 不震;一次十来颗,单颗别震)
@export var land_shake: float = 0.0
## 悬停出场时的淡入秒数
@export var fade_in_time: float = 0.15

const LAND_EFFECT_SCENE: PackedScene = preload("res://entities/octopus/octopus_bullet_land.tscn")

var _ground_y := 80.0
var _hover_left := 0.0
var _fall_gravity := 0.0
var _velocity := Vector2.ZERO
var _arc := false
var _arc_target := Vector2.ZERO
var _arc_time := 0.0
var _elapsed := 0.0
var _active := false
var _damage_applied := false


func _ready() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		sprite.play(&"default")


## 天上掉:start = 出生点;ground_y = 落地的 y;fall_time = 开始下落到落地的秒数;hover = 先原地停几秒
func setup(start: Vector2, ground_y: float, fall_time: float, hover: float = 0.0) -> void:
	global_position = start
	_arc = false
	_ground_y = ground_y
	var dy := maxf(ground_y - start.y, 1.0)
	var t := maxf(fall_time, 0.05)
	_fall_gravity = 2.0 * dy / (t * t)
	_velocity = Vector2.ZERO
	_hover_left = maxf(hover, 0.0)
	_active = true
	_damage_applied = false
	if _hover_left > 0.0 and fade_in_time > 0.0:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, minf(fade_in_time, _hover_left))


## 抛物线:从 start 出发,正好 flight_time 秒后落到 target(Actinos 子弹的算法);delay 秒后才出发(之前藏着不动)
func launch(start: Vector2, target: Vector2, flight_time: float, arc_gravity: float, delay: float = 0.0) -> void:
	global_position = start
	_arc = true
	_arc_target = target
	_arc_time = maxf(flight_time, 0.05)
	_elapsed = 0.0
	_fall_gravity = arc_gravity
	_velocity.x = (target.x - start.x) / _arc_time
	_velocity.y = (target.y - start.y - 0.5 * arc_gravity * _arc_time * _arc_time) / _arc_time
	_hover_left = maxf(delay, 0.0)
	visible = _hover_left <= 0.0
	_active = true
	_damage_applied = false


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _arc:
		if _hover_left > 0.0:
			_hover_left -= delta
			if _hover_left <= 0.0:
				visible = true
			return
		_elapsed += delta
		_velocity.y += _fall_gravity * delta
		global_position += _velocity * delta
		_try_damage_player()
		if _elapsed >= _arc_time:
			global_position = _arc_target
			_land()
		return
	if _hover_left > 0.0:
		_hover_left -= delta
	else:
		_velocity.y += _fall_gravity * delta
		global_position.y += _velocity.y * delta
	_try_damage_player()
	if global_position.y >= _ground_y:
		global_position.y = _ground_y
		_land()


func _try_damage_player() -> void:
	if _damage_applied:
		return
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage_amount)
		_damage_applied = true
		break


func _land() -> void:
	_active = false
	_spawn_land_effect()
	if land_shake > 0.0:
		Game.shake_camera(land_shake)
	queue_free()


func _spawn_land_effect() -> void:
	if LAND_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := LAND_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
