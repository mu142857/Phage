# 木头人 变激光眼(7 号)：手松线缩回去、脑袋亮成一只眼。播 ToEye 等它播完
# (没导帧就按 fallback_time 计时) → Laser。变身期间可以被打。
extends BasicState

@export var fallback_time: float = 1.2

@onready var monster: CharacterBody2D = $"../.."

var _ticket: int = 0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.face_player()
	_ticket += 1
	_run(_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1


func _run(t: int) -> void:
	if monster.has_anim(&"ToEye"):
		monster.play_anim(&"ToEye")
		await monster.sprite.animation_finished
	else:
		await get_tree().create_timer(fallback_time).timeout
	if t != _ticket or not is_instance_valid(monster):
		return
	monster.form = monster.FORM_EYE
	change_state(monster.STATE_LASER)
