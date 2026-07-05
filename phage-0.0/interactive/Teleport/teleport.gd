
extends Marker2D

@export_file("*.tscn") var scene_path: String = ""
@export var teleport_id: int = 0
@export var player_light: bool = false
@export var hint_fade_duration: float = 0.12
## 默认是否激活。Boss 房里设为 false:未激活时不显示文字、无法交互,
## 直到 Boss 被击败后由外部调用 activate() 打开。
@export var active: bool = true

var _player_inside: bool = false
var _tracked_player: Player = null
var _hint_visible: bool = false
var _hint_tween: Tween = null
var _hint_canvas_items: Array[CanvasItem] = []
var _hint_base_modulates: Dictionary = {}


func _ready() -> void:
	add_to_group("teleport")
	_cache_hint_nodes()
	_set_hint_visible(false)
	set_process(false)


## 由外部(如 Boss 被击败信号)调用,激活传送点。
func activate() -> void:
	if active:
		return
	active = true
	# 若玩家此刻正站在传送点内且可交互,立即显示提示。
	if _player_inside and is_instance_valid(_tracked_player) and not _tracked_player.input_locked:
		set_process(true)
		_set_hint_visible(true)


func _process(_delta: float) -> void:
	if not active:
		return
	if not _player_inside:
		return
	if not is_instance_valid(_tracked_player):
		return
	if _tracked_player.input_locked:
		if _hint_visible:
			_set_hint_visible(false)
		return
	if not _hint_visible:
		_set_hint_visible(true)
	if Input.is_action_just_pressed("Select"):
		Game.change_scene(scene_path, teleport_id, player_light)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		_tracked_player = body
		_player_inside = true
		set_process(true)
		if active and not body.input_locked:
			_set_hint_visible(true)

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
