extends Node
func _ready() -> void:
	call_deferred("_go")
func _go() -> void:
	get_parent().remove_child(self)
	get_tree().root.add_child(self)
	for i in 20: await get_tree().process_frame
	var p: Node2D = get_tree().current_scene.get_node("Player")
	p.global_position = Vector2(753, 76)
	for i in 30: await get_tree().process_frame
	Input.action_press("Select"); await get_tree().process_frame; await get_tree().process_frame; Input.action_release("Select")
	for i in 90: await get_tree().process_frame
	print("AFTER_Q ", get_tree().current_scene.scene_file_path)
	get_tree().quit()
