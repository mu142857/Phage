# res://systems/npc/talk.gd
# NPC 对话的通用开场/收场:锁住主角 + 压暗画面,结束时还原。
# 剧情里一段话可能套着另一段(必经剧情里调用 NPC 的对话),用计数防止重复锁/提前解锁。
# 用法:
#   Talk.begin()
#   await Dialogue.talk([["点灯人", "哇!新来的!"]])
#   Talk.end()
class_name Talk
extends RefCounted

const DIM_ALPHA := 0.45
const DIM_LAYER := 120  # 盖住 HUD(100),在触屏键(140)和对话(150)底下
const DIM_FADE := 0.2

static var _depth := 0
static var _dim_layer: CanvasLayer = null
static var _dim_rect: ColorRect = null
static var _dim_tween: Tween = null


static func begin() -> void:
	# 换过场景(死亡重载等)遮罩已经没了,旧计数作废
	if not is_instance_valid(_dim_layer):
		_depth = 0
	_depth += 1
	if _depth > 1:
		return
	var player := _player()
	if player != null:
		player.set_lock(true)
	# 有人开口了,别人头顶挂着的话都收起来
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group("npc", "hide_bark")
	_fade_dim(DIM_ALPHA)


static func end() -> void:
	if _depth == 0:
		return
	_depth -= 1
	if _depth > 0:
		return
	_fade_dim(0.0)
	var player := _player()
	if player != null:
		player.set_lock(false)


## 正在演对话(NPC 头顶提示要藏起来、别的 NPC 不许插话)。
static func busy() -> bool:
	return _depth > 0 and is_instance_valid(_dim_layer)


static func _player() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("player") if tree != null else null


static func _fade_dim(alpha: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	if not is_instance_valid(_dim_layer):
		_dim_layer = CanvasLayer.new()
		_dim_layer.layer = DIM_LAYER
		_dim_rect = ColorRect.new()
		_dim_rect.color = Color(0, 0, 0, 0)
		_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim_layer.add_child(_dim_rect)
		tree.current_scene.add_child(_dim_layer)
	if is_instance_valid(_dim_tween):
		_dim_tween.kill()
	_dim_tween = _dim_rect.create_tween()
	_dim_tween.tween_property(_dim_rect, "color:a", alpha, DIM_FADE)
