# 红丝虫 战吼状态(3 号)：
#   A. 出场战吼——由 BossIntro 字卡组件负责演出(它会预先把 initial_battlecry_shown
#      设 true)，这里的出场分支只是没挂 BossIntro 时的兜底(镜头聚焦+放大)。
#   B. 阶段插播战吼(50%/25% 血)——只震屏锁玩家。
# 注意：按新规范不做 Front 名字层，boss 名字全交给 BossIntro。
extends BasicState

@export var duration: float = 2.5
@export var shake_amount: float = 3.0
@export var zoom_amount: float = 1.15
@export var zoom_duration: float = 0.2
@export var camera_focus_position: Vector2 = Vector2(16.0, 9.0)
@export var camera_move_duration: float = 0.25

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false
var _show_intro: bool = false


func enter() -> void:
	is_active = true
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Battlecry")

	_show_intro = false
	if monster != null and "initial_battlecry_shown" in monster:
		if not monster.initial_battlecry_shown:
			monster.initial_battlecry_shown = true
			_show_intro = true

	if _show_intro:
		Game.set_position_override_smooth(camera_focus_position, camera_move_duration)
		Game.zoom_to(Vector2(zoom_amount, zoom_amount), zoom_duration)

	_set_player_lock(true)
	_start_timer()


func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)


func exit() -> void:
	is_active = false
	_set_player_lock(false)
	Game.stop_shake()
	if _show_intro:
		Game.clear_position_override_smooth(camera_move_duration)
	else:
		Game.clear_position_override()
	Game.reset_zoom(zoom_duration)


func _start_timer() -> void:
	await get_tree().create_timer(duration).timeout
	if not is_active:
		return
	Game.stop_shake()
	if _show_intro and monster != null and monster.has_method("show_health_ui"):
		monster.show_health_ui()
	change_state(1)  # 回 Idle


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	# 战吼式锁定:空中的主角落地站好,全程无敌+解锁后余量无敌(残留弹幕兜底)
	if players[0].has_method("set_battlecry_lock"):
		players[0].set_battlecry_lock(locked)
	elif players[0].has_method("set_lock"):
		players[0].set_lock(locked)
