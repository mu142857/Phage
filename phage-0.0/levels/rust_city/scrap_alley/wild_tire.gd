# 第 3 场从对面废车场滚过来的野轮胎:顺着地形往左滚,前面高了就蹦。
# 撞到主角 = 被撞开、定一下(不扣血,比赛而已);主角跳过去就没事,也能一刀砍碎。
extends Area2D

const BREAK: PackedScene = preload("res://entities/gang/roller/barrel_break.tscn")
const G := 620.0

@export var speed := 92.0

var _race: TireRace
var _player: Node2D
var _vy := 0.0
var _grounded := true
var _t := 0.0
var _hit := false

@onready var sprite: Sprite2D = $Sprite2D


func setup(race: TireRace, player: Node2D) -> void:
	_race = race
	_player = player


func _ready() -> void:
	add_to_group("monster")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _race == null or not is_instance_valid(_race):
		queue_free()
		return
	_t += delta
	var x := global_position.x
	var y := global_position.y
	var nx := x - speed * delta
	if _grounded:
		var top := _race.highest_ahead(x, -1.0, 10.0)
		if top < y - 3.0:
			_vy = -sqrt(2.0 * G * (y - top + 4.0))
			_grounded = false
		else:
			var g := _race.ground_y(nx)
			if g <= y + 1.5:
				y = g
			else:
				_grounded = false
				_vy = 0.0
	if not _grounded:
		_vy += G * delta
		y += _vy * delta
		if _race.ground_y(nx) < y - 2.0 and _vy < 0.0:
			nx = x
		var g2 := _race.ground_y(nx)
		if y >= g2 and _vy >= 0.0:
			y = g2
			_vy = 0.0
			_grounded = true
	global_position = Vector2(nx, y)
	sprite.frame = int(_t * 14.0) % 4
	if nx < _race.start_x - 60.0 or _t > 8.0:
		queue_free()


func _on_body(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	# 物理回调里不能改碰撞状态(定身会关攻击判定),挪到这一帧之后
	(func() -> void: MiniHud.knock(body, -1.0, 16.0, 0.45)).call_deferred()
	# 撞完弹起来,从主角头上越过去
	_vy = -150.0
	_grounded = false


func take_damage(_v: int) -> void:
	var fx := BREAK.instantiate() as GPUParticles2D
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.emitting = true
	queue_free()
