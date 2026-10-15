# 扔瓶子的扔出来的瓶子:抛物线,转着飞;碰到主角或者落地就碎(碎片方块粒子)。
# 碰到主角直接算一下;落地碎的时候脚边一小块也算(站在落点上会挨)。
# 奥斯卡帮不管队友:砸到同伙也算(扔的那个自己除外)。
extends Area2D

const SHATTER: PackedScene = preload("res://entities/gang/thrower/bottle_shatter.tscn")

@export var splash_radius: float = 9.0
@export var max_life: float = 3.0
@export var friendly_damage: int = 80

## 谁扔的(不砸自己)
var thrower: Node = null

var _v := Vector2.ZERO
var _g := 320.0
var _life := 0.0
var _done := false

@onready var sprite: Sprite2D = $Sprite2D


func launch(v: Vector2, g: float) -> void:
	_v = v
	_g = g


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	_v.y += _g * delta
	global_position += _v * delta
	sprite.rotation += signf(_v.x) * 14.0 * delta
	if _life > max_life:
		queue_free()
		return
	# 落到地面:往下打一条短射线
	if _v.y > 0.0:
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 3.0 + _v.y * delta), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			global_position = hit.position
			_shatter(true)


func _on_body_entered(body: Node2D) -> void:
	if _done:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.call("take_damage", 1)
		_shatter(false)
	elif body is GangMob and body != thrower and _life > 0.1:
		(body as GangMob).take_friendly(friendly_damage, global_position.x, thrower)
		_shatter(false)
	elif body is StaticBody2D and _v.y > 0.0:
		_shatter(true)


func _shatter(on_ground: bool) -> void:
	if _done:
		return
	_done = true
	if on_ground:
		for p in get_tree().get_nodes_in_group("player"):
			if p is Node2D and (p as Node2D).global_position.distance_to(global_position) < splash_radius \
					and p.has_method("take_damage"):
				p.call("take_damage", 1)
		for m in get_tree().get_nodes_in_group("gang"):
			if m != thrower and m is GangMob and (m as Node2D).global_position.distance_to(global_position) < splash_radius:
				(m as GangMob).take_friendly(friendly_damage, global_position.x, thrower)
	var fx := SHATTER.instantiate() as GPUParticles2D
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.emitting = true
	Game.shake_camera(1.0)
	queue_free()
