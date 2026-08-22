# res://entities/player/BuffEffect/player_line_bullet.gd
# 玩家侧直线子弹(水刺/蛛卵弹共用):"Fly"=第一帧飞行,命中后播"Hit"(后三帧)再消失。
# 碰撞形状在各自场景里手画(CollisionPolygon2D)。
# 上下左右仍走镜像/90°整旋(素材完全贴网格);斜向(珊瑚扇形)自由旋转——
# 160×90 视口先光栅化再放大,旋转后的像素仍落在巨像素网格上,不算高分辨率斜线。
extends Area2D

## 命中怪物时发出(珊瑚潮汐"全中"统计用)。
signal hit_landed

@export var speed: float = 140.0
@export var lifetime: float = 0.7
@export var damage: int = 20

var _dir: Vector2 = Vector2.RIGHT
var _flying: bool = true
var _life: float = 0.0
var _damaged: Array[Node] = []

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_hit_node)
	area_entered.connect(_on_hit_node)
	_sprite.play(&"Fly")


## 正上下左右保持原来的镜像/整旋处理,其余方向按实际角度旋转飞行。
func setup(direction: Vector2, damage_value: int) -> void:
	damage = damage_value
	_dir = direction.normalized()
	if absf(_dir.x) < 0.001:
		_dir = Vector2(0.0, signf(_dir.y))
		rotation = PI / 2.0 * _dir.y  # 向下=+90°,向上=-90°,整旋不破像素网格
	elif absf(_dir.y) < 0.001:
		_dir = Vector2(signf(_dir.x), 0.0)
		if _dir.x < 0.0:
			scale.x = -1.0  # 镜像根节点,手画的碰撞形状跟着镜像
	else:
		rotation = _dir.angle()  # 素材朝右画,旋到实际飞行方向


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_life += delta
	if _life >= lifetime:
		queue_free()
		return
	global_position += _dir * speed * delta


func _on_hit_node(node: Node) -> void:
	if not _flying:
		return
	if not node.is_in_group("monster") and not node.is_in_group("breakable_wall"):
		return
	# 与主角攻击判定同款:目标自己或它的父节点承伤。
	var target: Node = node
	if not target.has_method("take_damage"):
		target = target.get_parent()
		if target == null or not target.has_method("take_damage"):
			return
	if target in _damaged:
		return
	_damaged.append(target)
	target.call("take_damage", damage)
	hit_landed.emit()
	_explode()


func _explode() -> void:
	_flying = false
	set_deferred("monitoring", false)
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"Hit"):
		_sprite.play(&"Hit")
		await _sprite.animation_finished
	queue_free()
