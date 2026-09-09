# 木头人 激光横扫(8 号)：激光眼悬在原地，从 EyePoint 朝主角那边平射一整屏：
#   预警线亮 aim_time → 开火(主束) → 光束脱手往下压到离地 sweep_end_above 格
#   (sweep_time 秒，主角要跳过去) → 停 hold_time → 收束
# → 告诉木偶师打完了 → Vanish 化开。
# 铁律：激光只能横平竖直(禁斜线)，所以是「横着射、整根往下落」，不是转着扫。
extends BasicState

const LASER_SCENE: PackedScene = preload("res://entities/wooden_man/eye_laser.tscn")

@export var aim_time: float = 0.8
@export var beam_length: float = 170.0
@export var sweep_time: float = 0.7
@export var sweep_end_above: float = 5.0   # 光束最后停在离地这么高(主角 8 格高，必须跳)
@export var hold_time: float = 0.25
@export var damage: int = 10
@export var fire_shake: float = 2.0
@export var fire_flash: float = 0.12

@onready var monster: CharacterBody2D = $"../.."

var _ticket: int = 0
var _laser: Node = null


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.face_player()
	monster.play_anim(&"EyeIdle")
	_ticket += 1
	_run(_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1
	if is_instance_valid(_laser) and _laser.has_method("cancel"):
		_laser.call("cancel")
	_laser = null


func _run(t: int) -> void:
	if LASER_SCENE == null or get_tree().current_scene == null:
		_finish()
		return
	_laser = LASER_SCENE.instantiate()
	get_tree().current_scene.add_child(_laser)
	_laser.set("damage", damage)
	_laser.call("show_aim", monster.eye_point.global_position, monster.facing, beam_length)
	await get_tree().create_timer(aim_time).timeout
	if t != _ticket or not is_instance_valid(monster) or not is_instance_valid(_laser):
		return
	_laser.call("fire", fire_shake, fire_flash)
	await get_tree().create_timer(0.12).timeout
	if t != _ticket or not is_instance_valid(monster) or not is_instance_valid(_laser):
		return
	_laser.call("sweep_to", monster.floor_y - sweep_end_above, sweep_time)
	await get_tree().create_timer(sweep_time + hold_time).timeout
	if t != _ticket or not is_instance_valid(monster):
		return
	if is_instance_valid(_laser):
		_laser.call("retract")
	_laser = null
	_finish()


func _finish() -> void:
	monster.on_attack_finished()
	change_state(monster.STATE_VANISH)
