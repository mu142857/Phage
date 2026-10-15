# 扔瓶子的:背一麻袋瓶子,不跟你近身。你靠太近他就往后退,站在中远距离往你脚下扔瓶子
# (伸手摸瓶 → 举过头憋一下 → 甩出去,第 7 帧出手)。瓶子落地就碎,碎的那一下才有伤害。
extends GangMob

const BOTTLE: PackedScene = preload("res://entities/gang/thrower/bottle.tscn")

@export var too_close: float = 44.0
@export var too_far: float = 130.0
@export var release_frame: int = 7
@export var flight_time: float = 0.85
@export var bottle_gravity: float = 320.0

var _thrown := false


func _engage(_delta: float) -> void:
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	if dist < too_close and floor_ahead(-signf(dx)):
		# 往后退(背对着你跑两步)
		face(-signf(dx))
		walk(facing, move_speed)
		return
	face(signf(dx))
	if dist > too_far:
		walk(facing, move_speed)
		return
	velocity.x = _separation()
	if cooldown <= 0.0:
		start_attack(&"Throw")
	else:
		play(&"Idle")


func _on_attack_started() -> void:
	_thrown = false


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == &"Throw" and sprite.frame >= release_frame and not _thrown:
		_thrown = true
		_throw()


func _throw() -> void:
	var p := player()
	var scene := get_tree().current_scene
	if p == null or scene == null:
		return
	var from := global_position + Vector2(facing * 7.0, -22.0)
	# 落点:主角现在站的地方,稍微往他跑的方向提前一点
	var target := p.global_position
	var pv: Variant = p.get("velocity")
	if pv is Vector2:
		target.x += (pv as Vector2).x * 0.25
	var t := flight_time
	var v := Vector2((target.x - from.x) / t, (target.y - 2.0 - from.y - 0.5 * bottle_gravity * t * t) / t)
	var b := BOTTLE.instantiate()
	scene.add_child(b)
	b.global_position = from
	b.call("launch", v, bottle_gravity)
