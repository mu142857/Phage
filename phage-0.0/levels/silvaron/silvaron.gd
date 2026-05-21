extends Node2D

@export var pop_tops_scene: PackedScene = preload("res://entities/pop_tops/pop_tops.tscn")
@export var camera_limit_top: int = -100000
@export var camera_limit_bottom: int = 410
@export var camera_limit_left: int = 0
@export var camera_limit_right: int = 1365.0

const POP_TOPS_SPAWN_POINTS: Array[NodePath] = [
	NodePath("PopTopsPosition1"),
	NodePath("PopTopsPosition2"),
]

var _pop_tops_by_slot: Array[CharacterBody2D] = []

func _ready() -> void:
	add_to_group("camera_follow")
	_spawn_pop_tops()

func _spawn_pop_tops() -> void:
	if pop_tops_scene == null:
		return
	_pop_tops_by_slot.resize(POP_TOPS_SPAWN_POINTS.size())
	for index in range(POP_TOPS_SPAWN_POINTS.size()):
		_spawn_pop_tops_at(index)

func _spawn_pop_tops_at(slot_index: int) -> void:
	if pop_tops_scene == null:
		return
	if slot_index < 0 or slot_index >= POP_TOPS_SPAWN_POINTS.size():
		return
	var spawn_node := get_node_or_null(POP_TOPS_SPAWN_POINTS[slot_index]) as Node2D
	if spawn_node == null:
		return
	var pop_tops := pop_tops_scene.instantiate() as CharacterBody2D
	if pop_tops == null:
		return
	add_child(pop_tops)
	pop_tops.global_position = spawn_node.global_position
	_pop_tops_by_slot[slot_index] = pop_tops

func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}
