extends Node2D

func _on_player_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		pass


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		pass

func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.
