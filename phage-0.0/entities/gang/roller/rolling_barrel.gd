# 滚过来的油桶:贴地滚,撞到主角算一下然后碎;撞墙/箱子碎;主角一刀也能砍碎(在 monster 组)。
# 撞到路上的同伙也碎、也算(踢它的那个除外)。
# 4 帧滚动(箍往后挪),碎的时候锈渣方块粒子。
extends Area2D

const BREAK: PackedScene = preload("res://entities/gang/roller/barrel_break.tscn")

@export var life: float = 5.0
@export var friendly_damage: int = 120

var kicker: Node = null

var _vx := 0.0
var _vy := 0.0
var _t := 0.0
var _done := false

@onready var sprite: Sprite2D = $Sprite2D


func roll(vx: float) -> void:
	_vx = vx


func _ready() -> void:
	add_to_group("monster")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var space := get_world_2d().direct_space_state
	# 前面撞墙/箱子(半个桶高的位置往前打一条线)
	var dir := signf(_vx)
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(dir * 7.0, -4), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider as Node).has_method("_drop"):
		_break()
		return
	# 脚下:有地就贴着,没地就往下掉
	var g := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, 2.0 + _vy * delta), 1)
	var gh := space.intersect_ray(g)
	if gh.is_empty():
		_vy += 600.0 * delta
		global_position.y += _vy * delta
	else:
		_vy = 0.0
		global_position.y = gh.position.y
	global_position.x += _vx * delta
	sprite.frame = int(_t * 12.0) % 4 if dir > 0.0 else 3 - int(_t * 12.0) % 4
	if _t > life:
		_break()


func _on_body(body: Node2D) -> void:
	if _done:
		return
	if body is GangMob and body != kicker:
		(body as GangMob).take_friendly(friendly_damage, global_position.x - signf(_vx) * 4.0, kicker)
		_break()
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", 1)
	_break()


func take_damage(_value: int) -> void:
	_break()


func _break() -> void:
	if _done:
		return
	_done = true
	var scene := get_tree().current_scene
	if scene != null:
		var fx := BREAK.instantiate() as GPUParticles2D
		scene.add_child(fx)
		fx.global_position = global_position
		fx.emitting = true
	Game.shake_camera(1.5)
	queue_free()
