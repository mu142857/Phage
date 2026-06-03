extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

var finished_once: bool = false

func enter() -> void:
	finished_once = false
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Crystallization")

func exit() -> void:
	finished_once = true

func _on_animated_sprite_2d_animation_finished() -> void:
	if finished_once:
		return
	finished_once = true
	if boss != null:
		boss.visible = false
		boss.start_crystallization_wait()
