# res://systems/state_machine/basic_state.gd
class_name BasicState
extends Node

@export var state_id: StringName = &""
var host: Node = null

func enter() -> void:
	pass

func process(_delta: float) -> void:
	pass

func exit() -> void:
	pass

func change_state(next_state_id: int) -> void:
	if host != null and host.has_method("change_state"):
		host.change_state(next_state_id)
