# 锈虫(剧本 #15):从剑中石的石缝里爬出来的小虫,是它们把石头和剑锈在一起的。
# 一刀一只。贴地一拱一拱地朝主角爬,碰到就咬一口(真的掉盾,它是怪)。
extends Area2D

signal died

const DEATH: PackedScene = preload("res://entities/gang/roller/barrel_break.tscn")

@export var speed := 13.0
@export var hp := 150   # 两刀一只
## 只在这段地面上爬(坡顶小广场)
@export var min_x := 0.0
@export var max_x := 9999.0

var _t := 0.0
var _emerge := 0.0
var _dir := 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("monster")
	body_entered.connect(_on_body)
	# 从石缝里钻出来:先往上冒一下
	_emerge = 0.35
	sprite.position.y = 2.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _emerge > 0.0:
		_emerge -= delta
		sprite.position.y = roundf(lerpf(-2.5, 2.0, maxf(_emerge, 0.0) / 0.35))
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		_dir = signf(p.global_position.x - global_position.x)
		if _dir == 0.0:
			_dir = 1.0
	sprite.flip_h = _dir < 0.0
	var f := int(_t * 8.0) % 4
	sprite.frame = f
	# 尺蠖:身子伸长的那两帧才往前挪
	if f == 0 or f == 3:
		global_position.x = clampf(global_position.x + _dir * speed * 2.0 * delta, min_x, max_x)
	for b in get_overlapping_bodies():
		_on_body(b)


func _on_body(body: Node2D) -> void:
	if _emerge > 0.0 or not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	body.call("take_damage", 1)


func take_damage(value: int) -> void:
	hp -= value
	if hp > 0:
		return
	var fx := DEATH.instantiate() as GPUParticles2D
	fx.amount = 6
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -2)
	fx.emitting = true
	died.emit()
	queue_free()
