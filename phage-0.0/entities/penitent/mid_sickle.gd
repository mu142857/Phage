# =============================================================================
# mid_sickle.gd  —  中镰刀：抛物线弹，落地弹起一次（物理弹跳），再落地即炸
# =============================================================================
extends Area2D

const LAND_EFFECT: PackedScene = preload("res://entities/penitent/mid_sickle_effect.tscn")

@export var flight_time: float = 0.7     # 首段飞行总时长
@export var fall_gravity: float = 600.0  # 重力 px/s²
@export var target_jitter: float = 20.0  # 目标点随机横向偏移
@export var restitution: float = 0.55    # 弹跳恢复系数（越小弹得越低）
@export var bounce_friction: float = 0.7 # 弹跳后水平速度保留比例
@export var land_y: float = 82.0
@export var damage: int = 11
@export var lifetime: float = 6.0
@export var shake_amount: float = 2.5

var _velocity: Vector2 = Vector2.ZERO
var _launched: bool = false
var _bounced: bool = false
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
	if _landed or not _launched:
		return
	if $AnimatedSprite2D.animation != &"Spin":
		return
	if _velocity.y > 0.0 and global_position.y >= land_y:
		if not _bounced:
			_bounce()
		else:
			_land()
		return
	_velocity.y += fall_gravity * delta
	global_position += _velocity * delta


func _launch() -> void:
	var start_pos := global_position
	var target := start_pos
	var player := _find_player()
	if player != null:
		target = player.global_position + Vector2(randf_range(-target_jitter, target_jitter), 0)
	_velocity.x = (target.x - start_pos.x) / flight_time
	_velocity.y = (target.y - start_pos.y - 0.5 * fall_gravity * flight_time * flight_time) / flight_time
	_launched = true


func _bounce() -> void:
	_bounced = true
	global_position.y = land_y - 0.5
	_velocity.y = -absf(_velocity.y) * restitution
	_velocity.x *= bounce_friction
	Game.shake_camera(shake_amount * 0.5)


func _land() -> void:
	_landed = true
	global_position.y = land_y
	rotation = 0.0
	Game.shake_camera(shake_amount)
	Game.flash(0.15, Color(1.5, 0.4, 0.4, 0.5))
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
		_launch()
	elif $AnimatedSprite2D.animation == &"Stop":
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _landed or $AnimatedSprite2D.animation != &"Spin":
		return
	if body != null and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
