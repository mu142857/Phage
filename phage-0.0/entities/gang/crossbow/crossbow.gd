# 拿弩的:不近身。站定单膝跪下端弩,一根红色瞄准线跟着你 aim_time 秒,
# 然后锁住不动、闪 lock_time 秒(这时候赶紧离开那条线),射出一支弩箭(直线、很快)。
# 射完上弦(Reload),你靠太近就往后退。喜欢落在消防梯上往下射。
extends GangMob

const BOLT: PackedScene = preload("res://entities/gang/crossbow/bolt.tscn")
const AIM_COLOR := Color(0.95, 0.22, 0.25, 0.75)

@export var aim_time: float = 0.8
@export var lock_time: float = 0.4
@export var too_close: float = 40.0
@export var shoot_range: float = 170.0
@export var bolt_speed: float = 230.0
@export var muzzle: Vector2 = Vector2(11.0, -8.0)

enum A { NONE, AIM, LOCK, SHOT }

var _a: A = A.NONE
var _at := 0.0
var _dir := Vector2.RIGHT
var _line: Line2D = null


func _ready() -> void:
	super._ready()
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = AIM_COLOR
	_line.light_mask = 0
	_line.z_index = 15
	_line.visible = false
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_line)


func _engage(_delta: float) -> void:
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	if dist < too_close and floor_ahead(-signf(dx)):
		face(-signf(dx))
		walk(facing, move_speed)
		return
	face(signf(dx))
	if dist > shoot_range:
		walk(facing, move_speed)
		return
	velocity.x = _separation()
	if cooldown <= 0.0:
		_start_aim()
	else:
		play(&"Idle")


func _start_aim() -> void:
	state = S.CUSTOM
	_a = A.AIM
	_at = 0.0
	velocity.x = 0.0
	play_once(&"Aim", func() -> void: play(&"Hold"))


func _custom_tick(delta: float) -> void:
	velocity.x = 0.0
	if _a == A.NONE:
		return
	_at += delta
	var p := player()
	var from := global_position + Vector2(muzzle.x * facing, muzzle.y)
	if _a == A.AIM:
		if p != null:
			_dir = (p.global_position + Vector2(0, -4) - from).normalized()
			if signf(_dir.x) != facing and absf(_dir.x) > 0.2:
				face(signf(_dir.x))
		_show_line(from, true)
		if _at >= aim_time:
			_a = A.LOCK
			_at = 0.0
	elif _a == A.LOCK:
		# 锁住:线不跟了,一闪一闪
		_show_line(from, int(_at * 16.0) % 2 == 0)
		if _at >= lock_time:
			_fire(from)


func _show_line(from: Vector2, on: bool) -> void:
	_line.visible = on
	if not on:
		return
	# 线一直画到撞墙/地面为止
	var to := from + _dir * 220.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	_line.points = PackedVector2Array([to_local(from), to_local(to)])


func _fire(from: Vector2) -> void:
	_a = A.SHOT
	_line.visible = false
	var scene := get_tree().current_scene
	if scene != null:
		var b := BOLT.instantiate() as Node2D
		scene.add_child(b)
		b.global_position = from
		b.call("launch", _dir * bolt_speed)
	play_once(&"Shoot", func() -> void:
		play_once(&"Reload", func() -> void:
			_a = A.NONE
			cooldown = attack_cooldown
			state = S.ENGAGE))


func take_damage(value: int) -> void:
	super.take_damage(value)
	# 挨一刀会打断瞄准(线没了,重新来)
	if health > 0 and (_a == A.AIM or _a == A.LOCK) and not heavy:
		_a = A.NONE
		_line.visible = false
		cooldown = 0.6
		state = S.ENGAGE
