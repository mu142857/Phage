# res://systems/state_machine/state_manager.gd
class_name StateManager
extends Node

@export var initial_state_index: int = 1

var states_array: Array = []
var current: BasicState = null
var host: Node = null

func _ready() -> void:
	host = get_parent()
	states_array = get_children()
	for state in states_array:
		if state is BasicState:
			(state as BasicState).host = host
	if states_array.is_empty():
		return
	var start_index := clampi(initial_state_index, 0, states_array.size() - 1)
	current = states_array[start_index] as BasicState
	if current != null:
		current.enter()

func _physics_process(delta: float) -> void:
	if current != null:
		current.process(delta)

func change_state(id: int) -> void:
	if states_array.is_empty():
		return
	if id < 0 or id >= states_array.size():
		return
	if current != null:
		current.exit()
	current = states_array[id] as BasicState
	if current != null:
		current.enter()
