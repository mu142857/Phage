extends Node2D

@export var pop_tops_scene: PackedScene = preload("res://entities/pop_tops/pop_tops.tscn")
@export var camera_limit_top: int = 0
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = -80
@export var camera_limit_right: int = 1325


func _ready() -> void:
	add_to_group("camera_follow")

func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}
