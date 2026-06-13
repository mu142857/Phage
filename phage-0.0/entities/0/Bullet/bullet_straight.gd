# =============================================================================
# bullet_straight.gd  —  直线匀速子弹（飞篮球类）
# =============================================================================
# 行为：按给定速度向量直线飞 → 碰到玩家造成一次伤害后消失 → 飞出寿命自动消失。
# setup 约定: setup(start_pos: Vector2, velocity_vector: Vector2)
#   （state_shoot.gd 里 "straight" 分支调的就是这个签名）
#
# 场景结构：
#   Bullet (Area2D, 挂本脚本)
#   ├── Sprite2D 或 AnimatedSprite2D
#   └── CollisionShape2D
# Area2D 的 collision_mask 勾选玩家所在层（player 层）。
# =============================================================================

extends Area2D

@export var damage_amount: int = 5        # 参考 Actinos 子弹: 5
@export var lifetime: float = 3.0         # 寿命（秒），防止飞出屏幕永不消失
@export var rotate_to_velocity: bool = false  # 贴图是否随飞行方向旋转（篮球可开自转见下）
@export var spin_speed: float = 0.0       # 自转角速度（弧度/秒）；篮球转起来更像样，试 8.0

var velocity: Vector2 = Vector2.ZERO
var active: bool = false
var damage_applied: bool = false
var elapsed: float = 0.0


func _ready() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		sprite.play(&"default")


func setup(start_pos: Vector2, velocity_vector: Vector2) -> void:
	global_position = start_pos
	velocity = velocity_vector
	elapsed = 0.0
	active = true
	damage_applied = false
	if rotate_to_velocity and velocity.length() > 0.0:
		rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	global_position += velocity * delta

	if spin_speed != 0.0:
		rotation += spin_speed * delta
	elif rotate_to_velocity and velocity.length() > 0.0:
		rotation = velocity.angle()

	_try_damage_player()

	if elapsed >= lifetime:
		queue_free()


func _try_damage_player() -> void:
	if damage_applied:
		return
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		damage_applied = true
		queue_free()  # 打中即消失；想穿透就删这行
		break
