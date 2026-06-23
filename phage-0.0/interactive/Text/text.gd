extends Marker2D

@export var hint_fade_duration: float = 0.12
@export var hint_linger_duration: float = 1.0  # 离开区域后保留多久才淡出消失

var _hint_tween: Tween = null
var _labels: Array[CanvasItem] = []          # 可随机挑选显示的文字
var _always_items: Array[CanvasItem] = []    # 非 Label 的显示物(气泡背景等),始终显示
var _base_modulates: Dictionary = {}
var _active_items: Array[CanvasItem] = []    # 当前显示的一组(供淡出复用)


func _ready() -> void:
	_cache_hint_nodes()
	_hide_all_now()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		_show_hint()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		_hide_hint()


## 进入:随机挑一条 Label(连同始终显示的其它物件)淡入。
func _show_hint() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	# 先把所有 Label 藏起来,再随机选一条
	for item in _labels:
		if is_instance_valid(item):
			item.visible = false
	_active_items = _always_items.duplicate()
	if not _labels.is_empty():
		var chosen: CanvasItem = _labels[randi() % _labels.size()]
		if is_instance_valid(chosen):
			_active_items.append(chosen)
	if _active_items.is_empty():
		return
	_hint_tween = create_tween().set_parallel(true)
	_hint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for item in _active_items:
		if not is_instance_valid(item):
			continue
		var base: Color = _base_modulates.get(item.get_instance_id(), item.modulate)
		item.visible = true
		item.modulate = Color(base.r, base.g, base.b, 0.0)
		_hint_tween.tween_property(item, "modulate:a", base.a, hint_fade_duration)


## 离开:停留 hint_linger_duration 后再淡出消失。
func _hide_hint() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	if _active_items.is_empty():
		return
	_hint_tween = create_tween().set_parallel(true)
	_hint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for item in _active_items:
		if not is_instance_valid(item):
			continue
		_hint_tween.tween_property(item, "modulate:a", 0.0, hint_fade_duration).set_delay(hint_linger_duration)
	_hint_tween.chain().tween_callback(_set_active_hidden)


func _set_active_hidden() -> void:
	for item in _active_items:
		if is_instance_valid(item):
			item.visible = false


func _hide_all_now() -> void:
	for item in _labels + _always_items:
		if is_instance_valid(item):
			item.visible = false


func _cache_hint_nodes() -> void:
	_labels.clear()
	_always_items.clear()
	_base_modulates.clear()
	for child in get_children():
		if child is Area2D:
			continue
		_collect_hint_canvas_items(child)


func _collect_hint_canvas_items(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		_base_modulates[canvas_item.get_instance_id()] = canvas_item.modulate
		if node is Label:
			_labels.append(canvas_item)
		else:
			_always_items.append(canvas_item)
	for child in node.get_children():
		_collect_hint_canvas_items(child)
