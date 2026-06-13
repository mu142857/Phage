# =============================================================================
# basket_ball.gd  —  天降篮球（挂在 res://entities/basket_ball.tscn 根节点）
# =============================================================================
# 行为：从 setup 给的位置开始重力加速下落 → 途中碰到玩家造成一次伤害并消失 →
#       落到地面 → 震屏 + 落地表现 → 消失。
# setup 约定: setup(start_pos: Vector2)
#   （state_shoot.gd 落球时调的就是这个）
#
# 场景结构：
#   BasketBall (Area2D, 挂本脚本)
#   │   collision_mask 勾 player 层
#   ├── Sprite2D 或 AnimatedSprite2D
#   ├── CollisionShape2D
#   └── Trail (GPUParticles2D, 可选拖尾，没有就不管)
#
# 参考：照 Azure Warlord 的垂直下落弹整理，参数同源。
# =============================================================================

extends Area2D

@export var projectile_gravity: float = 200.0  # 下落加速度（Azure: 200）
@export var ground_y: float = 80.0             # 地面高度（Azure: 80）
@export var damage_amount: int = 5             # 命中伤害（Azure: 5）
@export var land_shake: float = 5.0            # 落地震屏（Azure: 1）
@export var spin_speed: float = 6.0            # 自转角速度（弧度/秒，0=不转；篮球转着掉更像样）

# 落地粒子（可空）：例 preload("res://entities/rust_goat/ball_land_effect.tscn")
const LAND_EFFECT_SCENE: PackedScene = preload("res://entities/rust_goat/basketball_land.tscn")

var velocity: Vector2 = Vector2.ZERO
var active: bool = false
var damage_applied: bool = false
var landed: bool = false


func _ready() -> void:
	var ani := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(ani):
		ani.play(&"default")


func setup(start_pos: Vector2) -> void:
	global_position = start_pos
	velocity = Vector2.ZERO
	active = true
	damage_applied = false
	landed = false
	var trail := get_node_or_null("Trail") as GPUParticles2D
	if is_instance_valid(trail):
		trail.emitting = true


func _physics_process(delta: float) -> void:
	if not active:
		return

	velocity.y += projectile_gravity * delta
	global_position += velocity * delta

	if spin_speed != 0.0:
		rotation += spin_speed * delta

	if global_position.y >= ground_y:
		global_position.y = ground_y
		_land()
	else:
		_try_damage_player()


func _land() -> void:
	if landed:
		return
	landed = true
	active = false
	Game.shake_camera(land_shake)

	if LAND_EFFECT_SCENE != null and get_tree().current_scene != null:
		var eff := LAND_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = global_position
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true

	# 藏本体、停拖尾，留 1 秒让拖尾粒子飘完再删（Azure 的做法）
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		sprite.modulate.a = 0.0
	var ani := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(ani):
		ani.modulate.a = 0.0
	var trail := get_node_or_null("Trail") as GPUParticles2D
	if is_instance_valid(trail):
		trail.emitting = false

	await get_tree().create_timer(1.0).timeout
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
		break
