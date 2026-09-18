# 章鱼 Laser(5):十字激光(用 Idle 动画)。
# 原地定住(不走、不飘、不掉子弹),以本体原点为交点在身后摆两根预警线:一根指向主角(锁定摆线那一刻的位置),
# 另一根和它垂直;预警 warn_time 秒后两根一起开火,火完歇 after_time 秒回 Idle。
# 激光本体是红丝虫那根通用激光(octopus_laser.tscn 只换了颜色、放到章鱼身后一层)。
extends BasicState

const SELF_ID := 5
const LASER_SCENE: PackedScene = preload("res://entities/octopus/octopus_laser.tscn")

## 预警线亮着多久才开火(预警线本身 0.45s 渐显,之后呼吸闪)
@export var warn_time: float = 1.0
## 开火后再停多久回 Idle(束本身 0.04 张开 + beam_hold + 0.1 收拢)
@export var after_time: float = 0.6
## 每根激光从交点往两头各伸多长(够穿过整个屏幕)
@export var beam_length: float = 260.0
## 开火那一下的震屏 / 闪屏
@export var fire_shake: float = 2.5
@export var fire_flash: float = 0.12

@onready var monster = $"../.."

var _t := 0.0
var _fired := false
var _lasers: Array[Node] = []


func enter() -> void:
	_t = 0.0
	_fired = false
	monster.set_drops(false)
	monster.set_advancing(false)
	monster.set_bobbing(false)
	monster.play_anim(&"Idle")
	var center: Vector2 = monster.global_position
	var dir := Vector2.LEFT
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var to_player := (players[0] as Node2D).global_position + Vector2(0.0, -4.0) - center  # 瞄主角身子中间
		if to_player.length() > 1.0:
			dir = to_player.normalized()
	var scene := get_tree().current_scene
	for d: Vector2 in [dir, Vector2(-dir.y, dir.x)]:
		var laser := LASER_SCENE.instantiate()
		scene.add_child(laser)
		laser.call("show_aim", center - d * beam_length, center + d * beam_length, true, fire_shake, fire_flash)
		_lasers.append(laser)


func process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= warn_time:
		_fired = true
		for laser in _lasers:
			if is_instance_valid(laser):
				laser.call("fire")
	if _fired and _t >= warn_time + after_time:
		change_state(monster.get_next_attack_state(SELF_ID))


# 被打断(打赢了要逃、剧情杀)时没开火的预警线淡出;已经开火的自己收拢删掉
func exit() -> void:
	if not _fired:
		for laser in _lasers:
			if is_instance_valid(laser):
				laser.call("cancel")
	_lasers.clear()
