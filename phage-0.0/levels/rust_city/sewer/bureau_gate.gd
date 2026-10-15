# 管道局检查站的铁栅门:关着挡路(世界层碰撞),open() 往上收进拱顶。
class_name BureauGate
extends StaticBody2D

@export var lift: float = 40.0
@export var start_open: bool = false

var is_open := false
@onready var _sprite: Node2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if start_open:
		open(true)


func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	if instant:
		_sprite.position.y -= lift
		return
	Game.shake_camera(1.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", _sprite.position.y - lift, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_shape.set_deferred("disabled", false)
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", _sprite.position.y + lift, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: Game.shake_camera(3.0))
