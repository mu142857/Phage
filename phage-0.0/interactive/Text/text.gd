extends Marker2D

@export var hint_fade_duration: float = 0.12

var _hint_tween: Tween = null
var _hint_canvas_items: Array[CanvasItem] = []
var _hint_base_modulates: Dictionary = {}


func _ready() -> void:
	_cache_hint_nodes()
	_set_hint_visible(false)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		_set_hint_visible(true)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		_set_hint_visible(false)


func _set_hint_visible(visible: bool) -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
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
