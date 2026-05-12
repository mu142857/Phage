extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"

func enter() -> void:
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Spin")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation == &"Spin":
		change_state(1)
