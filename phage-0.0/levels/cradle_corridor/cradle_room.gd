# 珊瑚摇篮的横向长房间(房间1/房间2/22 房)公用脚本:只管相机限位,小怪以后再加。
extends Node2D

@export var camera_limit_top: int = 0
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = 0
@export var camera_limit_right: int = 1836


func _ready() -> void:
	add_to_group("camera_follow")


func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}
