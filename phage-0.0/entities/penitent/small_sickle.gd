# =============================================================================
# small_sickle.gd  —  小镰刀：先绕 boss 转一圈，再平滑追踪玩家（Start→Spin→落地 Stop）
# =============================================================================
# 绕满一圈后切向甩出，弱追踪飞向玩家（steer 调低，比之前好躲），落地炸。
# 成对生成（_direction 决定顺/逆时针）。
# =============================================================================
extends Area2D

const LAND_EFFECT: PackedScene = preload("res://entities/penitent/small_sickle_effect.tscn")

@export var orbit_radius: float = 18.0     # 绕圈半径
@export var orbit_speed: float = 7.0       # 绕圈角速度 rad/s
@export var orbit_turns: float = 1.0       # 绕几圈再走
@export var start_speed: float = 55.0       # 甩出初速度
@export var speed_cap: float = 130.0
@export var accel: float = 70.0            # 追踪期加速度
@export var steer: float = 2.5             # 追踪转向强度（中等：能躲但有压力）
@export var land_y: float = 82.0
@export var damage: int = 9
@export var lifetime: float = 8.0
@export var shake_amount: float = 2.0

var _direction: int = 1                    # 由 boss 设置：1=顺 / -1=逆
var _center: Vector2 = Vector2.ZERO
var _angle: float = 0.0
var _swept: float = 0.0
var _orbiting: bool = true
var _vel: Vector2 = Vector2.ZERO
var _landed: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"Start")
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	if _landed:
		return
	if $AnimatedSprite2D.animation != &"Spin":
		return
	if _orbiting:
		_orbit(delta)
	else:
		_track(delta)


func _orbit(delta: float) -> void:
	var step := float(_direction) * orbit_speed * delta
	_angle += step
	_swept += absf(step)
	global_position = _center + Vector2(cos(_angle), sin(_angle)) * orbit_radius
	rotation = _angle + PI * 0.5 * float(_direction)   # 朝切线方向
	if _swept >= TAU * orbit_turns:
		_orbiting = false
		var tangent := Vector2(-sin(_angle), cos(_angle)) * float(_direction)
		_vel = tangent.normalized() * start_speed


func _track(delta: float) -> void:
	var speed := minf(_vel.length() + accel * delta, speed_cap)
	var player := _find_player()
	if player != null:
		var to_p := (player.global_position - global_position).normalized()
		if to_p != Vector2.ZERO and _vel != Vector2.ZERO:
			_vel = _vel.normalized().slerp(to_p, clampf(steer * delta, 0.0, 1.0))
	_vel = _vel.normalized() * speed
	global_position += _vel * delta
	rotation = _vel.angle()
	if _vel.y > 0.0 and global_position.y >= land_y:
		_land()


func _land() -> void:
	_landed = true
	global_position.y = land_y
	rotation = 0.0
	Game.shake_camera(shake_amount)
	Game.flash(0.12, Color(1.6, 0.5, 0.9, 0.4))
	spawn_land_effect(LAND_EFFECT)
	$AnimatedSprite2D.play(&"Stop")


func spawn_land_effect(scene: PackedScene) -> void:
	if scene == null or get_tree().current_scene == null:
		return
	var fx := scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	if fx is GPUParticles2D:
		(fx as GPUParticles2D).emitting = true


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"Start":
		$AnimatedSprite2D.play(&"Spin")
		# 圆心设在出生点正上方，出生点作为圆的最低点 → 从 boss 处起转
		_center = global_position + Vector2(0, -orbit_radius)
		_angle = PI * 0.5
		_swept = 0.0
		_orbiting = true
	elif $AnimatedSprite2D.animation == &"Stop":
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _landed or $AnimatedSprite2D.animation != &"Spin":
		return
	if body != null and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
