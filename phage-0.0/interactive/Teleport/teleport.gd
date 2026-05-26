
extends Marker2D

@export_file("*.tscn") var scene_path: String = ""
@export var teleport_id: int = 0
@export var player_light: bool = false

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("teleport")
	_set_hint_visible(false)
	set_process(false)


func _process(_delta: float) -> void:
	if not _player_inside:
		return
	if Input.is_action_just_pressed("Select"):
		Game.change_scene(scene_path, teleport_id, player_light)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		_set_hint_visible(true)
		set_process(true)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_set_hint_visible(false)
		set_process(false)


func _set_hint_visible(visible: bool) -> void:
	for child in get_children():
		if child is Area2D:
			continue
		_set_canvas_item_visible_recursive(child, visible)


func _set_canvas_item_visible_recursive(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		node.visible = visible
	for child in node.get_children():
		_set_canvas_item_visible_recursive(child, visible)
