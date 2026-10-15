# 放哨的:平时缩成一个垃圾袋蹲在墙根(和真垃圾袋混在一起)。你走近或者砍它一下,
# 它就站起来吹哨(第 2~7 帧)叫人,然后往远处跑;没死的话过一阵再吹一次。
# 哨声发 whistled 信号,伏击巷脚本听这个信号叫同伙从天上掉下来。没人听就什么也不发生。
extends GangMob

signal whistled(lookout: GangMob)

@export var reveal_range: float = 40.0
@export var flee_speed: float = 46.0
@export var whistle_again: float = 7.0
@export var whistle_frame: int = 3
@export var start_hidden: bool = true

var in_bag := true
var _whistle_cd := 0.0
var _blew := false


func _start() -> void:
	if start_hidden:
		in_bag = true
		state = S.CUSTOM
		play(&"Bag")
	else:
		in_bag = false
		state = S.ENGAGE


func _custom_tick(_delta: float) -> void:
	velocity.x = 0.0
	if in_bag:
		var p := player()
		if p != null and absf(p.global_position.x - global_position.x) < reveal_range \
				and absf(p.global_position.y - global_position.y) < 30.0:
			reveal()
	elif sprite.animation == &"Whistle" and sprite.frame >= whistle_frame and not _blew:
		_blew = true
		whistled.emit(self)


func reveal() -> void:
	if not in_bag:
		return
	in_bag = false
	var p := player()
	if p != null:
		face(signf(p.global_position.x - global_position.x))
	state = S.CUSTOM
	play_once(&"Reveal", _whistle)


func _whistle() -> void:
	state = S.CUSTOM
	_blew = false
	_whistle_cd = whistle_again
	bark("哔——！", 0.9)
	play_once(&"Whistle", func() -> void: state = S.ENGAGE)


func _on_hurt() -> void:
	if in_bag:
		reveal()


func _engage(delta: float) -> void:
	_whistle_cd -= delta
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	if _whistle_cd <= 0.0 and absf(dx) > 50.0:
		face(signf(dx))
		_whistle()
		return
	if absf(dx) < 90.0 and floor_ahead(-signf(dx)) and not is_on_wall():
		face(-signf(dx))
		walk(facing, flee_speed, &"Run")
	else:
		# 跑不动了(墙角/坑边):回头看着你发抖
		face(signf(dx))
		velocity.x = 0.0
		play(&"Idle")
