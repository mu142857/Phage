# 大块头砸地的震波:贴着地面往一边跑,碰到主角算一下(跳起来就躲开)。
# 路上的同伙也被震(大块头自己除外)。
# 画法:几根随机高低的土块方柱 + 火星,一边跑一边掉渣,跑完淡掉。
extends Area2D

@export var speed: float = 95.0
@export var life: float = 0.75

const COLORS := [Color(0.54, 0.48, 0.4), Color(0.42, 0.36, 0.3), Color(1.0, 0.78, 0.38)]

var _dir := 1.0
var _t := 0.0
var _hit := false
var _cols: Array = []
var brute: Node = null
var _hit_mobs: Array = []
@export var friendly_damage: int = 150


func go(dir: float) -> void:
	_dir = dir


func _ready() -> void:
	body_entered.connect(_on_body)
	z_index = 12
	_reroll()


func _physics_process(delta: float) -> void:
	_t += delta
	global_position.x += _dir * speed * delta
	# 前面撞墙就没了
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -3), global_position + Vector2(_dir * 4.0, -3), 1)
	if not space.intersect_ray(q).is_empty():
		queue_free()
		return
	if Engine.get_physics_frames() % 3 == 0:
		_reroll()
	modulate.a = clampf((life - _t) / 0.2, 0.0, 1.0)
	queue_redraw()
	if _t >= life:
		queue_free()


func _reroll() -> void:
	_cols.clear()
	var h_max := 5.0 * (1.0 - _t / life) + 1.0
	for i in range(5):
		_cols.append([i - 2, int(randf_range(1.0, h_max)), randi() % 2])


func _draw() -> void:
	for c in _cols:
		var x: int = c[0]
		var h: int = c[1]
		draw_rect(Rect2(x, -h, 1, h), COLORS[c[2]])
	draw_rect(Rect2(randi() % 5 - 2, -randi() % 6 - 2, 1, 1), COLORS[2])


func _on_body(body: Node2D) -> void:
	if body is GangMob and body != brute and not (body in _hit_mobs):
		_hit_mobs.append(body)
		(body as GangMob).take_friendly(friendly_damage, global_position.x - _dir * 4.0, brute)
		return
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call("take_damage", 1)
