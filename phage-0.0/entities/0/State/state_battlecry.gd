# =============================================================================
# state_battlecry.gd  —  战吼状态（固定 3 号）
# =============================================================================
# 两种触发场景，自动区分：
#   A. 出场战吼（第一次）：相机聚焦 + 放大 + 显示 boss 名字 + 结束后亮血条
#   B. 阶段插播战吼（50%/25% 血时由主体的 pending_battlecry 排队）：只震屏锁玩家
# 区分依据：boss_base.gd 的 initial_battlecry_shown 标记。
#
# 节点要求：
#   - 主体下 AnimatedSprite2D 有 "Battlecry" 动画
#   - 场景根节点下有 Front (CanvasLayer)，里面放 boss 名字 Label
#   - Game autoload 提供 shake_camera / stop_shake / zoom_to / reset_zoom /
#     set_position_override_smooth / clear_position_override(_smooth)
# =============================================================================

extends BasicState

@export var duration: float = 3.0                 # 战吼总时长（Actinos: 3.0）
@export var shake_amount: float = 3.0             # 持续震屏强度（Actinos: 3.0）
@export var zoom_amount: float = 1.15             # 出场镜头放大倍率（Actinos: 1.15）
@export var zoom_duration: float = 0.2            # 放大耗时（Actinos: 0.2）
@export var camera_focus_position: Vector2 = Vector2(16.0, 9.0)  # 出场镜头聚焦点（Actinos: 16,9）
@export var camera_move_duration: float = 0.25    # 镜头移动耗时（Actinos: 0.25）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false
var _show_intro: bool = false  # 本次是不是出场战吼


func enter() -> void:
	is_active = true
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Battlecry")

	# 判断：出场战吼 or 阶段插播
	_show_intro = false
	if monster != null and "initial_battlecry_shown" in monster:
		if not monster.initial_battlecry_shown:
			monster.initial_battlecry_shown = true
			_show_intro = true

	if _show_intro:
		# 出场专属演出：镜头聚焦 + 放大 + boss 名字
		Game.set_position_override_smooth(camera_focus_position, camera_move_duration)
		_set_boss_name_visible(true)
		Game.zoom_to(Vector2(zoom_amount, zoom_amount), zoom_duration)

	# 不管哪种战吼，期间都锁玩家
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
	# 出场战吼结束 → 亮血条
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


func _set_boss_name_visible(visible_flag: bool) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var front := scene.get_node_or_null("Front") as CanvasLayer
	if front != null:
		front.visible = visible_flag
