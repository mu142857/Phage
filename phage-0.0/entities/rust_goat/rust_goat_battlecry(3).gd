# =============================================================================
# state_battlecry.gd  —  rust_goat 战吼（3 号）：没有专属动画，播 Idle 充当
# =============================================================================
# 出场战吼（第一次）：镜头聚焦 + 放大 + 显示 boss 名字（Front 层）+ 结束亮血条
# 阶段插播战吼：只震屏锁玩家
# 结束后「问大脑」→ 出场战吼完会自动开播一阶段剧本的第一条（Shoot）
# =============================================================================

extends BasicState

@export var battlecry_animation: StringName = &"Idle"  # 没有专属动画就用 Idle
@export var duration: float = 3.0
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
		ani_2d.play(battlecry_animation)

	_show_intro = false
	if monster != null and "initial_battlecry_shown" in monster:
		if not monster.initial_battlecry_shown:
			monster.initial_battlecry_shown = true
			_show_intro = true

	if _show_intro:
		Game.set_position_override_smooth(camera_focus_position, camera_move_duration)
		_set_boss_name_visible(true)
		Game.zoom_to(Vector2(zoom_amount, zoom_amount), zoom_duration)

	_set_player_lock(true)
	_start_timer()


func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)


func exit() -> void:
	is_active = false
	_set_player_lock(false)
	_set_boss_name_visible(false)
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
	# 演完问大脑（出场战吼完 = 开播剧本第一条）
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	if players[0].has_method("set_lock"):
		players[0].set_lock(locked)


func _set_boss_name_visible(visible_flag: bool) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var front := scene.get_node_or_null("Front") as CanvasLayer
	if front != null:
		front.visible = visible_flag
