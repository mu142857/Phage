# res://systems/map_element_counting.gd
extends Node

signal wall_state_changed(wall_id: StringName, intact: bool)

const BROKEN_WALL_001_ID: StringName = &"spawn_room/BrokenWall001"

var _wall_states: Dictionary = {}


func is_wall_intact(wall_id: StringName) -> bool:
	if wall_id == &"":
		return true
	return _wall_states.get(wall_id, true)


func set_wall_intact(wall_id: StringName, intact: bool) -> void:
	if wall_id == &"":
		return
	_wall_states[wall_id] = intact
	wall_state_changed.emit(wall_id, intact)


func mark_wall_broken(wall_id: StringName) -> void:
	set_wall_intact(wall_id, false)


func mark_wall_restored(wall_id: StringName) -> void:
	set_wall_intact(wall_id, true)


func is_broken_wall_001_intact() -> bool:
	return is_wall_intact(BROKEN_WALL_001_ID)


func mark_broken_wall_001_broken() -> void:
	mark_wall_broken(BROKEN_WALL_001_ID)


func mark_broken_wall_001_restored() -> void:
	mark_wall_restored(BROKEN_WALL_001_ID)
