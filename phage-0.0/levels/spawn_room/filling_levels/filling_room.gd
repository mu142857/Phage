extends Node2D

@export var camera_limit_top: int = 0
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = 0
@export var camera_limit_right: int = 160


func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}
