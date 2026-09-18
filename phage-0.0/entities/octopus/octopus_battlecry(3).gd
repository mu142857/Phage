# 大章鱼 Battlecry(3):掉到半血 / 四分之一血时插一次——停下吼、震屏,
# 主角战吼式锁定(空中的会落地站好,全程无敌,解锁后还有一小段闪烁无敌兜底残留子弹)。
extends BasicState

const SELF_ID := 3

@export var duration: float = 1.6
@export var shake_amount: float = 3.0

@onready var monster = $"../.."

var _t := 0.0
var _active := false


func enter() -> void:
	_t = 0.0
	_active = true
	monster.set_advancing(false)
	monster.set_drops(false)
	monster.play_anim(&"Battlecry")
	_set_player_lock(true)


func process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	Game.shake_camera(shake_amount)
	if _t >= duration:
		_active = false
		change_state(monster.get_next_attack_state(SELF_ID))


func exit() -> void:
	_active = false
	Game.stop_shake()
	_set_player_lock(false)


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if player.has_method("set_battlecry_lock"):
		player.call("set_battlecry_lock", locked)
	elif player.has_method("set_lock"):
		player.call("set_lock", locked)
