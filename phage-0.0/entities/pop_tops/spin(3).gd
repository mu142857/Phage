extends BasicState

@export var spin_distance: float = 10.0

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

func enter() -> void:
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Spin")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)

func process(_delta: float) -> void:
	if monster != null and monster.has_method("is_player_close"):
		if not monster.call("is_player_close", spin_distance):
			change_state(1)

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	if ani_2D.animation == "Spin":
		get_parent().change_state(1)
