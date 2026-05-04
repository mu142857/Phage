# res://systems/state_machine/state_manager.gd
class_name StateManager
extends Node

@export var initial_state_index: int = 1

var states_array: Array = []
var current_state: Node = null
var current_state_index: int = -1
var host: Node = null

func _ready() -> void:
	host = get_parent()
	states_array = get_children()
	for state in states_array:
		if state is BasicState:
			(state as BasicState).host = host
	_start_initial_state()

func _start_initial_state() -> void:
	if states_array.is_empty():
		return
	var start_index := clampi(initial_state_index, 0, states_array.size() - 1)
	current_state_index = start_index
	current_state = states_array[current_state_index]
	_call_state_method(current_state, &"enter")

func _physics_process(delta: float) -> void:
	if current_state != null:
		_call_state_method(current_state, &"process", [delta])

func change_state(id: int) -> void:
	if states_array.is_empty():
		return
	if id < 0 or id >= states_array.size():
		return
	if current_state_index == id:
		return
	var next_state: Node = states_array[id]
	if current_state != null:
		_call_state_method(current_state, &"exit")
	current_state = next_state
	current_state_index = id
	_call_state_method(current_state, &"enter")

func _call_state_method(state: Node, method_name: StringName, args: Array = []) -> void:
	if state.has_method(method_name):
		state.callv(method_name, args)

func get_current_state_index() -> int:
	return current_state_index
