# =============================================================================
# Appear(4)  —  现身：在 Disappear 选好的悬浮点播 Appear 动画 → Skill(镰刀弹幕)
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.show()
	monster.face_player()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Appear")


func process(_delta: float) -> void:
	pass


func exit() -> void:
	pass


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == &"Appear":
		change_state(monster.STATE_SKILL)
