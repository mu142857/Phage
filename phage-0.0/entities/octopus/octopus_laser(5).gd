# 章鱼 Laser(5):十字激光(用 Idle 动画)。
# 原地定住(不走、不飘、不掉子弹),以本体原点为交点在身后摆十字预警线:
# 第一根瞄"这一刻主角的方向再往左 sweep_angle 度",第二根和它垂直;预警线摆好就固定,不跟着转。
# 预警完开火:整个十字按 sweep_speed(度/秒)慢慢转,扫到**开火那一刻**主角的位置,转完直接变细消失。
# 躲法:开火后往章鱼那边(前)走——光停在你开火时站的地方;往后退反而会被扫到。
extends BasicState

const SELF_ID := 5
const LASER_SCENE: PackedScene = preload("res://entities/octopus/octopus_laser.tscn")

## 预警线亮着多久才开火
@export var warn_time: float = 1.0
## 预警线瞄在主角左边多少度(开火后大约就转这么多度扫到主角)
@export var sweep_angle: float = 30.0
## 开火后转动的速度(度/秒);30 度 ÷ 20 = 扫 1.5 秒
@export var sweep_speed: float = 20.0
## 扫一次最短 / 最长几秒(主角预警时乱跑会让要转的角度变大变小)
@export var sweep_time_min: float = 0.4
@export var sweep_time_max: float = 2.5
## 收束后再停多久回 Idle
@export var after_time: float = 0.5

@onready var monster = $"../.."

var _t := 0.0
var _fired := false
var _cross: Node = null
var _aim := Vector2.LEFT
var _sweep_time := 0.0


func enter() -> void:
	_t = 0.0
	_fired = false
	_sweep_time = 0.0
	monster.set_drops(false)
	monster.set_advancing(false)
	monster.set_bobbing(false)
	monster.play_anim(&"Idle")
	_aim = _aim_dir()
	_cross = LASER_SCENE.instantiate()
	get_tree().current_scene.add_child(_cross)
	_cross.call("aim", monster.global_position, _aim)


func process(delta: float) -> void:
	_t += delta
	if not _fired:
		if _t < warn_time:
			return
		_fired = true
		var to := _to_player()
		var degrees := absf(rad_to_deg(angle_difference(_aim.angle(), to.angle())))
		_sweep_time = clampf(degrees / maxf(sweep_speed, 1.0), sweep_time_min, sweep_time_max)
		if is_instance_valid(_cross):
			_cross.call("fire", to, _sweep_time)
		return
	if _t >= warn_time + _sweep_time + after_time:
		change_state(monster.get_next_attack_state(SELF_ID))


# 被打断(打赢了要逃、剧情杀)时,没开火的预警线淡出;已经开火的自己演完自己删
func exit() -> void:
	if not _fired and is_instance_valid(_cross):
		_cross.call("cancel")
	_cross = null


# 从交点指向主角身子中间
func _to_player() -> Vector2:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2.LEFT
	var v: Vector2 = (players[0] as Node2D).global_position + Vector2(0.0, -4.0) - monster.global_position
	return v.normalized() if v.length() > 1.0 else Vector2.LEFT


# 预警瞄的方向:主角方向再往左转 sweep_angle 度(朝下的往顺时针、朝上的往逆时针,都是往画面左边偏)
func _aim_dir() -> Vector2:
	var d := _to_player()
	var turn := deg_to_rad(sweep_angle) * (1.0 if d.y >= 0.0 else -1.0)
	return d.rotated(turn)
