extends Marker2D

@export_file("*.tscn") var scene_path: String = ""
@export var teleport_id: int = 0
@export var player_light: bool = false

var _transported: bool = false

func _ready() -> void:
	add_to_group("teleport")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if _transported:
		return
	if body is Player:
		_transported = true
		Game.change_scene(scene_path, teleport_id, player_light)
