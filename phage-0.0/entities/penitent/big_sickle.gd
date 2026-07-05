# =============================================================================
# big_sickle.gd  —  大镰刀：缓慢转向的追踪弹（Start→Spin→落地 Stop）
# =============================================================================
# 移植自旧「大镰刀.gd」，数值重定到 160×90。追着玩家飞，越飞越快、转向越准，
# 落到地板后炸开消失。
# =============================================================================
extends Area2D

@export var speed: float = 46.0          # 起始速度 px/s
@export var speed_cap: float = 120.0
@export var speed_gain: float = 55.0     # 每秒加速
@export var turn_rate: float = 0.18      # 每帧转向比例（越小转越慢）
@export var turn_floor: float = 0.05
@export var turn_decay: float = 0.06     # 每秒转向比例衰减
@export var land_y: float = 82.0         # 落地高度
@export var damage: int = 14
@export var lifetime: float = 5.0
@export var shake_amount: float = 3.0

var _player: Node2D = null
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
	if global_position.y >= land_y:
		_land()
		return
	if $AnimatedSprite2D.animation != &"Spin":
		return

	_player = _find_player()
	if _player != null:
		var target_angle := (_player.global_position - global_position).angle()
		rotation = lerp_angle(rotation, target_angle, turn_rate)

	global_position += Vector2(cos(rotation), sin(rotation)) * speed * delta
	speed = minf(speed + speed_gain * delta, speed_cap)
	turn_rate = maxf(turn_rate - turn_decay * delta, turn_floor)


func _land() -> void:
	_landed = true
	global_position.y = land_y
	rotation = 0.0
	Game.shake_camera(shake_amount)
	Game.flash(0.15, Color(1.5, 0.4, 0.4, 0.5))
	$AnimatedSprite2D.play(&"Stop")


func _find_player() -> Node2D:
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return body as Node2D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"Start":
		$AnimatedSprite2D.play(&"Spin")
	elif $AnimatedSprite2D.animation == &"Stop":
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _landed or $AnimatedSprite2D.animation != &"Spin":
		return
	if body != null and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
