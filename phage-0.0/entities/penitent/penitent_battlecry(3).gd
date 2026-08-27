# =============================================================================
# Battlecry(3)  —  出场战吼：播 Battlecry 动画 + 镜头聚焦/放大 + 震屏 + 锁玩家
# =============================================================================
# 仿 actinos / rust_goat 的出场演出。这一版先不做血条与名字（见 penitent.gd 钩子），
# 名字/血条接口都留好了：以后在关卡里加一个 "Front" CanvasLayer 放名字、给 boss 挂
# BossHealthUI，把下面 _show_intro 分支里的两行注释解开即可。
# 演完 → Disappear，开始正式循环。
# =============================================================================
extends BasicState

@export var duration: float = 2.4
@export var shake_amount: float = 3.0
@export var zoom_amount: float = 1.15
@export var zoom_duration: float = 0.2
@export var camera_focus_offset: Vector2 = Vector2(0.0, -14.0)  # 运镜聚焦点相对 boss 的偏移
@export var camera_move_duration: float = 0.25
@export var move_camera: bool = false   # 固定相机的竞技场默认关；开了才做聚焦+放大

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false
var _show_intro: bool = false


func enter() -> void:
	is_active = true
	monster.velocity = Vector2.ZERO
	monster.show()
	monster.global_position.y = monster.floor_y
	monster.face_player()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Battlecry")

	# 只有第一次战吼才做「运镜 + 放大（+ 名字）」
	_show_intro = not monster.initial_battlecry_shown
	if _show_intro:
		monster.initial_battlecry_shown = true
		if move_camera:
			Game.set_position_override_smooth(monster.global_position + camera_focus_offset, camera_move_duration)
			Game.zoom_to(Vector2(zoom_amount, zoom_amount), zoom_duration)
		# _set_boss_name_visible(true)   # ← 关卡里做好 Front 名字层后解开

	_set_player_lock(true)
	_start_timer()


func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)


func exit() -> void:
	is_active = false
	_set_player_lock(false)
	# _set_boss_name_visible(false)     # ← 同上
	Game.stop_shake()
	if move_camera:
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
	if _show_intro and monster.has_method("show_health_ui"):
		monster.show_health_ui()
	change_state(monster.STATE_DISAPPEAR)


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	# 战吼式锁定:空中的主角落地站好,全程无敌+解锁后余量无敌(残留弹幕兜底)
	if players[0].has_method("set_battlecry_lock"):
		players[0].set_battlecry_lock(locked)
	elif players[0].has_method("set_lock"):
		players[0].set_lock(locked)


# 名字显示：关卡根节点下的 "Front" CanvasLayer（这版留着不用）
func _set_boss_name_visible(v: bool) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var front := scene.get_node_or_null("Front") as CanvasLayer
	if front != null:
		front.visible = v


func _on_animated_sprite_2d_animation_finished() -> void:
	pass  # 靠 duration 计时切状态；Battlecry 动画播完停在末帧即可
