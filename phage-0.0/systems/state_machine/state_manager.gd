# res://systems/state_machine/state_manager.gd
class_name StateManager
extends Node

@export var initial_state_id: StringName = &""

var states_by_id: Dictionary = {}
var current_state: BasicState = null
var current_state_id: StringName = &""
var host: Node = null

func _ready() -> void:
	host = get_parent()
	_register_states()
	_start_initial_state()

func _register_states() -> void:
	states_by_id.clear()
	for child in get_children():
		if not child is BasicState:
			continue
		var state: BasicState = child
		state.host = host
		var state_key: StringName = state.state_id
		if state_key == &"":
			state_key = StringName(state.name)
		states_by_id[state_key] = state

func _start_initial_state() -> void:
	if states_by_id.is_empty():
		return
	var start_state_id: StringName = initial_state_id
	if start_state_id == &"" or not states_by_id.has(start_state_id):
		start_state_id = &"idle"
	if not states_by_id.has(start_state_id):
		start_state_id = states_by_id.keys()[0]
	current_state_id = start_state_id
	current_state = states_by_id[current_state_id]
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.process(delta)

func change_state(id: StringName) -> void:
	if current_state_id == id:
		return
	var next_state: BasicState = states_by_id.get(id, null)
	if next_state == null:
		return
	if current_state != null:
		current_state.exit()
	current_state = next_state
	current_state_id = id
	current_state.enter()

func has_state(id: StringName) -> bool:
	return states_by_id.has(id)

func get_current_state_id() -> StringName:
	return current_state_id
