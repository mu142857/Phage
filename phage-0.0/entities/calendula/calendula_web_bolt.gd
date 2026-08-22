# =============================================================================
# calendula_web_bolt.gd  —  金盏网弹（挂在 calendula_web_bolt.tscn 根节点）
# =============================================================================
# 行为：setup 给起点和目标点 → 直线匀速飞向目标方向（不追踪）→
#       途中碰到玩家造成一次伤害并消失 → 碰到地面（y >= ground_y）或
#       飞出边界 → 消失。
# setup 约定: setup(start_pos: Vector2, target_pos: Vector2)
#   （web_shot 朝玩家吐、net_rain 从天上垂直落，调的都是这个）
#
# 场景结构：
#   CalendulaWebBolt (Area2D, 挂本脚本)
#   │   collision_mask = 2（只测玩家）
#   ├── Sprite2D（占位用蛛网森林的茧贴图，素材到位后换）
#   └── CollisionShape2D
#
# 渲染铁律：严禁旋转——网弹不自转，斜向飞也保持贴图直立。
# =============================================================================

extends Area2D

@export var bolt_speed: float = 120.0     # 飞行速度（像素/秒）
@export var damage_amount: int = 8        # 命中伤害
@export var ground_y: float = 80.0        # 地面高度（碰到即消失）
@export var margin: float = 30.0          # 出屏边界余量（超出场地这么多就删）

var velocity: Vector2 = Vector2.ZERO
var active: bool = false
var damage_applied: bool = false


func setup(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	var dir := (target_pos - start_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	velocity = dir * bolt_speed
	active = true
	damage_applied = false


func _physics_process(delta: float) -> void:
	if not active:
		return

	global_position += velocity * delta

	if global_position.y >= ground_y or _out_of_bounds():
		_vanish()
		return
	_try_damage_player()


func _out_of_bounds() -> bool:
	return global_position.x < -margin or global_position.x > 160.0 + margin \
			or global_position.y < -margin - 30.0


func _vanish() -> void:
	active = false
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
		_vanish()
		break
