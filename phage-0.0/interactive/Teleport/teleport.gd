
extends Marker2D

@export_file("*.tscn") var scene_path: String = ""
@export var teleport_id: int = 0
@export var player_light: bool = false
@export var hint_fade_duration: float = 0.12
## 默认是否激活。Boss 房里设为 false:未激活时不显示文字、无法交互,
## 直到 Boss 被击败后由外部调用 activate() 打开。
@export var active: bool = true
## 只是走进隔壁的街巷(不是进新梦/存档点):主角护盾/技能运行态原样继承,不重置。
@export var preserve_player_state: bool = false
## 不空 = 这个 Story 标记立起来之前门是锁着的:提示换成锁,按 Q 没反应。
## (捷径门:另一边从里面拉开门闩以后才能走)
@export var unlock_flag: String = ""
## 不空 = 从这扇门走过去时立起这个标记(拉开门闩,另一边的门就开了)。
@export var set_flag_on_use: String = ""

const LOCK_TEX: Texture2D = preload("res://interactive/Teleport/key_lock.png")

var _player_inside: bool = false
var _tracked_player: Player = null
var _hint_visible: bool = false
var _hint_tween: Tween = null
var _hint_canvas_items: Array[CanvasItem] = []
var _hint_base_modulates: Dictionary = {}
var _hint_tex: Texture2D = null   # 提示原来的图(锁着时换成锁,开了换回来)


func _ready() -> void:
	add_to_group("teleport")
	add_to_group(InteractFocus.GROUP)
	_cache_hint_nodes()
	_set_hint_visible(false)
	if is_instance_valid(_hint_tween):   # 开场直接藏好,别让提示淡出那一下闪出来
		_hint_tween.kill()
	_set_hint_nodes_hidden()
	set_process(false)


## 由外部(如 Boss 被击败信号)调用,激活传送点。
func activate() -> void:
	if active:
		return
	active = true
	# 玩家此刻正站在传送点内:交给 _process 判断要不要冒提示
	if _player_inside and is_instance_valid(_tracked_player):
		set_process(true)


## Boss 开打时由 BossIntro 调用,关闭传送点(不可交互并收起提示)。
func deactivate() -> void:
	if not active:
		return
	active = false
	if _hint_visible:
		_set_hint_visible(false)


func _process(_delta: float) -> void:
	if not active:
		return
	if not _player_inside:
		return
	if not is_instance_valid(_tracked_player):
		return
	# 门口还站着会说话的 NPC 时,只有离主角最近的那个冒提示、接 Q(见 InteractFocus)
	if not InteractFocus.is_focused(self, _tracked_player):
		if _hint_visible:
			_set_hint_visible(false)
		return
	if not _hint_visible:
		_set_hint_visible(true)
	var locked := is_locked()
	_show_lock(locked)
	if locked:
		return
	# 触屏模式下没有 Q 键,攻击键也能确认传送
	if Input.is_action_just_pressed("Select") \
			or (TouchControls.enabled and Input.is_action_just_pressed("Attack1")):
		if set_flag_on_use != "":
			Story.set_flag(set_flag_on_use, true)
		Game.change_scene(scene_path, teleport_id, player_light, preserve_player_state)


func is_locked() -> bool:
	return unlock_flag != "" and not Story.flag(unlock_flag, false)


# 锁着:提示的键帽换成一把锁
func _show_lock(locked: bool) -> void:
	for item in _hint_canvas_items:
		if item is Sprite2D:
			var s := item as Sprite2D
			if _hint_tex == null:
				_hint_tex = s.texture
			s.texture = LOCK_TEX if locked else _hint_tex
			return

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		_tracked_player = body
		_player_inside = true
		set_process(true)   # 冒不冒提示由 _process 判断

## InteractFocus 用:主角站在门区里、能按的时候返回水平距离,否则 INF。
func interact_distance(player: Node2D) -> float:
	if not active or not _player_inside or not is_instance_valid(_tracked_player):
		return INF
	if _tracked_player.input_locked or Talk.busy() or Dialogue.is_open:
		return INF
	return absf(player.global_position.x - global_position.x)


## InteractFocus 用:提示(键帽贴图或文字)的框,世界坐标。
func prompt_rect() -> Rect2:
	if not _hint_visible:
		return Rect2()
	for item in _hint_canvas_items:
		if item is Sprite2D:
			var r := (item as Sprite2D).get_rect()
			return Rect2((item as Sprite2D).global_position + r.position, r.size)
		if item is Control:
			return Rect2((item as Control).global_position, (item as Control).size)
	return Rect2()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_set_hint_visible(false)
		_tracked_player = null
		set_process(false)


func _set_hint_visible(visible: bool) -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	_hint_visible = visible
	# 没挂提示气泡的门(比如只当落脚点的 FromArenaStreet):没东西可淡入淡出,别建空补间(会报错)
	if _hint_canvas_items.is_empty():
		return
	if visible:
		for canvas_item in _hint_canvas_items:
			if is_instance_valid(canvas_item):
				canvas_item.visible = true
				canvas_item.modulate = Color(canvas_item.modulate.r, canvas_item.modulate.g, canvas_item.modulate.b, 0.0)
		_hint_tween = create_tween()
		_hint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for canvas_item in _hint_canvas_items:
			if not is_instance_valid(canvas_item):
				continue
			var base_modulate: Color = _hint_base_modulates.get(canvas_item.get_instance_id(), canvas_item.modulate)
			_hint_tween.parallel().tween_property(canvas_item, "modulate:a", base_modulate.a, hint_fade_duration)
		return

	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for canvas_item in _hint_canvas_items:
		if not is_instance_valid(canvas_item):
			continue
		_hint_tween.parallel().tween_property(canvas_item, "modulate:a", 0.0, hint_fade_duration)
	_hint_tween.tween_callback(_set_hint_nodes_hidden)


func _cache_hint_nodes() -> void:
	_hint_canvas_items.clear()
	_hint_base_modulates.clear()
	for child in get_children():
		if child is Area2D:
			continue
		_collect_hint_canvas_items(child)


func _collect_hint_canvas_items(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		_hint_canvas_items.append(canvas_item)
		_hint_base_modulates[canvas_item.get_instance_id()] = canvas_item.modulate
	for child in node.get_children():
		_collect_hint_canvas_items(child)


func _set_hint_nodes_hidden() -> void:
	for canvas_item in _hint_canvas_items:
		if is_instance_valid(canvas_item):
			canvas_item.visible = false
