# 重弩手:瘦、宽檐铁帽(脸在阴影里)、锁子甲,扛一把黑铁重弩。不近身:
# 单膝跪下端弩(Aim)→ 蓄着(Hold,弩头一闪一闪,地上一道淡淡的瞄准线)→ 队长喊"放!"全队一起射
# (队里没队长了就自己数 hold_time 射)→ 上弦(Reload)。弩箭又快又直,穿过自己人不伤。
extends BureauMob

const HEAVY_BOLT: PackedScene = preload("res://entities/bureau/arbalest/heavy_bolt.tscn")
const AIM_COLOR := Color(1.0, 0.95, 0.82, 0.32)

@export var shoot_range: float = 180.0
@export var too_close: float = 34.0
@export var hold_time: float = 0.7
## 等队长下令最多等多久
@export var max_wait: float = 3.0
@export var bolt_speed: float = 260.0
@export var muzzle: Vector2 = Vector2(20.0, -17.0)

enum A { NONE, AIM, HOLD, SHOT }

var _a: A = A.NONE
var _at := 0.0
var _dir := Vector2.RIGHT
var _volley_now := false
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


func is_shooter() -> bool:
	return _a == A.AIM or _a == A.HOLD


func _engage(delta: float) -> void:
	var f := foe()
	if f == null:
		super._engage(delta)
		return
	var dx := f.global_position.x - global_position.x
	var dist := absf(dx)
	var in_squad := squad != null and not _broken
	if not in_squad and dist < too_close and floor_ahead(-signf(dx)):
		face(-signf(dx))
		walk(facing, move_speed)
		return
	if in_squad and absf(post_x() - global_position.x) > 3.0:
		_keep_slot()
		return
	face(signf(dx))
	if dist > shoot_range:
		if in_squad:
			velocity.x = 0.0
			play(&"Idle")
		else:
			walk(facing, move_speed)
		return
	velocity.x = 0.0
	if cooldown <= 0.0:
		_start_aim()
	else:
		play(&"Idle")


func _start_aim() -> void:
	shout("aim", 0.4)
	state = S.CUSTOM
	_a = A.AIM
	_at = 0.0
	_volley_now = false
	velocity.x = 0.0
	play_once(&"Aim", func() -> void:
		if _a == A.AIM:
			_a = A.HOLD
			_at = 0.0
			play(&"Hold"))


func _custom_tick(delta: float) -> void:
	velocity.x = 0.0
	if _a == A.NONE or _a == A.SHOT:
		return
	_at += delta
	var f := foe()
	var from := global_position + Vector2(muzzle.x * facing, muzzle.y)
	if f != null:
		_dir = (f.global_position + Vector2(0, -4) - from).normalized()
		if signf(_dir.x) != facing and absf(_dir.x) > 0.3:
			face(signf(_dir.x))
	if _a != A.HOLD:
		return
	_show_line(from)
	var commanded := squad != null and not _broken and squad.commander != null
	if f == null:
		_cancel()
	elif _volley_now or (not commanded and _at >= hold_time) or _at >= max_wait:
		_fire(from)


## 队长喊"放!"那一帧
func on_volley() -> void:
	if _a == A.AIM or _a == A.HOLD:
		_volley_now = true


func _show_line(from: Vector2) -> void:
	_line.visible = int(_at * 10.0) % 2 == 0
	var to := from + _dir * 200.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	_line.points = PackedVector2Array([to_local(from), to_local(to)])


func _fire(from: Vector2) -> void:
	_a = A.SHOT
	_volley_now = false
	_line.visible = false
	var scene := get_tree().current_scene
	if scene != null:
		var b := HEAVY_BOLT.instantiate() as Node2D
		scene.add_child(b)
		b.global_position = from
		b.set("shooter", self)
		b.set("hits_player", hostile_to_player())
		b.call("launch", _dir * bolt_speed)
	Game.shake_camera(0.8)
	play_once(&"Shoot", func() -> void:
		play_once(&"Reload", func() -> void:
			_a = A.NONE
			cooldown = attack_cooldown
			state = S.ENGAGE))


func _cancel() -> void:
	_a = A.NONE
	_line.visible = false
	cooldown = 0.5
	state = S.ENGAGE


func _on_hurt() -> void:
	if health > 0 and (_a == A.AIM or _a == A.HOLD):
		_cancel()


func _lines() -> Dictionary:
	return {
		"aim": ["瞄准。", "别动。"],
		"spot": ["目标确认。", "站住。"],
	}
